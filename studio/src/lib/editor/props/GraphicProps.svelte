<script lang="ts">
	import NumField from '$lib/components/NumField.svelte';
	import type { GraphicItem } from '$lib/bindings/GraphicItem';
	import { moveItem, trimItem, updateItem } from '$lib/edit';
	import { HOOK_MAX_CHARS } from '$lib/layout';
	import type { ItemRef } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	let { ref, item }: { ref: ItemRef; item: GraphicItem } = $props();

	const p = $derived(studio.project!);

	const TITLES: Partial<Record<GraphicItem['type'], string>> = {
		kicker: 'Kicker',
		hook: 'Hook (bandeau)',
		tag: 'Tag jaune',
		cta: 'CTA final',
		progress: 'Barre de progression',
		end_card: 'Carte finale',
		card: 'Carte texte',
		lower: 'Nom + rôle'
	};

	/** Champs texte : frappe regroupée en un commit (400 ms). */
	function setField(field: string, value: unknown, label: string) {
		studio.edit(
			updateItem<GraphicItem>(p, ref, (g) => ((g as Record<string, unknown>)[field] = value)),
			label,
			`${ref.track}:${ref.index}:${field}`
		);
	}

	/** Champ « liste de lignes » de chaque type de scène, s'il y en a un. */
	function stringList(g: GraphicItem): { field: string; list: string[] } | null {
		switch (g.type) {
			case 'hook':
			case 'cta':
			case 'card':
			case 'dice':
				return { field: 'lines', list: g.lines };
			case 'end_card':
				return { field: 'lines', list: g.lines ?? [] };
			case 'quotes':
			case 'tags':
				return { field: 'items', list: g.items };
			case 'constellation':
				return { field: 'names', list: g.names };
			case 'mech':
				return { field: 'cards', list: g.cards };
			default:
				return null;
		}
	}
	const lf = $derived(stringList(item));
	const listField = $derived(lf?.field);
	const list = $derived(lf?.list ?? []);
	const maxLines = $derived(item.type === 'hook' ? 2 : 8);

	function setLine(i: number, v: string) {
		const next = [...list];
		next[i] = v;
		setField(listField!, next, `Texte ${item.type}`);
	}
	function addLine() {
		studio.edit(updateItem<GraphicItem>(p, ref, (g) => ((g as Record<string, unknown>)[listField!] = [...list, ''])), `Ligne ajoutée (${item.type})`);
	}
	function removeLine(i: number) {
		studio.edit(updateItem<GraphicItem>(p, ref, (g) => ((g as Record<string, unknown>)[listField!] = list.filter((_, j) => j !== i))), `Ligne supprimée (${item.type})`);
	}
</script>

<section>
	<h3>{TITLES[item.type] ?? item.type} <span class="mono dim">{ref.track}[{ref.index}]</span></h3>
	<div class="grid2">
		<NumField label="Début" value={item.at} unit="s" onchange={(v) => studio.edit(moveItem(p, ref, v), `Déplacer ${item.type}`)} />
		<NumField label="Durée" value={item.dur} unit="s" min={0.1} onchange={(v) => studio.edit(trimItem(p, ref, 'end', item.at + v), `Durée ${item.type}`)} />
	</div>
</section>

<section>
	{#if 'text' in item}
		<label>
			<span>Texte</span>
			<input value={item.text} oninput={(e) => setField('text', e.currentTarget.value, `Texte ${item.type}`)} />
		</label>
	{/if}

	{#if item.type === 'lower'}
		<label><span>Nom</span><input value={item.name} oninput={(e) => setField('name', e.currentTarget.value, 'Nom')} /></label>
		<label><span>Rôle</span><input value={item.role} oninput={(e) => setField('role', e.currentTarget.value, 'Rôle')} /></label>
	{/if}

	{#if item.type === 'end_card'}
		<label>
			<span>Variante</span>
			<select value={item.variant} onchange={(e) => studio.edit(updateItem<GraphicItem>(p, ref, (g) => ((g as { variant: string }).variant = e.currentTarget.value)), 'Variante de carte finale')}>
				<option value="undated">Sans date (prochaines dates)</option>
				<option value="dated">Datée</option>
			</select>
		</label>
	{/if}

	{#if item.type === 'card'}
		<label>
			<span>Style</span>
			<select value={item.style} onchange={(e) => studio.edit(updateItem<GraphicItem>(p, ref, (g) => ((g as { style: string }).style = e.currentTarget.value)), 'Style de carte')}>
				<option value="fade">Fondu</option>
				<option value="stamp">Tampon</option>
			</select>
		</label>
	{/if}

	{#if listField}
		<div class="lines">
			<span class="label">{item.type === 'hook' ? 'Lignes (2 max, 20 car.)' : 'Lignes'}</span>
			{#each list as line, i (i)}
				{@const n = [...line].length}
				<div class="line">
					<input value={line} oninput={(e) => setLine(i, e.currentTarget.value)} />
					{#if item.type === 'hook'}<span class="mono count" class:over={n > HOOK_MAX_CHARS}>{n}</span>{/if}
					<button class="icon ghost" title="Supprimer cette ligne de texte." onclick={() => removeLine(i)}>✕</button>
				</div>
			{/each}
			{#if list.length < maxLines}<button class="ghost add" onclick={addLine} title="Ajouter une ligne de texte à ce graphisme.">+ Ligne</button>{/if}
		</div>
	{/if}

	{#if item.type === 'reviews_txt'}
		<div class="lines">
			<span class="label">Avis (citation · auteur)</span>
			{#each item.items as [quote, author], i (i)}
				<div class="line">
					<input value={quote} oninput={(e) => setField('items', item.items.map((x, j) => (j === i ? [e.currentTarget.value, x[1]] : x)), 'Avis')} />
					<input class="author" value={author} oninput={(e) => setField('items', item.items.map((x, j) => (j === i ? [x[0], e.currentTarget.value] : x)), 'Avis')} />
				</div>
			{/each}
		</div>
	{/if}

	{#if item.type === 'progress' || item.type === 'ring' || item.type === 'black' || item.type === 'flash'}
		<p class="dim small">Pas de texte pour cet élément.</p>
	{/if}
</section>

<style>
	.lines {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.line {
		display: flex;
		align-items: center;
		gap: 4px;
	}
	.line input {
		flex: 1;
	}
	.line .author {
		flex: 0 0 90px;
	}
	.count {
		width: 22px;
		text-align: right;
		color: var(--text-mute);
		font-size: 11px;
	}
	.count.over {
		color: var(--orange);
	}
	.add {
		align-self: flex-start;
	}
</style>
