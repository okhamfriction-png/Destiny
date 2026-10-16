<script lang="ts">
	import type { MusicAnalysis } from '$lib/bindings/MusicAnalysis';
	import { basename, clock, num } from '$lib/format';

	/** Courbe d'énergie d'une musique, onsets, coups forts et creux. */
	let { analysis }: { analysis: MusicAnalysis } = $props();

	const H = 120;
	let width = $state(800);
	const lo = -60;
	const hi = 0;
	const x = (t: number) => (t / analysis.duration) * width;
	const y = (db: number) => H - ((Math.max(lo, Math.min(hi, db)) - lo) / (hi - lo)) * H;

	const path = $derived(
		analysis.env.map((db, k) => `${k === 0 ? 'M' : 'L'}${x(k * analysis.hop).toFixed(1)},${y(db).toFixed(1)}`).join('')
	);
	const area = $derived(`${path}L${width},${H}L0,${H}Z`);
</script>

<div class="music">
	<div class="head">
		<h3>{basename(analysis.file)}</h3>
		<span class="dim mono">{num(analysis.duration, 1, 's')}</span>
		<span class="chip gold">{analysis.hits.length} coups</span>
		<span class="chip">{analysis.onsets.length} onsets</span>
		<span class="chip">{analysis.dips.length} creux</span>
		{#if analysis.biggest_hit != null}<span class="chip gold">coup final {clock(analysis.biggest_hit)}</span>{/if}
	</div>
	<div class="plot" bind:clientWidth={width}>
		<svg {width} height={H + 16}>
			{#each analysis.dips as [a, b] (a)}
				<rect class="dip" x={x(a)} y="0" width={x(b) - x(a)} height={H} />
			{/each}
			<path class="area" d={area} />
			<path class="line" d={path} />
			{#each analysis.onsets as o (o.t)}
				<line class="onset" x1={x(o.t)} x2={x(o.t)} y1={H - 10} y2={H} />
			{/each}
			{#each analysis.hits as h (h)}
				<line class="hit" class:big={h === analysis.biggest_hit} x1={x(h)} x2={x(h)} y1="0" y2={H} />
				<text x={x(h) + 3} y="11">{clock(h)}</text>
			{/each}
			{#each Array(Math.floor(analysis.duration / 10) + 1) as _, i (i)}
				<text class="axis" x={x(i * 10) + 2} y={H + 13}>{clock(i * 10, 0)}</text>
			{/each}
		</svg>
	</div>
</div>

<style>
	.music {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.head {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.plot {
		width: 100%;
	}
	svg {
		display: block;
	}
	.area {
		fill: rgba(154, 107, 181, 0.25);
	}
	.line {
		fill: none;
		stroke: #b98ad4;
		stroke-width: 1.2;
	}
	.dip {
		fill: rgba(255, 255, 255, 0.04);
	}
	.onset {
		stroke: var(--text-dim);
	}
	.hit {
		stroke: var(--gold);
		stroke-width: 1.5;
	}
	.hit.big {
		stroke: var(--red);
		stroke-width: 2.5;
	}
	text {
		fill: var(--gold-light);
		font-size: 10px;
		font-family: var(--mono);
	}
	text.axis {
		fill: var(--text-mute);
	}
</style>
