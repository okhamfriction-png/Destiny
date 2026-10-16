<script lang="ts">
	import Preview from '$lib/editor/Preview.svelte';
	import Transport from '$lib/editor/Transport.svelte';
	import Timeline from '$lib/editor/Timeline.svelte';
	import Properties from '$lib/editor/Properties.svelte';
	import ClaudeDialog from '$lib/editor/ClaudeDialog.svelte';
	import { editor } from '$lib/editor.svelte';
	import { removeItem, rippleDelete, splitItem } from '$lib/edit';
	import { basename } from '$lib/format';
	import { clipAt, findTrack, itemLabel, type ItemRef } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	let asking = $state(false);
	let timelineH = $state(300);

	// Nouveau projet ouvert : tête de lecture au début, plus de sélection.
	let lastPath: string | null = null;
	$effect(() => {
		const path = studio.path;
		if (path !== lastPath) {
			lastPath = path;
			editor.reset();
		}
	});

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

	function split() {
		const ref = splitTarget();
		if (!ref) return;
		const p = studio.project!;
		const next = splitItem(p, ref, editor.playhead);
		if (next === p) {
			studio.info('Placez la tête de lecture à l’intérieur du plan pour le couper.');
			return;
		}
		const t = findTrack(p, ref.track)!;
		studio.edit(next, `Couper ${itemLabel(t.kind, t.items[ref.index])}`);
		editor.selection = ref;
	}

	function remove(ripple: boolean) {
		const ref = editor.selection;
		if (!ref) return;
		const p = studio.project!;
		const t = findTrack(p, ref.track);
		if (!t) return;
		const name = itemLabel(t.kind, t.items[ref.index]).slice(0, 40);
		studio.edit(ripple ? rippleDelete(p, ref) : removeItem(p, ref), `${ripple ? 'Supprimer avec raccord' : 'Supprimer'} ${name}`);
		editor.selection = null;
	}

	function onkeydown(e: KeyboardEvent) {
		if (asking) return;
		const el = e.target as HTMLElement;
		if (el.closest('input, textarea, select, [contenteditable="true"]')) return;
		const mod = e.metaKey || e.ctrlKey;
		if (mod && e.key.toLowerCase() === 'z') {
			e.preventDefault();
			if (e.shiftKey) studio.redo();
			else studio.undo();
			return;
		}
		if (mod && e.key.toLowerCase() === 'y') {
			e.preventDefault();
			studio.redo();
			return;
		}
		if (mod || e.altKey) return;
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
			case 'Home':
				editor.seek(0);
				break;
			case 'End':
				editor.seek(editor.duration);
				break;
			case 's':
			case 'S':
				e.preventDefault();
				split();
				break;
			case 'Delete':
			case 'Backspace':
				e.preventDefault();
				remove(e.shiftKey);
				break;
			case 'Escape':
				editor.selection = null;
				break;
		}
	}

	// Poignée de redimensionnement entre l'aperçu et la timeline.
	let resizing: { y: number; h: number } | null = null;
	function resizeDown(e: PointerEvent) {
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		resizing = { y: e.clientY, h: timelineH };
	}
	function resizeMove(e: PointerEvent) {
		if (resizing) timelineH = Math.min(window.innerHeight - 260, Math.max(140, resizing.h - (e.clientY - resizing.y)));
	}
</script>

<svelte:window {onkeydown} />

{#if studio.project}
	<div class="editor" style:grid-template-rows="auto 1fr 6px {timelineH}px">
		<header class="bar">
			<div class="title">
				<div class="kicker">Éditeur · {studio.project.preset}</div>
				<h2>{studio.path ? basename(studio.path).replace(/\.json$/, '') : ''}</h2>
			</div>
			<div class="history">
				<button disabled={!studio.server?.canUndo} onclick={() => studio.undo()} title="Annuler (Ctrl/Cmd+Z)">
					↶ Annuler{#if studio.server?.undoLabel}<span class="what">{studio.server.undoLabel}</span>{/if}
				</button>
				<button disabled={!studio.server?.canRedo} onclick={() => studio.redo()} title="Rétablir (Ctrl/Cmd+Maj+Z)">
					↷ Rétablir{#if studio.server?.redoLabel}<span class="what">{studio.server.redoLabel}</span>{/if}
				</button>
			</div>
			<div class="grow"></div>
			<button onclick={split} title="Couper à la tête de lecture (S)">Couper</button>
			<button disabled={!editor.selection} onclick={() => remove(false)} title="Supprimer (Suppr)">Supprimer</button>
			<button disabled={!editor.selection} onclick={() => remove(true)} title="Supprimer avec raccord (Maj+Suppr)">Raccord</button>
			<button class="claude" onclick={() => (asking = true)}>✦ Demander à Claude</button>
			<button class="primary" onclick={() => (studio.view = 'export')}>Exporter…</button>
		</header>

		<div class="top">
			<div class="viewer">
				<div class="preview"><Preview /></div>
				<Transport />
			</div>
			<aside class="side"><Properties /></aside>
		</div>

		<div class="resize" onpointerdown={resizeDown} onpointermove={resizeMove} onpointerup={() => (resizing = null)} role="separator" aria-orientation="horizontal"></div>

		<div class="tl"><Timeline /></div>
	</div>
{:else}
	<div class="empty">
		<h1>Aucun montage ouvert</h1>
		<p class="dim">Ouvrez un montage depuis la bibliothèque ou les propositions.</p>
		<button class="primary" onclick={() => (studio.view = 'library')}>Bibliothèque</button>
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
	.bar {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 14px;
		border-bottom: 1px solid var(--line);
		background: var(--bg-1);
	}
	.title {
		min-width: 0;
		margin-right: 10px;
	}
	.title h2 {
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		max-width: 320px;
	}
	.history {
		display: flex;
		gap: 4px;
	}
	.what {
		margin-left: 6px;
		font-family: var(--font-ui);
		text-transform: none;
		letter-spacing: 0;
		font-weight: 400;
		color: var(--text-mute);
		max-width: 160px;
		overflow: hidden;
		text-overflow: ellipsis;
		display: inline-block;
		vertical-align: bottom;
	}
	.grow {
		flex: 1;
	}
	.claude {
		border-color: #6b5420;
		color: var(--gold-light);
	}
	.top {
		display: grid;
		grid-template-columns: minmax(0, 1fr) 340px;
		min-height: 0;
	}
	.viewer {
		display: flex;
		flex-direction: column;
		min-width: 0;
		min-height: 0;
		background: radial-gradient(ellipse at 50% 40%, #17120d, #0b0907 70%);
	}
	.preview {
		flex: 1;
		min-height: 0;
		padding: 14px;
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
	.empty {
		margin: auto;
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: 12px;
		align-items: center;
	}
</style>
