<script lang="ts">
	/** Curseur : `oninput` pendant le glissé (aperçu), `onchange` au relâchement (commit). */
	let {
		label,
		value,
		min,
		max,
		step = 0.01,
		digits = 2,
		oninput,
		onchange
	}: {
		label: string;
		value: number;
		min: number;
		max: number;
		step?: number;
		digits?: number;
		oninput: (v: number) => void;
		onchange: (v: number) => void;
	} = $props();
</script>

<label class="slider">
	<span>{label}</span>
	<div>
		<input
			type="range"
			{min}
			{max}
			{step}
			{value}
			oninput={(e) => oninput(+e.currentTarget.value)}
			onchange={(e) => onchange(+e.currentTarget.value)}
		/>
		<output class="mono">{value.toFixed(digits)}</output>
	</div>
</label>

<style>
	.slider div {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	input {
		flex: 1;
	}
	output {
		width: 40px;
		text-align: right;
		color: var(--gold-light);
	}
</style>
