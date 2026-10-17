<script lang="ts">
	import NumField from '$lib/components/NumField.svelte';
	import type { Caption } from '$lib/bindings/Caption';
	import { applyDictionary, blocks, blockText, captionWords, diffCorrection, normalizeWord, tokenize } from '$lib/captions';
	import { addDictionaryEntry, trimItem, updateItem } from '$lib/edit';
	import type { ItemRef } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	let { ref, item }: { ref: ItemRef; item: Caption } = $props();

	const p = $derived(studio.project!);

	/** Texte au moment de la sélection : sert à détecter une correction d'ASR. */
	let original = $state('');
	let lastKey = '';
	$effect.pre(() => {
		const key = `${ref.track}:${ref.index}`;
		if (key !== lastKey) {
			lastKey = key;
			original = item.text;
		}
	});

	const correction = $derived(diffCorrection(original, item.text));
	const known = $derived(!!correction && p.dictionary?.[correction.wrong] === correction.right);
	const emphasis = $derived(new Set((item.emphasis ?? []).map(normalizeWord)));
	const words = $derived(tokenize(item.text));
	const preview = $derived(blocks(captionWords([item]).map((w) => ({ ...w, text: applyDictionary(w.text, p.dictionary) }))));

	function setText(text: string) {
		studio.edit(
			updateItem<Caption>(p, ref, (c) => {
				c.text = text;
				// Le calage mot à mot ne correspond plus : recalcul automatique au rendu.
				delete c.words;
			}),
			'Texte du sous-titre',
			`${ref.track}:${ref.index}:text`
		);
	}

	function toggleEmphasis(word: string) {
		const key = normalizeWord(word);
		if (!key) return;
		const cur = item.emphasis ?? [];
		const has = cur.some((e) => normalizeWord(e) === key);
		const clean = word.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, '');
		studio.edit(
			updateItem<Caption>(p, ref, (c) => {
				c.emphasis = has ? cur.filter((e) => normalizeWord(e) !== key) : [...cur, clean];
				if (c.emphasis.length === 0) delete c.emphasis;
			}),
			`${has ? 'Retirer' : 'Ajouter'} l'emphase « ${clean} »`
		);
	}

	function addToDictionary() {
		if (!correction) return;
		studio.edit(addDictionaryEntry(p, correction.wrong, correction.right), `Dictionnaire : ${correction.wrong} → ${correction.right}`);
	}
</script>

<section>
	<h3>Sous-titre <span class="mono dim">{ref.track}[{ref.index}]</span></h3>
	<div class="grid2">
		<NumField label="Début" value={item.start} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'start', v), 'Début du sous-titre')} />
		<NumField label="Fin" value={item.end} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'end', v), 'Fin du sous-titre')} />
	</div>
	<label>
		<span>Texte</span>
		<textarea rows="2" value={item.text} oninput={(e) => setText(e.currentTarget.value)}></textarea>
	</label>

	{#if correction && !known}
		<div class="dict">
			<span>Correction détectée : <b>« {correction.wrong} »</b> → <b>« {correction.right} »</b></span>
			<button class="primary" onclick={addToDictionary} title="Ajouter cette correction au dictionnaire du projet : elle sera appliquée à tous les sous-titres, présents et futurs (ex. « morture » → « morsure »).">Ajouter au dictionnaire</button>
		</div>
	{:else if correction && known}
		<div class="dim small">« {correction.wrong} » → « {correction.right} » est dans le dictionnaire.</div>
	{/if}
</section>

<section>
	<h3>Mots d'emphase <span class="dim small">cliquer pour basculer (rouge)</span></h3>
	<div class="words">
		{#each words as w, i (i)}
			<button class="word" class:emph={emphasis.has(normalizeWord(w))} onclick={() => toggleEmphasis(w)} title="Mot d'emphase : cliquer pour l'afficher en rouge dans les sous-titres (recliquer pour l'enlever).">{w}</button>
		{/each}
	</div>
</section>

<section>
	<h3>Blocs affichés</h3>
	<div class="blocks">
		{#each preview as b, i (i)}
			<span class="block">{blockText(b).toUpperCase()}</span>
		{/each}
	</div>
	<div class="dim small">{item.words?.length ? `${item.words.length} mots calés` : 'Calage au prorata des lettres'}</div>
</section>

<style>
	textarea {
		resize: vertical;
		font-size: 13px;
	}
	.dict {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding: 8px;
		border: 1px solid #6b5420;
		border-radius: var(--radius);
		background: #1f190e;
	}
	.dict b {
		color: var(--gold-light);
		font-weight: 600;
	}
	.dict button {
		align-self: flex-start;
	}
	.words,
	.blocks {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}
	.word {
		text-transform: none;
		letter-spacing: 0;
		font-family: var(--font-ui);
		font-weight: 500;
		font-size: 12px;
		padding: 3px 7px;
	}
	.word.emph {
		background: var(--red);
		border-color: var(--red);
		color: #fff;
	}
	.block {
		font-family: var(--font-anton);
		font-size: 14px;
		padding: 2px 6px;
		background: #000;
		border-radius: 2px;
	}
</style>
