<script lang="ts">
	import { api } from '$lib/api';
	import { editor } from '$lib/editor.svelte';
	import { timecode } from '$lib/format';
	import { studio } from '$lib/state.svelte';

	let shooting = $state(false);

	/** Image exacte : PNG rendu par le moteur à l'instant de la tête de lecture. */
	async function exactFrame() {
		editor.pause();
		shooting = true;
		try {
			await studio.flush();
			const t = editor.playhead;
			const path = await api.snapshot(t);
			editor.snapshotUrl = api.fileSrc(path);
			editor.snapshotAt = t;
		} catch (e) {
			studio.error(e);
		} finally {
			shooting = false;
		}
	}
</script>

<div class="transport">
	<button class="icon ghost" title="Aller au début du montage. Raccourci : ↖ (Origine, fn ← sur un clavier Mac compact)." onclick={() => editor.seek(0)}>⏮</button>
	<button class="icon ghost" title="Reculer d'une seconde. Raccourcis : ⇧← ou J." onclick={() => editor.step(-editor.fps)}>«</button>
	<button class="icon ghost" title="Reculer d'une image. Raccourci : ←." onclick={() => editor.step(-1)}>‹</button>
	<button class="icon play" title="Lire ou mettre en pause le montage. Raccourcis : Espace, ou L pour lire et K pour arrêter." onclick={() => editor.toggle()}>
		{#if editor.playing}
			<svg viewBox="0 0 24 24" width="14" height="14"><path d="M6 4h4v16H6zM14 4h4v16h-4z" /></svg>
		{:else}
			<svg viewBox="0 0 24 24" width="14" height="14"><path d="M7 4l13 8-13 8z" /></svg>
		{/if}
	</button>
	<button class="icon ghost" title="Avancer d'une image. Raccourci : →." onclick={() => editor.step(1)}>›</button>
	<button class="icon ghost" title="Avancer d'une seconde. Raccourci : ⇧→." onclick={() => editor.step(editor.fps)}>»</button>
	<button class="icon ghost" title="Aller à la fin du montage. Raccourci : ↘ (Fin, fn → sur un clavier Mac compact)." onclick={() => editor.seek(editor.duration)}>⏭</button>

	<div class="tc mono">
		<b>{timecode(editor.playhead, editor.fps)}</b>
		<span>/ {timecode(editor.duration, editor.fps)}</span>
	</div>

	<button class:on={!!editor.snapshotUrl} disabled={shooting} onclick={() => (editor.snapshotUrl ? editor.clearSnapshot() : exactFrame())} title="Image exacte : calcule l'image à la tête de lecture avec le vrai moteur de rendu (couleurs, effets, textes définitifs) et l'affiche par-dessus l'aperçu. Recliquer pour la masquer. Prend quelques secondes la première fois.">
		{shooting ? 'Rendu…' : editor.snapshotUrl ? 'Masquer l’image exacte' : 'Image exacte'}
	</button>
</div>

<style>
	.transport {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 4px;
		padding: 6px 10px;
		border-top: 1px solid var(--line);
		background: var(--bg-1);
		flex-wrap: wrap;
	}
	.ghost {
		font-size: 14px;
		color: var(--text-dim);
	}
	.play {
		width: 38px;
		height: 30px;
		background: var(--gold);
		border-color: var(--gold);
		color: #1a1208;
		border-radius: 15px;
	}
	.play:hover:not(:disabled) {
		background: var(--gold-light);
		color: #1a1208;
	}
	.play svg {
		fill: currentColor;
	}
	.tc {
		margin: 0 12px;
		font-size: 13px;
	}
	.tc b {
		color: var(--gold-light);
		font-weight: 500;
		font-size: 15px;
	}
	.tc span {
		color: var(--text-mute);
	}
</style>
