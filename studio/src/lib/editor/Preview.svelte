<script lang="ts">
	import ShortOverlay from './ShortOverlay.svelte';
	import { api } from '$lib/api';
	import type { VideoItem } from '$lib/bindings/VideoItem';
	import { editor } from '$lib/editor.svelte';
	import { updateItem } from '$lib/edit';
	import { timecode } from '$lib/format';
	import { clipAt, findTrack, graphics, itemLabel, sameRef, type ItemRef } from '$lib/project';
	import { BAND_ZOOM, clipZoom, cropPlacement, FLASH_DUR, isVertical, LETTERBOX, shortLayout } from '$lib/layout';
	import { studio } from '$lib/state.svelte';

	/** Aperçu au format final. Approximation : la vidéo est le proxy lu dans le
	 * navigateur ; « Image exacte » affiche le PNG du vrai moteur de rendu. */

	const p = $derived(studio.project!);
	const t = $derived(editor.playhead);
	const W = $derived(p.format.w);
	const H = $derived(p.format.h);
	const vertical = $derived(isVertical(p.format));
	const isShort = $derived(p.preset === 'short_scene' || p.preset === 'retention_peaks');
	const lay = $derived(shortLayout(W, H));
	// Bande vidéo : 1080×608 au centre − 60 en vertical, plein cadre sinon.
	const band = $derived(
		vertical ? { top: lay.bandTop, height: lay.bandBottom - lay.bandTop } : { top: 0, height: H }
	);
	const baseZoom = $derived(vertical ? BAND_ZOOM : 1);

	const clip = $derived(clipAt(p, t));
	const clipRef = $derived.by((): ItemRef | null => {
		if (!clip) return null;
		for (const tr of p.tracks) {
			if (tr.kind !== 'video') continue;
			const index = tr.items.findIndex((c) => c.id === clip.id);
			if (index >= 0) return { track: tr.id, index };
		}
		return null;
	});
	const local = $derived(clip ? t - clip.at : 0);
	const srcTime = $derived(clip ? clip.in + local : 0);
	const source = $derived(clip ? p.sources.find((s) => s.id === clip.src) : undefined);
	const url = $derived(source ? api.fileSrc(source.proxy ?? source.path) : '');
	const zoom = $derived(clip ? clipZoom(clip, local, baseZoom) : 1);
	const place = $derived(clip ? cropPlacement(clip.crop, zoom, W, band.height) : null);
	const selectedClip = $derived(!!clipRef && sameRef(clipRef, editor.selection));

	// Flash blanc chaud à l'entrée des plans marqués, et éléments `flash`.
	const flash = $derived.by(() => {
		const starts = [
			...p.tracks.flatMap((tr) => (tr.kind === 'video' ? tr.items.filter((c) => c.fx?.flash && c.at > 0).map((c) => c.at) : [])),
			...graphics(p).filter((g) => g.type === 'flash').map((g) => g.at)
		];
		let a = 0;
		for (const s of starts) if (t >= s && t < s + FLASH_DUR) a = Math.max(a, 1 - (t - s) / FLASH_DUR);
		return a;
	});
	// Graphismes du moteur B (trailers) : non simulés, simplement signalés.
	const otherGraphics = $derived(
		isShort ? [] : graphics(p).filter((g) => t >= g.at && t < g.at + g.dur && g.type !== 'flash')
	);

	// --- Mise à l'échelle du cadre dans la zone disponible -------------------
	let boxW = $state(400);
	let boxH = $state(600);
	const scale = $derived(Math.max(0.01, Math.min(boxW / W, boxH / H)));

	// --- Vidéo : synchronisation sur la tête de lecture ------------------------
	let video = $state<HTMLVideoElement>();
	let bgVideo = $state<HTMLVideoElement>();
	let failed = $state(false);

	$effect(() => {
		void url;
		failed = false;
	});

	function sync(v: HTMLVideoElement | undefined, tolerance: number, muted: boolean) {
		if (!v || !url || failed || !clip) return;
		v.muted = muted;
		if (editor.playing) {
			if (Math.abs(v.currentTime - srcTime) > tolerance) v.currentTime = srcTime;
			if (v.paused) v.play().catch(() => {});
		} else {
			if (!v.paused) v.pause();
			if (Math.abs(v.currentTime - srcTime) > 0.5 / p.format.fps) v.currentTime = srcTime;
		}
	}

	$effect(() => {
		sync(video, 0.3, false);
		sync(bgVideo, 0.5, true);
	});

	// --- Recadrage direct : glisser l'image déplace le centre (cx, cy) ---------
	let drag: { x: number; y: number; cx: number; cy: number; ref: ItemRef; base: typeof p } | null = null;

	function cropDown(e: PointerEvent) {
		if (!clip || !clipRef || e.button !== 0) return;
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		editor.pause();
		editor.selection = clipRef;
		drag = { x: e.clientX, y: e.clientY, cx: clip.crop.cx, cy: clip.crop.cy, ref: clipRef, base: p };
	}

	function cropMove(e: PointerEvent) {
		if (!drag || !place) return;
		// Déplacement écran → déplacement dans l'image zoomée (normalisé).
		const dx = (e.clientX - drag.x) / scale / place.width;
		const dy = (e.clientY - drag.y) / scale / place.height;
		const d = drag;
		const clamp = (v: number) => Math.round(Math.min(1, Math.max(0, v)) * 1000) / 1000;
		studio.project = updateItem<VideoItem>(d.base, d.ref, (c) => {
			c.crop = { ...c.crop, cx: clamp(d.cx - dx), cy: clamp(d.cy - dy) };
		});
	}

	function cropUp() {
		if (!drag) return;
		const d = drag;
		drag = null;
		const c = findTrack(studio.project!, d.ref.track)?.items[d.ref.index] as VideoItem | undefined;
		if (c && (c.crop.cx !== d.cx || c.crop.cy !== d.cy)) studio.edit(studio.project!, `Recadrage ${itemLabel('video', c)}`);
	}
</script>

<div class="box" bind:clientWidth={boxW} bind:clientHeight={boxH}>
	<div class="frame" style:width="{W * scale}px" style:height="{H * scale}px">
		<div class="stage" style:width="{W}px" style:height="{H}px" style:transform="scale({scale})">
			{#if clip}
				{#if vertical}
					<!-- Fond : même image, floutée et assombrie -->
					<div class="bg">
						{#if url && !failed}
							<!-- svelte-ignore a11y_media_has_caption -->
							<video bind:this={bgVideo} src={url} muted playsinline preload="auto"></video>
						{:else}
							<div class="mire"></div>
						{/if}
					</div>
				{/if}
				<div class="band" class:selected={selectedClip} style:top="{band.top}px" style:height="{band.height}px" onpointerdown={cropDown} onpointermove={cropMove} onpointerup={cropUp} role="presentation">
					<div class="img" style:left="{place!.left}px" style:top="{place!.top}px" style:width="{place!.width}px" style:height="{place!.height}px">
						{#if url && !failed}
							<!-- svelte-ignore a11y_media_has_caption -->
							<video bind:this={video} src={url} playsinline preload="auto" onerror={() => (failed = true)}></video>
						{:else}
							<div class="mire">
								<div class="spot"></div>
								<div class="thirds"></div>
								<div class="src">
									<span>{clip.src}</span>
									<b>{timecode(srcTime, 25)}</b>
									<span>proxy indisponible dans le navigateur</span>
								</div>
							</div>
						{/if}
					</div>
					{#if selectedClip}
						<div class="crosshair" style:left="{place!.left + clip.crop.cx * place!.width}px" style:top="{place!.top + clip.crop.cy * place!.height}px"></div>
					{/if}
				</div>
			{:else}
				<div class="black"></div>
			{/if}

			{#if !vertical}
				<div class="letterbox" style:height="{(LETTERBOX * H) / 1080}px" style:top="0"></div>
				<div class="letterbox" style:height="{(LETTERBOX * H) / 1080}px" style:bottom="0"></div>
			{/if}

			{#if isShort}
				<ShortOverlay project={p} {t} />
			{:else}
				{#each otherGraphics as g, i (i)}
					<div class="scene" style:top="{H / 2 + i * 80}px">{g.type}{'text' in g ? ` · ${g.text}` : ''}{'lines' in g && g.lines ? ` · ${g.lines.join(' / ')}` : ''}</div>
				{/each}
			{/if}

			{#if flash > 0}<div class="flash" style:opacity={flash}></div>{/if}

			{#if editor.snapshotUrl}
				<img class="snapshot" src={editor.snapshotUrl} alt="Rendu exact du moteur" />
			{/if}
		</div>
		{#if editor.snapshotUrl}<div class="badge">Image exacte · {timecode(editor.snapshotAt ?? 0, p.format.fps)}</div>{/if}
	</div>
</div>

<style>
	.box {
		position: relative;
		width: 100%;
		height: 100%;
		display: grid;
		place-items: center;
		overflow: hidden;
	}
	.frame {
		position: relative;
		box-shadow: 0 0 0 1px var(--line-2), 0 10px 40px rgba(0, 0, 0, 0.6);
		overflow: hidden;
	}
	.stage {
		position: absolute;
		left: 0;
		top: 0;
		transform-origin: 0 0;
		background: #000;
		overflow: hidden;
	}
	.bg {
		position: absolute;
		inset: 0;
		transform: scale(1.12);
		filter: blur(36px) brightness(0.72) saturate(0.8);
	}
	.bg video,
	.img video {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}
	.band {
		position: absolute;
		left: 0;
		right: 0;
		overflow: hidden;
		cursor: grab;
	}
	.band:active {
		cursor: grabbing;
	}
	.band.selected {
		outline: 4px solid rgba(230, 180, 70, 0.8);
		outline-offset: -4px;
	}
	.img {
		position: absolute;
	}
	.mire {
		position: absolute;
		inset: 0;
		background:
			radial-gradient(ellipse 30% 45% at 50% 62%, rgba(255, 214, 150, 0.35), transparent 70%),
			linear-gradient(90deg, #3a0f0c 0 9%, transparent 9% 91%, #3a0f0c 91%),
			linear-gradient(180deg, #1c1510 0%, #2a2018 60%, #4a3a2a 61%, #2b2117 100%);
	}
	.thirds {
		position: absolute;
		inset: 0;
		background:
			linear-gradient(90deg, transparent calc(33.3% - 1px), rgba(255, 255, 255, 0.12) 33.3%, transparent calc(33.3% + 1px), transparent calc(66.6% - 1px), rgba(255, 255, 255, 0.12) 66.6%, transparent calc(66.6% + 1px)),
			linear-gradient(180deg, transparent calc(33.3% - 1px), rgba(255, 255, 255, 0.12) 33.3%, transparent calc(33.3% + 1px), transparent calc(66.6% - 1px), rgba(255, 255, 255, 0.12) 66.6%, transparent calc(66.6% + 1px));
	}
	.src {
		position: absolute;
		left: 50%;
		top: 40%;
		transform: translate(-50%, -50%);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 6px;
		font-family: var(--font-label);
		color: rgba(243, 237, 228, 0.6);
		font-size: 22px;
		letter-spacing: 0.2em;
		text-transform: uppercase;
	}
	.src b {
		font-family: var(--mono);
		font-size: 52px;
		color: rgba(247, 220, 138, 0.85);
		letter-spacing: 0;
	}
	.crosshair {
		position: absolute;
		width: 60px;
		height: 60px;
		margin: -30px 0 0 -30px;
		border: 3px solid #e6b446;
		border-radius: 50%;
		pointer-events: none;
		box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.6);
	}
	.crosshair::after {
		content: '';
		position: absolute;
		left: 50%;
		top: 50%;
		width: 8px;
		height: 8px;
		margin: -4px;
		background: #e6b446;
		border-radius: 50%;
	}
	.black {
		position: absolute;
		inset: 0;
		background: #000;
	}
	.letterbox {
		position: absolute;
		left: 0;
		right: 0;
		background: #000;
	}
	.scene {
		position: absolute;
		left: 0;
		right: 0;
		text-align: center;
		font-family: var(--font-title);
		font-weight: 900;
		font-size: 64px;
		color: #f7dc8a;
		text-transform: uppercase;
	}
	.flash {
		position: absolute;
		inset: 0;
		background: #fff3dc;
		pointer-events: none;
	}
	.snapshot {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		object-fit: contain;
		pointer-events: none;
	}
	.badge {
		position: absolute;
		top: 6px;
		left: 6px;
		font-family: var(--font-label);
		font-size: 9px;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		background: var(--gold);
		color: #1a1208;
		padding: 3px 6px;
		border-radius: 3px;
	}
</style>
