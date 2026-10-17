<script lang="ts">
	import type { Snippet } from 'svelte';
	import TimelineItem, { type ItemMedia } from './TimelineItem.svelte';
	import { packLanes, rulerStep, type DragMode } from './lanes';
	import type { MusicItem } from '$lib/bindings/MusicItem';
	import type { Project } from '$lib/bindings/Project';
	import type { Track } from '$lib/bindings/Track';
	import type { VideoItem } from '$lib/bindings/VideoItem';
	import type { VoiceItem } from '$lib/bindings/VoiceItem';
	import { editor } from '$lib/editor.svelte';
	import { closeGaps, linkedRefs, moveGroup, rippleTrimGroup, snap, snapSpan, snapTargets, splitGroup, trimGroup } from '$lib/edit';
	import { clock } from '$lib/format';
	import {
		itemLabel,
		itemSpan,
		refSpan,
		resolveMedia,
		sameRef,
		sourceOffset,
		TRACK_LABEL,
		type AnyItem,
		type ItemRef,
		type TrackKind
	} from '$lib/project';
	import { studio } from '$lib/state.svelte';
	import { place } from './place';

	/** Boutons d'action de l'éditeur, posés à droite de la barre d'outils. */
	let { actions }: { actions?: Snippet } = $props();

	const HEAD = 190;
	const PAD = 3;
	const RULER = 28;
	/** Seuil d'aimantation en pixels. */
	const SNAP_PX = 8;

	/** Pistes dans l'ordre de DaVinci : vidéo en haut (sous-titres et graphismes par-dessus
	 * l'image), audio en dessous. Toujours affichées, même vides : on voit où va chaque chose. */
	const LAYOUT: { kind: TrackKind; code: string; lane: number }[] = [
		{ kind: 'captions', code: 'ST1', lane: 26 },
		{ kind: 'graphics', code: 'V2', lane: 24 },
		{ kind: 'video', code: 'V1', lane: 62 },
		{ kind: 'voice', code: 'A1', lane: 46 },
		{ kind: 'music', code: 'A2', lane: 46 },
		{ kind: 'sfx', code: 'A3', lane: 28 }
	];
	const VISUAL: TrackKind[] = ['captions', 'graphics', 'video'];

	const p = $derived(studio.project!);

	const rows = $derived(
		LAYOUT.flatMap((def) => {
			const tracks = p.tracks.filter((t) => t.kind === def.kind);
			if (!tracks.length) return [{ def, code: def.code, track: null as Track | null, spans: [] as [number, number][], lane: [] as number[], height: def.lane + PAD * 2 }];
			return tracks.map((track, i) => {
				const spans = track.items.map((it) => itemSpan(track.kind, it, p));
				const { lane, count } = packLanes(spans);
				return { def, code: tracks.length > 1 ? `${def.code}.${i + 1}` : def.code, track, spans, lane, height: count * def.lane + PAD * 2 };
			});
		})
	);

	/** Sélection et plans liés (surlignés ensemble). */
	const selected = $derived(editor.selection ? (editor.linked ? linkedRefs(p, editor.selection) : [editor.selection]) : []);

	/** Ce que le clip montre sous son nom : bande d'images ou forme d'onde (calculées par Rust). */
	function mediaOf(kind: TrackKind, item: AnyItem, span: [number, number]): ItemMedia | null {
		if (kind === 'video' || kind === 'voice') {
			const c = item as VideoItem | VoiceItem;
			const s = p.sources.find((x) => x.id === c.src);
			if (!s) return null;
			const path = resolveMedia(studio.path, s.proxy ?? s.path);
			return { kind: kind === 'video' ? 'film' : 'wave', path, from: c.in, to: c.out };
		}
		if (kind === 'music') {
			const m = item as MusicItem;
			return { kind: 'wave', path: resolveMedia(studio.path, m.file), from: m.offset, to: m.offset + span[1] - span[0] };
		}
		return null;
	}

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
	/** Arrondi à l'image : une coupe tombe toujours entre deux images. */
	const toFrame = (t: number) => Math.round(t * editor.fps) / editor.fps;

	// --- Glisser / rogner / lame ---------------------------------------------
	interface Drag {
		ref: ItemRef;
		group: ItemRef[];
		mode: DragMode;
		base: Project;
		span: [number, number];
		x0: number;
		targets: number[];
		moved: boolean;
	}
	let drag: Drag | null = null;

	function down(e: PointerEvent, ref: ItemRef, kind: TrackKind, mode: DragMode) {
		if (e.button !== 0 || editor.locked[kind]) return;
		e.stopPropagation();
		const group = editor.linked ? linkedRefs(p, ref) : [ref];
		if (editor.tool === 'blade') {
			if (kind !== 'video' && kind !== 'voice') return;
			const t = toFrame(timeAt(e.clientX));
			const next = splitGroup(p, group, t);
			if (next !== p) {
				const tr = p.tracks.find((x) => x.id === ref.track)!;
				studio.edit(next, `Lame ${itemLabel(tr.kind, tr.items[ref.index])} à ${clock(t, 2)}`);
				editor.selection = ref;
			}
			return;
		}
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		editor.selection = ref;
		const span = refSpan(p, ref);
		if (!span) return;
		// Les bords du groupe ne sont pas des cibles : sinon le plan colle à sa propre place.
		const own = group.flatMap((r) => refSpan(p, r) ?? []);
		drag = {
			ref,
			group,
			mode,
			base: p,
			span,
			x0: e.clientX,
			targets: snapTargets(p, editor.playhead, ref).filter((x) => !own.some((o) => Math.abs(o - x) < 1e-3)),
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
		let guide: number | null = null;
		let next: Project;
		if (d.mode === 'move') {
			let start = d.span[0] + dt;
			if (magnet) {
				const r = snapSpan(start, start + d.span[1] - d.span[0], d.targets, thr);
				start = r.t;
				guide = r.target;
			}
			next = moveGroup(d.base, d.group, start - d.span[0]);
		} else {
			let t = d.span[d.mode === 'start' ? 0 : 1] + dt;
			if (magnet) {
				const r = snap(t, d.targets, thr);
				t = r.t;
				guide = r.target;
			}
			// Magnétique : la suite suit le bord rogné (pas de trou) ; Alt garde l'ancien comportement.
			next = editor.ripple && !e.altKey ? rippleTrimGroup(d.base, d.group, d.mode, t) : trimGroup(d.base, d.group, d.mode, t);
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
		studio.edit(studio.project!, `${d.mode === 'move' ? 'Déplacer' : editor.ripple ? 'Rogner (magnétique)' : 'Rogner'} ${name.slice(0, 40)}`);
	}

	// Trait rouge de la lame qui suit la souris.
	let bladeX = $state<number | null>(null);
	function hover(e: PointerEvent) {
		bladeX = editor.tool === 'blade' && ruler ? Math.max(0, toFrame(timeAt(e.clientX))) : null;
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

	// --- Zoom : Ctrl/Cmd + molette (ou pincement), centré sur le curseur -------
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

	// Maj+Z (ou bouton) : toute la timeline dans la fenêtre.
	let lastFit = 0;
	$effect(() => {
		if (editor.fitTick !== lastFit) {
			lastFit = editor.fitTick;
			fit();
		}
	});

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

	// --- Dépôt d'un rush glissé depuis les Médias ou le visualiseur source ----------
	// Lâcher = écraser à cet endroit (comme DaVinci) ; Maj = insérer en poussant la suite.
	let dropAt = $state<number | null>(null);
	let dropInsert = $state(false);
	function dragOver(e: PointerEvent) {
		const d = editor.drag;
		if (!d || !scroller || !ruler) {
			dropAt = null;
			return;
		}
		const r = scroller.getBoundingClientRect();
		const inside = e.clientX > r.left + HEAD && e.clientX < r.right && e.clientY > r.top + RULER && e.clientY < r.bottom;
		if (!inside) {
			dropAt = null;
			return;
		}
		let t = Math.max(0, toFrame(timeAt(e.clientX)));
		if (editor.magnet && !e.altKey) {
			const len = d.clip.out - d.clip.in;
			t = Math.max(0, snapSpan(t, t + len, snapTargets(p, editor.playhead, null), SNAP_PX / editor.pps).t);
		}
		dropAt = t;
		dropInsert = e.shiftKey;
	}
	function dropUp(e: PointerEvent) {
		// Position recalculée au relâchement : un geste très rapide peut n'avoir envoyé aucun
		// mouvement au-dessus de la timeline.
		dragOver(e);
		const d = editor.drag;
		if (d && dropAt !== null) place(d.clip, dropAt, e.shiftKey ? 'insert' : 'overwrite');
		dropAt = null;
	}

	function fillGaps() {
		const next = closeGaps(p);
		if (next === p) studio.info('Aucun trou dans V1.');
		else studio.edit(next, 'Fermer les trous de V1');
	}

	const toggle = (rec: Partial<Record<TrackKind, boolean>>, k: TrackKind) => ({ ...rec, [k]: !rec[k] });
</script>

<div class="timeline" class:blade={editor.tool === 'blade'}>
	<div class="tools">
		<div class="group" role="radiogroup" aria-label="Outil">
			<button class="tool" class:on={editor.tool === 'select'} onclick={() => (editor.tool = 'select')} title="Outil Sélection : cliquer pour sélectionner un plan, le glisser pour le déplacer, tirer ses bords pour le rogner. Raccourci : A.">
				<svg viewBox="0 0 24 24"><path d="M5 3l14 8-6 2-3 6z" /></svg>
			</button>
			<button class="tool" class:on={editor.tool === 'blade'} onclick={() => (editor.tool = 'blade')} title="Outil Lame : cliquer sur un plan le coupe en deux à l'endroit du clic, à l'image près (avec sa voix liée). Raccourci : B. Échap revient à la Sélection.">
				<svg viewBox="0 0 24 24"><path d="M4 20L15 9M14 4l6 6-5 1-2-2z" /></svg>
			</button>
		</div>
		<span class="sep"></span>
		<button class="tool" class:on={editor.ripple} onclick={() => (editor.ripple = !editor.ripple)} title="Montage magnétique (ripple) — activé : supprimer ou rogner un plan referme la place sur toutes les pistes, jamais de trou. Désactivé : il reste un trou. Raccourci : ⇧R. Pendant un rognage, ⌥ ignore le mode magnétique.">
			<svg viewBox="0 0 24 24"><path d="M3 8h6v8H3zM15 8h6v8h-6zM10 12h4M12 10l2 2-2 2" /></svg>
		</button>
		<button class="tool" onclick={fillGaps} title="Fermer les trous : recolle tous les plans de V1 les uns aux autres, et tout ce qui suit un trou recule d'autant (toutes pistes).">
			<svg viewBox="0 0 24 24"><path d="M4 7h5v10H4zM15 7h5v10h-5zM9 12h6M11 10l-2 2 2 2M13 10l2 2-2 2" /></svg>
		</button>
		<span class="sep"></span>
		<button class="tool" class:on={editor.magnet} onclick={() => (editor.magnet = !editor.magnet)} title="Aimantation : en glissant, les plans s'accrochent aux bords des autres plans, à la tête de lecture et aux coups de musique. Raccourci : N. Maintenir ⌥ pendant le geste pour l'ignorer.">
			<svg viewBox="0 0 24 24"><path d="M6 3v9a6 6 0 0 0 12 0V3h-4v9a2 2 0 0 1-4 0V3z" /></svg>
		</button>
		<button class="tool" class:on={editor.linked} onclick={() => (editor.linked = !editor.linked)} title="Sélection liée : un plan vidéo et sa voix (même découpe) se déplacent, se rognent, se coupent et se suppriment ensemble. Raccourci : ⌘⇧L.">
			<svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1" /></svg>
		</button>
		<span class="sep"></span>
		<button class="tool" disabled={!studio.server?.canUndo} onclick={() => studio.undo()} title="Annuler la dernière action{studio.server?.undoLabel ? ` : « ${studio.server.undoLabel} »` : ''}. Raccourci : ⌘Z.">
			<svg viewBox="0 0 24 24"><path d="M9 14L4 9l5-5M4 9h10a6 6 0 0 1 0 12h-3" /></svg>
		</button>
		<button class="tool" disabled={!studio.server?.canRedo} onclick={() => studio.redo()} title="Rétablir l'action annulée{studio.server?.redoLabel ? ` : « ${studio.server.redoLabel} »` : ''}. Raccourci : ⇧⌘Z.">
			<svg viewBox="0 0 24 24"><path d="M15 14l5-5-5-5M20 9H10a6 6 0 0 0 0 12h3" /></svg>
		</button>
		<span class="sep"></span>
		<button class="tool" onclick={() => zoomTo(editor.pps / 1.4)} title="Dézoomer la timeline (voir plus de temps). Raccourci : ⌘− ou ⌘ + molette vers le bas.">−</button>
		<input type="range" min="2" max="400" step="1" value={editor.pps} oninput={(e) => zoomTo(+e.currentTarget.value)} title="Zoom de la timeline. Raccourcis : ⌘= / ⌘−, ou ⌘ + molette (pincement sur le trackpad)." />
		<button class="tool" onclick={() => zoomTo(editor.pps * 1.4)} title="Zoomer la timeline (voir plus de détail). Raccourci : ⌘= ou ⌘ + molette vers le haut.">+</button>
		<button onclick={fit} title="Ajuster : toute la durée du montage tient dans la largeur de la timeline. Raccourci : ⇧Z.">Ajuster</button>
		<div class="grow"></div>
		{@render actions?.()}
	</div>

	<div class="scroller" bind:this={scroller} bind:clientWidth={viewW} onwheel={wheel} onpointermove={hover} onpointerleave={() => (bladeX = null)} role="presentation">
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
			{#each rows as row (row.code)}
				{@const kind = row.def.kind}
				{@const visual = VISUAL.includes(kind)}
				<div class="row" class:audio={!visual} class:first-audio={kind === 'voice'} style:height="{row.height}px">
					<div class="head {kind}">
						<span class="code">{row.code}</span>
						<span class="tname">{TRACK_LABEL[kind]}</span>
						<span class="count dim">{row.track?.items.length ?? 0}</span>
						<span class="btns">
							<button class="mini" class:on={editor.off[kind]} onclick={() => (editor.off = toggle(editor.off, kind))} title={visual ? `Masquer ${TRACK_LABEL[kind]} dans le visualiseur (n'agit pas sur le rendu final).` : `Couper le son de ${TRACK_LABEL[kind]} dans le visualiseur (n'agit pas sur le rendu final).`}>
								{#if visual}
									<svg viewBox="0 0 24 24"><path d={editor.off[kind] ? 'M3 3l18 18M10.6 6.1A9 9 0 0 1 21 12a14 14 0 0 1-2.6 3.3M6.6 6.6A14 14 0 0 0 3 12s3.5 6 9 6a8 8 0 0 0 4-1' : 'M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z'} /></svg>
								{:else}
									<b>M</b>
								{/if}
							</button>
							<button class="mini" class:on={editor.locked[kind]} onclick={() => (editor.locked = toggle(editor.locked, kind))} title={`Verrouiller ${TRACK_LABEL[kind]} : ses éléments ne peuvent plus être sélectionnés, déplacés, rognés ni coupés (S et la Lame l'ignorent).`}>
								<svg viewBox="0 0 24 24"><path d={editor.locked[kind] ? 'M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4' : 'M6 11h12v10H6zM8 11V7a4 4 0 0 1 7.5-2'} /></svg>
							</button>
						</span>
					</div>
					<div class="lane" class:locked={editor.locked[kind]} class:off={editor.off[kind]} onpointerdown={() => (editor.selection = null)} role="presentation">
						{#if kind === 'music'}
							{#each p.markers.music_hits as h (h)}<div class="hitline" style:left="{h * editor.pps}px"></div>{/each}
						{/if}
						{#if row.track}
							{#each row.track.items as item, index (index)}
								{@const ref = { track: row.track.id, index }}
								<TimelineItem
									{kind}
									{item}
									start={row.spans[index][0]}
									end={row.spans[index][1]}
									pps={editor.pps}
									top={PAD + row.lane[index] * row.def.lane}
									height={row.def.lane - 3}
									selected={selected.some((r) => sameRef(r, ref))}
									media={mediaOf(kind, item, row.spans[index])}
									suspects={kind === 'voice' ? voiceSuspects(item as VoiceItem) : []}
									ondown={(e, mode) => down(e, ref, kind, mode)}
								/>
							{/each}
						{/if}
					</div>
				</div>
			{/each}

			<div class="playhead" style:left="{HEAD + editor.playhead * editor.pps}px"></div>
			{#if editor.snapGuide !== null}
				<div class="guide" style:left="{HEAD + editor.snapGuide * editor.pps}px"></div>
			{/if}
			{#if dropAt !== null && editor.drag}
				{@const len = editor.drag.clip.out - editor.drag.clip.in}
				<div class="drop" class:insert={dropInsert} style:left="{HEAD + dropAt * editor.pps}px" style:width="{Math.max(2, len * editor.pps)}px">
					<span>{dropInsert ? 'Insérer' : 'Écraser'} · {clock(dropAt, 2)}</span>
				</div>
			{/if}
			{#if bladeX !== null}
				<div class="bladeline" style:left="{HEAD + bladeX * editor.pps}px"></div>
			{/if}
		</div>
	</div>
</div>

<svelte:window onpointermove={(e) => (move(e), dragOver(e))} onpointerup={(e) => (up(), dropUp(e))} />

<style>
	.timeline {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #14110d;
	}
	.tools {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 4px 10px;
		border-bottom: 1px solid var(--line);
		background: var(--bg-1);
	}
	.group {
		display: flex;
		gap: 2px;
		padding: 2px;
		border-radius: 5px;
		background: var(--bg-2);
	}
	.tool {
		min-width: 28px;
		height: 26px;
		padding: 0 6px;
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}
	.tool svg,
	.mini svg {
		width: 15px;
		height: 15px;
		fill: none;
		stroke: currentColor;
		stroke-width: 2;
		stroke-linecap: round;
		stroke-linejoin: round;
	}
	.tool.on {
		color: var(--gold-light);
		background: #2a2111;
		border-color: #6b5420;
	}
	.tools input[type='range'] {
		width: 110px;
	}
	.sep {
		width: 1px;
		height: 18px;
		background: var(--line-2);
		margin: 0 6px;
	}
	.grow {
		flex: 1;
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
		border-bottom: 1px solid #241f18;
	}
	.row.first-audio {
		border-top: 2px solid #3a3226;
	}
	.row.audio .lane {
		background: #110f0b;
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
		width: 190px;
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 0 6px 0 8px;
		background: var(--bg-2);
		border-right: 1px solid var(--line);
		border-left: 3px solid transparent;
	}
	.code {
		font-family: var(--mono);
		font-size: 10px;
		font-weight: 700;
		color: var(--text);
		min-width: 26px;
	}
	.tname {
		font-size: 11px;
		color: var(--text-dim);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		flex: 1;
	}
	.count {
		font-family: var(--mono);
		font-size: 9px;
	}
	.btns {
		display: flex;
		gap: 2px;
	}
	.mini {
		width: 20px;
		height: 20px;
		padding: 0;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		font-size: 10px;
		border-color: transparent;
		background: transparent;
		color: var(--text-mute, #8a8070);
	}
	.mini:hover {
		color: var(--text);
		border-color: var(--line-2);
	}
	.mini.on {
		color: #1a1208;
		background: var(--gold);
	}
	.mini svg {
		width: 13px;
		height: 13px;
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
	.lane.locked {
		background-image: repeating-linear-gradient(135deg, rgba(255, 255, 255, 0.03) 0 6px, transparent 6px 12px);
	}
	.lane.locked :global(.item) {
		cursor: not-allowed;
	}
	.lane.off :global(.item) {
		opacity: 0.4;
	}
	.blade .lane :global(.item) {
		cursor: crosshair;
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
	.drop {
		position: absolute;
		top: 28px;
		bottom: 0;
		z-index: 4;
		pointer-events: none;
		background: rgba(91, 137, 185, 0.28);
		border-left: 2px solid #9cc4ff;
		border-right: 1px solid #9cc4ff;
	}
	.drop.insert {
		background: rgba(230, 180, 70, 0.25);
		border-left-color: var(--gold-light);
		border-right-color: var(--gold);
	}
	.drop span {
		position: absolute;
		top: 4px;
		left: 6px;
		font-size: 10px;
		white-space: nowrap;
		color: #fff;
		background: rgba(0, 0, 0, 0.6);
		padding: 1px 5px;
		border-radius: 2px;
	}
	.bladeline {
		position: absolute;
		top: 28px;
		bottom: 0;
		border-left: 1px solid #ff5a4f;
		z-index: 3;
		pointer-events: none;
	}
</style>
