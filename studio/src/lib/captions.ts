// Sous-titres dynamiques : port TypeScript de `destiny-core/src/captions.rs`
// (calage mot à mot, découpe en blocs, dictionnaire) pour que l'aperçu affiche
// exactement les blocs que le moteur A écrira dans le fichier ASS.

import type { Block } from './bindings/Block';
import type { Caption } from './bindings/Caption';
import type { Word } from './bindings/Word';

export const SUB_MAX_CHARS = 16;
export const SUB_MAX_WORDS = 3;
export const SUB_PAUSE = 0.45;

const NBSP = ' ';
const ALNUM = /[\p{L}\p{N}]/u;

/** Nombre de caractères (points de code, comme `chars().count()` en Rust). */
export function charCount(s: string): number {
	return [...s].length;
}

function letters(w: string): number {
	return Math.max(1, [...w].filter((c) => ALNUM.test(c)).length);
}

/** Découpe un texte en mots ; la ponctuation isolée (« toi ? ») est rattachée au mot
 * précédent par une espace insécable. */
export function tokenize(text: string): string[] {
	const out: string[] = [];
	for (const tok of text.split(/\s+/).filter(Boolean)) {
		const punctOnly = !ALNUM.test(tok);
		if (punctOnly && out.length > 0) out[out.length - 1] += NBSP + tok;
		else out.push(tok);
	}
	return out;
}

/** Calage mot à mot au prorata des lettres (sans enveloppe d'énergie : l'aperçu n'en a pas). */
export function timeWords(start: number, end: number, text: string): Word[] {
	const words = tokenize(text);
	if (words.length === 0 || end <= start) return [];
	const total = words.reduce((s, w) => s + letters(w), 0);
	const dur = end - start;
	let acc = 0;
	return words.map((w) => {
		const a = start + (acc / total) * dur;
		acc += letters(w);
		const b = start + (acc / total) * dur;
		return { start: a, end: b, text: w };
	});
}

function endsWithPunct(w: string): boolean {
	return /[.,!?;:…]$/.test(w);
}

/** Découpe des mots horodatés en blocs : coupure sur ponctuation, pause > 0,45 s,
 * 3 mots ou 16 caractères. */
export function blocks(words: Word[]): Block[] {
	const out: Block[] = [];
	let cur: Word[] = [];
	const flush = () => {
		if (cur.length > 0) {
			out.push({ start: cur[0].start, end: cur[cur.length - 1].end, words: cur });
			cur = [];
		}
	};
	for (const w of words) {
		const prev = cur[cur.length - 1];
		if (prev) {
			// Même formule que `captions.rs` : longueur du bloc si on y ajoute `w`
			// (l'aperçu doit couper exactement comme le moteur de rendu).
			const len = cur.reduce((s, x) => s + charCount(x.text) + 1, 0) + charCount(w.text);
			if (
				w.start - prev.end > SUB_PAUSE ||
				cur.length >= SUB_MAX_WORDS ||
				len > SUB_MAX_CHARS ||
				endsWithPunct(prev.text)
			) {
				flush();
			}
		}
		cur.push({ ...w });
	}
	flush();
	// Chaque bloc reste affiché jusqu'au suivant si l'écart est court (pas de clignotement).
	for (let i = 0; i + 1 < out.length; i++) {
		const next = out[i + 1].start;
		if (next - out[i].end < SUB_PAUSE) out[i].end = next;
	}
	return out;
}

export function blockText(b: Block): string {
	return b.words.map((w) => w.text).join(' ');
}

/** Mots de tous les sous-titres (calage automatique si `words` est vide). */
export function captionWords(caps: Caption[]): Word[] {
	return caps.flatMap((c) => (c.words && c.words.length > 0 ? c.words : timeWords(c.start, c.end, c.text)));
}

/** Forme comparable d'un mot (lettres et chiffres en minuscules). */
export function normalizeWord(w: string): string {
	return [...w].filter((c) => ALNUM.test(c)).join('').toLowerCase();
}

function escapeRe(s: string): string {
	return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Applique le dictionnaire de corrections (insensible à la casse, sur mots entiers),
 * les entrées les plus longues d'abord. */
export function applyDictionary(text: string, dict: Record<string, string> | undefined): string {
	if (!dict) return text;
	const entries = Object.entries(dict)
		.filter(([k]) => k.length > 0)
		.sort((a, b) => charCount(b[0]) - charCount(a[0]));
	let out = text;
	for (const [wrong, right] of entries) {
		const re = new RegExp(`(?<![\\p{L}\\p{N}])${escapeRe(wrong)}(?![\\p{L}\\p{N}])`, 'giu');
		out = out.replace(re, () => right);
	}
	return out;
}

/** Blocs affichés à l'instant `t`, avec l'indice du mot actif. */
export interface ActiveBlock {
	block: Block;
	active: number;
}

/** Bloc visible à `t` (les sous-titres s'arrêtent au début du CTA). */
export function activeBlock(all: Block[], t: number, ctaStart = Infinity): ActiveBlock | null {
	if (t >= ctaStart) return null;
	for (const block of all) {
		const end = Math.min(block.end, ctaStart);
		if (t >= block.start && t < end) {
			let active = 0;
			for (let i = 0; i < block.words.length; i++) {
				const a = i === 0 ? block.start : block.words[i].start;
				if (t >= a) active = i;
			}
			return { block, active };
		}
	}
	return null;
}

/** Correction détectée entre deux versions d'un sous-titre : la plus petite plage de mots
 * qui diffère (« morture » → « morsure »). `null` si rien n'a changé ou si tout a changé. */
export function diffCorrection(before: string, after: string): { wrong: string; right: string } | null {
	const a = before.split(/\s+/).filter(Boolean);
	const b = after.split(/\s+/).filter(Boolean);
	let i = 0;
	while (i < a.length && i < b.length && a[i] === b[i]) i++;
	let j = 0;
	while (j < a.length - i && j < b.length - i && a[a.length - 1 - j] === b[b.length - 1 - j]) j++;
	const wrongW = a.slice(i, a.length - j);
	const rightW = b.slice(i, b.length - j);
	if (wrongW.length === 0 || rightW.length === 0) return null;
	// Une réécriture complète n'est pas une correction d'ASR.
	if (wrongW.length > 4 || rightW.length > 4) return null;
	const strip = (ws: string[]) => ws.join(' ').replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, '');
	const wrong = strip(wrongW);
	const right = strip(rightW);
	if (!wrong || !right || wrong === right) return null;
	return { wrong, right };
}
