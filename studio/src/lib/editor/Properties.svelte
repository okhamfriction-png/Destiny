<script lang="ts">
	import VideoProps from './props/VideoProps.svelte';
	import VoiceProps from './props/VoiceProps.svelte';
	import GraphicProps from './props/GraphicProps.svelte';
	import CaptionProps from './props/CaptionProps.svelte';
	import AudioProps from './props/AudioProps.svelte';
	import ProjectProps from './props/ProjectProps.svelte';
	import type { Caption } from '$lib/bindings/Caption';
	import type { GraphicItem } from '$lib/bindings/GraphicItem';
	import type { MusicItem } from '$lib/bindings/MusicItem';
	import type { SfxItem } from '$lib/bindings/SfxItem';
	import type { VideoItem } from '$lib/bindings/VideoItem';
	import type { VoiceItem } from '$lib/bindings/VoiceItem';
	import { editor } from '$lib/editor.svelte';
	import { findTrack } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	const sel = $derived.by(() => {
		const ref = editor.selection;
		if (!ref || !studio.project) return null;
		const track = findTrack(studio.project, ref.track);
		const item = track?.items[ref.index];
		return track && item ? { ref, kind: track.kind, item } : null;
	});
</script>

<div class="props scroll">
	{#if !sel}
		<ProjectProps />
	{:else if sel.kind === 'video'}
		<VideoProps ref={sel.ref} item={sel.item as VideoItem} />
	{:else if sel.kind === 'voice'}
		<VoiceProps ref={sel.ref} item={sel.item as VoiceItem} />
	{:else if sel.kind === 'graphics'}
		<GraphicProps ref={sel.ref} item={sel.item as GraphicItem} />
	{:else if sel.kind === 'captions'}
		<CaptionProps ref={sel.ref} item={sel.item as Caption} />
	{:else}
		<AudioProps ref={sel.ref} kind={sel.kind} item={sel.item as MusicItem | SfxItem} />
	{/if}
</div>

<style>
	.props {
		height: 100%;
		display: flex;
		flex-direction: column;
	}
	.props :global(section) {
		padding: 12px 14px;
		border-bottom: 1px solid var(--line);
		display: flex;
		flex-direction: column;
		gap: 9px;
	}
	.props :global(h3) {
		display: flex;
		align-items: baseline;
		gap: 8px;
		color: var(--gold-light);
	}
	.props :global(h3 .mono),
	.props :global(h3 .dim) {
		font-family: var(--font-ui);
		font-size: 10px;
		font-weight: 400;
		letter-spacing: 0;
		color: var(--text-mute);
	}
	.props :global(.small) {
		font-size: 11px;
		margin: 0;
	}
	.props :global(.grid2) {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 8px;
	}
	.props :global(.grid3) {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 8px;
	}
	.props :global(.toggles) {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}
	.props :global(.reset) {
		align-self: flex-start;
	}
</style>
