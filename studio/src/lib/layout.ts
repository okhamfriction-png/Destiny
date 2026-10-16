// Géométrie et effets du moteur A (port de `ass.rs` / `render_a.rs` / `style.rs`)
// pour que l'aperçu place chaque élément au pixel près, en coordonnées du format final.

import type { Crop } from './bindings/Crop';
import type { Format } from './bindings/Format';
import type { VideoItem } from './bindings/VideoItem';

export const COLORS = {
	bg: '#0b0907',
	text: '#f3ede4',
	gold: '#e6b446',
	goldLight: '#f7dc8a',
	yellow: '#f7dc8a',
	red: '#e0352b',
	flash: '#fff3dc'
} as const;

export const BAND_W = 1080;
export const BAND_H = 608;
export const BAND_ZOOM = 1.2;
export const BAND_CY_OFFSET = -60;
export const HOOK_MAX_CHARS = 20;
export const PROGRESS_H = 12;
export const LETTERBOX = 131;
export const DEFAULT_PUSH = 0.06;
export const PUNCH_AMOUNT = 0.09;
export const PUNCH_DUR = 0.6;
export const PUNCH_IN_ZOOM = 1.2;
export const FLASH_DUR = 0.22;

/** Géométrie verticale du layout « group » (identique à `Layout::for_format`). */
export interface ShortLayout {
	w: number;
	h: number;
	kickerY: number;
	banner: [number, number];
	tagY: number;
	bandTop: number;
	bandBottom: number;
	subsY: number;
	ctaY: number;
}

export function shortLayout(w: number, h: number): ShortLayout {
	const bandCy = Math.trunc(h / 2) + BAND_CY_OFFSET;
	const bandH = Math.trunc((BAND_H * w) / BAND_W);
	const bandTop = bandCy - Math.trunc(bandH / 2);
	const bandBottom = bandTop + bandH;
	return {
		w,
		h,
		kickerY: bandTop - 345,
		banner: [bandTop - 306, bandTop - 96],
		tagY: bandTop - 50,
		bandTop,
		bandBottom,
		subsY: bandBottom + 230,
		ctaY: bandBottom + 250
	};
}

export function isVertical(f: Format): boolean {
	return f.h > f.w;
}

/** Coupe un hook d'une seule ligne trop longue en 2 lignes équilibrées (`wrap_hook`). */
export function wrapHook(lines: string[]): string[] {
	if (lines.length !== 1 || [...lines[0]].length <= HOOK_MAX_CHARS) return lines;
	const words = lines[0].split(/\s+/).filter(Boolean);
	const total = [...lines[0]].length;
	let best = { diff: Infinity, k: 1 };
	for (let k = 1; k < words.length; k++) {
		const l1 = [...words.slice(0, k).join(' ')].length;
		const diff = Math.abs(l1 - (total - l1));
		if (diff < best.diff) best = { diff, k };
	}
	return [words.slice(0, best.k).join(' '), words.slice(best.k).join(' ')];
}

/** Zoom total d'un plan à l'instant local `t` (secondes depuis le début du plan),
 * même expression que `zoom_expr` : zoom de base × recadrage × push × punch × punch-in. */
export function clipZoom(c: VideoItem, t: number, base: number): number {
	const dur = Math.max(0.01, c.out - c.in);
	const push = c.fx?.push ?? DEFAULT_PUSH;
	let z = base * c.crop.zoom * (1 + (push * t) / dur);
	if (c.fx?.punch && t < PUNCH_DUR) z *= 1 + PUNCH_AMOUNT * (1 - t / PUNCH_DUR) ** 2;
	const pi = c.fx?.punch_in;
	if (pi) {
		const clip01 = (v: number) => Math.min(1, Math.max(0, v));
		z *= 1 + (PUNCH_IN_ZOOM - 1) * clip01((t - pi[0]) / 0.25) * clip01((pi[1] - t) / 0.25);
	}
	return z;
}

/** Position (px, dans le cadre `w×h`) de l'image zoomée pour que le point (cx, cy)
 * soit au centre, bornée aux bords de l'image (comme `zoompan` x/y). */
export function cropPlacement(crop: Crop, zoom: number, w: number, h: number) {
	const W = w * zoom;
	const H = h * zoom;
	const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
	const left = -clamp(crop.cx * W - w / 2, 0, Math.max(0, W - w));
	const top = -clamp(crop.cy * H - h / 2, 0, Math.max(0, H - h));
	return { left, top, width: W, height: H };
}
