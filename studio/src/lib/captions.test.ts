import { describe, expect, it } from 'vitest';
import type { Word } from './bindings/Word';
import {
	activeBlock,
	applyDictionary,
	blocks,
	blockText,
	captionWords,
	charCount,
	diffCorrection,
	timeWords,
	tokenize
} from './captions';

const NBSP = ' ';
const w = (start: number, end: number, text: string): Word => ({ start, end, text });

describe('calage mot à mot', () => {
	it('répartit au prorata des lettres', () => {
		const ws = timeWords(0, 3, 'a bb ccc');
		expect(ws).toHaveLength(3);
		expect(ws[0].end).toBeCloseTo(0.5);
		expect(ws[1].end).toBeCloseTo(1.5);
		expect(ws[2].end).toBeCloseTo(3);
	});

	it('rattache la ponctuation isolée au mot précédent (espace insécable)', () => {
		expect(tokenize('toi ? oui !')).toEqual([`toi${NBSP}?`, `oui${NBSP}!`]);
		expect(timeWords(0, 1, 'toi ? oui !')[0].text).toBe(`toi${NBSP}?`);
	});

	it('intervalle vide : aucun mot', () => {
		expect(timeWords(2, 2, 'abc')).toEqual([]);
	});

	it('utilise les mots fournis quand ils existent', () => {
		const words = [w(1, 2, 'Bonjour')];
		expect(captionWords([{ start: 0, end: 5, text: 'x y', words }])).toEqual(words);
		expect(captionWords([{ start: 0, end: 2, text: 'x y' }])).toHaveLength(2);
	});
});

describe('découpe en blocs (règles du moteur A)', () => {
	it('ponctuation, pause > 0,45 s, 16 caractères', () => {
		const words = [
			w(0, 0.3, "C'est"),
			w(0.3, 0.6, 'pour'),
			w(0.6, 1.2, `toi${NBSP}?`),
			w(1.3, 1.5, 'Y'),
			w(1.5, 1.7, 'a'),
			w(1.7, 2.3, "quelqu'un"),
			w(3.0, 3.4, 'Immense')
		];
		const b = blocks(words);
		expect(b.map(blockText)).toEqual([`C'est pour toi${NBSP}?`, "Y a quelqu'un", 'Immense']);
		expect(b.every((x) => charCount(blockText(x)) <= 16)).toBe(true);
	});

	it('3 mots maximum', () => {
		const b = blocks([w(0, 0.1, 'a'), w(0.1, 0.2, 'b'), w(0.2, 0.3, 'c'), w(0.3, 0.4, 'd')]);
		expect(b.map(blockText)).toEqual(['a b c', 'd']);
	});

	it('coupe au-delà de 16 caractères', () => {
		const b = blocks([w(0, 0.5, 'immensément'), w(0.5, 1, 'grandes')]);
		expect(b.map(blockText)).toEqual(['immensément', 'grandes']);
		// 17 caractères exactement : coupé aussi.
		const c = blocks([w(0, 0.5, 'immensément'), w(0.5, 1, 'grand')]);
		expect(c.map(blockText)).toEqual(['immensément', 'grand']);
		// 16 caractères : un seul bloc.
		const d = blocks([w(0, 0.5, 'immensément'), w(0.5, 1, 'gros')]);
		expect(d.map(blockText)).toEqual(['immensément gros']);
	});

	it('un bloc reste affiché jusqu’au suivant si l’écart est court', () => {
		const b = blocks([w(0, 1, 'Oui.'), w(1.3, 2, 'Non')]);
		expect(b[0].end).toBe(1.3);
		const c = blocks([w(0, 1, 'Oui.'), w(2, 3, 'Non')]);
		expect(c[0].end).toBe(1);
	});

	it('cas du serpent', () => {
		const b = blocks(timeWords(0.4, 2.4, 'Un immense serpent aux yeux verts !'));
		expect(b.map(blockText)).toEqual(['Un immense', 'serpent aux yeux', `verts${NBSP}!`]);
	});
});

describe('bloc actif', () => {
	const b = blocks([w(0, 0.5, 'Un'), w(0.5, 1, 'serpent'), w(3, 4, 'vert')]);

	it('mot actif selon le temps', () => {
		expect(activeBlock(b, 0.2)).toMatchObject({ active: 0 });
		expect(activeBlock(b, 0.7)).toMatchObject({ active: 1 });
		expect(activeBlock(b, 2)).toBeNull();
		expect(activeBlock(b, 3.5)?.block.words[0].text).toBe('vert');
	});

	it('rien après le début du CTA', () => {
		expect(activeBlock(b, 3.5, 3.2)).toBeNull();
	});
});

describe('dictionnaire', () => {
	const dict = { "sonnette d'Allah": "sonnette d'alarme", morture: 'morsure' };

	it('insensible à la casse, mots entiers seulement', () => {
		expect(applyDictionary("La Sonnette d'Allah sonne", dict)).toBe("La sonnette d'alarme sonne");
		expect(applyDictionary('une morture, mortures', dict)).toBe('une morsure, mortures');
	});

	it('détecte la correction faite à la main', () => {
		expect(diffCorrection('Attention, il a une morture au cou.', 'Attention, il a une morsure au cou.')).toEqual({
			wrong: 'morture',
			right: 'morsure'
		});
		expect(diffCorrection("Appuie sur la sonnette d'Allah !", "Appuie sur la sonnette d'alarme !")).toEqual({
			wrong: "d'Allah",
			right: "d'alarme"
		});
		expect(diffCorrection('pareil', 'pareil')).toBeNull();
		expect(diffCorrection('un deux trois quatre cinq six', 'a b c d e f')).toBeNull();
	});
});
