<script lang="ts">
	import { api } from '$lib/api';
	import { videoEnd } from '$lib/edit';
	import { editor } from '$lib/editor.svelte';
	import { duration, timecode } from '$lib/format';
	import { studio } from '$lib/state.svelte';
	import { place } from './place';

	/** Visualiseur source (comme celui de DaVinci) : on lit un rush, on marque l'entrée (I)
	 * et la sortie (O), puis on l'insère (F9), l'écrase (F10) ou on le glisse sur la timeline. */

	const FPS = 25; // caméra DJI : 25 i/s
	const s = $derived(editor.source!);
	const url = $derived(api.fileSrc(s.source.proxy ?? s.source.path));

	let video = $state<HTMLVideoElement>();
	let playing = $state(false);
	let fileDur = $state(0);
	const dur = $derived(s.source.duration ?? fileDur ?? 0);
	const clip = $derived(editor.sourceClip());

	// Lecture : la vidéo est l'horloge ; à l'arrêt, c'est la position mémorisée qui la pilote.
	let raf = 0;
	function tick() {
		if (video && editor.source) editor.source.t = video.currentTime;
		if (playing) raf = requestAnimationFrame(tick);
	}
	export function toggle() {
		if (!video) return;
		if (playing) {
			video.pause();
			playing = false;
			cancelAnimationFrame(raf);
		} else {
			// Lecture depuis l'entrée si la tête est hors des marques, comme on s'y attend.
			video.play().catch(() => {});
			playing = true;
			raf = requestAnimationFrame(tick);
		}
	}
	$effect(() => {
		if (!video || playing) return;
		if (Math.abs(video.currentTime - s.t) > 0.5 / FPS) video.currentTime = s.t;
	});
	$effect(() => () => cancelAnimationFrame(raf));

	export function seek(t: number) {
		if (!editor.source) return;
		editor.source.t = Math.min(Math.max(0, t), dur || t);
		if (video) video.currentTime = editor.source.t;
	}
	export function step(frames: number) {
		if (playing) toggle();
		seek(Math.round(s.t * FPS + frames) / FPS);
	}
	export function markIn() {
		if (!editor.source) return;
		editor.source.in = Math.round(s.t * FPS) / FPS;
		if (editor.source.out != null && editor.source.out <= editor.source.in) editor.source.out = null;
	}
	export function markOut() {
		if (!editor.source) return;
		editor.source.out = Math.round(s.t * FPS) / FPS;
		if (editor.source.in != null && editor.source.in >= editor.source.out) editor.source.in = null;
	}
	export function put(mode: 'insert' | 'overwrite' | 'append') {
		if (!clip) return;
		if (playing) toggle();
		const at = mode === 'append' ? videoEnd(studio.project!) : editor.playhead;
		place(clip, at, mode === 'insert' ? 'insert' : 'overwrite');
	}

	// --- Barre de navigation dans le rush ----------------------------------------
	let bar = $state<HTMLDivElement>();
	let scrubbing = false;
	const tAt = (x: number) => {
		const r = bar!.getBoundingClientRect();
		return ((x - r.left) / r.width) * dur;
	};
	function barDown(e: PointerEvent) {
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		scrubbing = true;
		if (playing) toggle();
		seek(tAt(e.clientX));
	}
	const pct = (t: number) => `${(100 * t) / Math.max(1e-6, dur)}%`;

	// --- Glisser l'image vers la timeline -----------------------------------------
	let press: { x: number; y: number } | null = null;
	function frameMove(e: PointerEvent) {
		if (!press || editor.drag || !clip) return;
		if (Math.hypot(e.clientX - press.x, e.clientY - press.y) < 5) return;
		editor.drag = { clip, x: e.clientX, y: e.clientY };
	}
</script>

<svelte:window onpointermove={frameMove} onpointerup={() => (press = null)} />

<div class="source">
	<div class="frame" onpointerdown={(e) => e.button === 0 && ((press = { x: e.clientX, y: e.clientY }), e.preventDefault())} role="presentation" title="Glisser l'image sur la timeline pour poser le morceau marqué">
		<!-- svelte-ignore a11y_media_has_caption -->
		<video
			bind:this={video}
			src={url}
			playsinline
			preload="auto"
			onloadedmetadata={() => (fileDur = video?.duration ?? 0)}
			onended={() => playing && toggle()}
		></video>
		<span class="tag mono">SOURCE · {s.source.id}</span>
	</div>

	<div class="bar" bind:this={bar} onpointerdown={barDown} onpointermove={(e) => scrubbing && seek(tAt(e.clientX))} onpointerup={() => (scrubbing = false)} role="presentation">
		{#if clip && dur}
			<div class="range" style:left={pct(clip.in)} style:width={pct(clip.out - clip.in)} class:auto={s.out == null}></div>
		{/if}
		{#if s.in != null}<div class="mark in" style:left={pct(s.in)}></div>{/if}
		{#if s.out != null}<div class="mark out" style:left={pct(s.out)}></div>{/if}
		<div class="head" style:left={pct(s.t)}></div>
	</div>

	<div class="controls">
		<button class="icon ghost" onclick={() => step(-1)} title="Image précédente (←)">‹</button>
		<button class="icon play" onclick={toggle} title="Lecture / pause (Espace)">
			{#if playing}
				<svg viewBox="0 0 24 24" width="13" height="13"><path d="M6 4h4v16H6zM14 4h4v16h-4z" /></svg>
			{:else}
				<svg viewBox="0 0 24 24" width="13" height="13"><path d="M7 4l13 8-13 8z" /></svg>
			{/if}
		</button>
		<button class="icon ghost" onclick={() => step(1)} title="Image suivante (→)">›</button>
		<span class="tc mono"><b>{timecode(s.t, FPS)}</b> / {timecode(dur, FPS)}</span>
		<span class="sep"></span>
		<button onclick={markIn} title="Point d'entrée (I)">I · {s.in != null ? timecode(s.in, FPS) : '—'}</button>
		<button onclick={markOut} title="Point de sortie (O)">O · {s.out != null ? timecode(s.out, FPS) : '—'}</button>
		{#if s.in != null || s.out != null}
			<button class="ghost" onclick={() => editor.source && ((editor.source.in = null), (editor.source.out = null))} title="Effacer les marques (Alt+X)">✕</button>
		{/if}
		<span class="dim len">{clip ? duration(clip.out - clip.in) : ''}{s.out == null && clip ? ' (sans sortie : 10 s)' : ''}</span>
	</div>

	<div class="put">
		<button disabled={!clip} onclick={() => put('insert')} title="Insérer à la tête de lecture : tout ce qui suit est décalé (F9)">Insérer <kbd>F9</kbd></button>
		<button disabled={!clip} class="primary" onclick={() => put('overwrite')} title="Écraser à la tête de lecture (F10)">Écraser <kbd>F10</kbd></button>
		<button disabled={!clip} onclick={() => put('append')} title="Ajouter après le dernier plan">À la fin</button>
		<button class="ghost back" onclick={() => (editor.viewer = 'timeline')} title="Revenir au visualiseur de la timeline (Q)">Timeline ↩</button>
	</div>
</div>

<style>
	.source {
		display: flex;
		flex-direction: column;
		height: 100%;
		min-height: 0;
	}
	.frame {
		position: relative;
		flex: 1;
		min-height: 0;
		overflow: hidden;
		background: #000;
		cursor: grab;
		touch-action: none;
	}
	/* Rempli et contenu dans le cadre : un max-height en % ne se résout pas ici et l'image
	   débordait sur la barre et les boutons. */
	video {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		object-fit: contain;
		pointer-events: none;
	}
	.tag {
		position: absolute;
		left: 10px;
		top: 8px;
		font-size: 10px;
		padding: 2px 6px;
		background: rgba(0, 0, 0, 0.6);
		border: 1px solid #3c7fd6;
		color: #9cc4ff;
		border-radius: 3px;
	}
	.bar {
		position: relative;
		height: 22px;
		margin: 6px 12px 2px;
		background: #1c1813;
		border-radius: 3px;
		cursor: text;
	}
	.range {
		position: absolute;
		top: 0;
		bottom: 0;
		background: rgba(230, 180, 70, 0.35);
		border-left: 1px solid var(--gold);
		border-right: 1px solid var(--gold);
	}
	.range.auto {
		background: repeating-linear-gradient(135deg, rgba(230, 180, 70, 0.28) 0 5px, rgba(230, 180, 70, 0.12) 5px 10px);
	}
	.mark {
		position: absolute;
		top: -3px;
		bottom: -3px;
		width: 0;
		border-left: 2px solid var(--gold-light);
	}
	.head {
		position: absolute;
		top: -4px;
		bottom: -4px;
		width: 0;
		border-left: 2px solid #fff;
		pointer-events: none;
	}
	.controls,
	.put {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 4px 12px;
	}
	.put {
		padding-bottom: 8px;
		border-bottom: 1px solid var(--line);
	}
	.tc {
		font-size: 12px;
		color: var(--text-dim);
	}
	.tc b {
		color: var(--text);
	}
	.sep {
		width: 1px;
		height: 18px;
		background: var(--line-2);
	}
	.len {
		font-size: 11px;
	}
	.back {
		margin-left: auto;
	}
	kbd {
		font-family: var(--mono);
		font-size: 9px;
		opacity: 0.7;
		margin-left: 4px;
	}
	.play svg {
		fill: currentColor;
	}
</style>
