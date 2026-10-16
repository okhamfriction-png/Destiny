<script lang="ts">
	import TimelineItem from './TimelineItem.svelte';
	import { packLanes, rulerStep, type DragMode } from './lanes';
	import type { Project } from '$lib/bindings/Project';
	import type { VoiceItem } from '$lib/bindings/VoiceItem';
	import { editor } from '$lib/editor.svelte';
	import { moveItem, snap, snapSpan, snapTargets, trimItem } from '$lib/edit';
	import { clock } from '$lib/format';
	import {
		itemLabel,
		itemSpan,
		refSpan,
		sameRef,
		sourceOffset,
		TRACK_LABEL,
		TRACK_ORDER,
		type ItemRef
	} from '$lib/project';
	import { studio } from '$lib/state.svelte';

	const HEAD = 128;
	const LANE = 26;
	const PAD = 4;
	const RULER = 26;
	/** Seuil d'aimantation en pixels. */
	const SNAP_PX = 8;

	const p = $derived(studio.project!);

	const rows = $derived.by(() =>
		p.tracks
			.map((track) => {
				const spans = track.items.map((it) => itemSpan(track.kind, it, p));
				const { lane, count } = packLanes(spans);
				return { track, spans, lane, height: count * LANE + PAD * 2 };
			})
			.sort((a, b) => TRACK_ORDER.indexOf(a.track.kind) - TRACK_ORDER.indexOf(b.track.kind))
	);

	let scroller = $state<HTMLDivElement>();
	let viewW = $state(800);
	const contentSec = $derived(Math.max(editor.duration + 8, (viewW - HEAD) / editor.pps));
	const step = $derived(rulerStep(editor.pps));
	const ticks = $derived(Array.from({ length: Math.floor(contentSec / step) + 1 }, (_, i) => i * step));

	/** Segments suspects d'un clip voix, ramenés en temps final. */
	function voiceSuspects(v: VoiceItem): [number, number][] {
		const off = sourceOffset(p, v.src);
		const a = off + v.in;
		const b = off + v.out;
		return studio.suspects
			.filter((s) => s.end > a && s.start < b)
			.map((s) => [v.at + Math.max(s.start, a) - a, v.at + Math.min(s.end, b) - a]);
	}

	// --- Conversion écran → temps --------------------------------------------
	let ruler = $state<HTMLDivElement>();
	const timeAt = (clientX: number) => (clientX - ruler!.getBoundingClientRect().left) / editor.pps;

	// --- Glisser / rogner -----------------------------------------------------
	interface Drag {
		ref: ItemRef;
		mode: DragMode;
		base: Project;
		span: [number, number];
		x0: number;
		targets: number[];
		moved: boolean;
	}
	let drag: Drag | null = null;

	function down(e: PointerEvent, ref: ItemRef, mode: DragMode) {
		if (e.button !== 0) return;
		e.stopPropagation();
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		editor.selection = ref;
		const span = refSpan(p, ref);
		if (!span) return;
		drag = {
			ref,
			mode,
			base: p,
			span,
			x0: e.clientX,
			targets: snapTargets(p, editor.playhead, ref),
			moved: false
		};
	}

	function move(e: PointerEvent) {
		const d = drag;
		if (!d) return;
		const dt = (e.clientX - d.x0) / editor.pps;
		if (!d.moved && Math.abs(e.clientX - d.x0) < 3) return;
		d.moved = true;
		// Alt désactive l'aimantation le temps du geste.
		const magnet = editor.magnet && !e.altKey;
		const thr = SNAP_PX / editor.pps;
		let next: Project;
		let guide: number | null = null;
		if (d.mode === 'move') {
			let start = d.span[0] + dt;
			if (magnet) {
				const r = snapSpan(start, start + d.span[1] - d.span[0], d.targets, thr);
				start = r.t;
				guide = r.target;
			}
			next = moveItem(d.base, d.ref, start);
		} else {
			let t = d.span[d.mode === 'start' ? 0 : 1] + dt;
			if (magnet) {
				const r = snap(t, d.targets, thr);
				t = r.t;
				guide = r.target;
			}
			next = trimItem(d.base, d.ref, d.mode, t);
		}
		editor.snapGuide = guide;
		studio.project = next;
	}

	function up() {
		const d = drag;
		drag = null;
		editor.snapGuide = null;
		if (!d || !d.moved) return;
		const tr = d.base.tracks.find((t) => t.id === d.ref.track)!;
		const name = itemLabel(tr.kind, tr.items[d.ref.index]);
		studio.edit(studio.project!, `${d.mode === 'move' ? 'Déplacer' : 'Rogner'} ${name.slice(0, 40)}`);
	}

	// --- Règle : clic / glisser pour déplacer la tête de lecture ---------------
	let scrubbing = false;
	function rulerDown(e: PointerEvent) {
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		scrubbing = true;
		editor.pause();
		editor.seek(timeAt(e.clientX));
	}
	function rulerMove(e: PointerEvent) {
		if (scrubbing) editor.seek(timeAt(e.clientX));
	}

	// --- Zoom : Ctrl/Cmd + molette, centré sur le curseur ----------------------
	function wheel(e: WheelEvent) {
		if (!(e.ctrlKey || e.metaKey) || !scroller) return;
		e.preventDefault();
		const t = timeAt(e.clientX);
		const before = e.clientX - ruler!.getBoundingClientRect().left - scroller.scrollLeft;
		zoomTo(editor.pps * Math.exp(-e.deltaY * 0.0025));
		scroller.scrollLeft = t * editor.pps - before;
	}

	function zoomTo(pps: number) {
		editor.pps = Math.min(400, Math.max(2, pps));
	}

	function fit() {
		zoomTo((viewW - HEAD - 40) / Math.max(1, editor.duration));
		if (scroller) scroller.scrollLeft = 0;
	}

	// Nouveau projet : toute la durée tient dans la largeur visible.
	let fittedPath: string | null = null;
	$effect(() => {
		const path = studio.path;
		if (path !== fittedPath && viewW > HEAD && editor.duration > 0) {
			fittedPath = path;
			fit();
		}
	});

	// Pendant la lecture, la vue suit la tête de lecture.
	$effect(() => {
		const x = editor.playhead * editor.pps;
		if (!editor.playing || !scroller) return;
		const visible = viewW - HEAD;
		if (x < scroller.scrollLeft || x > scroller.scrollLeft + visible - 40) scroller.scrollLeft = x - visible * 0.2;
	});
</script>

<div class="timeline">
	<div class="tools">
		<button class="icon" class:on={editor.magnet} onclick={() => (editor.magnet = !editor.magnet)} title="Aimantation (Alt pendant le geste pour l'ignorer)">
			<svg viewBox="0 0 24 24" width="14" height="14"><path d="M6 3v9a6 6 0 0 0 12 0V3h-4v9a2 2 0 0 1-4 0V3z" /></svg>
			Aimant
		</button>
		<span class="sep"></span>
		<button class="icon" onclick={() => zoomTo(editor.pps / 1.4)} title="Dézoomer">−</button>
		<input type="range" min="2" max="400" step="1" value={editor.pps} oninput={(e) => zoomTo(+e.currentTarget.value)} title="Zoom (Ctrl + molette)" />
		<button class="icon" onclick={() => zoomTo(editor.pps * 1.4)} title="Zoomer">+</button>
		<button onclick={fit}>Ajuster</button>
		<span class="dim hint">Ctrl+molette : zoom · S : couper · Suppr : supprimer · Maj+Suppr : avec raccord</span>
	</div>

	<div class="scroller" bind:this={scroller} bind:clientWidth={viewW} onwheel={wheel}>
		<div class="content" style:width="{HEAD + contentSec * editor.pps}px">
			<!-- Règle -->
			<div class="rrow" style:height="{RULER}px">
				<div class="head corner mono">{clock(editor.playhead, 2)}</div>
				<div class="ruler" bind:this={ruler} onpointerdown={rulerDown} onpointermove={rulerMove} onpointerup={() => (scrubbing = false)} role="presentation">
					{#each ticks as t (t)}
						<div class="tick" style:left="{t * editor.pps}px"><span>{clock(t, step < 1 ? 1 : 0)}</span></div>
					{/each}
					{#each p.markers.music_hits as h (h)}
						<div class="hit" style:left="{h * editor.pps}px" title="Coup de musique {clock(h, 2)}"></div>
					{/each}
					{#each p.markers.cuts as c (c)}
						<div class="cut" style:left="{c * editor.pps}px" title="Coupe {clock(c, 2)}"></div>
					{/each}
					<div class="phmark" style:left="{editor.playhead * editor.pps}px"></div>
				</div>
			</div>

			<!-- Pistes -->
			{#each rows as row (row.track.id)}
				<div class="row" style:height="{row.height}px">
					<div class="head {row.track.kind}">
						<span class="label">{TRACK_LABEL[row.track.kind]}</span>
						<span class="mono dim">{row.track.id}</span>
					</div>
					<div class="lane" onpointerdown={() => (editor.selection = null)} role="presentation">
						{#if row.track.kind === 'music'}
							{#each p.markers.music_hits as h (h)}<div class="hitline" style:left="{h * editor.pps}px"></div>{/each}
						{/if}
						{#each row.track.items as item, index (index)}
							{@const ref = { track: row.track.id, index }}
							<TimelineItem
								kind={row.track.kind}
								{item}
								start={row.spans[index][0]}
								end={row.spans[index][1]}
								pps={editor.pps}
								top={PAD + row.lane[index] * LANE}
								height={LANE - 3}
								selected={sameRef(editor.selection, ref)}
								suspects={row.track.kind === 'voice' ? voiceSuspects(item as VoiceItem) : []}
								ondown={(e, mode) => down(e, ref, mode)}
							/>
						{/each}
					</div>
				</div>
			{/each}

			<div class="playhead" style:left="{HEAD + editor.playhead * editor.pps}px"></div>
			{#if editor.snapGuide !== null}
				<div class="guide" style:left="{HEAD + editor.snapGuide * editor.pps}px"></div>
			{/if}
		</div>
	</div>
</div>

<svelte:window onpointermove={move} onpointerup={up} />

<style>
	.timeline {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--bg-1);
	}
	.tools {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 5px 10px;
		border-bottom: 1px solid var(--line);
	}
	.tools svg {
		fill: none;
		stroke: currentColor;
		stroke-width: 2;
		vertical-align: -2px;
	}
	.tools input[type='range'] {
		width: 120px;
	}
	.sep {
		width: 1px;
		height: 18px;
		background: var(--line-2);
		margin: 0 4px;
	}
	.hint {
		margin-left: auto;
		font-size: 10px;
	}
	.scroller {
		flex: 1;
		overflow: auto;
		position: relative;
	}
	.content {
		position: relative;
		min-height: 100%;
	}
	.rrow,
	.row {
		display: flex;
		border-bottom: 1px solid var(--line);
	}
	.rrow {
		position: sticky;
		top: 0;
		z-index: 4;
		background: var(--bg-2);
	}
	.head {
		position: sticky;
		left: 0;
		z-index: 3;
		width: 128px;
		flex-shrink: 0;
		display: flex;
		flex-direction: column;
		justify-content: center;
		gap: 2px;
		padding: 0 10px;
		background: var(--bg-2);
		border-right: 1px solid var(--line);
		border-left: 3px solid transparent;
	}
	.head .mono {
		font-size: 9px;
	}
	.head.video {
		border-left-color: var(--tr-video);
	}
	.head.voice {
		border-left-color: var(--tr-voice);
	}
	.head.music {
		border-left-color: var(--tr-music);
	}
	.head.sfx {
		border-left-color: var(--tr-sfx);
	}
	.head.graphics {
		border-left-color: var(--tr-graphics);
	}
	.head.captions {
		border-left-color: var(--tr-captions);
	}
	.corner {
		color: var(--gold-light);
		font-size: 11px;
		z-index: 5;
	}
	.ruler {
		position: relative;
		flex: 1;
		cursor: text;
		overflow: hidden;
	}
	.tick {
		position: absolute;
		top: 0;
		bottom: 0;
		border-left: 1px solid var(--line-2);
		pointer-events: none;
	}
	.tick span {
		position: absolute;
		left: 4px;
		top: 6px;
		font-family: var(--mono);
		font-size: 10px;
		color: var(--text-dim);
		white-space: nowrap;
	}
	.hit {
		position: absolute;
		bottom: 0;
		width: 0;
		height: 0;
		margin-left: -5px;
		border: 5px solid transparent;
		border-bottom: 8px solid var(--gold);
		border-top: none;
	}
	.cut {
		position: absolute;
		bottom: 0;
		height: 10px;
		border-left: 2px solid var(--text);
	}
	.lane {
		position: relative;
		flex: 1;
	}
	.hitline {
		position: absolute;
		top: 0;
		bottom: 0;
		border-left: 1px dashed var(--gold);
		opacity: 0.7;
		pointer-events: none;
	}
	.playhead {
		position: absolute;
		top: 0;
		bottom: 0;
		width: 0;
		border-left: 2px solid var(--gold-light);
		z-index: 2;
		pointer-events: none;
		margin-left: -1px;
	}
	.phmark {
		position: absolute;
		top: 0;
		bottom: 0;
		margin-left: -7px;
		width: 14px;
		pointer-events: none;
	}
	.phmark::before {
		content: '';
		position: absolute;
		bottom: 0;
		left: 0;
		border: 7px solid transparent;
		border-top: 10px solid var(--gold-light);
		border-bottom: none;
	}
	.phmark::after {
		content: '';
		position: absolute;
		top: 0;
		bottom: 0;
		left: 6px;
		border-left: 2px solid var(--gold-light);
	}
	.guide {
		position: absolute;
		top: 0;
		bottom: 0;
		border-left: 1px solid #7fe0ff;
		z-index: 2;
		pointer-events: none;
	}
</style>
