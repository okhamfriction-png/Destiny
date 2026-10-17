<script lang="ts">
	import Modal from '$lib/components/Modal.svelte';
	import { api, type ClaudeAnswer } from '$lib/api';
	import { studio } from '$lib/state.svelte';

	/** « Demander à Claude » : consigne → patch JSON proposé, appliqué seulement sur demande. */
	let { onclose }: { onclose: () => void } = $props();

	let instruction = $state('');
	let answer = $state<ClaudeAnswer | null>(null);
	let busy = $state(false);

	async function ask() {
		busy = true;
		answer = null;
		try {
			await studio.flush();
			answer = await api.askClaude(instruction);
		} catch (e) {
			studio.error(e);
		} finally {
			busy = false;
		}
	}

	async function apply() {
		if (!answer) return;
		const label = `Claude : ${instruction.trim().slice(0, 48)}${instruction.length > 48 ? '…' : ''}`;
		if (await studio.applyPatch(answer.patch, label)) {
			studio.info('Patch appliqué (annulable avec Ctrl+Z)');
			onclose();
		}
	}
</script>

<Modal title="Demander à Claude" {onclose} width={640}>
	<label>
		<span>Consigne</span>
		<textarea
			rows="3"
			bind:value={instruction}
			placeholder="Ex. : raccourcis le hook, recadre plus serré sur les comédiens, ajoute un flash sur la coupe…"
			onkeydown={(e) => e.key === 'Enter' && (e.metaKey || e.ctrlKey) && instruction.trim() && ask()}
		></textarea>
	</label>
	{#if answer}
		<div class="answer">
			<p>{answer.explanation}</p>
			<div class="label">Patch proposé · {answer.patch.length} opération{answer.patch.length > 1 ? 's' : ''}</div>
			<pre class="mono">{JSON.stringify(answer.patch, null, 2)}</pre>
		</div>
	{/if}

	{#snippet footer()}
		{#if answer}
			<button onclick={() => (answer = null)} title="Refuser la proposition de Claude : rien n'est modifié.">Annuler</button>
			<button class="primary" disabled={answer.patch.length === 0} onclick={apply} title="Appliquer la proposition de Claude au montage. Annulable avec ⌘Z.">Appliquer</button>
		{:else}
			<button onclick={onclose} title="Fermer sans rien demander. Raccourci : Échap.">Fermer</button>
			<button class="primary" disabled={busy || !instruction.trim()} onclick={ask} title="Envoyer la consigne à Claude, qui propose une modification du montage. Raccourci : ⌘↩.">{busy ? 'Claude réfléchit…' : 'Envoyer'}</button>
		{/if}
	{/snippet}
</Modal>

<style>
	textarea {
		resize: vertical;
	}
	.answer {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.answer p {
		margin: 0;
		line-height: 1.5;
		user-select: text;
	}
	pre {
		margin: 0;
		padding: 10px;
		background: var(--bg);
		border: 1px solid var(--line);
		border-radius: var(--radius);
		max-height: 260px;
		overflow: auto;
		color: var(--gold-light);
		font-size: 11px;
		user-select: text;
	}
</style>
