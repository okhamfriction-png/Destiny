<script lang="ts">
	import { studio, type View } from '$lib/state.svelte';

	const items: { view: View; label: string; icon: string }[] = [
		{ view: 'library', label: 'Bibliothèque', icon: 'M4 5h4v14H4zM10 5h4v14h-4zM16 6l3.5-1 3 13.5-3.5 1z' },
		{ view: 'explorer', label: 'Explorateur', icon: 'M3 12h3l3-7 4 14 3-7h5' },
		{ view: 'proposals', label: 'Propositions', icon: 'M5 4h14v6H5zM5 14h6v6H5zM13 14h6v6h-6z' },
		{ view: 'editor', label: 'Éditeur', icon: 'M3 6h18M3 12h12M3 18h16M9 3v6M17 9v6M13 15v6' },
		{ view: 'export', label: 'Export', icon: 'M12 3v12M7 10l5 5 5-5M4 19h16' }
	];

	const running = $derived(studio.jobs.filter((j) => !j.done).length);
</script>

<nav>
	<div class="logo" title="Destiny Studio">D</div>
	{#each items as it (it.view)}
		<button
			class="ghost"
			class:active={studio.view === it.view}
			disabled={it.view === 'editor' && !studio.project}
			onclick={() => (studio.view = it.view)}
			title={it.label}
		>
			<svg viewBox="0 0 24 24" width="20" height="20"><path d={it.icon} /></svg>
			<span>{it.label}</span>
			{#if it.view === 'export' && running > 0}<i class="badge">{running}</i>{/if}
		</button>
	{/each}
</nav>

<style>
	nav {
		display: flex;
		flex-direction: column;
		align-items: stretch;
		gap: 2px;
		padding: 10px 4px;
		background: var(--bg-1);
		border-right: 1px solid var(--line);
	}
	.logo {
		font-family: var(--font-title);
		font-weight: 900;
		font-size: 26px;
		text-align: center;
		background: var(--gold-gradient);
		-webkit-background-clip: text;
		background-clip: text;
		color: transparent;
		margin-bottom: 12px;
	}
	button {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		padding: 8px 2px;
		font-size: 7.5px;
		letter-spacing: 0.06em;
		color: var(--text-dim);
	}
	button.active {
		color: var(--gold-light);
		background: #221b10;
		border-color: #4a3b1c;
	}
	svg {
		fill: none;
		stroke: currentColor;
		stroke-width: 1.6;
		stroke-linecap: round;
		stroke-linejoin: round;
	}
	.badge {
		position: absolute;
		top: 3px;
		right: 8px;
		font-style: normal;
		font-size: 9px;
		background: var(--gold);
		color: #1a1208;
		border-radius: 8px;
		padding: 0 4px;
	}
</style>
