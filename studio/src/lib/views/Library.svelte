<script lang="ts">
	import IngestDialog from './IngestDialog.svelte';
	import Thumb from '$lib/components/Thumb.svelte';
	import { basename, date } from '$lib/format';
	import { studio, type View } from '$lib/state.svelte';
	import type { LibraryEntry } from '$lib/api';

	let ingesting = $state(false);
	let filter = $state('');

	const shows = $derived(
		studio.library
			.filter((s) => s.name.toLowerCase().includes(filter.toLowerCase()))
			.toSorted((a, b) => b.modified - a.modified)
	);

	function go(show: LibraryEntry, view: View) {
		studio.show = show;
		studio.view = view;
	}
</script>

<header class="bar">
	<div>
		<div class="kicker">Destiny Studio</div>
		<h1>Bibliothèque</h1>
	</div>
	<span class="mono dim root" title="Dossier de travail">{studio.root}</span>
	<input class="search" placeholder="Filtrer…" bind:value={filter} />
	<button onclick={() => studio.refreshLibrary()}>Actualiser</button>
	<button class="primary" onclick={() => (ingesting = true)}>Ingérer un dossier</button>
</header>

<div class="list scroll">
	{#each shows as show (show.dir)}
		<section class="show panel">
			<div class="head">
				<div class="title">
					<h2>{show.name}</h2>
					<span class="mono dim">{show.dir}</span>
				</div>
				<div class="chips">
					{#if show.hasIngest}<span class="chip ok">Ingéré</span>{:else}<span class="chip warn">Non ingéré</span>{/if}
					<span class="chip" class:gold={show.transcripts.length > 0}>
						{show.transcripts.length} transcription{show.transcripts.length > 1 ? 's' : ''}
					</span>
					<span class="chip">{show.sheets.length} planche{show.sheets.length > 1 ? 's' : ''}</span>
					<span class="chip">{show.projects.length} montage{show.projects.length > 1 ? 's' : ''}</span>
					<span class="dim date">modifié le {date(show.modified)}</span>
				</div>
				<div class="actions">
					<button disabled={!show.hasIngest} onclick={() => go(show, 'explorer')}>Explorer</button>
					<button disabled={!show.hasIngest} onclick={() => go(show, 'proposals')}>Proposer un short</button>
				</div>
			</div>

			{#if show.sheets.length}
				<div class="sheets">
					{#each show.sheets as sheet (sheet)}<Thumb path={sheet} />{/each}
				</div>
			{/if}

			{#if show.projects.length}
				<ul class="montages">
					{#each show.projects as p (p)}
						<li>
							<span class="file">{basename(p).replace(/\.json$/, '')}</span>
							<span class="mono dim path">{p}</span>
							<button class:primary={studio.path === p} onclick={() => studio.open(p)}>
								{studio.path === p ? 'Ouvert · Reprendre' : "Ouvrir dans l'éditeur"}
							</button>
						</li>
					{/each}
				</ul>
			{:else}
				<p class="dim empty">Aucun montage pour l'instant.</p>
			{/if}
		</section>
	{:else}
		<p class="dim empty">Aucun spectacle dans {studio.root}. Commencez par « Ingérer un dossier ».</p>
	{/each}
</div>

{#if ingesting}<IngestDialog onclose={() => (ingesting = false)} />{/if}

<style>
	.bar {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 14px 20px;
		border-bottom: 1px solid var(--line);
	}
	.root {
		flex: 1;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.search {
		width: 180px;
	}
	.list {
		flex: 1;
		padding: 16px 20px;
		display: flex;
		flex-direction: column;
		gap: 14px;
	}
	.show {
		padding: 14px 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
	.head {
		display: flex;
		align-items: center;
		gap: 16px;
		flex-wrap: wrap;
	}
	.title {
		display: flex;
		flex-direction: column;
		gap: 3px;
		min-width: 240px;
	}
	.title .mono {
		font-size: 10px;
	}
	.chips {
		flex: 1;
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}
	.date {
		font-size: 11px;
		margin-left: 6px;
	}
	.actions {
		display: flex;
		gap: 6px;
	}
	.sheets {
		display: flex;
		gap: 8px;
		overflow-x: auto;
		padding-bottom: 2px;
	}
	.montages {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.montages li {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 6px 10px;
		background: var(--bg-2);
		border-radius: var(--radius);
	}
	.file {
		font-family: var(--font-label);
		font-weight: 600;
		color: var(--text);
	}
	.path {
		flex: 1;
		font-size: 10px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.empty {
		margin: 0;
		font-style: italic;
	}
</style>
