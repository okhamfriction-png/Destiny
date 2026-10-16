// Accès typés au modèle `project.json` (types générés par ts-rs dans ./bindings).
// Aucune règle métier ici : seulement de quoi lire un projet sans répéter les `switch`.

import type { Caption } from './bindings/Caption';
import type { GraphicItem } from './bindings/GraphicItem';
import type { MusicItem } from './bindings/MusicItem';
import type { Project } from './bindings/Project';
import type { SfxItem } from './bindings/SfxItem';
import type { Track } from './bindings/Track';
import type { VideoItem } from './bindings/VideoItem';
import type { VoiceItem } from './bindings/VoiceItem';

export type TrackKind = Track['kind'];
export type AnyItem = VideoItem | VoiceItem | MusicItem | SfxItem | GraphicItem | Caption;

/** Adresse d'un élément de timeline : piste (par id) + position dans la piste. */
export interface ItemRef {
	track: string;
	index: number;
}

/** Ordre d'affichage des pistes dans la timeline (haut → bas). */
export const TRACK_ORDER: TrackKind[] = ['graphics', 'video', 'voice', 'music', 'sfx', 'captions'];

export const TRACK_LABEL: Record<TrackKind, string> = {
	video: 'Vidéo',
	voice: 'Voix',
	music: 'Musique',
	sfx: 'Bruitages',
	graphics: 'Graphismes',
	captions: 'Sous-titres'
};

/** Durée minimale d'un élément après un trim (secondes). */
export const MIN_DUR = 0.1;

/** Fréquence de la timeline maîtresse (frames `rec` des sources). */
export const MASTER_FPS = 25;

export function findTrack(p: Project, id: string): Track | undefined {
	return p.tracks.find((t) => t.id === id);
}

export function getItem(p: Project, ref: ItemRef): AnyItem | undefined {
	return findTrack(p, ref.track)?.items[ref.index];
}

export function sameRef(a: ItemRef | null, b: ItemRef | null): boolean {
	return !!a && !!b && a.track === b.track && a.index === b.index;
}

/** Début et fin (secondes de la vidéo finale) d'un élément. */
export function itemSpan(kind: TrackKind, item: AnyItem, p?: Project): [number, number] {
	switch (kind) {
		case 'video':
		case 'voice': {
			const c = item as VideoItem | VoiceItem;
			return [c.at, c.at + (c.out - c.in)];
		}
		case 'music': {
			const m = item as MusicItem;
			const dur = m.dur ?? Math.max(MIN_DUR, (p ? projectDuration(p) : m.at + 10) - m.at);
			return [m.at, m.at + dur];
		}
		case 'sfx': {
			const s = item as SfxItem;
			return [s.at, s.at + 0.5];
		}
		case 'graphics': {
			const g = item as GraphicItem;
			return [g.at, g.at + g.dur];
		}
		case 'captions': {
			const c = item as Caption;
			return [c.start, c.end];
		}
	}
}

export function refSpan(p: Project, ref: ItemRef): [number, number] | null {
	const t = findTrack(p, ref.track);
	const it = t?.items[ref.index];
	return t && it ? itemSpan(t.kind, it, p) : null;
}

export function videoItems(p: Project): VideoItem[] {
	return p.tracks.flatMap((t) => (t.kind === 'video' ? t.items : []));
}

export function voiceItems(p: Project): VoiceItem[] {
	return p.tracks.flatMap((t) => (t.kind === 'voice' ? t.items : []));
}

export function graphics(p: Project): GraphicItem[] {
	return p.tracks.flatMap((t) => (t.kind === 'graphics' ? t.items : []));
}

export function captions(p: Project): Caption[] {
	return p.tracks.flatMap((t) => (t.kind === 'captions' ? t.items : []));
}

/** Durée de la vidéo finale : fin du dernier élément visuel (comme `Project::duration`). */
export function projectDuration(p: Project): number {
	let d = 0;
	for (const c of videoItems(p)) d = Math.max(d, c.at + c.out - c.in);
	for (const g of graphics(p)) d = Math.max(d, g.at + g.dur);
	return d;
}

/** Plan vidéo sous la tête de lecture `t` (le dernier posé l'emporte). */
export function clipAt(p: Project, t: number): VideoItem | undefined {
	let found: VideoItem | undefined;
	for (const c of videoItems(p)) if (t >= c.at && t < c.at + c.out - c.in) found = c;
	return found;
}

/** Début d'une source sur la timeline maîtresse (secondes). */
export function sourceOffset(p: Project, srcId: string): number {
	const s = p.sources.find((x) => x.id === srcId);
	return s ? s.rec / MASTER_FPS : 0;
}

/** Intervalle maître `[a, b]` couvert par un clip voix (pour les gates micros). */
export function voiceMasterSpan(p: Project, v: VoiceItem): [number, number] {
	const off = sourceOffset(p, v.src);
	return [off + v.in, off + v.out];
}

/** Libellé court d'un élément pour la timeline et l'historique. */
export function itemLabel(kind: TrackKind, item: AnyItem): string {
	switch (kind) {
		case 'video':
		case 'voice':
			return (item as VideoItem).id;
		case 'music':
			return (item as MusicItem).file.split('/').pop() ?? 'musique';
		case 'sfx':
			return (item as SfxItem).type;
		case 'captions':
			return (item as Caption).text;
		case 'graphics': {
			const g = item as GraphicItem;
			switch (g.type) {
				case 'kicker':
				case 'tag':
				case 'fin':
					return `${g.type} · ${g.text}`;
				case 'hook':
				case 'cta':
				case 'card':
				case 'dice':
					return `${g.type} · ${g.lines.join(' / ')}`;
				case 'lower':
					return `lower · ${g.name}`;
				default:
					return g.type;
			}
		}
	}
}

/** Complète les champs facultatifs (`serde(default)`) d'un projet lu tel quel. */
export function normalizeProject(raw: unknown): Project {
	const p = structuredClone(raw) as Project;
	p.sources ??= [];
	p.mics ??= [];
	p.tracks ??= [];
	p.mic_gates ??= {};
	p.markers ??= { music_hits: [], cuts: [] };
	p.markers.music_hits ??= [];
	p.markers.cuts ??= [];
	p.export ??= { targets: [] };
	for (const t of p.tracks) {
		if (t.kind === 'video') {
			for (const c of t.items) {
				c.crop ??= { cx: 0.5, cy: 0.5, zoom: 1 };
				c.fx ??= {};
			}
		}
	}
	return p;
}

/** Copie profonde (les éditions sont des fonctions pures). */
export function clone<T>(v: T): T {
	return structuredClone(v);
}
