<script lang="ts">
	import IngestDialog from './IngestDialog.svelte';
	import Thumb from '$lib/components/Thumb.svelte';
	import { date, duration } from '$lib/format';
	import { studio, type View } from '$lib/state.svelte';
	import { api, type LibraryEntry, type MontageInfo } from '$lib/api';
	import type { Preset } from '$lib/bindings/Preset';

	let ingesting = $state(false);
	let filter = $state('');

	const q = $derived(filter.toLowerCase());
	const shows = $derived(
		studio.library
			.filter((s) => s.name.toLowerCase().includes(q) || s.montages.some((m) => m.name.toLowerCase().includes(q)))
			.toSorted((a, b) => b.modified - a.modified)
	);

	/** Tous les montages de tous les spectacles, le plus récent d'abord. */
	const all = $derived(
		studio.library
			.flatMap((s) => s.montages.filter((m) => !m.master).map((m) => ({ ...m, show: s.name })))
			.filter((m) => m.name.toLowerCase().includes(q) || m.show.toLowerCase().includes(q))
			.toSorted((a, b) => b.modified - a.modified)
	);

	const KIND: Record<Preset, string> = {
		short_scene: 'Short',
		retention_peaks: 'Short · pic YouTube',
		reel_bm: 'Reel',
		trailer_v: 'Trailer 9:16',
		trailer_h: 'Trailer 16:9'
	};

	const when = (unix: number) =>
		new Date(unix * 1000).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });

	function go(show: LibraryEntry, view: View) {
		studio.show = show;
		studio.view = view;
	}

	async function duplicate(m: MontageInfo) {
		try {
			const path = await api.duplicateProject(m.path);
			await studio.refreshLibrary();
			studio.info(`Copie créée : ${path.split('/').pop()}`);
		} catch (e) {
			studio.error(e);
		}
	}
</script>

{#snippet row(m: MontageInfo, show?: string)}
	<li class:current={studio.path === m.path}>
		<span class="kind {m.master ? 'master' : m.preset}">{m.master ? 'Rushes' : KIND[m.preset]}</span>
		<span class="file">{m.name}</span>
		{#if show}<span class="dim showname">{show}</span>{/if}
		<span class="dim meta">{m.duration > 0 ? duration(m.duration) : '—'}</span>
		<span class="dim meta">{when(m.modified)}</span>
		{#if !m.master}<button class="ghost" onclick={() => duplicate(m)} title="Dupliquer : crée une copie de ce montage (nom_2, nom_3…) pour essayer une variante sans toucher à l'original.">Dupliquer</button>{/if}
		<button class:primary={studio.path === m.path} onclick={() => studio.open(m.path)} title="Ouvrir ce montage dans la page Montage (timeline).">
			{studio.path === m.path ? 'Ouvert · Reprendre' : 'Ouvrir'}
		</button>
	</li>
{/snippet}

<header class="bar">
	<div>
		<div class="kicker">Destiny Studio</div>
		<h1>Bibliothèque</h1>
	</div>
	<span class="mono dim root" title="Dossier de travail">{studio.root}</span>
	<input class="search" placeholder="Filtrer…" bind:value={filter} />
	<button onclick={() => studio.refreshLibrary()} title="Relire le dossier de travail : nouveaux montages, analyses et spectacles ingérés.">Actualiser</button>
	<button class="primary" onclick={() => (ingesting = true)} title="Ingérer un dossier de spectacle (caméras, micros, musiques) : classement, synchronisation et création du projet. Les rushes restent sur le NAS, rien n'y est écrit.">Ingérer un dossier</button>
</header>

<div class="list scroll">
	{#if all.length}
		<section class="show panel">
			<div class="head">
				<div class="title">
					<h2>Tous les projets</h2>
					<span class="dim">{all.length} montage{all.length > 1 ? 's' : ''}, le plus récent en haut · chaque proposition crée un nouveau fichier</span>
				</div>
			</div>
			<ul class="montages">
				{#each all as m (m.path)}{@render row(m, m.show)}{/each}
			</ul>
		</section>
	{/if}

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
					<button disabled={!show.hasIngest} onclick={() => go(show, 'explorer')} title="Explorer ce spectacle : transcription, carte des micros, moments forts.">Explorer</button>
					<button disabled={!show.hasIngest} onclick={() => go(show, 'proposals')} title="Proposer un short à partir d'un passage de ce spectacle (recadré automatiquement sur les comédiens).">Proposer un short</button>
				</div>
			</div>

			{#if show.sheets.length}
				<div class="sheets">
					{#each show.sheets as sheet (sheet)}<Thumb path={sheet} />{/each}
				</div>
			{/if}

			{#if show.montages.length}
				<ul class="montages">
					{#each show.montages as m (m.path)}{@render row(m)}{/each}
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
	.montages li.current {
		outline: 1px solid var(--gold);
	}
	/* Le nom se raccourcit, les boutons restent toujours visibles. */
	.montages li > :not(.file) {
		flex-shrink: 0;
	}
	.file {
		flex: 1;
		min-width: 0;
		font-family: var(--font-label);
		font-weight: 600;
		color: var(--text);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.showname {
		font-size: 11px;
		white-space: nowrap;
	}
	.meta {
		font-size: 11px;
		white-space: nowrap;
		min-width: 64px;
		text-align: right;
	}
	/* Type de montage : même code couleur que la timeline (or = shorts, violet = trailers). */
	.kind {
		font-family: var(--font-label);
		font-size: 9px;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		padding: 2px 7px;
		border-radius: 3px;
		white-space: nowrap;
		min-width: 92px;
		text-align: center;
		background: #e2c56e;
		color: #1a1208;
	}
	.kind.trailer_v,
	.kind.trailer_h {
		background: #8a5fb0;
		color: #fff;
	}
	.kind.reel_bm {
		background: #b8281f;
		color: #fff;
	}
	.kind.master {
		background: var(--bg-3, #2a251e);
		color: var(--text-dim, #b9ae9c);
	}
	.empty {
		margin: 0;
		font-style: italic;
	}
</style>
