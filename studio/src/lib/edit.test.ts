import { describe, expect, it } from 'vitest';
import serpent from '../../examples/serpent/project.json';
import type { Project } from './bindings/Project';
import type { VideoItem } from './bindings/VideoItem';
import type { Caption } from './bindings/Caption';
import type { GraphicItem } from './bindings/GraphicItem';
import {
	addDictionaryEntry,
	editPoints,
	linkedRefs,
	moveGroup,
	placeClip,
	videoEnd,
	removeGroup,
	splitGroup,
	micState,
	moveItem,
	removeItem,
	rippleDelete,
	setMicOpen,
	snap,
	snapSpan,
	snapTargets,
	splitItem,
	trimItem,
	uniqueId
} from './edit';
import { normalizeProject, findTrack, projectDuration } from './project';

const base = (): Project => normalizeProject(serpent);
const video = (p: Project) => findTrack(p, 'v0')!.items as VideoItem[];
const caps = (p: Project) => findTrack(p, 'subs')!.items as Caption[];
const gfx = (p: Project) => findTrack(p, 'g_text')!.items as GraphicItem[];

describe('moveItem', () => {
	it('déplace un plan vidéo sans toucher in/out', () => {
		const p = base();
		const q = moveItem(p, { track: 'v0', index: 1 }, 70);
		expect(video(q)[1]).toMatchObject({ at: 70, in: 5327.1, out: 5331.1 });
		// fonction pure
		expect(video(p)[1].at).toBe(62.5);
	});

	it('refuse un temps négatif', () => {
		expect(video(moveItem(base(), { track: 'v0', index: 0 }, -3))[0].at).toBe(0);
	});

	it('déplace un sous-titre en gardant sa durée', () => {
		const q = moveItem(base(), { track: 'subs', index: 0 }, 1.4);
		expect(caps(q)[0].start).toBeCloseTo(1.4);
		expect(caps(q)[0].end).toBeCloseTo(3.4);
	});

	it('référence invalide : projet inchangé', () => {
		const p = base();
		expect(moveItem(p, { track: 'nope', index: 0 }, 1)).toBe(p);
	});
});

describe('trimItem', () => {
	it('bord gauche vidéo : at et in avancent ensemble, la fin reste', () => {
		const q = trimItem(base(), { track: 'v0', index: 1 }, 'start', 63.5);
		const c = video(q)[1];
		expect(c.at).toBeCloseTo(63.5);
		expect(c.in).toBeCloseTo(5328.1);
		expect(c.out).toBeCloseTo(5331.1);
	});

	it('bord droit vidéo : out suit', () => {
		const c = video(trimItem(base(), { track: 'v0', index: 0 }, 'end', 50))[0];
		expect(c.out).toBeCloseTo(5314.6);
		expect(c.at).toBe(0);
	});

	it('ne descend pas sous la durée minimale', () => {
		const c = video(trimItem(base(), { track: 'v0', index: 1 }, 'start', 100))[1];
		expect(c.out - c.in).toBeCloseTo(0.1);
	});

	it('ne dépasse pas la fin du fichier source', () => {
		const p = base();
		p.sources[0].duration = 5330;
		const c = video(trimItem(p, { track: 'v0', index: 1 }, 'end', 80))[1];
		expect(c.out).toBeCloseTo(5330);
	});

	it('sous-titre : start/end, mots recalés', () => {
		const p = base();
		caps(p)[0].words = [
			{ start: 0.4, end: 1.4, text: 'Un' },
			{ start: 1.4, end: 2.4, text: 'serpent' }
		];
		const c = caps(trimItem(p, { track: 'subs', index: 0 }, 'end', 4.4))[0];
		expect(c.end).toBeCloseTo(4.4);
		expect(c.words![1]).toMatchObject({ start: 2.4, end: 4.4 });
	});

	it('graphisme : bord gauche garde la fin', () => {
		const g = gfx(trimItem(base(), { track: 'g_text', index: 2 }, 'start', 2))[2];
		expect(g.at).toBe(2);
		expect(g.dur).toBe(4);
	});
});

describe('splitItem', () => {
	it('coupe un plan en deux morceaux continus avec un nouvel id', () => {
		const q = splitItem(base(), { track: 'v0', index: 0 }, 10);
		const [a, b, c] = video(q);
		expect(video(q)).toHaveLength(3);
		expect(a).toMatchObject({ id: 'c1', in: 5264.6, out: 5274.6, at: 0 });
		expect(b).toMatchObject({ id: 'c3', in: 5274.6, out: 5327.1, at: 10 });
		expect(c.id).toBe('c2');
		expect(projectDuration(q)).toBeCloseTo(66.5);
	});

	it('le second morceau perd le punch d’entrée ; le punch-in est réparti', () => {
		const q = splitItem(base(), { track: 'v0', index: 0 }, 1.4, 'x');
		const [a, b] = video(q);
		expect(a.fx.punch).toBe(true);
		expect(a.fx.punch_in).toEqual([0.4, 1.4]);
		expect(b.fx.punch).toBeUndefined();
		expect(b.fx.punch_in).toEqual([0, 1]);
		expect(b.crop).toEqual(a.crop);
	});

	it('ne coupe pas hors du plan ni sur un bord', () => {
		const p = base();
		expect(splitItem(p, { track: 'v0', index: 0 }, 0)).toBe(p);
		expect(splitItem(p, { track: 'v0', index: 0 }, 80)).toBe(p);
		expect(splitItem(p, { track: 'g_text', index: 0 }, 5)).toBe(p);
	});

	it('uniqueId évite les collisions', () => {
		expect(uniqueId(base(), 'c')).toBe('c3');
		expect(uniqueId(base(), 'v')).toBe('v2');
	});
});

describe('suppression', () => {
	it('removeItem laisse un trou', () => {
		const q = removeItem(base(), { track: 'v0', index: 0 });
		expect(video(q)).toHaveLength(1);
		expect(video(q)[0].at).toBe(62.5);
	});

	it('rippleDelete recule tout ce qui suit, sur toutes les pistes', () => {
		const p = base();
		p.markers.music_hits = [10, 64];
		const q = rippleDelete(p, { track: 'v0', index: 0 });
		expect(video(q)).toHaveLength(1);
		expect(video(q)[0].at).toBe(0);
		// le CTA (62,5 s) suit le plan
		expect(gfx(q)[4]).toMatchObject({ type: 'cta', at: 0 });
		// les éléments qui commencent avant la fin du plan supprimé ne bougent pas
		expect(gfx(q)[0].at).toBe(0);
		expect(q.markers.music_hits).toEqual([10, 1.5]);
	});
});

describe('aimantation', () => {
	it('snap vers la cible la plus proche sous le seuil', () => {
		expect(snap(10.04, [5, 10, 10.1], 0.1)).toEqual({ t: 10, target: 10 });
		expect(snap(12, [5, 10], 0.5)).toEqual({ t: 12, target: null });
	});

	it('snapSpan aimante le bord le plus proche', () => {
		// fin 14.95 → 15 (écart 0.05) plutôt que début 10.1 → 10 (écart 0.1)
		const r = snapSpan(10.1, 14.95, [10, 15], 0.2);
		expect(r.target).toBe(15);
		expect(r.t).toBeCloseTo(10.15);
	});

	it('cibles : tête de lecture, bords, coups de musique, coupes, répliques', () => {
		const p = base();
		p.markers = { music_hits: [55.9], cuts: [14] };
		const t = snapTargets(p, 3.3, { track: 'v0', index: 1 });
		for (const x of [0, 3.3, 62.5, 55.9, 14, 0.4, 66.5]) expect(t).toContain(x);
	});
});

describe('micros et dictionnaire', () => {
	it('ferme puis rouvre un micro sur un intervalle', () => {
		let p = base();
		p.mics = [{ id: 'm1', path: 'a.wav', rec: 0 }];
		expect(micState(p, 'm1', 10, 20)).toBe('open');
		p = setMicOpen(p, 'm1', 10, 20, false);
		expect(p.mic_gates.m1).toEqual([
			[0, 10],
			[20, 1e9]
		]);
		expect(micState(p, 'm1', 10, 20)).toBe('closed');
		expect(micState(p, 'm1', 5, 15)).toBe('partial');
		p = setMicOpen(p, 'm1', 12, 14, true);
		expect(micState(p, 'm1', 12, 14)).toBe('open');
		p = setMicOpen(p, 'm1', 10, 20, true);
		expect(p.mic_gates.m1).toEqual([[0, 1e9]]);
	});

	it('ajoute une correction au dictionnaire', () => {
		const q = addDictionaryEntry(base(), 'Osmo', 'Osmô');
		expect(q.dictionary).toMatchObject({ morture: 'morsure', Osmo: 'Osmô' });
	});
});

describe('plans liés', () => {
	// Une proposition : une voix par plan vidéo, même découpe.
	const linked = (): Project => {
		const p = base();
		const voice = findTrack(p, 'a_voice')!;
		voice.items = video(p).map((c, i) => ({ id: `v${i + 1}`, src: c.src, in: c.in, out: c.out, at: c.at }));
		return p;
	};

	it('trouve la voix de même découpe', () => {
		expect(linkedRefs(linked(), { track: 'v0', index: 1 })).toEqual([
			{ track: 'v0', index: 1 },
			{ track: 'a_voice', index: 1 }
		]);
		// Voix qui couvre deux plans (exemple serpent écrit à la main) : pas de lien.
		expect(linkedRefs(base(), { track: 'v0', index: 0 })).toHaveLength(1);
	});

	it('déplace vidéo et voix ensemble, sans passer sous zéro', () => {
		const p = linked();
		const refs = linkedRefs(p, { track: 'v0', index: 1 });
		const q = moveGroup(p, refs, 3);
		expect(video(q)[1].at).toBeCloseTo(65.5);
		expect((findTrack(q, 'a_voice')!.items[1] as VideoItem).at).toBeCloseTo(65.5);
		const z = moveGroup(p, linkedRefs(p, { track: 'v0', index: 0 }), -10);
		expect(video(z)[0].at).toBe(0);
	});

	it('coupe et supprime le groupe', () => {
		const p = linked();
		const cut = splitGroup(p, linkedRefs(p, { track: 'v0', index: 0 }), 20);
		expect(video(cut)).toHaveLength(3);
		expect(findTrack(cut, 'a_voice')!.items).toHaveLength(3);
		const del = removeGroup(cut, linkedRefs(cut, { track: 'v0', index: 1 }), true);
		expect(video(del)).toHaveLength(2);
		expect(findTrack(del, 'a_voice')!.items).toHaveLength(2);
		// Raccord : le dernier plan recule de la durée supprimée (62,5 − 20).
		expect(video(del)[1].at).toBeCloseTo(20);
	});

	it('points de montage triés', () => {
		expect(editPoints(base())).toEqual([0, 62.5, 66.5]);
	});
});

describe('ajout de rush (placeClip)', () => {
	const rush = (p: Project) => ({ source: p.sources[0], in: 100, out: 110 });

	it('écrase au milieu d’un plan : coupe autour, voix liée posée aussi', () => {
		const p = base();
		const { project: q, ref } = placeClip(p, rush(p), 20, 'overwrite');
		const v = video(q);
		expect(v.map((c) => [c.at, c.in, c.out])).toEqual([
			[0, 5264.6, 5284.6],
			[20, 100, 110],
			[30, 5294.6, 5327.1],
			[62.5, 5327.1, 5331.1]
		]);
		expect(ref).toEqual({ track: 'v0', index: 1 });
		// Le nouveau plan et sa voix sont liés.
		expect(linkedRefs(q, ref)).toHaveLength(2);
		// La voix longue de l'exemple est découpée de la même façon.
		const voice = findTrack(q, 'a_voice')!.items as VideoItem[];
		expect(voice.map((c) => c.at)).toEqual([0, 20, 30]);
		expect(projectDuration(q)).toBeCloseTo(projectDuration(p));
	});

	it('insère : tout ce qui suit recule de la durée du morceau', () => {
		const p = base();
		const { project: q } = placeClip(p, rush(p), 20, 'insert');
		const v = video(q);
		expect(v.map((c) => c.at)).toEqual([0, 20, 30, 72.5]);
		expect(v[2].in).toBeCloseTo(5284.6);
		// Les sous-titres après 20 s reculent aussi.
		expect(caps(q).every((c, i) => c.start === caps(p)[i].start || c.start >= 30 - 1e-6)).toBe(true);
	});

	it('ajoute la source du rush si le montage ne la connaît pas', () => {
		const p = base();
		const other = { ...p.sources[0], id: 'soiree', path: '/autre/fichier.MP4' };
		const { project: q } = placeClip(p, { source: other, in: 0, out: 4 }, videoEnd(p), 'overwrite');
		expect(q.sources.map((s) => s.id)).toEqual(['soiree', 'soiree_2']);
		expect(video(q).at(-1)).toMatchObject({ src: 'soiree_2', at: 66.5 });
	});

	it('crée les pistes V1/A1 dans un montage vide', () => {
		const p = base();
		p.tracks = p.tracks.filter((t) => t.kind !== 'video' && t.kind !== 'voice');
		const { project: q } = placeClip(p, rush(base()), 0, 'overwrite');
		expect(q.tracks.filter((t) => t.kind === 'video' || t.kind === 'voice').map((t) => t.items.length)).toEqual([1, 1]);
	});
});
