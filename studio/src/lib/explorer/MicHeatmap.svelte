<script lang="ts">
	import type { MicMap } from '$lib/bindings/MicMap';
	import type { Mic } from '$lib/bindings/Mic';
	import type { Suspect } from '$lib/bindings/Suspect';
	import { clock } from '$lib/format';
	import { dbColor } from './colors';

	/** Carte des micros : une ligne par micro, couleur = niveau, micro dominant surligné,
	 * segments suspects en orange. Glisser pour choisir une plage. */
	let {
		map,
		mics = [],
		suspects = [],
		range = null,
		onrange
	}: {
		map: MicMap;
		mics?: Mic[];
		suspects?: Suspect[];
		range?: [number, number] | null;
		onrange?: (r: [number, number]) => void;
	} = $props();

	const ROW = 26;
	const AXIS = 18;
	let canvas = $state<HTMLCanvasElement>();
	let width = $state(800);

	const n = $derived(map.levels[0]?.length ?? 0);
	const t1 = $derived(map.t0 + n * map.hop);
	const height = $derived(map.mics.length * ROW + AXIS);
	const x = (t: number) => ((t - map.t0) / (t1 - map.t0)) * width;
	const tAt = (px: number) => map.t0 + (px / width) * (t1 - map.t0);

	function actor(id: string) {
		return mics.find((m) => m.id === id)?.actor ?? id;
	}

	$effect(() => {
		const c = canvas;
		if (!c || n === 0) return;
		const dpr = window.devicePixelRatio || 1;
		c.width = width * dpr;
		c.height = height * dpr;
		const g = c.getContext('2d')!;
		g.scale(dpr, dpr);
		g.clearRect(0, 0, width, height);
		const cw = width / n;
		map.levels.forEach((row, m) => {
			const y = m * ROW;
			row.forEach((db, k) => {
				g.fillStyle = dbColor(db);
				g.fillRect(k * cw, y + 1, Math.ceil(cw), ROW - 2);
			});
			// Micro dominant : liseré clair en bas de la case.
			map.dominant.forEach((d, k) => {
				if (d === m) {
					g.fillStyle = '#fff6dc';
					g.fillRect(k * cw, y + ROW - 5, Math.ceil(cw), 3);
				}
			});
		});
		// Suspects : chuchotements de coulisses, en orange.
		for (const s of suspects) {
			const m = map.mics.indexOf(s.mic);
			if (m < 0) continue;
			g.strokeStyle = '#f08a24';
			g.lineWidth = 2;
			g.fillStyle = 'rgba(240,138,36,0.35)';
			g.fillRect(x(s.start), m * ROW + 1, x(s.end) - x(s.start), ROW - 2);
			g.strokeRect(x(s.start), m * ROW + 1, x(s.end) - x(s.start), ROW - 2);
		}
		// Axe des temps.
		g.fillStyle = '#a89d8d';
		g.font = '10px ui-monospace, monospace';
		const step = niceStep((t1 - map.t0) / Math.max(1, width / 90));
		for (let t = Math.ceil(map.t0 / step) * step; t < t1; t += step) {
			g.fillRect(x(t), height - AXIS, 1, 4);
			g.fillText(clock(t, 0), x(t) + 3, height - 5);
		}
	});

	function niceStep(raw: number): number {
		for (const s of [1, 2, 5, 10, 15, 30, 60, 120, 300, 600]) if (s >= raw) return s;
		return 1200;
	}

	let dragFrom: number | null = null;
	function down(e: PointerEvent) {
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		dragFrom = tAt(e.offsetX);
		onrange?.([dragFrom, dragFrom + map.hop]);
	}
	function move(e: PointerEvent) {
		if (dragFrom === null) return;
		const t = tAt(Math.min(width, Math.max(0, e.offsetX)));
		onrange?.([Math.min(dragFrom, t), Math.max(dragFrom, t)]);
	}
	function up() {
		dragFrom = null;
	}
</script>

<div class="heatmap">
	<div class="names">
		{#each map.mics as m (m)}
			<div class="name" style:height="{ROW}px">
				<span class="mono">{m}</span>
				<span>{actor(m)}</span>
			</div>
		{/each}
	</div>
	<div class="plot" bind:clientWidth={width} onpointerdown={down} onpointermove={move} onpointerup={up} role="presentation">
		<canvas bind:this={canvas} style:width="{width}px" style:height="{height}px"></canvas>
		{#if range}
			<div class="sel" style:left="{x(range[0])}px" style:width="{Math.max(2, x(range[1]) - x(range[0]))}px" style:height="{height - AXIS}px"></div>
		{/if}
	</div>
</div>

<div class="legend">
	<span class="dim">−60 dB</span>
	<i class="ramp"></i>
	<span class="dim">−14 dB</span>
	<span class="key dom"></span><span class="dim">micro dominant</span>
	<span class="key sus"></span><span class="dim">suspect (chuchotement de coulisses)</span>
</div>

<style>
	.heatmap {
		display: flex;
		gap: 8px;
	}
	.names {
		width: 110px;
		flex-shrink: 0;
	}
	.name {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
	}
	.name .mono {
		color: var(--gold);
		font-size: 10px;
	}
	.plot {
		position: relative;
		flex: 1;
		min-width: 0;
		cursor: crosshair;
	}
	canvas {
		display: block;
	}
	.sel {
		position: absolute;
		top: 0;
		border: 1px solid var(--gold-light);
		background: rgba(247, 220, 138, 0.12);
		pointer-events: none;
	}
	.legend {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 10px;
		margin-top: 6px;
		padding-left: 118px;
	}
	.ramp {
		width: 120px;
		height: 8px;
		background: linear-gradient(90deg, #0b0907, #302212, #78501c, #e6b446, #fbe7a6);
		border: 1px solid var(--line);
	}
	.key {
		width: 14px;
		height: 8px;
		margin-left: 10px;
	}
	.key.dom {
		background: linear-gradient(transparent 60%, #fff6dc 60%);
		border: 1px solid var(--line-2);
	}
	.key.sus {
		background: rgba(240, 138, 36, 0.5);
		border: 1px solid #f08a24;
	}
</style>
