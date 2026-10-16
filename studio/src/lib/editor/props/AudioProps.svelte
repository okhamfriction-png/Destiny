<script lang="ts">
	import NumField from '$lib/components/NumField.svelte';
	import Slider from '$lib/components/Slider.svelte';
	import type { MusicItem } from '$lib/bindings/MusicItem';
	import type { SfxItem } from '$lib/bindings/SfxItem';
	import type { SfxKind } from '$lib/bindings/SfxKind';
	import { moveItem, trimItem, updateItem } from '$lib/edit';
	import { basename, clock } from '$lib/format';
	import type { ItemRef, TrackKind } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	/** Propriétés d'un élément musique ou bruitage. */
	let { ref, kind, item }: { ref: ItemRef; kind: TrackKind; item: MusicItem | SfxItem } = $props();

	const p = $derived(studio.project!);
	const SFX: SfxKind[] = ['snap', 'whoosh', 'tom', 'gong', 'braam', 'sub_drop', 'impact'];

	function setGain(v: number, commit: boolean) {
		const next = updateItem<SfxItem>(p, ref, (s) => (s.gain = v));
		if (commit) studio.edit(next, 'Gain du bruitage');
		else studio.project = next;
	}
</script>

{#if kind === 'music'}
	{@const m = item as MusicItem}
	<section>
		<h3>Musique <span class="dim">{basename(m.file)}</span></h3>
		<div class="grid3">
			<NumField label="Début" value={m.at} unit="s" onchange={(v) => studio.edit(moveItem(p, ref, v), 'Déplacer la musique')} />
			<NumField label="Offset fichier" value={m.offset} unit="s" min={0}
				onchange={(v) => studio.edit(updateItem<MusicItem>(p, ref, (x) => (x.offset = Math.max(0, v))), 'Offset musique')} />
			<NumField label="Durée" value={m.dur ?? 0} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'end', m.at + v), 'Durée musique')} />
		</div>
		<div class="dim small">Le coup le plus fort doit tomber sur la carte finale : offset = coup − début de la carte.</div>
	</section>
	{#if m.gain_env?.length}
		<section>
			<h3>Enveloppe de gain</h3>
			<ul class="env mono">
				{#each m.gain_env as [t, g], i (i)}<li><span>{clock(t, 1)}</span><b>{g.toFixed(2)}</b></li>{/each}
			</ul>
		</section>
	{/if}
{:else}
	{@const s = item as SfxItem}
	<section>
		<h3>Bruitage</h3>
		<label>
			<span>Type</span>
			<select value={s.type} onchange={(e) => studio.edit(updateItem<SfxItem>(p, ref, (x) => (x.type = e.currentTarget.value as SfxKind)), 'Type de bruitage')}>
				{#each SFX as k (k)}<option value={k}>{k}</option>{/each}
			</select>
		</label>
		<NumField label="Position" value={s.at} unit="s" onchange={(v) => studio.edit(moveItem(p, ref, v), 'Déplacer le bruitage')} />
		<Slider label="Gain" value={s.gain} min={0} max={1.5} oninput={(v) => setGain(v, false)} onchange={(v) => setGain(v, true)} />
	</section>
{/if}

<style>
	.env {
		list-style: none;
		margin: 0;
		padding: 0;
		font-size: 11px;
	}
	.env li {
		display: flex;
		justify-content: space-between;
		padding: 2px 0;
		border-bottom: 1px solid var(--line);
	}
	.env b {
		color: var(--gold-light);
		font-weight: 500;
	}
</style>
