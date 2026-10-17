<script lang="ts">
	import { api } from '$lib/api';

	/** Bande d'images d'un plan vidéo : vignettes extraites et mises en cache par Rust
	 * (`media::thumbs`). Le pas suit le zoom pour qu'une vignette couvre toujours sa place. */
	let { path, from, to, pps, height }: { path: string; from: number; to: number; pps: number; height: number } =
		$props();

	const thumbW = $derived(Math.round((height * 16) / 9));
	const STEPS = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300];
	const step = $derived(STEPS.find((s) => s * pps >= thumbW) ?? 600);

	let thumbs = $state<{ t: number; url: string }[]>([]);

	$effect(() => {
		const args = { path, from: Math.max(0, from - step), to, step, height: Math.round(height * 2) };
		// Attente courte : pendant un zoom à la molette, seule la dernière demande part.
		const id = setTimeout(() => {
			api.thumbs(args).then(
				(list) => (thumbs = list.map((x) => ({ t: x.t, url: api.fileSrc(x.path) }))),
				() => {}
			);
		}, 120);
		return () => clearTimeout(id);
	});
</script>

<div class="strip" style:height="{height}px">
	{#each thumbs as th (th.t)}
		<img src={th.url} alt="" style:left="{(th.t - from) * pps}px" style:width="{step * pps}px" draggable="false" />
	{/each}
</div>

<style>
	.strip {
		position: absolute;
		left: 0;
		right: 0;
		bottom: 0;
		overflow: hidden;
		pointer-events: none;
	}
	img {
		position: absolute;
		top: 0;
		height: 100%;
		object-fit: cover;
		border-right: 1px solid rgba(0, 0, 0, 0.45);
		opacity: 0.9;
	}
</style>
