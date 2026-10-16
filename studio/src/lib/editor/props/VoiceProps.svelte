<script lang="ts">
	import NumField from '$lib/components/NumField.svelte';
	import Slider from '$lib/components/Slider.svelte';
	import type { VoiceItem } from '$lib/bindings/VoiceItem';
	import { micState, moveItem, setMicOpen, trimItem, updateItem } from '$lib/edit';
	import { clock } from '$lib/format';
	import { voiceMasterSpan, type ItemRef } from '$lib/project';
	import { studio } from '$lib/state.svelte';

	let { ref, item }: { ref: ItemRef; item: VoiceItem } = $props();

	const p = $derived(studio.project!);
	/** Intervalle maître du clip : rec/25 + in → rec/25 + out. */
	const span = $derived(voiceMasterSpan(p, item));

	const STATE_LABEL = { open: 'Ouvert', closed: 'Fermé', partial: 'Partiel' } as const;

	function toggle(mic: string) {
		const open = micState(p, mic, span[0], span[1]) !== 'open';
		studio.edit(setMicOpen(p, mic, span[0], span[1], open), `${open ? 'Ouvrir' : 'Fermer'} ${mic} sur ${item.id}`);
	}

	function setGain(v: number, commit: boolean) {
		const next = updateItem<VoiceItem>(p, ref, (c) => {
			if (v === 1) delete c.gain;
			else c.gain = v;
		});
		if (commit) studio.edit(next, `Gain ${item.id}`);
		else studio.project = next;
	}
</script>

<section>
	<h3>Voix <span class="mono dim">{item.id} · {item.src}</span></h3>
	<div class="grid3">
		<NumField label="Position" value={item.at} unit="s" onchange={(v) => studio.edit(moveItem(p, ref, v), `Déplacer ${item.id}`)} />
		<NumField label="Entrée source" value={item.in} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'start', item.at + (v - item.in)), `Rogner ${item.id}`)} />
		<NumField label="Sortie source" value={item.out} unit="s" onchange={(v) => studio.edit(trimItem(p, ref, 'end', item.at + (v - item.in)), `Rogner ${item.id}`)} />
	</div>
	<Slider label="Gain" value={item.gain ?? 1} min={0} max={2} oninput={(v) => setGain(v, false)} onchange={(v) => setGain(v, true)} />
	<label class="inline">
		<input
			type="checkbox"
			checked={!!item.camera_audio}
			onchange={(e) => {
				const on = e.currentTarget.checked;
				studio.edit(
					updateItem<VoiceItem>(p, ref, (c) => {
						if (on) c.camera_audio = true;
						else delete c.camera_audio;
					}),
					`Audio caméra ${item.id}`
				);
			}}
		/>
		Utiliser l'audio caméra (cri du public…)
	</label>
</section>

<section>
	<h3>Micros sur ce clip</h3>
	<div class="dim small mono">maître {clock(span[0], 2)} → {clock(span[1], 2)}</div>
	{#if p.mics.length === 0}
		<p class="dim small">Aucun micro dans ce projet.</p>
	{/if}
	<ul class="mics">
		{#each p.mics as m (m.id)}
			{@const st = micState(p, m.id, span[0], span[1])}
			<li>
				<span class="mono gold">{m.id}</span>
				<span class="actor">{m.actor ?? '—'}</span>
				{#if studio.suspects.some((s) => s.mic === m.id && s.end > span[0] && s.start < span[1])}
					<span class="chip warn" title="Chuchotement de coulisses détecté">suspect</span>
				{/if}
				<button class="gate {st}" onclick={() => toggle(m.id)} title="Basculer sur tout l'intervalle du clip">{STATE_LABEL[st]}</button>
			</li>
		{/each}
	</ul>
	{#if item.camera_audio}<p class="dim small">Audio caméra actif : les gates micros sont ignorées pour ce clip.</p>{/if}
</section>

<style>
	.mics {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.mics li {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 4px 6px;
		background: var(--bg);
		border-radius: var(--radius);
	}
	.gold {
		color: var(--gold);
	}
	.actor {
		flex: 1;
	}
	.gate {
		width: 74px;
	}
	.gate.open {
		border-color: #3d5a32;
		color: var(--ok);
	}
	.gate.closed {
		border-color: #5a2a26;
		color: var(--red);
	}
	.gate.partial {
		border-color: #6b4318;
		color: var(--orange);
	}
</style>
