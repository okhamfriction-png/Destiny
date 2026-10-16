// Échelle de couleurs des niveaux (dB) : noir → bronze → or → or clair.

const STOPS: [number, [number, number, number]][] = [
	[-62, [11, 9, 7]],
	[-48, [48, 34, 18]],
	[-36, [120, 80, 28]],
	[-26, [230, 180, 70]],
	[-14, [251, 231, 166]]
];

export function dbColor(db: number): string {
	if (!Number.isFinite(db) || db <= STOPS[0][0]) return 'rgb(11,9,7)';
	for (let i = 1; i < STOPS.length; i++) {
		const [d1, c1] = STOPS[i];
		if (db <= d1) {
			const [d0, c0] = STOPS[i - 1];
			const k = (db - d0) / (d1 - d0);
			const c = c0.map((v, j) => Math.round(v + (c1[j] - v) * k));
			return `rgb(${c[0]},${c[1]},${c[2]})`;
		}
	}
	const c = STOPS[STOPS.length - 1][1];
	return `rgb(${c[0]},${c[1]},${c[2]})`;
}
