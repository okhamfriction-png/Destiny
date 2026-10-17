// Éditions de la timeline : fonctions pures `Project → Project`.
// L'UI calcule le nouveau projet ici puis l'envoie au backend (`commit_project`),
// qui le valide, enregistre le diff pour l'undo et l'écrit sur disque.

import type { Caption } from './bindings/Caption';
import type { GraphicItem } from './bindings/GraphicItem';
import type { MusicItem } from './bindings/MusicItem';
import type { Project } from './bindings/Project';
import type { Source } from './bindings/Source';
import type { Track } from './bindings/Track';
import type { VideoItem } from './bindings/VideoItem';
import type { VoiceItem } from './bindings/VoiceItem';
import type { Word } from './bindings/Word';
import {
	captions,
	clone,
	findTrack,
	itemSpan,
	MIN_DUR,
	type AnyItem,
	type ItemRef
} from './project';

const EPS = 1e-6;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
/** Arrondi à la milliseconde : évite les 12.300000000000001 dans le JSON. */
const r3 = (v: number) => Math.round(v * 1000) / 1000;

/** Applique `fn` à une copie de l'élément visé ; renvoie le projet inchangé si la référence est invalide. */
export function updateItem<T extends AnyItem>(p: Project, ref: ItemRef, fn: (item: T, track: Track) => void): Project {
	const next = clone(p);
	const track = findTrack(next, ref.track);
	const item = track?.items[ref.index] as T | undefined;
	if (!track || !item) return p;
	fn(item, track);
	return next;
}

function shiftWords(words: Word[] | undefined, delta: number): Word[] | undefined {
	return words?.map((w) => ({ ...w, start: r3(w.start + delta), end: r3(w.end + delta) }));
}

/** Recale des mots horodatés de `[a0, b0]` vers `[a1, b1]` (proportionnellement). */
function rescaleWords(words: Word[] | undefined, a0: number, b0: number, a1: number, b1: number): Word[] | undefined {
	if (!words || words.length === 0 || b0 <= a0) return words;
	const k = (b1 - a1) / (b0 - a0);
	return words.map((w) => ({ ...w, start: r3(a1 + (w.start - a0) * k), end: r3(a1 + (w.end - a0) * k) }));
}

/** Déplace le début de l'élément à `at` (secondes de la vidéo finale, ≥ 0). */
export function moveItem(p: Project, ref: ItemRef, at: number): Project {
	const target = r3(Math.max(0, at));
	return updateItem(p, ref, (item, track) => {
		if (track.kind === 'captions') {
			const c = item as Caption;
			const delta = target - c.start;
			c.start = target;
			c.end = r3(c.end + delta);
			if (c.words?.length) c.words = shiftWords(c.words, delta);
		} else {
			(item as { at: number }).at = target;
		}
	});
}

/** Rallonge/raccourcit un élément par son bord gauche (`start`) ou droit (`end`),
 * en posant ce bord à l'instant `t`. Pour un plan vidéo/voix, `in`/`out` suivent
 * pour que l'image reste calée sur le même instant source. */
export function trimItem(p: Project, ref: ItemRef, edge: 'start' | 'end', t: number): Project {
	return updateItem(p, ref, (item, track) => {
		switch (track.kind) {
			case 'video':
			case 'voice': {
				const c = item as VideoItem | VoiceItem;
				const end = c.at + c.out - c.in;
				if (edge === 'start') {
					// Le bord gauche ne peut pas reculer avant le début du fichier source.
					const nt = clamp(t, Math.max(0, c.at - c.in), end - MIN_DUR);
					c.in = r3(c.in + (nt - c.at));
					c.at = r3(nt);
				} else {
					const srcDur = p.sources.find((s) => s.id === c.src)?.duration ?? Infinity;
					const nt = clamp(t, c.at + MIN_DUR, c.at + (srcDur - c.in));
					c.out = r3(c.in + (nt - c.at));
				}
				break;
			}
			case 'captions': {
				const c = item as Caption;
				const [a0, b0] = [c.start, c.end];
				if (edge === 'start') c.start = r3(clamp(t, 0, c.end - MIN_DUR));
				else c.end = r3(Math.max(t, c.start + MIN_DUR));
				if (c.words?.length) c.words = rescaleWords(c.words, a0, b0, c.start, c.end);
				break;
			}
			case 'graphics': {
				const g = item as GraphicItem;
				const end = g.at + g.dur;
				if (edge === 'start') {
					const nt = clamp(t, 0, end - MIN_DUR);
					g.at = r3(nt);
					g.dur = r3(end - nt);
				} else {
					g.dur = r3(Math.max(MIN_DUR, t - g.at));
				}
				break;
			}
			case 'music': {
				const m = item as MusicItem;
				if (edge === 'start') {
					// Le bord gauche recule au plus jusqu'au début du fichier musique.
					const nt = clamp(t, Math.max(0, m.at - m.offset), m.dur != null ? m.at + m.dur - MIN_DUR : Infinity);
					const delta = nt - m.at;
					m.at = r3(nt);
					m.offset = r3(m.offset + delta);
					if (m.dur != null) m.dur = r3(m.dur - delta);
				} else {
					m.dur = r3(Math.max(MIN_DUR, t - m.at));
				}
				break;
			}
			case 'sfx':
				// Un bruitage est ponctuel : pas de durée à rogner.
				break;
		}
	});
}

/** Identifiant libre de la forme `<prefix><n>` parmi les plans vidéo et voix. */
export function uniqueId(p: Project, prefix: string): string {
	const used = new Set(
		p.tracks.flatMap((t) => (t.kind === 'video' || t.kind === 'voice' ? t.items.map((i) => i.id) : []))
	);
	let n = 1;
	for (const id of used) {
		const m = id.match(new RegExp(`^${prefix}(\\d+)$`));
		if (m) n = Math.max(n, Number(m[1]) + 1);
	}
	while (used.has(`${prefix}${n}`)) n++;
	return `${prefix}${n}`;
}

/** Coupe un plan vidéo (ou voix) à l'instant `t` : deux éléments, le second avec un
 * nouvel identifiant. Le second hérite du recadrage mais pas du punch/flash d'entrée
 * (la coupe est une continuité) ; un punch-in est réparti entre les deux morceaux. */
export function splitItem(p: Project, ref: ItemRef, t: number, newId?: string): Project {
	const track = findTrack(p, ref.track);
	const item = track?.items[ref.index];
	if (!track || !item || (track.kind !== 'video' && track.kind !== 'voice')) return p;
	const c = item as VideoItem | VoiceItem;
	const end = c.at + c.out - c.in;
	if (t <= c.at + MIN_DUR - EPS || t >= end - MIN_DUR + EPS) return p;

	const next = clone(p);
	const nt = findTrack(next, ref.track)!;
	const first = nt.items[ref.index] as VideoItem | VoiceItem;
	const local = t - c.at;
	const cut = r3(c.in + local);
	const second = clone(first);
	second.id = newId ?? uniqueId(p, track.kind === 'video' ? 'c' : 'v');
	first.out = cut;
	second.in = cut;
	second.at = r3(t);

	if (track.kind === 'video') {
		const f = first as VideoItem;
		const s = second as VideoItem;
		delete s.fx.punch;
		delete s.fx.flash;
		const pi = f.fx.punch_in;
		if (pi) {
			const [a, b] = pi;
			f.fx.punch_in = a < local ? [a, r3(Math.min(b, local))] : null;
			s.fx.punch_in = b > local ? [r3(Math.max(0, a - local)), r3(b - local)] : null;
			if (f.fx.punch_in === null) delete f.fx.punch_in;
			if (s.fx.punch_in === null) delete s.fx.punch_in;
		}
	}
	(nt.items as (VideoItem | VoiceItem)[]).splice(ref.index + 1, 0, second);
	return next;
}

/** Supprime un élément (le trou reste). */
export function removeItem(p: Project, ref: ItemRef): Project {
	const next = clone(p);
	const track = findTrack(next, ref.track);
	if (!track || !track.items[ref.index]) return p;
	track.items.splice(ref.index, 1);
	return next;
}

/** Décale de `delta` le début de tous les éléments qui commencent à `from` ou après,
 * sur toutes les pistes (ainsi que les marqueurs). */
function shiftAfter(p: Project, from: number, delta: number): void {
	for (const track of p.tracks) {
		for (const item of track.items) {
			const [s] = itemSpan(track.kind, item);
			if (s < from - EPS) continue;
			if (track.kind === 'captions') {
				const c = item as Caption;
				c.start = r3(c.start + delta);
				c.end = r3(c.end + delta);
				if (c.words?.length) c.words = shiftWords(c.words, delta);
			} else {
				const it = item as { at: number };
				it.at = r3(Math.max(0, it.at + delta));
			}
		}
	}
	const shift = (xs: number[]) => xs.map((x) => (x >= from - EPS ? r3(x + delta) : x));
	p.markers = { music_hits: shift(p.markers.music_hits), cuts: shift(p.markers.cuts) };
}

/** Retire le temps `[a, b]` de la vidéo finale (montage magnétique, « ripple » de DaVinci) :
 * ce qui commence après `b` recule de `b − a` sur toutes les pistes ; les graphismes et la
 * musique qui enjambent l'intervalle raccourcissent d'autant (l'accroche, le sur-titre et la
 * barre de progression d'un short gardent la durée du montage) ; les sous-titres entièrement
 * dedans disparaissent, ceux qui débordent sont rognés. Les plans vidéo/voix qui chevauchent
 * ne sont pas touchés (c'est à l'appelant de les avoir retirés ou rognés). Modifie `p`. */
function rippleClose(p: Project, a: number, b: number): void {
	const d = b - a;
	if (d <= EPS) return;
	for (const track of p.tracks) {
		if (track.kind === 'captions') {
			const caps = track.items as Caption[];
			for (let i = caps.length - 1; i >= 0; i--) {
				const c = caps[i];
				if (c.start >= b - EPS || c.end <= a + EPS) continue;
				const r = clip(c.start, c.end, a, b);
				if (!r) caps.splice(i, 1);
				else {
					c.start = r[0];
					c.end = r[1];
					c.words = undefined;
				}
			}
		} else if (track.kind === 'graphics') {
			const gs = track.items as GraphicItem[];
			for (let i = gs.length - 1; i >= 0; i--) {
				const g = gs[i];
				if (g.at >= b - EPS || g.at + g.dur <= a + EPS) continue;
				const r = clip(g.at, g.at + g.dur, a, b);
				if (!r) gs.splice(i, 1);
				else {
					g.at = r[0];
					g.dur = r3(r[1] - r[0]);
				}
			}
		} else if (track.kind === 'music') {
			for (const m of track.items as MusicItem[]) {
				if (m.dur == null || m.at >= b - EPS || m.at + m.dur <= a + EPS) continue;
				const r = clip(m.at, m.at + m.dur, a, b);
				if (!r) continue;
				// La musique qui commençait dans le trou reprend plus loin dans le fichier.
				if (m.at > a) m.offset = r3(m.offset + (Math.min(b, m.at + m.dur) - m.at));
				m.at = r[0];
				m.dur = r3(r[1] - r[0]);
			}
		}
	}
	shiftAfter(p, b, -d);
}

/** `[s, e]` privé de `[a, b]` (qui le chevauche) : la partie avant `a` plus la partie après
 * `b` ramenée à `a`. `null` si l'élément était entièrement dedans. */
function clip(s: number, e: number, a: number, b: number): [number, number] | null {
	if (s >= a - EPS && e <= b + EPS) return null;
	const ns = Math.min(s, a);
	const ne = ns + Math.max(0, Math.min(e, a) - s) + Math.max(0, e - Math.max(b, s));
	return [r3(ns), r3(Math.max(ns + MIN_DUR, ne))];
}

/** Ouvre `d` secondes à l'instant `a` (rallonge magnétique) : ce qui commence à `a` ou après
 * avance de `d`, les graphismes et la musique qui enjambent `a` s'allongent d'autant. */
function rippleOpen(p: Project, a: number, d: number): void {
	if (d <= EPS) return;
	for (const track of p.tracks) {
		if (track.kind === 'graphics') {
			for (const g of track.items as GraphicItem[]) if (g.at < a - EPS && g.at + g.dur > a - EPS) g.dur = r3(g.dur + d);
		} else if (track.kind === 'music') {
			for (const m of track.items as MusicItem[]) if (m.dur != null && m.at < a - EPS && m.at + m.dur > a - EPS) m.dur = r3(m.dur + d);
		}
	}
	shiftAfter(p, a, d);
}

/** Rogne un groupe de plans en mode magnétique : le plan garde sa place, et tout ce qui le
 * suit se rapproche ou s'écarte pour qu'il n'y ait ni trou ni chevauchement. Bord gauche :
 * l'image de départ change (comme le trim « ripple » de DaVinci), pas la position du plan. */
export function rippleTrimGroup(p: Project, refs: ItemRef[], edge: 'start' | 'end', t: number): Project {
	const first = findTrack(p, refs[0]?.track ?? '');
	const it = first?.items[refs[0].index];
	if (!first || !it || (first.kind !== 'video' && first.kind !== 'voice' && first.kind !== 'music')) return trimGroup(p, refs, edge, t);
	const [s, e] = itemSpan(first.kind, it, p);
	// Nouvelle durée voulue, puis rognage par la fin (le début reste en place).
	const want = edge === 'end' ? t - s : e - t;
	let next = clone(p);
	let applied = 0;
	for (const r of refs) {
		const tr = findTrack(next, r.track);
		const x = tr?.items[r.index];
		if (!tr || !x) continue;
		if (tr.kind === 'video' || tr.kind === 'voice') {
			const c = x as VideoItem | VoiceItem;
			const srcDur = next.sources.find((q) => q.id === c.src)?.duration ?? Infinity;
			const len = c.out - c.in;
			const nl = clamp(want, MIN_DUR, edge === 'end' ? srcDur - c.in : c.out);
			if (edge === 'end') c.out = r3(c.in + nl);
			else c.in = r3(c.out - nl);
			applied = nl - len;
		} else if (tr.kind === 'music') {
			const m = x as MusicItem;
			const len = (m.dur ?? e - s);
			const nl = Math.max(MIN_DUR, want);
			if (edge === 'start') m.offset = r3(Math.max(0, m.offset + (len - nl)));
			m.dur = r3(nl);
			applied = nl - len;
		}
	}
	if (applied < -EPS) rippleCloseExcept(next, e + applied, e, refs);
	else if (applied > EPS) rippleOpenExcept(next, e, applied, refs);
	return next;
}

/** `rippleClose` / `rippleOpen` sans toucher au groupe qu'on vient de rogner. */
function rippleCloseExcept(p: Project, a: number, b: number, keep: ItemRef[]): void {
	withHeld(p, keep, () => rippleClose(p, a, b));
}
function rippleOpenExcept(p: Project, a: number, d: number, keep: ItemRef[]): void {
	withHeld(p, keep, () => rippleOpen(p, a, d));
}
/** Sort temporairement les éléments `keep` du projet pendant `fn` (ils ne bougent pas). */
function withHeld(p: Project, keep: ItemRef[], fn: () => void): void {
	const held = [...keep].sort((x, y) => y.index - x.index).map((r) => {
		const t = findTrack(p, r.track)!;
		return { t, index: r.index, item: t.items.splice(r.index, 1)[0] };
	});
	fn();
	for (const h of held.reverse()) (h.t.items as AnyItem[]).splice(h.index, 0, h.item);
}

/** Coupe toutes les pistes à l'instant `t` (S, comme le ⌘B de DaVinci) : plans vidéo, voix
 * et musique qui enjambent `t`, sauf sur les pistes de `skip` (verrouillées). Les sous-titres
 * et graphismes, qui sont des habillages, ne sont pas coupés. */
export function splitAll(p: Project, t: number, skip: Partial<Record<string, boolean>> = {}): Project {
	let next = p;
	for (const track of p.tracks) {
		if (skip[track.kind]) continue;
		if (track.kind !== 'video' && track.kind !== 'voice' && track.kind !== 'music') continue;
		const index = track.items.findIndex((it) => {
			const [s, e] = itemSpan(track.kind, it, p);
			return s < t - MIN_DUR + EPS && e > t + MIN_DUR - EPS;
		});
		if (index < 0) continue;
		if (track.kind === 'music') {
			next = clone(next);
			const tr = findTrack(next, track.id)!;
			const m = tr.items[index] as MusicItem;
			const [s, e] = itemSpan('music', m, next);
			const second: MusicItem = { ...clone(m), at: r3(t), offset: r3(m.offset + (t - s)), dur: m.dur != null ? r3(e - t) : null };
			if (m.gain_env) second.gain_env = m.gain_env.filter(([x]) => x >= t);
			m.dur = r3(t - s);
			if (m.gain_env) m.gain_env = m.gain_env.filter(([x]) => x <= t);
			(tr.items as MusicItem[]).splice(index + 1, 0, second);
		} else {
			next = splitItem(next, { track: track.id, index }, t);
		}
	}
	return next;
}

/** Ferme les trous de V1 : chaque plan vidéo est recollé au précédent, et tout ce qui suit
 * un trou (toutes pistes) recule d'autant. */
export function closeGaps(p: Project): Project {
	const next = clone(p);
	const v = next.tracks.find((t) => t.kind === 'video');
	if (!v) return p;
	let changed = false;
	for (;;) {
		const spans = (v.items as VideoItem[]).map((c) => [c.at, c.at + c.out - c.in]).sort((x, y) => x[0] - y[0]);
		let end = 0;
		let gap: [number, number] | null = null;
		for (const [s, e] of spans) {
			if (s > end + 0.01) {
				gap = [end, s];
				break;
			}
			end = Math.max(end, e);
		}
		if (!gap) break;
		rippleClose(next, gap[0], gap[1]);
		changed = true;
	}
	return changed ? next : p;
}

/** Supprime avec raccord : l'élément disparaît et tout ce qui commence après sa fin
 * (toutes pistes confondues, pour garder voix, sous-titres et graphismes synchrones)
 * recule de sa durée. */
export function rippleDelete(p: Project, ref: ItemRef): Project {
	const track = findTrack(p, ref.track);
	const item = track?.items[ref.index];
	if (!track || !item) return p;
	const [s, e] = itemSpan(track.kind, item, p);
	const next = removeItem(p, ref);
	shiftAfter(next, e, -(e - s));
	return next;
}

// ---------------------------------------------------------------------------
// Plans liés (sélection liée de DaVinci)
// ---------------------------------------------------------------------------

const near = (a: number, b: number) => Math.abs(a - b) < 0.02;

/** Le plan visé et ses plans liés : un plan vidéo et la voix de même découpe (même
 * source, même `in`/`out`, même position), comme les propositions les génèrent. Ils se
 * déplacent, se rognent, se coupent et se suppriment ensemble. */
export function linkedRefs(p: Project, ref: ItemRef): ItemRef[] {
	const track = findTrack(p, ref.track);
	const item = track?.items[ref.index];
	if (!track || !item || (track.kind !== 'video' && track.kind !== 'voice')) return [ref];
	const c = item as VideoItem | VoiceItem;
	const other = track.kind === 'video' ? 'voice' : 'video';
	const out = [ref];
	for (const t of p.tracks) {
		if (t.kind !== other) continue;
		t.items.forEach((x, index) => {
			const o = x as VideoItem | VoiceItem;
			if (o.src === c.src && near(o.at, c.at) && near(o.in, c.in) && near(o.out, c.out)) out.push({ track: t.id, index });
		});
	}
	return out;
}

/** Déplace un groupe de plans du même `delta` (secondes), chacun depuis sa position. */
export function moveGroup(p: Project, refs: ItemRef[], delta: number): Project {
	// Le groupe bute à 0 ensemble : aucun plan ne se décale par rapport aux autres.
	const starts = refs.map((r) => {
		const t = findTrack(p, r.track);
		return t ? itemSpan(t.kind, t.items[r.index], p)[0] : 0;
	});
	const d = Math.max(delta, -Math.min(...starts));
	return refs.reduce((q, r, i) => moveItem(q, r, starts[i] + d), p);
}

/** Rogne tous les plans du groupe au même bord. */
export function trimGroup(p: Project, refs: ItemRef[], edge: 'start' | 'end', t: number): Project {
	return refs.reduce((q, r) => trimItem(q, r, edge, t), p);
}

/** Coupe tous les plans du groupe à l'instant `t` (chacun sur sa piste). */
export function splitGroup(p: Project, refs: ItemRef[], t: number): Project {
	return refs.reduce((q, r) => splitItem(q, r, t), p);
}

/** Supprime le groupe ; avec `ripple`, tout ce qui suit recule de la durée du premier. */
export function removeGroup(p: Project, refs: ItemRef[], ripple = false): Project {
	const first = findTrack(p, refs[0]?.track ?? '');
	if (!first || !first.items[refs[0].index]) return p;
	const [s, e] = itemSpan(first.kind, first.items[refs[0].index], p);
	// Indices décroissants : retirer un élément ne décale pas les suivants à retirer.
	const sorted = [...refs].sort((a, b) => b.index - a.index);
	const next = sorted.reduce((q, r) => removeItem(q, r), p);
	if (ripple) rippleClose(next, s, e);
	return next;
}

/** Points de montage (débuts et fins de plans vidéo), triés : ↑/↓ y sautent. */
export function editPoints(p: Project): number[] {
	const pts = new Set<number>([0]);
	for (const t of p.tracks) {
		if (t.kind !== 'video') continue;
		for (const it of t.items) {
			const [a, b] = itemSpan(t.kind, it, p);
			pts.add(r3(a));
			pts.add(r3(b));
		}
	}
	return [...pts].sort((a, b) => a - b);
}

// ---------------------------------------------------------------------------
// Ajout d'un rush (visualiseur source → timeline), comme F9 / F10 de DaVinci
// ---------------------------------------------------------------------------

/** Un morceau de rush choisi dans le visualiseur source (temps du fichier). */
export interface SourceClip {
	source: Source;
	in: number;
	out: number;
}

export type PlaceMode = 'overwrite' | 'insert';

/** Première piste du genre demandé, créée vide si le montage n'en a pas. */
function ensureTrack(p: Project, kind: 'video' | 'voice'): Track {
	let t = p.tracks.find((x) => x.kind === kind);
	if (!t) {
		const base = kind === 'video' ? 'v0' : 'a_voice';
		let id = base;
		for (let k = 2; p.tracks.some((x) => x.id === id); k++) id = `${base}_${k}`;
		t = { kind, id, items: [] } as Track;
		p.tracks.push(t);
	}
	return t;
}

/** Libère `[a, b]` sur une piste vidéo ou voix (modifie `p`) : ce qui est dedans part,
 * ce qui déborde est rogné, ce qui couvre tout l'intervalle est coupé en deux. */
function clearRange(p: Project, track: Track, a: number, b: number): void {
	const items = track.items as (VideoItem | VoiceItem)[];
	for (let i = items.length - 1; i >= 0; i--) {
		const c = items[i];
		const s = c.at;
		const e = c.at + c.out - c.in;
		if (e <= a + EPS || s >= b - EPS) continue;
		if (s >= a - EPS && e <= b + EPS) {
			items.splice(i, 1);
		} else if (s < a && e > b) {
			const right = clone(c);
			right.id = uniqueId(p, track.kind === 'video' ? 'c' : 'v');
			right.in = r3(c.in + (b - c.at));
			right.at = r3(b);
			if (track.kind === 'video') {
				delete (right as VideoItem).fx.punch;
				delete (right as VideoItem).fx.flash;
				delete (right as VideoItem).fx.punch_in;
			}
			c.out = r3(c.in + (a - c.at));
			items.splice(i + 1, 0, right);
		} else if (s < a) {
			c.out = r3(c.in + (a - c.at));
		} else {
			c.in = r3(c.in + (b - c.at));
			c.at = r3(b);
		}
	}
}

/** Fin du dernier plan vidéo (« ajouter à la fin »). */
export function videoEnd(p: Project): number {
	let end = 0;
	for (const t of p.tracks) if (t.kind === 'video') for (const c of t.items) end = Math.max(end, c.at + c.out - c.in);
	return r3(end);
}

/** Pose un morceau de rush à l'instant `at` sur V1 et A1 (plan vidéo + voix liés).
 * `overwrite` remplace ce qui occupe la place ; `insert` coupe à `at` et pousse tout ce
 * qui suit (toutes pistes) de la durée du morceau. La source est ajoutée au montage si
 * elle n'y est pas encore. Renvoie le projet et la référence du nouveau plan vidéo. */
export function placeClip(p: Project, clip: SourceClip, at: number, mode: PlaceMode): { project: Project; ref: ItemRef } {
	const d = r3(clip.out - clip.in);
	const t0 = r3(Math.max(0, at));
	let next = clone(p);
	// Source : même identifiant et même fichier → réutilisée ; identifiant pris par un autre
	// fichier → renommée.
	let src = next.sources.find((s) => s.id === clip.source.id && s.path === clip.source.path);
	if (!src) {
		src = clone(clip.source);
		const base = src.id;
		for (let k = 2; next.sources.some((s) => s.id === src!.id); k++) src.id = `${base}_${k}`;
		next.sources.push(src);
	}
	if (mode === 'insert') {
		// Coupe les plans à cheval sur `at`, puis décale tout ce qui commence après.
		for (const t of next.tracks) {
			if (t.kind !== 'video' && t.kind !== 'voice') continue;
			const index = t.items.findIndex((c) => c.at < t0 - EPS && c.at + c.out - c.in > t0 + EPS);
			if (index >= 0) next = splitItem(next, { track: t.id, index }, t0);
		}
		shiftAfter(next, t0, d);
	}
	const video = ensureTrack(next, 'video');
	const voice = ensureTrack(next, 'voice');
	if (mode === 'overwrite') {
		clearRange(next, video, t0, t0 + d);
		clearRange(next, voice, t0, t0 + d);
	}
	const base = { src: src.id, in: r3(clip.in), out: r3(clip.out), at: t0 };
	const v: VideoItem = { id: uniqueId(next, 'c'), ...base, crop: { cx: 0.5, cy: 0.5, zoom: 1 }, fx: {} };
	const a: VoiceItem = { id: uniqueId(next, 'v'), ...base };
	// Rangés dans l'ordre chronologique, comme les propositions.
	const put = <T extends { at: number }>(items: T[], it: T) => {
		const i = items.findIndex((x) => x.at > t0 + EPS);
		const index = i < 0 ? items.length : i;
		items.splice(index, 0, it);
		return index;
	};
	const index = put(video.items as VideoItem[], v);
	put(voice.items as VoiceItem[], a);
	return { project: next, ref: { track: video.id, index } };
}

// ---------------------------------------------------------------------------
// Aimantation
// ---------------------------------------------------------------------------

export interface SnapResult {
	/** Instant aimanté (ou l'instant d'origine). */
	t: number;
	/** Cible atteinte, `null` si rien n'était assez proche. */
	target: number | null;
}

/** Aimante `t` sur la cible la plus proche à moins de `threshold` secondes. */
export function snap(t: number, targets: number[], threshold: number): SnapResult {
	let best: number | null = null;
	for (const x of targets) {
		if (Math.abs(x - t) <= threshold && (best === null || Math.abs(x - t) < Math.abs(best - t))) best = x;
	}
	return { t: best ?? t, target: best };
}

/** Aimante un intervalle déplacé en bloc : le bord (début ou fin) le plus proche d'une
 * cible l'emporte. Renvoie le nouveau début. */
export function snapSpan(start: number, end: number, targets: number[], threshold: number): SnapResult {
	const a = snap(start, targets, threshold);
	const b = snap(end, targets, threshold);
	const da = a.target === null ? Infinity : Math.abs(a.target - start);
	const db = b.target === null ? Infinity : Math.abs(b.target - end);
	if (da === Infinity && db === Infinity) return { t: start, target: null };
	return da <= db ? { t: a.t, target: a.target } : { t: start + (b.t - end), target: b.target };
}

/** Cibles d'aimantation : tête de lecture, bords des autres éléments, coups de musique,
 * coupes et débuts de répliques. */
export function snapTargets(p: Project, playhead: number, exclude?: ItemRef | null): number[] {
	const out = new Set<number>([0, playhead]);
	for (const track of p.tracks) {
		track.items.forEach((item, index) => {
			if (exclude && exclude.track === track.id && exclude.index === index) return;
			const [s, e] = itemSpan(track.kind, item, p);
			out.add(s);
			out.add(e);
		});
	}
	for (const t of p.markers.music_hits) out.add(t);
	for (const t of p.markers.cuts) out.add(t);
	for (const c of captions(p)) out.add(c.start);
	return [...out].sort((a, b) => a - b);
}

// ---------------------------------------------------------------------------
// Micros, dictionnaire
// ---------------------------------------------------------------------------

/** Intervalles d'ouverture effectifs d'un micro (absent de la table = ouvert partout). */
export function micIntervals(p: Project, mic: string): [number, number][] {
	return p.mic_gates[mic] ?? [[0, 1e9]];
}

function mergeIntervals(xs: [number, number][]): [number, number][] {
	const sorted = xs.filter(([a, b]) => b > a).sort((x, y) => x[0] - y[0]);
	const out: [number, number][] = [];
	for (const [a, b] of sorted) {
		const last = out[out.length - 1];
		if (last && a <= last[1] + EPS) last[1] = Math.max(last[1], b);
		else out.push([a, b]);
	}
	return out;
}

/** Ouvre ou ferme un micro sur l'intervalle maître `[a, b]`. */
export function setMicOpen(p: Project, mic: string, a: number, b: number, open: boolean): Project {
	const next = clone(p);
	const cur = micIntervals(p, mic);
	let res: [number, number][];
	if (open) {
		res = mergeIntervals([...cur.map((x) => [...x] as [number, number]), [a, b]]);
	} else {
		res = [];
		for (const [x, y] of cur) {
			if (y <= a || x >= b) res.push([x, y]);
			else {
				if (x < a) res.push([x, a]);
				if (y > b) res.push([b, y]);
			}
		}
		res = mergeIntervals(res);
	}
	next.mic_gates = { ...next.mic_gates, [mic]: res.map(([x, y]) => [r3(x), r3(y)]) };
	return next;
}

/** État d'un micro sur `[a, b]` : ouvert partout, fermé partout, ou partiel. */
export function micState(p: Project, mic: string, a: number, b: number): 'open' | 'closed' | 'partial' {
	let covered = 0;
	for (const [x, y] of micIntervals(p, mic)) covered += Math.max(0, Math.min(y, b) - Math.max(x, a));
	const len = b - a;
	if (covered >= len - 1e-3) return 'open';
	if (covered <= 1e-3) return 'closed';
	return 'partial';
}

/** Ajoute (ou remplace) une correction ASR au dictionnaire du projet. */
export function addDictionaryEntry(p: Project, wrong: string, right: string): Project {
	const next = clone(p);
	next.dictionary = { ...(next.dictionary ?? {}), [wrong]: right };
	return next;
}

export function removeDictionaryEntry(p: Project, wrong: string): Project {
	const next = clone(p);
	const d = { ...(next.dictionary ?? {}) };
	delete d[wrong];
	next.dictionary = d;
	return next;
}
