<script lang="ts">
	import { api } from '$lib/api';
	import { basename } from '$lib/format';

	/** Vignette d'un fichier image local ; mire si le fichier n'est pas lisible. */
	let { path, onclick }: { path: string; onclick?: () => void } = $props();

	let failed = $state(false);
	const src = $derived(api.fileSrc(path));
</script>

<button class="thumb ghost" title={basename(path)} {onclick}>
	{#if src && !failed}
		<img {src} alt={basename(path)} onerror={() => (failed = true)} />
	{:else}
		<div class="placeholder">
			{#each Array(24) as _, i (i)}<i style:opacity={0.25 + ((i * 37) % 11) / 20}></i>{/each}
		</div>
	{/if}
	<span class="name">{basename(path)}</span>
</button>

<style>
	.thumb {
		position: relative;
		padding: 0;
		width: 168px;
		aspect-ratio: 16 / 10;
		overflow: hidden;
		border: 1px solid var(--line);
		background: #000;
		text-transform: none;
		letter-spacing: 0;
	}
	img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}
	.placeholder {
		display: grid;
		grid-template-columns: repeat(8, 1fr);
		gap: 2px;
		padding: 4px;
		height: 100%;
	}
	.placeholder i {
		background: linear-gradient(135deg, #3a2f22, #1d1813);
		border-radius: 1px;
	}
	.name {
		position: absolute;
		left: 0;
		right: 0;
		bottom: 0;
		padding: 2px 6px;
		font-family: var(--mono);
		font-size: 9px;
		text-align: left;
		color: var(--text-dim);
		background: rgba(0, 0, 0, 0.7);
	}
</style>
