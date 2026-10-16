<script lang="ts">
	import JobProgress from '$lib/components/JobProgress.svelte';
	import ReportCard from '$lib/components/ReportCard.svelte';
	import { api, type RenderResult } from '$lib/api';
	import { basename, duration } from '$lib/format';
	import { clone, projectDuration } from '$lib/project';
	import { studio, type Job } from '$lib/state.svelte';

	const p = $derived(studio.project);
	/** Jobs de rendu/export (le `kind` n'est connu qu'au premier événement : on regarde aussi le libellé). */
	const isRender = (j: Job) => j.kind === 'render' || j.kind === 'export' || /^(Rendu|Export)/.test(j.label);
	const queue = $derived(studio.jobs.filter(isRender));
	const others = $derived(studio.jobs.filter((j) => !isRender(j)));

	function resultOf(j: Job): RenderResult | null {
		const r = j.result as Partial<RenderResult> | null;
		return r && r.report ? (r as RenderResult) : null;
	}

	async function preview() {
		await studio.flush();
		await studio.startJob(`Rendu aperçu · ${name()}`, () => api.render({ quality: 'preview', out: null }));
	}

	async function deliver() {
		await studio.flush();
		await studio.startJob(`Export livraison · ${name()}`, () => api.exportProject(p?.export.targets.length ? p.export.targets : null));
	}

	function name() {
		return p?.export.name ?? (studio.path ? basename(studio.path) : 'montage');
	}

	function setTargets(text: string) {
		if (!p) return;
		const next = clone(p);
		next.export.targets = text
			.split('\n')
			.map((s) => s.trim())
			.filter(Boolean);
		studio.edit(next, 'Destinations d’export', 'export-targets');
	}

	function setName(v: string) {
		if (!p) return;
		const next = clone(p);
		next.export.name = v || null;
		studio.edit(next, 'Nom du fichier exporté', 'export-name');
	}
</script>

<header class="bar">
	<div>
		<div class="kicker">Export</div>
		<h1>File de rendus</h1>
	</div>
	<div class="grow"></div>
	<button disabled={!p} onclick={preview}>Aperçu rapide</button>
	<button class="primary" disabled={!p} onclick={deliver}>Exporter (livraison + NAS)</button>
</header>

<div class="body">
	<aside class="panel settings">
		<h3>Montage ouvert</h3>
		{#if p}
			<div class="mono dim path">{studio.path}</div>
			<div class="chips">
				<span class="chip gold">{p.preset}</span>
				<span class="chip">{p.format.w}×{p.format.h} · {p.format.fps} i/s</span>
				<span class="chip">{duration(projectDuration(p))}</span>
			</div>
			<label><span>Nom du fichier</span><input value={p.export.name ?? ''} oninput={(e) => setName(e.currentTarget.value)} /></label>
			<label>
				<span>Destinations (une par ligne)</span>
				<textarea rows="4" value={p.export.targets.join('\n')} oninput={(e) => setTargets(e.currentTarget.value)}></textarea>
			</label>
			<p class="dim note">Rendu en local puis copie vers le NAS avec reprise et contrôle md5. Rien n'est publié.</p>
		{:else}
			<p class="dim">Ouvrez un montage depuis la bibliothèque.</p>
		{/if}
	</aside>

	<section class="queue scroll">
		{#each queue as j (j.id)}
			{@const r = resultOf(j)}
			<article class="panel job">
				<JobProgress job={j} />
				{#if r}
					<div class="mono dim out">{r.out}</div>
					<ReportCard report={r.report} />
				{/if}
			</article>
		{:else}
			<p class="dim empty">Aucun rendu pour l'instant. « Aperçu rapide » rend une version légère pour vérifier le montage.</p>
		{/each}

		{#if others.length}
			<h3 class="sub">Autres tâches</h3>
			{#each others as j (j.id)}
				<article class="panel job"><JobProgress job={j} /></article>
			{/each}
		{/if}
	</section>
</div>

<style>
	.bar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 14px 20px;
		border-bottom: 1px solid var(--line);
	}
	.grow {
		flex: 1;
	}
	.body {
		flex: 1;
		min-height: 0;
		display: grid;
		grid-template-columns: 340px 1fr;
		gap: 16px;
		padding: 16px 20px;
	}
	.settings {
		padding: 14px;
		display: flex;
		flex-direction: column;
		gap: 12px;
		align-self: start;
	}
	.path {
		font-size: 10px;
		word-break: break-all;
	}
	.chips {
		display: flex;
		gap: 5px;
		flex-wrap: wrap;
	}
	textarea {
		resize: vertical;
		font-family: var(--mono);
		font-size: 11px;
	}
	.note {
		font-size: 11px;
		margin: 0;
	}
	.queue {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.job {
		padding: 12px 14px;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.out {
		font-size: 10px;
	}
	.empty {
		font-style: italic;
	}
	.sub {
		margin-top: 10px;
		color: var(--text-dim);
	}
</style>
