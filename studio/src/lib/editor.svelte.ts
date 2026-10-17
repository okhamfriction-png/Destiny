// État de l'éditeur : tête de lecture, lecture, sélection, zoom de la timeline.

import { studio } from './state.svelte';
import type { Source } from './bindings/Source';
import type { SourceClip } from './edit';
import { projectDuration, type ItemRef, type TrackKind } from './project';

/** Outils de la timeline, comme DaVinci : sélection (A) et lame (B). */
export type Tool = 'select' | 'blade';

class EditorState {
	playhead = $state(0);
	playing = $state(false);
	selection = $state<ItemRef | null>(null);
	/** Pixels par seconde dans la timeline. */
	pps = $state(24);
	magnet = $state(true);
	tool = $state<Tool>('select');
	/** Sélection liée : un plan vidéo entraîne la voix de même découpe. */
	linked = $state(true);
	/** Pistes verrouillées : ni sélection ni modification à la souris. */
	locked = $state<Partial<Record<TrackKind, boolean>>>({});
	/** Pistes masquées (image) ou coupées (son) dans le visualiseur ; le rendu n'est pas touché. */
	off = $state<Partial<Record<TrackKind, boolean>>>({});
	/** Visualiseur : la timeline montée, ou le rush ouvert depuis les Médias (comme DaVinci). */
	viewer = $state<'timeline' | 'source'>('timeline');
	/** Rush du visualiseur source : position et points d'entrée/sortie (temps du fichier). */
	source = $state<{ source: Source; t: number; in: number | null; out: number | null } | null>(null);
	/** Morceau de rush en cours de glisser-déposer vers la timeline (suit le pointeur). */
	drag = $state<{ clip: SourceClip; x: number; y: number } | null>(null);
	/** Incrémenté pour demander « toute la timeline dans la fenêtre » (Maj+Z). */
	fitTick = $state(0);
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

	/** Ouvre un rush dans le visualiseur source (garde ses marques s'il y était déjà). */
	openSource(source: Source): void {
		if (this.source?.source.id !== source.id || this.source.source.path !== source.path)
			this.source = { source, t: 0, in: null, out: null };
		this.viewer = 'source';
		this.pause();
	}

	/** Morceau choisi dans le visualiseur source : entre les marques, ou 10 s depuis la
	 * position (sans sortie) — jamais le rush entier de 27 min d'un coup. */
	sourceClip(): SourceClip | null {
		const s = this.source;
		if (!s) return null;
		const dur = s.source.duration ?? Infinity;
		const a = s.in ?? s.t;
		const b = s.out != null && s.out > a ? s.out : Math.min(dur, a + 10);
		return b - a >= 0.1 ? { source: s.source, in: a, out: b } : null;
	}

	reset(): void {
		this.pause();
		this.playhead = 0;
		this.selection = null;
		this.viewer = 'timeline';
		this.drag = null;
		this.clearSnapshot();
	}
}

export const editor = new EditorState();
