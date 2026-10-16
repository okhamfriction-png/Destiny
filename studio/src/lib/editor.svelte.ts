// État de l'éditeur : tête de lecture, lecture, sélection, zoom de la timeline.

import { studio } from './state.svelte';
import { projectDuration, type ItemRef } from './project';

class EditorState {
	playhead = $state(0);
	playing = $state(false);
	selection = $state<ItemRef | null>(null);
	/** Pixels par seconde dans la timeline. */
	pps = $state(24);
	magnet = $state(true);
	/** Instant de la dernière cible d'aimantation atteinte (guide vertical). */
	snapGuide = $state<number | null>(null);
	/** Image exacte (PNG du moteur de rendu) affichée par-dessus l'aperçu. */
	snapshotUrl = $state<string | null>(null);
	snapshotAt = $state<number | null>(null);

	duration = $derived(studio.project ? projectDuration(studio.project) : 0);
	fps = $derived(studio.project?.format.fps ?? 30);

	#raf = 0;
	#last = 0;

	seek(t: number): void {
		this.playhead = Math.min(Math.max(0, t), this.duration);
		if (this.snapshotAt !== null && Math.abs(this.snapshotAt - this.playhead) > 1e-3) this.clearSnapshot();
	}

	/** Avance de `n` images (négatif pour reculer). */
	step(frames: number): void {
		this.pause();
		const f = Math.round(this.playhead * this.fps) + frames;
		this.seek(f / this.fps);
	}

	toggle(): void {
		if (this.playing) this.pause();
		else this.play();
	}

	play(): void {
		if (this.playing) return;
		if (this.playhead >= this.duration - 1e-3) this.playhead = 0;
		this.clearSnapshot();
		this.playing = true;
		this.#last = performance.now();
		const tick = (now: number) => {
			if (!this.playing) return;
			const t = this.playhead + (now - this.#last) / 1000;
			this.#last = now;
			if (t >= this.duration) {
				this.playhead = this.duration;
				this.pause();
				return;
			}
			this.playhead = t;
			this.#raf = requestAnimationFrame(tick);
		};
		this.#raf = requestAnimationFrame(tick);
	}

	pause(): void {
		this.playing = false;
		cancelAnimationFrame(this.#raf);
	}

	clearSnapshot(): void {
		this.snapshotUrl = null;
		this.snapshotAt = null;
	}

	reset(): void {
		this.pause();
		this.playhead = 0;
		this.selection = null;
		this.clearSnapshot();
	}
}

export const editor = new EditorState();
