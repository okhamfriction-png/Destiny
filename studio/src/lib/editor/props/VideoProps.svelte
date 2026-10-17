<script lang="ts">
	import NumField from '$lib/components/NumField.svelte';
	import Slider from '$lib/components/Slider.svelte';
	import type { Fx } from '$lib/bindings/Fx';
	import type { VideoItem } from '$lib/bindings/VideoItem';
	import { moveItem, trimItem, updateItem } from '$lib/edit';
	import { DEFAULT_PUSH } from '$lib/layout';
	import type { ItemRef } from '$lib/project';
	import { studio } from '$lib/state.svelte';
	import { editor } from '$lib/editor.svelte';
	import { reframeClips } from '../reframe';

	let { ref, item }: { ref: ItemRef; item: VideoItem } = $props();

	const p = $derived(studio.project!);

	function set(fn: (c: VideoItem) => void, label: string, commit = true) {
		const next = updateItem<VideoItem>(p, ref, fn);
		if (commit) studio.edit(next, `${label} ${item.id}`);
		else studio.project = next;
	}

	function crop(key: 'cx' | 'cy' | 'zoom', v: number, commit: boolean) {
		set((c) => (c.crop = { ...c.crop, [key]: v }), 'Recadrage', commit);
	}

	function fx(patch: Partial<Fx>, label: string) {
		set((c) => {
			c.fx = { ...c.fx, ...patch };
			// Les valeurs par défaut ne s'écrivent pas (comme `skip_serializing_if` côté Rust).
			for (const k of Object.keys(c.fx) as (keyof Fx)[]) if (c.fx[k] === false || c.fx[k] == null) delete c.fx[k];
		}, label);
	}

	const dur = $derived(item.out - item.in);
</script>

<section>
	<h3>Plan vidéo <span class="mono dim">{item.id} · {item.src}</span></h3>
	<div class="grid3">
		<NumField label="Position" value={item.at} unit="s" onchange={(v) => studio.edit(moveItem(p, ref, v), `Déplacer ${item.id}`)} />
		<NumField label="Entrée source" value={item.in} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'start', item.at + (v - item.in)), `Rogner ${item.id}`)} />
		<NumField label="Sortie source" value={item.out} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'end', item.at + (v - item.in)), `Rogner ${item.id}`)} />
	</div>
	<div class="dim small">Durée {dur.toFixed(2).replace('.', ',')} s</div>
</section>

<section>
	<h3>Recadrage <span class="dim small">glisser l'image dans l'aperçu</span></h3>
	<Slider label="Centre horizontal (cx)" value={item.crop.cx} min={0} max={1} oninput={(v) => crop('cx', v, false)} onchange={(v) => crop('cx', v, true)} />
	<Slider label="Centre vertical (cy)" value={item.crop.cy} min={0} max={1} oninput={(v) => crop('cy', v, false)} onchange={(v) => crop('cy', v, true)} />
	<Slider label="Zoom" value={item.crop.zoom} min={0.5} max={3} oninput={(v) => crop('zoom', v, false)} onchange={(v) => crop('zoom', v, true)} />
	<div class="auto">
		<button class="primary" onclick={() => reframeClips([item.id])} title="Détecte les comédiens et les visages dans ce plan et cadre sur eux">◎ Recadrer sur les comédiens</button>
		<button onclick={() => reframeClips(null)} title="Même chose pour tous les plans du montage">Tous les plans</button>
	</div>
	<label class="det"><input type="checkbox" bind:checked={editor.showDetections} /> Montrer ce qui est détecté (à l'arrêt)</label>
	<button class="ghost reset" onclick={() => set((c) => (c.crop = { cx: 0.5, cy: 0.5, zoom: 1 }), 'Recadrage')}>Plan large (réinitialiser)</button>
</section>

<section>
	<h3>Effets</h3>
	<div class="toggles">
		<button class:on={item.fx.punch} onclick={() => fx({ punch: !item.fx.punch }, 'Punch')}>Punch d'entrée</button>
		<button class:on={item.fx.flash} onclick={() => fx({ flash: !item.fx.flash }, 'Flash')}>Flash</button>
		<button class:on={item.fx.push != null} onclick={() => fx({ push: item.fx.push != null ? null : DEFAULT_PUSH }, 'Push')}>Push</button>
		<button class:on={!!item.fx.punch_in} onclick={() => fx({ punch_in: item.fx.punch_in ? null : [0, Math.min(2, dur)] }, 'Punch-in')}>Punch-in</button>
	</div>
	{#if item.fx.push != null}
		<Slider label="Zoom continu (push)" value={item.fx.push} min={0} max={0.2} digits={3} step={0.005}
			oninput={(v) => set((c) => (c.fx = { ...c.fx, push: v }), 'Push', false)}
			onchange={(v) => fx({ push: v }, 'Push')} />
	{:else}
		<div class="dim small">Push par défaut du preset : {DEFAULT_PUSH} (1 → 1,06)</div>
	{/if}
	{#if item.fx.punch_in}
		{@const [a, b] = item.fx.punch_in}
		<div class="grid2">
			<NumField label="Punch-in début (relatif)" value={a} unit="s" onchange={(v) => fx({ punch_in: [v, Math.max(v + 0.1, b)] }, 'Punch-in')} />
			<NumField label="Punch-in fin" value={b} unit="s" onchange={(v) => fx({ punch_in: [a, Math.max(a + 0.1, v)] }, 'Punch-in')} />
		</div>
	{/if}
</section>

<style>
	.auto {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
		margin: 8px 0 4px;
	}
	.det {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 11px;
		color: var(--text-dim);
		margin: 4px 0;
	}
</style>
