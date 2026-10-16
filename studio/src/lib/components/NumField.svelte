<script lang="ts">
	/** Champ numérique compact : valide sur Entrée ou à la perte du focus. */
	let {
		label,
		value,
		step = 0.1,
		min,
		max,
		unit = '',
		onchange
	}: {
		label: string;
		value: number;
		step?: number;
		min?: number;
		max?: number;
		unit?: string;
		onchange: (v: number) => void;
	} = $props();

	function commit(e: Event) {
		const v = Number((e.currentTarget as HTMLInputElement).value);
		if (Number.isFinite(v) && v !== value) onchange(v);
	}
</script>

<label class="num">
	<span>{label}</span>
	<div>
		<input type="number" {step} {min} {max} value={Math.round(value * 1000) / 1000} onchange={commit} />
		{#if unit}<i>{unit}</i>{/if}
	</div>
</label>

<style>
	.num div {
		display: flex;
		align-items: center;
		gap: 4px;
	}
	input {
		width: 100%;
	}
	i {
		font-style: normal;
		color: var(--text-mute);
		font-size: 11px;
	}
</style>
