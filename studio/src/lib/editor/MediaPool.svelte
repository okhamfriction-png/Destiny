<script lang="ts">
	import { api } from '$lib/api';
	import type { Source } from '$lib/bindings/Source';
	import { editor } from '$lib/editor.svelte';
	import { basename, duration } from '$lib/format';
	import { normalizeProject, resolveMedia } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	/** Panneau « Médias » (le Media Pool de DaVinci, en simple) : tous les rushes du
	 * spectacle et les autres montages. Un clic ouvre le rush dans le visualiseur source ;
	 * on le glisse sur la timeline pour l'ajouter. */
	let tab = $state<'rushes' | 'montages'>('rushes');

	const p = $derived(studio.project!);
	const show = $derived(studio.library.find((s) => studio.path && s.projects.includes(studio.path)) ?? null);
	const montages = $derived(show?.montages.filter((m) => !m.master) ?? []);

	// Rushes du spectacle : ceux de l'ingest (project.json « Rushes »), chemins rendus
	// absolus par rapport à leur propre dossier, plus ceux déjà dans le montage.
	let showSources = $state<Source[]>([]);
	$effect(() => {
		const master = show?.montages.find((m) => m.master)?.path;
		if (!master || master === studio.path) {
			showSources = [];
			return;
		}
		api.readJson(master).then(
			(raw) => {
				showSources = normalizeProject(raw).sources.map((s) => ({
					...s,
					path: resolveMedia(master, s.path),
					proxy: s.proxy ? resolveMedia(master, s.proxy) : s.proxy
				}));
			},
			() => (showSources = [])
		);
	});
	const rushes = $derived.by(() => {
		const own = p.sources.map((s) => ({
			...s,
			path: resolveMedia(studio.path, s.path),
			proxy: s.proxy ? resolveMedia(studio.path, s.proxy) : s.proxy
		}));
		return [...own, ...showSources.filter((s) => !own.some((o) => o.path === s.path))];
	});

	/** Vignette de chaque rush (une image vers 10 s), via le cache Rust. */
	let covers = $state<Record<string, string>>({});
	$effect(() => {
		for (const s of rushes) {
			if (s.path in covers) continue;
			covers[s.path] = '';
			const t = Math.min(10, (s.duration ?? 30) / 3);
			api.thumbs({ path: s.proxy ?? s.path, from: t, to: t, step: 1, height: 108 }).then(
				(list) => {
					if (list[0]) covers[s.path] = api.fileSrc(list[0].path);
				},
				(e) => studio.errorOnce(e)
			);
		}
	});

	const usesOf = (s: Source) =>
		p.tracks.flatMap((t) => (t.kind === 'video' ? t.items.filter((c) => p.sources.find((x) => x.id === c.src)?.path === s.path || c.src === s.id) : []));

	// --- Glisser un rush vers la timeline (événements pointeur : marche aussi dans Tauri) --
	let press: { s: Source; x: number; y: number } | null = null;
	function down(e: PointerEvent, s: Source) {
		if (e.button !== 0) return;
		e.preventDefault();
		press = { s, x: e.clientX, y: e.clientY };
	}
	// Le suivi du pointeur et la fin du geste sont gérés par la page Montage.
	function move(e: PointerEvent) {
		if (!press || editor.drag) return;
		if (Math.hypot(e.clientX - press.x, e.clientY - press.y) < 5) return;
		// Morceau glissé : celui marqué dans le visualiseur source si c'est ce rush,
		// sinon les 10 premières secondes.
		const s = press.s;
		const marked = editor.source?.source.path === s.path ? editor.sourceClip() : null;
		const clip = marked ?? { source: s, in: 0, out: Math.min(10, s.duration ?? 10) };
		editor.drag = { clip, x: e.clientX, y: e.clientY };
	}
	function up(s: Source) {
		const wasDrag = !!editor.drag;
		press = null;
		if (!wasDrag) editor.openSource(s);
	}
</script>

<svelte:window onpointermove={move} onpointerup={() => (press = null)} />

<div class="pool">
	<div class="tabs">
		<button class:on={tab === 'rushes'} onclick={() => (tab = 'rushes')} title="Rushes du spectacle : cliquer pour l'ouvrir dans le visualiseur Source, glisser sur la timeline pour le poser (⇧ en lâchant : insérer).">Rushes <span class="dim">{rushes.length}</span></button>
		<button class:on={tab === 'montages'} onclick={() => (tab = 'montages')} title="Les autres montages du même spectacle : un clic ouvre le montage.">Montages <span class="dim">{montages.length}</span></button>
	</div>
	<div class="list scroll">
		{#if tab === 'rushes'}
			<p class="hint dim">Cliquer : ouvrir dans le visualiseur source · glisser : poser sur la timeline</p>
			{#each rushes as s (s.path)}
				{@const uses = usesOf(s)}
				<button
					class="clip"
					class:open={editor.viewer === 'source' && editor.source?.source.path === s.path}
					onpointerdown={(e) => down(e, s)}
					onpointerup={() => up(s)}
					title={`${s.path}\nCliquer : ouvrir dans le visualiseur Source (I / O pour marquer, F9 / F10 pour poser). Glisser sur la timeline : écraser à l'endroit du lâcher, ⇧ en lâchant pour insérer.`}
				>
					<div class="cover">
						{#if covers[s.path]}<img src={covers[s.path]} alt="" draggable="false" />{:else}<span class="mono dim">{s.id}</span>{/if}
						{#if s.duration}<span class="dur mono">{duration(s.duration)}</span>{/if}
					</div>
					<div class="meta">
						<b>{s.id}</b>
						<span class="dim name">{basename(s.path)}</span>
						<span class="dim">{uses.length ? `${uses.length} plan${uses.length > 1 ? 's' : ''} dans le montage` : 'pas encore utilisé'}</span>
					</div>
				</button>
			{:else}
				<p class="dim empty">Aucun rush : ingérez le dossier du spectacle depuis la page Médias.</p>
			{/each}
		{:else}
			{#each montages as m (m.path)}
				<button class="row" class:current={m.path === studio.path} onclick={() => m.path !== studio.path && studio.open(m.path)} title={m.path === studio.path ? 'Montage ouvert.' : `Ouvrir le montage « ${m.name} » dans la timeline (le montage actuel est déjà enregistré).`}>
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
	.hint {
		margin: 0;
		font-size: 10px;
		line-height: 1.4;
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
		cursor: grab;
		touch-action: none;
	}
	.clip.open {
		border-color: var(--gold);
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
