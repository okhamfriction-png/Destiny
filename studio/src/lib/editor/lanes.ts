// Outils de mise en page de la timeline.

/** Partie d'un élément saisie à la souris : le corps (déplacer) ou un bord (trim). */
export type DragMode = 'move' | 'start' | 'end';

// Répartition des éléments d'une piste sur des sous-lignes sans chevauchement
// (ex. kicker, hook, tag et barre de progression qui durent tout le short).

export function packLanes(spans: [number, number][]): { lane: number[]; count: number } {
	const order = spans.map((s, i) => i).sort((a, b) => spans[a][0] - spans[b][0] || spans[b][1] - spans[a][1]);
	const ends: number[] = [];
	const lane = new Array<number>(spans.length).fill(0);
	for (const i of order) {
		const [s, e] = spans[i];
		let l = ends.findIndex((end) => end <= s + 1e-6);
		if (l < 0) {
			l = ends.length;
			ends.push(e);
		} else ends[l] = e;
		lane[i] = l;
	}
	return { lane, count: Math.max(1, ends.length) };
}

/** Pas de graduation « rond » pour qu'il y ait au moins `minPx` pixels entre deux traits. */
export function rulerStep(pps: number, minPx = 70): number {
	for (const s of [0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300]) if (s * pps >= minPx) return s;
	return 600;
}
