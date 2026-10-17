// Éditions de la timeline : fonctions pures `Project → Project`.
// L'UI calcule le nouveau projet ici puis l'envoie au backend (`commit_project`),
// qui le valide, enregistre le diff pour l'undo et l'écrit sur disque.

import type { Caption } from './bindings/Caption';
import type { GraphicItem } from './bindings/GraphicItem';
import type { MusicItem } from './bindings/MusicItem';
import type { Project } from './bindings/Project';
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
	if (ripple) shiftAfter(next, e, -(e - s));
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
