<script lang="ts">
	import type { GraphicItem } from '$lib/bindings/GraphicItem';
	import type { Project } from '$lib/bindings/Project';
	import { activeBlock, applyDictionary, blocks, captionWords, normalizeWord } from '$lib/captions';
	import { captions, graphics } from '$lib/project';
	import { PROGRESS_H, shortLayout, wrapHook } from '$lib/layout';

	/** Habillage des shorts « scène » (moteur A), en pixels du format final :
	 * kicker, bandeau hook, tag, sous-titres dynamiques, CTA, barre de progression. */
	let { project, t }: { project: Project; t: number } = $props();

	const lay = $derived(shortLayout(project.format.w, project.format.h));
	const all = $derived(graphics(project));
	const active = $derived(all.filter((g) => t >= g.at && t < g.at + g.dur));
	const ctaStart = $derived(Math.min(Infinity, ...all.filter((g) => g.type === 'cta').map((g) => g.at)));

	// Calage et découpe identiques au rendu : dictionnaire appliqué mot par mot.
	const subBlocks = $derived(
		blocks(captionWords(captions(project)).map((w) => ({ ...w, text: applyDictionary(w.text, project.dictionary) })))
	);
	const emphasis = $derived(new Set(captions(project).flatMap((c) => (c.emphasis ?? []).map(normalizeWord))));
	const sub = $derived(activeBlock(subBlocks, t, ctaStart));

	function of<K extends GraphicItem['type']>(type: K) {
		return active.filter((g): g is Extract<GraphicItem, { type: K }> => g.type === type);
	}
</script>

{#each of('hook') as g, i (i)}
	{@const [y0, y1] = lay.banner}
	<div class="banner" style:top="{y0}px" style:height="{y1 - y0}px">
		<div class="hook">
			{#each wrapHook(g.lines) as line, j (j)}<div>{line.toUpperCase()}</div>{/each}
		</div>
	</div>
{/each}

{#each of('kicker') as g, i (i)}
	<div class="center kicker" style:top="{lay.kickerY}px">{g.text.toUpperCase()}</div>
{/each}

{#each of('tag') as g, i (i)}
	<div class="center" style:top="{lay.tagY}px"><span class="tag">{g.text.toUpperCase()}</span></div>
{/each}

{#if sub}
	<div class="center subs" style:top="{lay.subsY}px">
		{#each sub.block.words as w, j (j)}
			{@const emph = emphasis.has(normalizeWord(w.text))}
			<span class="word" class:active={j === sub.active} class:emph>{w.text.toUpperCase()}</span>{#if j < sub.block.words.length - 1}{' '}{/if}
		{/each}
	</div>
{/if}

{#each of('cta') as g, i (i)}
	<div class="center" style:top="{lay.ctaY}px">
		<div class="cta">{#each g.lines as l, j (j)}<div>{l.toUpperCase()}</div>{/each}</div>
	</div>
{/each}

{#each of('progress') as g, i (i)}
	<div class="progress" style:height="{PROGRESS_H}px" style:width="{((t - g.at) / g.dur) * lay.w}px"></div>
{/each}

<style>
	.banner {
		position: absolute;
		left: 0;
		right: 0;
		background: rgba(0, 0, 0, 0.94);
		display: grid;
		place-items: center;
	}
	.hook {
		font-family: var(--font-anton);
		font-size: 92px;
		line-height: 1.06;
		color: #f3ede4;
		text-align: center;
		letter-spacing: 1px;
	}
	/* Élément centré verticalement sur `top` (comme \pos en alignement 5). */
	.center {
		position: absolute;
		left: 40px;
		right: 40px;
		transform: translateY(-50%);
		text-align: center;
	}
	.kicker {
		font-family: var(--font-label);
		font-weight: 600;
		font-size: 44px;
		letter-spacing: 0.32em;
		color: #f7dc8a;
		text-shadow: 0 2px 2px rgba(0, 0, 0, 0.6);
	}
	.tag {
		display: inline-block;
		background: #f7dc8a;
		color: #000;
		font-family: var(--font-label);
		font-weight: 600;
		font-size: 34px;
		letter-spacing: 3px;
		padding: 8px 14px;
		line-height: 1.1;
	}
	.subs {
		left: 30px;
		right: 30px;
		font-family: var(--font-anton);
		font-size: 118px;
		line-height: 1.05;
		color: #fff;
		letter-spacing: 1px;
		-webkit-text-stroke: 14px #000;
		paint-order: stroke fill;
		text-shadow: 0 3px 0 rgba(0, 0, 0, 0.62);
	}
	.word {
		display: inline-block;
	}
	.word.emph {
		color: #e0352b;
	}
	.word.active {
		color: #f7dc8a;
		transform: scale(1.12);
		margin: 0 0.06em;
	}
	.word.active.emph {
		color: #e0352b;
	}
	.cta {
		display: inline-block;
		background: #e0352b;
		color: #f3ede4;
		font-family: var(--font-anton);
		font-size: 84px;
		line-height: 1.08;
		letter-spacing: 2px;
		padding: 20px 26px;
	}
	.progress {
		position: absolute;
		left: 0;
		bottom: 0;
		background: #f7dc8a;
	}
</style>
