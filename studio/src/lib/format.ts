// Mise en forme des temps, durées et chemins pour l'affichage.

/** Timecode `hh:mm:ss:ff` (ou `mm:ss:ff` sous l'heure) à `fps` images/s. */
export function timecode(t: number, fps: number): string {
	const total = Math.max(0, Math.round(t * fps));
	const f = total % fps;
	const s = Math.floor(total / fps);
	const hh = Math.floor(s / 3600);
	const mm = Math.floor(s / 60) % 60;
	const ss = s % 60;
	const p = (n: number) => String(n).padStart(2, '0');
	return hh > 0 ? `${p(hh)}:${p(mm)}:${p(ss)}:${p(f)}` : `${p(mm)}:${p(ss)}:${p(f)}`;
}

/** `1:23,4` ou `1:02:05` — lisible pour des temps maître. */
export function clock(t: number, decimals = 1): string {
	const neg = t < 0;
	const a = Math.abs(t);
	const h = Math.floor(a / 3600);
	const m = Math.floor(a / 60) % 60;
	const s = a % 60;
	const ss = s.toFixed(decimals).padStart(decimals > 0 ? 3 + decimals : 2, '0').replace('.', ',');
	const body = h > 0 ? `${h}:${String(m).padStart(2, '0')}:${ss}` : `${m}:${ss}`;
	return neg ? `−${body}` : body;
}

/** Durée courte : « 66,5 s » ou « 1 min 30 ». */
export function duration(t: number): string {
	if (t < 90) return `${t.toFixed(1).replace('.', ',')} s`;
	const m = Math.floor(t / 60);
	const s = Math.round(t % 60);
	return s ? `${m} min ${String(s).padStart(2, '0')}` : `${m} min`;
}

export function basename(path: string): string {
	return path.split(/[\\/]/).filter(Boolean).pop() ?? path;
}

export function dirname(path: string): string {
	const parts = path.split(/[\\/]/);
	parts.pop();
	return parts.join('/');
}

export function num(v: number | null | undefined, digits = 1, unit = ''): string {
	if (v == null || !Number.isFinite(v)) return '—';
	return `${v.toFixed(digits).replace('.', ',').replace('-', '−')}${unit ? ' ' + unit : ''}`;
}

export function date(unix: number): string {
	return new Date(unix * 1000).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
}
