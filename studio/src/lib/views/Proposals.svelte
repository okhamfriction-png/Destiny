<script lang="ts">
	import { api } from '$lib/api';
	import type { Project } from '$lib/bindings/Project';
	import type { ShortOpts } from '$lib/bindings/ShortOpts';
	import { basename, clock, duration } from '$lib/format';
	import { graphics, normalizeProject, projectDuration, videoItems } from '$lib/project';
	import { studio } from '$lib/state.svelte';
	import { wrapHook } from '$lib/layout';

	const show = $derived(studio.show ?? studio.library.find((s) => s.hasIngest) ?? null);

	let from = $state(studio.range?.[0] ?? 0);
	let to = $state(studio.range?.[1] ?? 30);
	let kicker = $state('SCÈNE 1/25');
	let hook1 = $state('');
	let hook2 = $state('');
	let emphasis = $state('');
	let punchAt = $state<number | null>(null);
	let cta1 = $state('VIENS VOIR DESTINY');
	let cta2 = $state('LIEN EN BIO');
	let name = $state('');
	let busy = $state(false);

	/** Résumés des montages (chargés à la demande). */
	let summaries = $state<Record<string, Project | null>>({});

	const slug = (s: string) =>
		s
			.normalize('NFD')
			.replace(/[̀-ͯ]/g, '')
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, '_')
			.replace(/^_|_$/g, '') || 'short';

	const outName = $derived(name || slug(`${hook1} ${hook2}`));
	const out = $derived(show ? `${show.dir}/montages/${outName}.json` : '');
	const paths = $derived([...new Set([...studio.proposals, ...(show?.projects ?? [])])]);
	const hookPreview = $derived(wrapHook([hook1, hook2].filter(Boolean)));

	$effect(() => {
		for (const p of paths) {
			if (p in summaries) continue;
			summaries[p] = null;
			api.readJson(p).then(
				(raw) => {
					summaries[p] = normalizeProject(raw);
				},
				() => {}
			);
		}
	});

	async function propose() {
		if (!show) return;
		busy = true;
		const opts: ShortOpts = {
			kicker: kicker || null,
			hook: [hook1, hook2].filter(Boolean),
			cta: [cta1, cta2].filter(Boolean),
			punch_at: punchAt,
			emphasis: emphasis
				.split(/[,;]/)
				.map((s) => s.trim())
				.filter(Boolean),
			crop: null
		};
		try {
			const path = await api.proposeShort({ from, to, opts, transcript: studio.transcript, out });
			studio.proposals = [path, ...studio.proposals.filter((p) => p !== path)];
			delete summaries[path];
			studio.info(`Montage proposé : ${basename(path)}`);
			void studio.refreshLibrary();
		} catch (e) {
			studio.error(e);
		} finally {
			busy = false;
		}
	}

	function hookOf(p: Project): string[] {
		const h = graphics(p).find((g) => g.type === 'hook');
		return h?.type === 'hook' ? h.lines : [];
	}
	function kickerOf(p: Project): string | null {
		const k = graphics(p).find((g) => g.type === 'kicker');
		return k?.type === 'kicker' ? k.text : null;
	}
</script>

<header class="bar">
	<div>
		<div class="kicker">Propositions · {show?.name ?? '—'}</div>
		<h1>Proposer un short</h1>
	</div>
</header>

<div class="body">
	<form class="panel form" onsubmit={(e) => (e.preventDefault(), propose())}>
		<div class="row">
			<label><span>De (s maître)</span><input type="number" step="0.1" bind:value={from} /></label>
			<label><span>À</span><input type="number" step="0.1" bind:value={to} /></label>
			<div class="dur mono dim">{clock(from)} → {clock(to)} · {duration(Math.max(0, to - from))}</div>
		</div>
		<label><span>Kicker</span><input bind:value={kicker} placeholder="LE PLUS REVU · 1/3" /></label>
		<label><span>Hook · ligne 1</span><input bind:value={hook1} maxlength="40" placeholder="UN IMMENSE SERPENT" /></label>
		<label><span>Hook · ligne 2</span><input bind:value={hook2} maxlength="40" placeholder="AUX YEUX VERTS" /></label>
		{#if hookPreview.length}
			<div class="hook-preview">
				{#each hookPreview as l, i (i)}<div class:long={[...l].length > 20}>{l.toUpperCase()}</div>{/each}
			</div>
		{/if}
		<label><span>Mots d'emphase (virgules)</span><input bind:value={emphasis} placeholder="serpent, morsure" /></label>
		<div class="row">
			<label>
				<span>Punch-in à (s maître)</span>
				<input type="number" step="0.1" value={punchAt ?? ''} oninput={(e) => (punchAt = e.currentTarget.value === '' ? null : +e.currentTarget.value)} placeholder="aucun" />
			</label>
			<label class="grow"><span>Fichier</span><input bind:value={name} placeholder={outName} /></label>
		</div>
		<div class="row">
			<label class="grow"><span>CTA · ligne 1</span><input bind:value={cta1} /></label>
			<label class="grow"><span>CTA · ligne 2</span><input bind:value={cta2} /></label>
		</div>
		<div class="foot">
			<span class="mono dim out">{out}</span>
			<button class="primary" type="submit" disabled={busy || !show || to <= from}>{busy ? 'Proposition…' : 'Proposer'}</button>
		</div>
	</form>

	<section class="cards scroll">
		{#each paths as p (p)}
			{@const s = summaries[p]}
			<article class="card panel" class:fresh={studio.proposals.includes(p)}>
				<div class="mini">
					{#if s}
						{#if kickerOf(s)}<div class="mk">{kickerOf(s)}</div>{/if}
						<div class="mh">{#each hookOf(s) as l, i (i)}<div>{l}</div>{/each}</div>
					{/if}
				</div>
				<div class="info">
					<h3>{basename(p).replace(/\.json$/, '')}</h3>
					{#if s}
						<div class="chips">
							<span class="chip gold">{s.preset}</span>
							<span class="chip">{duration(projectDuration(s))}</span>
							<span class="chip">{s.format.w}×{s.format.h}</span>
							<span class="chip">{videoItems(s).length} plan(s)</span>
						</div>
						<div class="dim moments">
							{#each videoItems(s) as c (c.id)}<span class="mono">{clock(c.in)}→{clock(c.out)}</span>{/each}
						</div>
					{:else}
						<span class="dim">Chargement…</span>
					{/if}
					<button class="primary" onclick={() => studio.open(p)}>Ouvrir dans l'éditeur</button>
				</div>
			</article>
		{:else}
			<p class="dim">Aucun montage proposé pour ce spectacle.</p>
		{/each}
	</section>
</div>

<style>
	.bar {
		padding: 14px 20px;
		border-bottom: 1px solid var(--line);
	}
	.body {
		flex: 1;
		min-height: 0;
		display: grid;
		grid-template-columns: 420px 1fr;
		gap: 16px;
		padding: 16px 20px;
	}
	.form {
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
		overflow: auto;
	}
	.row {
		display: flex;
		gap: 10px;
		align-items: flex-end;
	}
	.row > label {
		flex: 1;
		min-width: 0;
	}
	.row input {
		width: 100%;
	}
	.grow {
		flex: 1;
	}
	.dur {
		flex: 1.4;
		padding-bottom: 7px;
		font-size: 11px;
	}
	.hook-preview {
		background: #000;
		padding: 10px;
		text-align: center;
		font-family: var(--font-anton);
		font-size: 22px;
		line-height: 1.1;
	}
	.hook-preview .long {
		color: var(--orange);
	}
	.foot {
		display: flex;
		align-items: center;
		gap: 10px;
		margin-top: 4px;
	}
	.out {
		flex: 1;
		font-size: 10px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.cards {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
		align-content: start;
		gap: 12px;
	}
	.card {
		display: flex;
		gap: 12px;
		padding: 12px;
	}
	.card.fresh {
		border-color: #6b5420;
	}
	.mini {
		width: 90px;
		aspect-ratio: 9 / 16;
		background: linear-gradient(#14100c 0 15%, #000 15% 26%, #2b241b 26% 63%, #14100c 63%);
		border: 1px solid var(--line-2);
		padding-top: 6px;
		text-align: center;
		flex-shrink: 0;
		overflow: hidden;
	}
	.mk {
		font-family: var(--font-label);
		font-size: 5px;
		letter-spacing: 0.32em;
		color: var(--gold-light);
	}
	.mh {
		margin-top: 4px;
		font-family: var(--font-anton);
		font-size: 8px;
		line-height: 1.1;
		text-transform: uppercase;
	}
	.info {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 8px;
		align-items: flex-start;
		min-width: 0;
	}
	.chips {
		display: flex;
		gap: 5px;
		flex-wrap: wrap;
	}
	.moments {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
		font-size: 10px;
	}
	.info button {
		margin-top: auto;
	}
</style>
