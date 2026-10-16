<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		title,
		onclose,
		children,
		footer,
		width = 520
	}: { title: string; onclose: () => void; children: Snippet; footer?: Snippet; width?: number } = $props();

	function onkeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			e.stopPropagation();
			onclose();
		}
	}
</script>

<svelte:window {onkeydown} />

<div class="backdrop" role="presentation" onpointerdown={(e) => e.target === e.currentTarget && onclose()}>
	<div class="modal panel" role="dialog" aria-modal="true" aria-label={title} style:width="{width}px">
		<header>
			<h2>{title}</h2>
			<button class="icon ghost" onclick={onclose} title="Fermer">✕</button>
		</header>
		<div class="body">{@render children()}</div>
		{#if footer}<footer>{@render footer()}</footer>{/if}
	</div>
</div>

<style>
	.backdrop {
		position: fixed;
		inset: 0;
		background: rgba(5, 4, 3, 0.72);
		display: grid;
		place-items: center;
		z-index: 50;
	}
	.modal {
		max-width: calc(100vw - 40px);
		max-height: calc(100vh - 40px);
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
	}
	header,
	footer {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		padding: 12px 16px;
	}
	header {
		border-bottom: 1px solid var(--line);
	}
	footer {
		border-top: 1px solid var(--line);
		justify-content: flex-end;
	}
	.body {
		padding: 16px;
		overflow: auto;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
</style>
