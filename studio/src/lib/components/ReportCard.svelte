<script lang="ts">
	import type { Report } from '$lib/bindings/Report';
	import { num } from '$lib/format';

	/** Vérifications automatiques d'un rendu (durée, son non muet, loudness). */
	let { report }: { report: Report } = $props();

	const durOk = $derived(Math.abs(report.duration - report.expected_duration) < 0.2);
	const silent = $derived(report.mean_volume_db == null || report.mean_volume_db <= -40);
</script>

<div class="report">
	<dl>
		<div class:bad={!durOk}>
			<dt>Durée</dt>
			<dd>{num(report.duration, 2, 's')} <small>attendu {num(report.expected_duration, 2, 's')}</small></dd>
		</div>
		<div>
			<dt>Image</dt>
			<dd>{report.width ?? '—'}×{report.height ?? '—'}</dd>
		</div>
		<div class:bad={silent}>
			<dt>Volume moyen</dt>
			<dd>{num(report.mean_volume_db, 1, 'dB')} {#if silent}<small>muet ?</small>{/if}</dd>
		</div>
		<div>
			<dt>Loudness</dt>
			<dd>{num(report.integrated_lufs, 1, 'LUFS')}</dd>
		</div>
		<div>
			<dt>True peak</dt>
			<dd>{num(report.true_peak_db, 1, 'dBTP')}</dd>
		</div>
	</dl>
	{#if report.problems.length}
		<ul class="problems">
			{#each report.problems as p, i (i)}<li>{p}</li>{/each}
		</ul>
	{:else}
		<div class="ok">Aucun problème détecté</div>
	{/if}
</div>

<style>
	.report {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	dl {
		display: grid;
		grid-template-columns: repeat(5, minmax(0, 1fr));
		gap: 6px;
		margin: 0;
	}
	dl > div {
		background: var(--bg);
		border: 1px solid var(--line);
		border-radius: var(--radius);
		padding: 6px 8px;
	}
	dt {
		font-family: var(--font-label);
		font-size: 9px;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		color: var(--text-dim);
	}
	dd {
		margin: 3px 0 0;
		font-family: var(--mono);
		font-size: 13px;
	}
	small {
		color: var(--text-mute);
		font-size: 10px;
	}
	.bad {
		border-color: var(--red);
	}
	.bad dd {
		color: var(--red);
	}
	.problems {
		margin: 0;
		padding-left: 18px;
		color: var(--red);
	}
	.ok {
		color: var(--ok);
		font-size: 12px;
	}
</style>
