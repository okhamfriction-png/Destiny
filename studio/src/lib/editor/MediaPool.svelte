<script lang="ts">
	import { api } from '$lib/api';
	import { editor } from '$lib/editor.svelte';
	import { basename, duration } from '$lib/format';
	import { resolveMedia } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	/** Panneau « Médias » (le Media Pool de DaVinci, en simple) : les rushes du montage et
	 * les autres montages du même spectacle, pour passer de l'un à l'autre. */
	let tab = $state<'rushes' | 'montages'>('rushes');

	const p = $derived(studio.project!);
	const show = $derived(studio.library.find((s) => studio.path && s.projects.includes(studio.path)) ?? null);
	const montages = $derived(show?.montages.filter((m) => !m.master) ?? []);

	/** Vignette de chaque rush (une image vers 10 s), via le cache Rust. */
	let covers = $state<Record<string, string>>({});
	$effect(() => {
		for (const s of p.sources) {
			if (s.id in covers) continue;
			covers[s.id] = '';
			const t = Math.min(10, (s.duration ?? 30) / 3);
			api.thumbs({ path: resolveMedia(studio.path, s.proxy ?? s.path), from: t, to: t, step: 1, height: 108 }).then(
				(list) => {
					if (list[0]) covers[s.id] = api.fileSrc(list[0].path);
				},
				() => {}
			);
		}
	});

	/** Plans de ce rush dans le montage : un clic amène la tête de lecture sur le premier. */
	function usesOf(id: string) {
		return p.tracks.flatMap((t) => (t.kind === 'video' ? t.items.filter((c) => c.src === id) : []));
	}
</script>

<div class="pool">
	<div class="tabs">
		<button class:on={tab === 'rushes'} onclick={() => (tab = 'rushes')}>Rushes <span class="dim">{p.sources.length}</span></button>
		<button class:on={tab === 'montages'} onclick={() => (tab = 'montages')}>Montages <span class="dim">{montages.length}</span></button>
	</div>
	<div class="list scroll">
		{#if tab === 'rushes'}
			{#each p.sources as s (s.id)}
				{@const uses = usesOf(s.id)}
				<button class="clip" onclick={() => uses[0] && editor.seek(uses[0].at)} title={s.path}>
					<div class="cover">
						{#if covers[s.id]}<img src={covers[s.id]} alt="" />{:else}<span class="mono dim">{s.id}</span>{/if}
						{#if s.duration}<span class="dur mono">{duration(s.duration)}</span>{/if}
					</div>
					<div class="meta">
						<b>{s.id}</b>
						<span class="dim name">{basename(s.path)}</span>
						<span class="dim">{uses.length} plan{uses.length > 1 ? 's' : ''} dans le montage</span>
					</div>
				</button>
			{:else}
				<p class="dim empty">Aucun rush dans ce montage.</p>
			{/each}
		{:else}
			{#each montages as m (m.path)}
				<button class="row" class:current={m.path === studio.path} onclick={() => m.path !== studio.path && studio.open(m.path)}>
					<b>{m.name}</b>
					<span class="dim mono">{m.duration > 0 ? duration(m.duration) : '—'}</span>
				</button>
			{:else}
				<p class="dim empty">Les autres montages du spectacle apparaîtront ici.</p>
			{/each}
		{/if}
	</div>
</div>

<style>
	.pool {
		display: flex;
		flex-direction: column;
		height: 100%;
		min-height: 0;
		background: var(--bg-1);
		border-right: 1px solid var(--line);
	}
	.tabs {
		display: flex;
		gap: 2px;
		padding: 6px;
		border-bottom: 1px solid var(--line);
	}
	.tabs button {
		flex: 1;
		font-size: 10px;
		padding: 5px 4px;
		border-color: transparent;
		background: transparent;
	}
	.tabs button.on {
		background: var(--bg-2);
		border-color: var(--line-2);
		color: var(--gold-light);
	}
	.list {
		flex: 1;
		min-height: 0;
		overflow: auto;
		padding: 8px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.clip {
		display: flex;
		flex-direction: column;
		align-items: stretch;
		gap: 4px;
		padding: 4px;
		text-align: left;
		text-transform: none;
		letter-spacing: 0;
		background: var(--bg-2);
	}
	.cover {
		position: relative;
		aspect-ratio: 16 / 9;
		background: #000;
		border-radius: 3px;
		overflow: hidden;
		display: grid;
		place-items: center;
	}
	.cover img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.dur {
		position: absolute;
		right: 4px;
		bottom: 3px;
		font-size: 9px;
		padding: 1px 4px;
		background: rgba(0, 0, 0, 0.7);
		border-radius: 2px;
	}
	.meta {
		display: flex;
		flex-direction: column;
		gap: 1px;
		font-size: 11px;
		padding: 0 2px 2px;
	}
	.name {
		font-size: 10px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.row {
		display: flex;
		justify-content: space-between;
		gap: 8px;
		text-transform: none;
		letter-spacing: 0;
		font-size: 11px;
		text-align: left;
	}
	.row b {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.row.current {
		border-color: var(--gold);
		color: var(--gold-light);
	}
	.empty {
		font-size: 11px;
		font-style: italic;
	}
</style>
