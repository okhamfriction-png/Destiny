<script lang="ts">
	import { api } from '$lib/api';
	import { studio } from '$lib/state.svelte';

	/** Forme d'onde d'un clip audio : enveloppe calculée et mise en cache par Rust
	 * (`media::envelope`), dessinée sur un canvas (pas un nœud DOM par barre). */
	let {
		path,
		from,
		to,
		width,
		height,
		color = 'rgba(255,255,255,0.7)'
	}: { path: string; from: number; to: number; width: number; height: number; color?: string } = $props();

	let canvas = $state<HTMLCanvasElement>();
	let data = $state<number[]>([]);
	// Une barre tous les 2 px, plafonnée : au-delà l'œil ne voit pas la différence.
	const buckets = $derived(Math.max(1, Math.min(4096, Math.round(width / 2))));
	const cw = $derived(Math.max(1, Math.min(8192, Math.round(width))));

	$effect(() => {
		const args = { path, from, to, buckets };
		const id = setTimeout(() => {
			api.waveform(args).then(
				(v) => (data = v),
				(e) => ((data = []), studio.errorOnce(e))
			);
		}, 120);
		return () => clearTimeout(id);
	});

	$effect(() => {
		const ctx = canvas?.getContext('2d');
		if (!ctx) return;
		const dpr = window.devicePixelRatio || 1;
		canvas!.width = cw * dpr;
		canvas!.height = height * dpr;
		ctx.scale(dpr, dpr);
		ctx.clearRect(0, 0, cw, height);
		if (!data.length) return;
		ctx.fillStyle = color;
		const bw = cw / data.length;
		const mid = height / 2;
		for (let i = 0; i < data.length; i++) {
			const h = Math.max(1, data[i] * (height - 4));
			ctx.fillRect(i * bw, mid - h / 2, Math.max(1, bw - 0.6), h);
		}
	});
</script>

<canvas bind:this={canvas} style:width="{width}px" style:height="{height}px"></canvas>

<style>
	canvas {
		position: absolute;
		left: 0;
		top: 0;
		pointer-events: none;
	}
</style>
