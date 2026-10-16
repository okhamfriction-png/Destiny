<script lang="ts">
	import type { Job } from '$lib/state.svelte';
	import { api } from '$lib/api';

	let { job, compact = false }: { job: Job; compact?: boolean } = $props();

	const pct = $derived(Math.round(job.progress * 100));
</script>

<div class="job" class:compact>
	<div class="head">
		<span class="label">{job.label}</span>
		<span class="stage">{job.error ? job.error : job.done ? 'Terminé' : job.stage}</span>
		<span class="mono pct">{pct} %</span>
		{#if !job.done}
			<button class="icon ghost" title="Annuler" onclick={() => api.cancelJob(job.id)}>✕</button>
		{/if}
	</div>
	<div class="progress" class:error={!!job.error} class:done={job.done && !job.error}>
		<div style:width="{job.done && !job.error ? 100 : pct}%"></div>
	</div>
</div>

<style>
	.job {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}
	.head {
		display: flex;
		align-items: center;
		gap: 10px;
		min-height: 24px;
	}
	.stage {
		flex: 1;
		color: var(--text-dim);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.pct {
		color: var(--gold-light);
	}
	.compact .label {
		display: none;
	}
</style>
