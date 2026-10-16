<script lang="ts">
	import { onMount } from 'svelte';
	import Nav from '$lib/components/Nav.svelte';
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
	<Nav />
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
	<Toasts />
</div>

<style>
	.app {
		display: grid;
		grid-template-columns: 72px minmax(0, 1fr);
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
