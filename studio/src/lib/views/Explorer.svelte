<script lang="ts">
	import MicHeatmap from '$lib/explorer/MicHeatmap.svelte';
	import TranscriptList from '$lib/explorer/TranscriptList.svelte';
	import MusicViewer from '$lib/explorer/MusicViewer.svelte';
	import JobProgress from '$lib/components/JobProgress.svelte';
	import { api, type AnalyzeResult } from '$lib/api';
	import type { MediaIndex } from '$lib/bindings/MediaIndex';
	import type { MicMap } from '$lib/bindings/MicMap';
	import type { MusicAnalysis } from '$lib/bindings/MusicAnalysis';
	import type { Transcript } from '$lib/bindings/Transcript';
	import { basename, clock, num } from '$lib/format';
	import { studio } from '$lib/state.svelte';

	let transcript = $state<Transcript | null>(null);
	let micmap = $state<MicMap | null>(null);
	let media = $state<MediaIndex | null>(null);
	let musicFile = $state('');
	let music = $state<MusicAnalysis | null>(null);
	let model = $state('');
	let jobId = $state<string | null>(null);

	const shows = $derived(studio.library.filter((s) => s.hasIngest));
	const show = $derived(studio.show ?? shows[0] ?? null);
	const musics = $derived(media?.files.filter((f) => f.kind === 'music') ?? []);
	const job = $derived(studio.job(jobId));
	const range = $derived(studio.range);

	/** Convention de nommage : la carte des micros accompagne sa transcription. */
	const micmapPath = (t: string) => t.replace(/transcript_([^/]*)$/, 'micmap_$1');

	// Spectacle choisi → index des médias et première transcription.
	$effect(() => {
		const s = show;
		if (!s) return;
		media = null;
		api.readJson<MediaIndex>(`${s.dir}/.cache/ingest.json`).then((m) => (media = m), () => (media = null));
		if (!studio.transcript || !s.transcripts.includes(studio.transcript)) studio.transcript = s.transcripts[0] ?? null;
	});

	// Transcription choisie → répliques et carte des micros.
	$effect(() => {
		const path = studio.transcript;
		transcript = null;
		micmap = null;
		if (!path) return;
		api.readJson<Transcript>(path).then(
			(t) => {
				transcript = t;
				if (!studio.range && t.segments.length) studio.range = [t.segments[0].start, t.segments[t.segments.length - 1].end];
			},
			(e) => studio.error(e)
		);
		api.readJson<MicMap>(micmapPath(path)).then(
			(m) => (micmap = m),
			() => (micmap = null)
		);
	});

	function setRange(r: [number, number]) {
		studio.range = [Math.round(r[0] * 10) / 10, Math.round(r[1] * 10) / 10];
	}

	async function analyze() {
		if (!range) return;
		jobId = await studio.startJob(
			`Analyse ${clock(range[0])} → ${clock(range[1])}`,
			() => api.analyze({ from: range[0], to: range[1], model: model || null }),
			(e) => {
				if (e.error) return;
				const r = e.result as AnalyzeResult;
				studio.suspects = r.suspects;
				studio.transcript = r.transcript;
				studio.info(`Analyse terminée · ${r.suspects.length} segment(s) suspect(s)`);
				void studio.refreshLibrary();
			}
		);
	}

	async function analyzeMusic() {
		if (!musicFile) return;
		try {
			music = await api.musicAnalysis(musicFile);
		} catch (e) {
			studio.error(e);
		}
	}
</script>

<header class="bar">
	<div>
		<div class="kicker">Explorateur</div>
		<h1>{show?.name ?? 'Aucun spectacle'}</h1>
	</div>
	<label>
		<span>Spectacle</span>
		<select value={show?.dir} onchange={(e) => (studio.show = shows.find((s) => s.dir === e.currentTarget.value) ?? null)}>
			{#each shows as s (s.dir)}<option value={s.dir}>{s.name}</option>{/each}
		</select>
	</label>
	<label>
		<span>Transcription</span>
		<select bind:value={studio.transcript}>
			{#each show?.transcripts ?? [] as t (t)}<option value={t}>{basename(t)}</option>{/each}
		</select>
	</label>
	<div class="grow"></div>
	<label>
		<span>De (s maître)</span>
		<input type="number" step="0.1" value={range?.[0] ?? 0} onchange={(e) => setRange([+e.currentTarget.value, range?.[1] ?? +e.currentTarget.value + 10])} />
	</label>
	<label>
		<span>À</span>
		<input type="number" step="0.1" value={range?.[1] ?? 0} onchange={(e) => setRange([range?.[0] ?? 0, +e.currentTarget.value])} />
	</label>
	<span class="mono dim dur">{range ? num(range[1] - range[0], 1, 's') : ''}</span>
	<label>
		<span>Modèle whisper</span>
		<input placeholder="défaut" bind:value={model} style:width="110px" />
	</label>
	<button class="primary" disabled={!range || (!!job && !job.done)} onclick={analyze} title="Analyser le passage choisi : transcription des micros, carte de qui parle, chuchotements de coulisses.">Analyser</button>
	<button disabled={!range} onclick={() => (studio.view = 'proposals')} title="Proposer un short sur le passage choisi (page Propositions).">Proposer un short…</button>
</header>

{#if job && !job.done}<div class="jobline"><JobProgress {job} /></div>{/if}

<div class="body">
	<section class="panel transcript">
		<div class="phead"><h3>Transcription</h3><span class="dim">clic : plage · Maj+clic : étendre</span></div>
		<TranscriptList
			segments={transcript?.segments ?? []}
			mics={studio.project?.mics}
			dictionary={studio.project?.dictionary}
			{range}
			onrange={setRange}
		/>
	</section>

	<div class="right">
		<section class="panel">
			<div class="phead">
				<h3>Carte des micros</h3>
				{#if studio.suspects.length}<span class="chip warn">{studio.suspects.length} suspect(s)</span>{/if}
			</div>
			<div class="pad">
				{#if micmap}
					<MicHeatmap map={micmap} mics={studio.project?.mics} suspects={studio.suspects} {range} onrange={setRange} />
				{:else}
					<p class="dim">Pas de carte des micros pour cette transcription : lancez « Analyser ».</p>
				{/if}
			</div>
		</section>

		<section class="panel">
			<div class="phead">
				<h3>Musique</h3>
				<input list="musics" placeholder="Fichier musique (.m4a, .wav…)" bind:value={musicFile} class="file" />
				<datalist id="musics">{#each musics as m (m.path)}<option value={m.path}>{basename(m.path)}</option>{/each}</datalist>
				<button disabled={!musicFile} onclick={analyzeMusic} title="Analyser la musique : coups forts, creux et coup le plus fort (pour caler la carte finale).">Analyser la musique</button>
			</div>
			<div class="pad">
				{#if music}<MusicViewer analysis={music} />{:else}<p class="dim">Choisissez une musique pour voir son énergie, ses coups et ses creux.</p>{/if}
			</div>
		</section>
	</div>
</div>

<style>
	.bar {
		display: flex;
		align-items: flex-end;
		gap: 12px;
		padding: 14px 20px;
		border-bottom: 1px solid var(--line);
		flex-wrap: wrap;
	}
	.bar input[type='number'] {
		width: 92px;
	}
	.grow {
		flex: 1;
	}
	.dur {
		padding-bottom: 7px;
	}
	.jobline {
		padding: 8px 20px;
		border-bottom: 1px solid var(--line);
	}
	.body {
		flex: 1;
		min-height: 0;
		display: grid;
		grid-template-columns: minmax(340px, 34%) 1fr;
		gap: 12px;
		padding: 12px 20px 16px;
	}
	.transcript {
		display: flex;
		flex-direction: column;
		min-height: 0;
	}
	.right {
		display: flex;
		flex-direction: column;
		gap: 12px;
		min-width: 0;
		overflow: auto;
	}
	.phead {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 12px;
		border-bottom: 1px solid var(--line);
	}
	.phead .dim {
		font-size: 11px;
	}
	.pad {
		padding: 12px;
	}
	.pad p {
		margin: 0;
		font-style: italic;
	}
	.file {
		flex: 1;
	}
</style>
