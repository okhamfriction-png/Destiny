<script lang="ts">
	import Preview from '$lib/editor/Preview.svelte';
	import Transport from '$lib/editor/Transport.svelte';
	import Timeline from '$lib/editor/Timeline.svelte';
	import MediaPool from '$lib/editor/MediaPool.svelte';
	import SourceViewer from '$lib/editor/SourceViewer.svelte';
	import { place } from '$lib/editor/place';
	import Properties from '$lib/editor/Properties.svelte';
	import ClaudeDialog from '$lib/editor/ClaudeDialog.svelte';
	import { editor } from '$lib/editor.svelte';
	import { closeGaps, editPoints, linkedRefs, removeGroup, splitAll, splitGroup } from '$lib/edit';
	import { basename } from '$lib/format';
	import { clipAt, findTrack, itemLabel, type ItemRef } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	/** Page « Montage », disposée comme la page Edit de DaVinci : médias à gauche,
	 * visualiseur au centre, inspecteur à droite, timeline sur toute la largeur en bas. */

	let asking = $state(false);
	let timelineH = $state(Math.round(Math.max(300, (typeof window !== 'undefined' ? window.innerHeight : 900) * 0.42)));
	let showPool = $state(true);
	let sv = $state<SourceViewer>();
	const inSource = $derived(editor.viewer === 'source' && !!editor.source);

	const PRESET: Record<string, string> = {
		short_scene: 'Short',
		retention_peaks: 'Short · pic YouTube',
		reel_bm: 'Reel',
		trailer_v: 'Trailer 9:16',
		trailer_h: 'Trailer 16:9'
	};

	// Nouveau projet ouvert : tête de lecture au début, plus de sélection.
	let lastPath: string | null = null;
	$effect(() => {
		const path = studio.path;
		if (path !== lastPath) {
			lastPath = path;
			editor.reset();
		}
	});

	const group = (ref: ItemRef) => (editor.linked ? linkedRefs(studio.project!, ref) : [ref]);

	/** Élément à couper : la sélection (vidéo/voix), sinon le plan sous la tête de lecture. */
	function splitTarget(): ItemRef | null {
		const p = studio.project!;
		const sel = editor.selection;
		if (sel) {
			const kind = findTrack(p, sel.track)?.kind;
			if (kind === 'video' || kind === 'voice') return sel;
		}
		const clip = clipAt(p, editor.playhead);
		if (!clip) return null;
		for (const t of p.tracks) {
			if (t.kind !== 'video') continue;
			const index = t.items.findIndex((c) => c.id === clip.id);
			if (index >= 0) return { track: t.id, index };
		}
		return null;
	}

	/** S : coupe toutes les pistes non verrouillées à la tête de lecture (vidéo, voix,
	 * musique), comme le ⌘B de DaVinci. Avec ⇧ : seulement le plan sélectionné (et sa voix). */
	function split(onlySelection = false) {
		const p = studio.project!;
		const t = editor.playhead;
		let next: typeof p;
		if (onlySelection) {
			const ref = splitTarget();
			if (!ref || editor.locked[findTrack(p, ref.track)!.kind]) return;
			next = splitGroup(p, group(ref), t);
		} else {
			next = splitAll(p, t, editor.locked);
		}
		if (next === p) {
			studio.info('Rien à couper ici : placez la tête de lecture à l’intérieur d’un plan.');
			return;
		}
		studio.edit(next, onlySelection ? `Couper la sélection à ${t.toFixed(2)} s` : `Couper toutes les pistes à ${t.toFixed(2)} s`);
	}

	function remove(ripple: boolean) {
		const ref = editor.selection;
		if (!ref) return;
		const p = studio.project!;
		const t = findTrack(p, ref.track);
		if (!t || editor.locked[t.kind]) return;
		const name = itemLabel(t.kind, t.items[ref.index]).slice(0, 40);
		// Magnétique : la place du plan se referme, et les trous restants de V1 aussi.
		const next = removeGroup(p, group(ref), ripple);
		studio.edit(ripple ? closeGaps(next) : next, `${ripple ? 'Supprimer et refermer' : 'Supprimer (trou)'} ${name}`);
		editor.selection = null;
	}

	/** ↑ / ↓ : point de montage précédent / suivant, comme dans DaVinci. */
	function jumpEdit(dir: -1 | 1) {
		const pts = editPoints(studio.project!);
		const t = editor.playhead;
		const target = dir > 0 ? pts.find((x) => x > t + 1e-3) : pts.findLast((x) => x < t - 1e-3);
		if (target !== undefined) {
			editor.pause();
			editor.seek(target);
		}
	}

	function onkeydown(e: KeyboardEvent) {
		if (asking) return;
		const el = e.target as HTMLElement;
		if (el.closest('input, textarea, select, [contenteditable="true"]')) return;
		const mod = e.metaKey || e.ctrlKey;
		const key = e.key.toLowerCase();
		if (mod && key === 'z') {
			e.preventDefault();
			if (e.shiftKey) studio.redo();
			else studio.undo();
			return;
		}
		if (mod && key === 'y') {
			e.preventDefault();
			studio.redo();
			return;
		}
		if (mod && e.shiftKey && key === 'l') {
			e.preventDefault();
			editor.linked = !editor.linked;
			return;
		}
		if (mod && (e.key === '=' || e.key === '+')) {
			e.preventDefault();
			editor.pps = Math.min(400, editor.pps * 1.4);
			return;
		}
		if (mod && e.key === '-') {
			e.preventDefault();
			editor.pps = Math.max(2, editor.pps / 1.4);
			return;
		}
		// ⌥X : efface les points d'entrée et de sortie du visualiseur source (comme DaVinci).
		if (e.altKey && e.code === 'KeyX' && editor.source) {
			e.preventDefault();
			editor.source.in = null;
			editor.source.out = null;
			return;
		}
		if (mod || e.altKey) return;
		// F9 / F10 : insérer / écraser le morceau du visualiseur source, quel que soit le visualiseur.
		if ((e.key === 'F9' || e.key === 'F10') && editor.source) {
			e.preventDefault();
			const clip = editor.sourceClip();
			if (clip) place(clip, editor.playhead, e.key === 'F9' ? 'insert' : 'overwrite');
			return;
		}
		if (e.key === 'q' || e.key === 'Q') {
			if (editor.source) editor.viewer = editor.viewer === 'source' ? 'timeline' : 'source';
			return;
		}
		// Visualiseur source actif : lecture, images et marques portent sur le rush.
		if (inSource && sv) {
			const k = e.key.toLowerCase();
			if (e.key === ' ' || k === 'k' || k === 'l') {
				e.preventDefault();
				sv.toggle();
				return;
			}
			if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
				e.preventDefault();
				sv.step((e.key === 'ArrowLeft' ? -1 : 1) * (e.shiftKey ? 25 : 1));
				return;
			}
			if (k === 'i') return sv.markIn();
			if (k === 'o') return sv.markOut();
		}
		switch (e.key) {
			case ' ':
				e.preventDefault();
				editor.toggle();
				break;
			case 'ArrowLeft':
				e.preventDefault();
				editor.step(e.shiftKey ? -editor.fps : -1);
				break;
			case 'ArrowRight':
				e.preventDefault();
				editor.step(e.shiftKey ? editor.fps : 1);
				break;
			case 'ArrowUp':
				e.preventDefault();
				jumpEdit(-1);
				break;
			case 'ArrowDown':
				e.preventDefault();
				jumpEdit(1);
				break;
			case 'Home':
				editor.seek(0);
				break;
			case 'End':
				editor.seek(editor.duration);
				break;
			// J / K / L : recul d'une seconde, pause, lecture.
			case 'j':
			case 'J':
				editor.step(-editor.fps);
				break;
			case 'k':
			case 'K':
				editor.pause();
				break;
			case 'l':
			case 'L':
				editor.play();
				break;
			case 'a':
			case 'A':
				editor.tool = 'select';
				break;
			case 'b':
			case 'B':
				editor.tool = 'blade';
				break;
			case 'n':
			case 'N':
				editor.magnet = !editor.magnet;
				break;
			case 'Z':
				if (e.shiftKey) editor.fitTick++;
				break;
			case 's':
			case 'S':
				e.preventDefault();
				split(e.shiftKey);
				break;
			case 'R':
				// ⇧R : montage magnétique activé / désactivé.
				if (e.shiftKey) {
					editor.ripple = !editor.ripple;
					studio.info(editor.ripple ? 'Montage magnétique activé : plus de trous.' : 'Montage magnétique désactivé : les suppressions laissent un trou.');
				}
				break;
			case 'Delete':
			case 'Backspace':
				e.preventDefault();
				// Magnétique : ⌫ referme la place, ⇧⌫ laisse un trou (et l'inverse sans le mode).
				remove(editor.ripple !== e.shiftKey);
				break;
			case 'Escape':
				editor.selection = null;
				editor.tool = 'select';
				break;
		}
	}

	// Poignée de redimensionnement entre le haut (médias, visualiseur) et la timeline.
	let resizing: { y: number; h: number } | null = null;
	function resizeDown(e: PointerEvent) {
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		resizing = { y: e.clientY, h: timelineH };
	}
	function resizeMove(e: PointerEvent) {
		if (resizing) timelineH = Math.min(window.innerHeight - 240, Math.max(160, resizing.h - (e.clientY - resizing.y)));
	}
</script>

<!-- Glisser-déposer d'un rush : suivi du pointeur ici, dépôt géré par la timeline. Le
     glisser n'est effacé qu'au tour suivant : la timeline le lit quel que soit l'ordre
     des écouteurs du relâchement. -->
<svelte:window
	{onkeydown}
	onpointermove={(e) => editor.drag && (editor.drag = { ...editor.drag, x: e.clientX, y: e.clientY })}
	onpointerup={() => setTimeout(() => (editor.drag = null))}
/>

{#snippet actions()}
	<button onclick={() => split(false)} title="Couper toutes les pistes (vidéo, voix, musique) à la tête de lecture, sauf les pistes verrouillées. Raccourci : S. Avec ⇧S : seulement le plan sélectionné et sa voix.">Couper</button>
	<button disabled={!editor.selection} onclick={() => remove(editor.ripple)} title={editor.ripple ? 'Supprimer le plan sélectionné (et sa voix) et refermer la place : tout ce qui suit recule. Raccourci : ⌫ (⇧⌫ pour laisser un trou).' : 'Supprimer le plan sélectionné (et sa voix) en laissant un trou. Raccourci : ⌫ (⇧⌫ pour refermer la place).'}>Supprimer</button>
	<span class="sep"></span>
	<button class="claude" onclick={() => (asking = true)} title="Décrire une modification en français (« raccourcis l'intro », « mets le hook en deux lignes »…) : Claude propose un changement du montage, que vous acceptez ou non. Annulable avec ⌘Z.">✦ Demander à Claude</button>
	<button class="primary" onclick={() => (studio.view = 'export')} title="Aller à la page Livraison : rendu final en haute qualité, vérifications (durée, son, volume) et copie sur le NAS.">Exporter…</button>
{/snippet}

{#if studio.project}
	<div class="editor" style:grid-template-rows="minmax(0, 1fr) 5px {timelineH}px">
		<div class="top" style:grid-template-columns="{showPool ? '232px ' : ''}minmax(0, 1fr) 330px">
			{#if showPool}<MediaPool />{/if}
			<div class="viewer">
				<div class="vhead">
					<div class="vswitch">
						<button class:on={inSource} disabled={!editor.source} onclick={() => (editor.viewer = 'source')} title="Visualiseur Source : le rush cliqué dans les Médias, pour choisir un morceau (I / O) et l'insérer (F9) ou l'écraser (F10). Raccourci : Q pour basculer.">Source</button>
						<button class:on={!inSource} onclick={() => (editor.viewer = 'timeline')} title="Visualiseur Timeline : le montage tel qu'il sera rendu, à la tête de lecture. Raccourci : Q pour basculer.">Timeline</button>
					</div>
					<button class="ghost pooltoggle" class:on={showPool} onclick={() => (showPool = !showPool)} title="Afficher ou masquer le panneau Médias (rushes et autres montages du spectacle).">
						<svg viewBox="0 0 24 24" width="14" height="14"><path d="M3 5h7v14H3zM13 5h8M13 10h8M13 15h8" /></svg>
					</button>
					<b class="name">{studio.path ? basename(studio.path).replace(/\.json$/, '') : ''}</b>
					<span class="chip">{PRESET[studio.project.preset] ?? studio.project.preset}</span>
					<span class="dim mono fmt">{studio.project.format.w}×{studio.project.format.h} · {studio.project.format.fps} i/s</span>
				</div>
				{#if inSource}
					<SourceViewer bind:this={sv} />
				{:else}
					<div class="preview"><Preview /></div>
					<Transport />
				{/if}
			</div>
			<aside class="side"><Properties /></aside>
		</div>

		<div class="resize" onpointerdown={resizeDown} onpointermove={resizeMove} onpointerup={() => (resizing = null)} role="separator" aria-orientation="horizontal"></div>

		<div class="tl"><Timeline {actions} /></div>
	</div>
{:else}
	<div class="empty">
		<h1>Aucun montage ouvert</h1>
		<p class="dim">Ouvrez un montage depuis la page Médias ou les propositions.</p>
		<button class="primary" onclick={() => (studio.view = 'library')} title="Aller à la page Médias pour ouvrir un montage.">Médias</button>
	</div>
{/if}

{#if editor.drag}
	{@const c = editor.drag.clip}
	<div class="dragchip" style:left="{editor.drag.x + 14}px" style:top="{editor.drag.y + 10}px">
		<b>{c.source.id}</b> · {(c.out - c.in).toFixed(1).replace('.', ',')} s
		<span>Lâcher sur la timeline · Maj : insérer</span>
	</div>
{/if}

{#if asking}<ClaudeDialog onclose={() => (asking = false)} />{/if}

<style>
	.editor {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		height: 100%;
		min-height: 0;
	}
	.top {
		display: grid;
		min-height: 0;
	}
	.viewer {
		display: flex;
		flex-direction: column;
		min-width: 0;
		min-height: 0;
		background: #0e0c09;
	}
	.vhead {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 10px;
		border-bottom: 1px solid var(--line);
		background: var(--bg-1);
		min-width: 0;
	}
	.pooltoggle {
		padding: 3px 5px;
	}
	.pooltoggle svg {
		fill: none;
		stroke: currentColor;
		stroke-width: 2;
	}
	.pooltoggle.on {
		color: var(--gold-light);
	}
	.name {
		font-size: 12px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		min-width: 0;
	}
	.fmt {
		font-size: 10px;
		margin-left: auto;
		white-space: nowrap;
	}
	.preview {
		flex: 1;
		min-height: 0;
		padding: 10px;
	}
	.side {
		border-left: 1px solid var(--line);
		background: var(--bg-1);
		min-height: 0;
		overflow: hidden;
	}
	.resize {
		cursor: row-resize;
		background: var(--bg-2);
		border-top: 1px solid var(--line);
		border-bottom: 1px solid var(--line);
	}
	.resize:hover {
		background: #3a2e18;
	}
	.tl {
		min-height: 0;
	}
	.sep {
		width: 1px;
		height: 18px;
		background: var(--line-2);
		margin: 0 4px;
	}
	.claude {
		border-color: #6b5420;
		color: var(--gold-light);
	}
	.vswitch {
		display: flex;
		gap: 1px;
		padding: 2px;
		background: var(--bg-2);
		border-radius: 4px;
	}
	.vswitch button {
		font-size: 9px;
		padding: 3px 9px;
		border-color: transparent;
		background: transparent;
	}
	.vswitch button.on {
		background: #2a2111;
		color: var(--gold-light);
		border-color: #6b5420;
	}
	.dragchip {
		position: fixed;
		z-index: 50;
		pointer-events: none;
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 6px 9px;
		font-size: 11px;
		background: rgba(30, 60, 100, 0.92);
		border: 1px solid #5b89b9;
		border-radius: 4px;
		color: #fff;
		box-shadow: 0 6px 20px rgba(0, 0, 0, 0.5);
	}
	.dragchip span {
		font-size: 9px;
		opacity: 0.8;
	}
	.empty {
		margin: auto;
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: 12px;
		align-items: center;
	}
</style>
