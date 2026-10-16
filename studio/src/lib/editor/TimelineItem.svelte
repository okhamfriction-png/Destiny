<script lang="ts">
	import type { MusicItem } from '$lib/bindings/MusicItem';
	import type { VideoItem } from '$lib/bindings/VideoItem';
	import { clock } from '$lib/format';
	import { itemLabel, type AnyItem, type TrackKind } from '$lib/project';
	import type { DragMode } from './lanes';

	/** Bloc d'un élément dans la timeline, avec poignées de trim. */
	let {
		kind,
		item,
		start,
		end,
		pps,
		top,
		height,
		selected,
		suspects = [],
		ondown
	}: {
		kind: TrackKind;
		item: AnyItem;
		start: number;
		end: number;
		pps: number;
		top: number;
		height: number;
		selected: boolean;
		/** Intervalles suspects (temps final) à surligner en orange. */
		suspects?: [number, number][];
		ondown: (e: PointerEvent, mode: DragMode) => void;
	} = $props();

	const width = $derived(Math.max(2, (end - start) * pps));
	const trimmable = $derived(kind !== 'sfx');
	const label = $derived(itemLabel(kind, item));

	// Enveloppe de gain de la musique (temps vidéo → gain 0..1,2).
	const env = $derived.by(() => {
		if (kind !== 'music') return '';
		const m = item as MusicItem;
		if (!m.gain_env?.length) return '';
		const y = (g: number) => height - 4 - Math.min(1.2, g) / 1.2 * (height - 8);
		const pts = m.gain_env.map(([t, g]) => `${((t - start) * pps).toFixed(1)},${y(g).toFixed(1)}`);
		return `M0,${y(m.gain_env[0][1])}L${pts.join('L')}L${width},${y(m.gain_env[m.gain_env.length - 1][1])}`;
	});
</script>

<div
	class="item {kind}"
	class:selected
	style:left="{start * pps}px"
	style:width="{width}px"
	style:top="{top}px"
	style:height="{height}px"
	title="{label} · {clock(start, 2)} → {clock(end, 2)}"
	onpointerdown={(e) => ondown(e, 'move')}
	role="presentation"
>
	{#each suspects as [a, b] (a)}
		<div class="suspect" style:left="{(a - start) * pps}px" style:width="{(b - a) * pps}px"></div>
	{/each}
	{#if env}<svg class="env" {width} {height}><path d={env} /></svg>{/if}
	<span class="name">
		{#if kind === 'video'}<b>{(item as VideoItem).id}</b> {(item as VideoItem).src} · {clock((item as VideoItem).in)}{:else}{label}{/if}
	</span>
	{#if trimmable && width > 14}
		<div class="handle l" onpointerdown={(e) => (e.stopPropagation(), ondown(e, 'start'))} role="presentation"></div>
		<div class="handle r" onpointerdown={(e) => (e.stopPropagation(), ondown(e, 'end'))} role="presentation"></div>
	{/if}
</div>

<style>
	.item {
		position: absolute;
		border-radius: 3px;
		overflow: hidden;
		cursor: grab;
		border: 1px solid rgba(0, 0, 0, 0.5);
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12);
		display: flex;
		align-items: center;
	}
	.item:active {
		cursor: grabbing;
	}
	.video {
		background: linear-gradient(180deg, #5b89b9, var(--tr-video));
	}
	.voice {
		background: linear-gradient(180deg, #6aa878, var(--tr-voice));
	}
	.music {
		background: linear-gradient(180deg, #a77cc1, var(--tr-music));
	}
	.sfx {
		background: var(--tr-sfx);
	}
	.graphics {
		background: linear-gradient(180deg, #d4ae48, var(--tr-graphics));
		color: #1a1208;
	}
	.captions {
		background: #3a352d;
		border-color: #5a5246;
	}
	.selected {
		outline: 2px solid var(--gold-light);
		outline-offset: 0;
		z-index: 2;
		box-shadow: 0 0 0 1px #000, 0 0 12px rgba(247, 220, 138, 0.35);
	}
	.name {
		position: relative;
		padding: 0 8px;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		pointer-events: none;
	}
	.graphics .name {
		font-family: var(--font-label);
		font-weight: 600;
		font-size: 10px;
	}
	.handle {
		position: absolute;
		top: 0;
		bottom: 0;
		width: 7px;
		cursor: ew-resize;
		z-index: 1;
	}
	.handle.l {
		left: 0;
	}
	.handle.r {
		right: 0;
	}
	.item:hover .handle,
	.selected .handle {
		background: rgba(247, 220, 138, 0.55);
	}
	.suspect {
		position: absolute;
		top: 0;
		bottom: 0;
		background: repeating-linear-gradient(135deg, rgba(240, 138, 36, 0.85) 0 6px, rgba(240, 138, 36, 0.55) 6px 12px);
		pointer-events: none;
	}
	.env {
		position: absolute;
		left: 0;
		top: 0;
		pointer-events: none;
	}
	.env path {
		fill: none;
		stroke: rgba(255, 255, 255, 0.75);
		stroke-width: 1.5;
	}
</style>
