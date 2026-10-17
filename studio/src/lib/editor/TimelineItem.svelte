<script lang="ts">
	import type { GraphicItem } from '$lib/bindings/GraphicItem';
	import type { MusicItem } from '$lib/bindings/MusicItem';
	import type { VideoItem } from '$lib/bindings/VideoItem';
	import { clock } from '$lib/format';
	import { DEFAULT_PUSH, FLASH_DUR, PUNCH_DUR, PUNCH_IN_ZOOM } from '$lib/layout';
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
	const gtype = $derived(kind === 'graphics' ? (item as GraphicItem).type : '');

	// Effets du plan rendus visibles sur le bloc (temps relatifs au début du plan) :
	// flash et punch à l'entrée, fenêtre de punch-in, rampe du push en filigrane.
	const fx = $derived.by(() => {
		if (kind !== 'video') return [];
		const c = item as VideoItem;
		const dur = end - start;
		const out: { cls: string; a: number; b: number; label: string }[] = [];
		if (c.fx?.flash && start > 0) out.push({ cls: 'flash', a: 0, b: Math.min(FLASH_DUR, dur), label: 'flash' });
		if (c.fx?.punch) out.push({ cls: 'punch', a: 0, b: Math.min(PUNCH_DUR, dur), label: 'punch' });
		const pi = c.fx?.punch_in;
		if (pi) out.push({ cls: 'punchin', a: Math.max(0, pi[0]), b: Math.min(dur, pi[1]), label: `zoom ×${PUNCH_IN_ZOOM}` });
		return out;
	});
	const push = $derived(kind === 'video' ? ((item as VideoItem).fx?.push ?? DEFAULT_PUSH) : 0);

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
	class="item {kind} {gtype && `g-${gtype}`}"
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
	{#if push > 0 && width > 30}
		<!-- Rampe du zoom continu : plus elle monte, plus le plan avance vers le sujet. -->
		<svg class="push" {width} {height} preserveAspectRatio="none">
			<path d="M0,{height - 3}L{width},{height - 3 - Math.min(1, push / 0.12) * (height - 8)}" />
		</svg>
	{/if}
	{#each fx as f (f.cls)}
		<div class="fx {f.cls}" style:left="{f.a * pps}px" style:width="{Math.max(3, (f.b - f.a) * pps)}px">
			{#if (f.b - f.a) * pps > 34}<span>{f.label}</span>{/if}
		</div>
	{/each}
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
	/* Une teinte par famille de graphisme : on repère d'un coup d'œil accroche, bandeau, appel. */
	.g-hook,
	.g-card,
	.g-fin {
		background: linear-gradient(180deg, #f2d27a, #c99a2e);
	}
	.g-kicker,
	.g-tag,
	.g-tags,
	.g-lower {
		background: linear-gradient(180deg, #f7e7b0, #e2c56e);
	}
	.g-cta,
	.g-end_card {
		background: linear-gradient(180deg, #ef5b4f, #b8281f);
		color: #fff;
	}
	.g-progress,
	.g-ring,
	.g-black {
		background: #6b5a32;
		color: #f3ede4;
	}
	.g-reviews,
	.g-reviews_txt,
	.g-quotes {
		background: linear-gradient(180deg, #e0b25c, #a87a2a);
	}
	.g-mech,
	.g-dice,
	.g-constellation {
		background: linear-gradient(180deg, #c9a2e0, #8a5fb0);
		color: #fff;
	}
	.g-flash {
		background: #fff3dc;
	}
	/* Les effets occupent la moitié basse du plan : le nom reste lisible au-dessus. */
	.video {
		align-items: flex-start;
	}
	.video .name {
		padding-top: 1px;
	}
	.fx {
		position: absolute;
		top: 50%;
		bottom: 0;
		pointer-events: none;
		display: flex;
		align-items: flex-end;
		font-family: var(--font-label);
		font-size: 8px;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: #1a1208;
	}
	.fx span {
		padding: 0 3px 1px;
	}
	.fx.flash {
		background: linear-gradient(90deg, rgba(255, 243, 220, 0.95), rgba(255, 243, 220, 0));
	}
	.fx.punch {
		background: linear-gradient(90deg, rgba(247, 220, 138, 0.9), rgba(247, 220, 138, 0));
	}
	.fx.punchin {
		background: repeating-linear-gradient(135deg, rgba(224, 53, 43, 0.75) 0 5px, rgba(224, 53, 43, 0.45) 5px 10px);
		border-left: 1px solid #f7dc8a;
		border-right: 1px solid #f7dc8a;
		color: #fff;
	}
	.push {
		position: absolute;
		left: 0;
		top: 0;
		pointer-events: none;
	}
	.push path {
		stroke: rgba(255, 255, 255, 0.35);
		stroke-width: 1;
		stroke-dasharray: 3 3;
		fill: none;
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
