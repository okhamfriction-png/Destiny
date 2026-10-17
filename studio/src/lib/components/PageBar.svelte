<script lang="ts">
	import { basename } from '$lib/format';
	import { studio, type View } from '$lib/state.svelte';

	/** Barre des pages en bas de la fenêtre, comme DaVinci (Media, Edit, Deliver…). */
	const pages: { view: View; label: string; icon: string }[] = [
		{ view: 'library', label: 'Médias', icon: 'M4 5h4v14H4zM10 5h4v14h-4zM16 6l3.5-1 3 13.5-3.5 1z' },
		{ view: 'explorer', label: 'Analyse', icon: 'M3 12h3l3-7 4 14 3-7h5' },
		{ view: 'proposals', label: 'Propositions', icon: 'M5 4h14v6H5zM5 14h6v6H5zM13 14h6v6h-6z' },
		{ view: 'editor', label: 'Montage', icon: 'M3 6h18M3 12h12M3 18h16M9 3v6M17 9v6M13 15v6' },
		{ view: 'export', label: 'Livraison', icon: 'M12 3v12M7 10l5 5 5-5M4 19h16' }
	];

	const running = $derived(studio.jobs.filter((j) => !j.done).length);
</script>

<footer>
	<div class="logo" title="Destiny Studio">DESTINY <span>STUDIO</span></div>
	<nav>
		{#each pages as pg (pg.view)}
			<button
				class="ghost"
				class:active={studio.view === pg.view}
				disabled={pg.view === 'editor' && !studio.project}
				onclick={() => (studio.view = pg.view)}
				title={pg.label}
			>
				<svg viewBox="0 0 24 24" width="18" height="18"><path d={pg.icon} /></svg>
				<span>{pg.label}</span>
				{#if pg.view === 'export' && running > 0}<i class="badge">{running}</i>{/if}
			</button>
		{/each}
	</nav>
	<div class="current dim">{studio.path ? basename(studio.path).replace(/\.json$/, '') : ''}</div>
</footer>

<style>
	footer {
		display: grid;
		grid-template-columns: 1fr auto 1fr;
		align-items: center;
		padding: 0 14px;
		background: var(--bg-1);
		border-top: 1px solid var(--line);
	}
	.logo {
		font-family: var(--font-title);
		font-weight: 900;
		font-size: 13px;
		letter-spacing: 0.12em;
		background: var(--gold-gradient);
		-webkit-background-clip: text;
		background-clip: text;
		color: transparent;
	}
	.logo span {
		font-weight: 700;
		font-size: 9px;
		letter-spacing: 0.3em;
	}
	nav {
		display: flex;
		gap: 2px;
	}
	button {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
		min-width: 86px;
		padding: 4px 10px;
		font-size: 8.5px;
		letter-spacing: 0.08em;
		color: var(--text-dim);
		border-color: transparent;
	}
	button.active {
		color: var(--gold-light);
	}
	button.active::after {
		content: '';
		position: absolute;
		left: 22%;
		right: 22%;
		bottom: -1px;
		height: 2px;
		background: var(--gold);
		border-radius: 1px;
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
		top: 1px;
		right: 18px;
		font-style: normal;
		font-size: 9px;
		background: var(--gold);
		color: #1a1208;
		border-radius: 8px;
		padding: 0 4px;
	}
	.current {
		justify-self: end;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		max-width: 100%;
	}
</style>
