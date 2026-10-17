<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import JobProgress from '$lib/components/JobProgress.svelte';
	import { api } from '$lib/api';
	import { basename } from '$lib/format';
	import { studio } from '$lib/state.svelte';

	let { onclose }: { onclose: () => void } = $props();

	let dir = $state('/Volumes/ShikaZero/Spectacle/8 Octobre 2026');
	let projectDir = $state('');
	let proxies = $state(true);
	let sheets = $state(true);
	let jobId = $state<string | null>(null);

	/** Dossier projet proposé : <racine>/<nom du dossier de rushes>. */
	const suggested = $derived(`${studio.root}/${basename(dir)}`);
	const job = $derived(studio.job(jobId));

	async function start() {
		jobId = await studio.startJob(
			`Ingest · ${basename(dir)}`,
			() => api.ingest({ dir, projectDir: projectDir || suggested, proxies, sheets }),
			(e) => {
				if (!e.error) {
					studio.info('Ingest terminé');
					void studio.refreshLibrary();
				}
			}
		);
	}
</script>

<Modal title="Ingérer un dossier" {onclose}>
	<label>
		<span>Dossier des rushes</span>
		<input bind:value={dir} placeholder="/Volumes/ShikaZero/Spectacle/…" />
	</label>
	<label>
		<span>Dossier projet</span>
		<input bind:value={projectDir} placeholder={suggested} />
	</label>
	<div class="row">
		<label class="inline"><input type="checkbox" bind:checked={proxies} /> Créer les proxies manquants (720p)</label>
		<label class="inline"><input type="checkbox" bind:checked={sheets} /> Planches contact (toutes les 2,5 s)</label>
	</div>
	{#if job}<JobProgress {job} />{/if}

	{#snippet footer()}
		<button onclick={onclose} title="Fermer cette fenêtre (l'ingest en cours continue en arrière-plan). Raccourci : Échap.">{job?.done ? 'Fermer' : 'Annuler'}</button>
		<button class="primary" disabled={!dir || (!!job && !job.done)} onclick={start} title="Lancer l'ingest : lecture des fichiers, proxies et planches contact si demandés, synchronisation des micros.">Lancer l'ingest</button>
	{/snippet}
</Modal>

<style>
	.row {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
</style>
