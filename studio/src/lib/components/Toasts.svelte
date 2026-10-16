<script lang="ts">
	import { studio } from '$lib/state.svelte';
</script>

<div class="toasts" aria-live="polite">
	{#each studio.toasts as t (t.id)}
		<div class="toast {t.kind}">{t.text}</div>
	{/each}
</div>

<style>
	.toasts {
		position: fixed;
		right: 16px;
		bottom: 16px;
		display: flex;
		flex-direction: column;
		gap: 8px;
		z-index: 100;
		max-width: 420px;
	}
	.toast {
		padding: 10px 14px;
		border-radius: 6px;
		background: var(--bg-2);
		border: 1px solid var(--line-2);
		border-left: 3px solid var(--gold);
		box-shadow: 0 6px 24px rgba(0, 0, 0, 0.5);
		user-select: text;
	}
	.toast.error {
		border-left-color: var(--red);
		color: #f5c2bd;
	}
</style>
