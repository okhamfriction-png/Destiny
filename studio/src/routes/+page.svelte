<script lang="ts">
	import { onMount } from 'svelte';
	import PageBar from '$lib/components/PageBar.svelte';
	import Toasts from '$lib/components/Toasts.svelte';
	import Library from '$lib/views/Library.svelte';
	import Explorer from '$lib/views/Explorer.svelte';
	import Proposals from '$lib/views/Proposals.svelte';
	import Editor from '$lib/views/Editor.svelte';
	import Export from '$lib/views/Export.svelte';
	import { studio } from '$lib/state.svelte';

	onMount(() => {
		void studio.init();
	});
</script>

<div class="app">
	<main>
		{#if studio.view === 'library'}
			<Library />
		{:else if studio.view === 'explorer'}
			<Explorer />
		{:else if studio.view === 'proposals'}
			<Proposals />
		{:else if studio.view === 'editor'}
			<Editor />
		{:else}
			<Export />
		{/if}
	</main>
	<PageBar />
	<Toasts />
</div>

<style>
	.app {
		display: grid;
		/* Pages en bas, comme DaVinci : tout l'écran au-dessus pour le travail. */
		grid-template-rows: minmax(0, 1fr) 46px;
		height: 100vh;
	}
	main {
		min-width: 0;
		min-height: 0;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}
</style>
