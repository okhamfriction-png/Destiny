<script lang="ts">
	import { editor } from '$lib/editor.svelte';
	import { removeDictionaryEntry } from '$lib/edit';
	import { basename, clock, duration } from '$lib/format';
	import { clone } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	/** Rien de sélectionné : informations du projet, dictionnaire, marqueurs. */
	const p = $derived(studio.project!);
	const dict = $derived(Object.entries(p.dictionary ?? {}));

	function addMarker(kind: 'music_hits' | 'cuts') {
		const next = clone(p);
		const t = Math.round(editor.playhead * 100) / 100;
		next.markers[kind] = [...new Set([...next.markers[kind], t])].sort((a, b) => a - b);
		studio.edit(next, kind === 'music_hits' ? 'Ajouter un coup de musique' : 'Ajouter une coupe');
	}

	function removeMarker(kind: 'music_hits' | 'cuts', t: number) {
		const next = clone(p);
		next.markers[kind] = next.markers[kind].filter((x) => x !== t);
		studio.edit(next, 'Supprimer un marqueur');
	}
</script>

<section>
	<h3>Projet</h3>
	<div class="chips">
		<span class="chip gold">{p.preset}</span>
		<span class="chip">{p.format.w}×{p.format.h} · {p.format.fps} i/s</span>
		<span class="chip">{duration(editor.duration)}</span>
	</div>
	<ul class="kv">
		{#each p.sources as s (s.id)}
			<li><span class="mono gold">{s.id}</span><span class="dim ellipsis" title={s.path}>{basename(s.proxy ?? s.path)}</span></li>
		{/each}
		{#each p.mics as m (m.id)}
			<li><span class="mono gold">{m.id}</span><span class="dim">{m.actor ?? basename(m.path)}</span></li>
		{/each}
	</ul>
	<p class="dim small">Sélectionnez un élément de la timeline pour le modifier.</p>
</section>

<section>
	<h3>Marqueurs</h3>
	{#each [['music_hits', 'Coups de musique'], ['cuts', 'Coupes']] as const as [kind, title] (kind)}
		<div class="markers">
			<span class="label">{title}</span>
			{#each p.markers[kind] as t (t)}
				<button class="chip" title="Supprimer" onclick={() => removeMarker(kind, t)}>{clock(t, 2)} ✕</button>
			{/each}
			<button class="ghost" onclick={() => addMarker(kind)}>+ à la tête de lecture</button>
		</div>
	{/each}
</section>

<section>
	<h3>Dictionnaire de corrections</h3>
	{#if dict.length === 0}<p class="dim small">Vide. Corrigez un sous-titre pour proposer une entrée.</p>{/if}
	<ul class="kv">
		{#each dict as [wrong, right] (wrong)}
			<li>
				<span class="wrong">{wrong}</span>
				<span class="dim">→</span>
				<span class="right">{right}</span>
				<button class="icon ghost" title="Supprimer" onclick={() => studio.edit(removeDictionaryEntry(p, wrong), `Dictionnaire : retirer ${wrong}`)}>✕</button>
			</li>
		{/each}
	</ul>
</section>

<style>
	.chips {
		display: flex;
		flex-wrap: wrap;
		gap: 5px;
	}
	.kv {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 3px;
	}
	.kv li {
		display: flex;
		align-items: center;
		gap: 8px;
		min-width: 0;
	}
	.gold {
		color: var(--gold);
	}
	.ellipsis {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.wrong {
		text-decoration: line-through;
		color: var(--text-dim);
	}
	.right {
		flex: 1;
		color: var(--gold-light);
	}
	.markers {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 4px;
		margin-bottom: 6px;
	}
	.markers .label {
		width: 100%;
	}
	button.chip {
		cursor: pointer;
		background: transparent;
		text-transform: none;
	}
</style>
