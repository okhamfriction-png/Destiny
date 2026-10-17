<script lang="ts">
	import type { Mic } from '$lib/bindings/Mic';
	import type { Segment } from '$lib/bindings/Segment';
	import { applyDictionary } from '$lib/captions';
	import { clock } from '$lib/format';

	/** Transcription défilante. Clic = la réplique devient la plage ; Maj+clic étend la plage. */
	let {
		segments,
		mics = [],
		dictionary,
		range = null,
		onrange
	}: {
		segments: Segment[];
		mics?: Mic[];
		dictionary?: Record<string, string>;
		range?: [number, number] | null;
		onrange: (r: [number, number]) => void;
	} = $props();

	const inRange = (s: Segment) => !!range && s.start < range[1] && s.end > range[0];

	function pick(s: Segment, e: MouseEvent) {
		if (e.shiftKey && range) onrange([Math.min(range[0], s.start), Math.max(range[1], s.end)]);
		else onrange([s.start, s.end]);
	}
</script>

<ol class="segments scroll">
	{#each segments as s, i (i)}
		<li>
			<button class="ghost seg" class:active={inRange(s)} onclick={(e) => pick(s, e)} title="Choisir cette réplique comme passage. ⇧-clic : étendre le passage jusqu'à cette réplique.">
				<span class="mono t">{clock(s.start)}</span>
				<span class="mic">{mics.find((m) => m.id === s.mic)?.actor ?? s.mic}</span>
				<span class="text">{s.text ? applyDictionary(s.text, dictionary) : '(parole sans texte)'}</span>
				<span class="mono db">{s.db.toFixed(0)} dB</span>
			</button>
		</li>
	{:else}
		<li class="dim empty">Aucune réplique. Lancez une analyse sur une plage.</li>
	{/each}
</ol>

<style>
	.segments {
		list-style: none;
		margin: 0;
		padding: 0;
		height: 100%;
	}
	.seg {
		display: grid;
		grid-template-columns: 62px 74px 1fr 44px;
		gap: 8px;
		width: 100%;
		text-align: left;
		align-items: baseline;
		text-transform: none;
		letter-spacing: 0;
		font-family: var(--font-ui);
		font-weight: 400;
		font-size: 13px;
		padding: 7px 8px;
		border-radius: 0;
		border: none;
		border-bottom: 1px solid var(--line);
		white-space: normal;
	}
	.seg.active {
		background: #2a2213;
	}
	.seg.active .t {
		color: var(--gold-light);
	}
	.t {
		color: var(--text-dim);
		font-size: 11px;
	}
	.mic {
		font-family: var(--font-label);
		font-size: 9px;
		font-weight: 600;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: var(--gold);
	}
	.db {
		color: var(--text-mute);
		font-size: 10px;
		text-align: right;
	}
	.empty {
		padding: 12px;
		font-style: italic;
	}
</style>
