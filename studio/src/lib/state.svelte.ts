// État global de l'application (runes Svelte 5).
// Le backend est la source de vérité : l'UI affiche un brouillon optimiste
// (`project`) et envoie chaque édition à `commit_project`, dans l'ordre.

import { api, type JobEvent, type LibraryEntry, type ProjectState } from './api';
import type { Project } from './bindings/Project';
import type { Suspect } from './bindings/Suspect';

export type View = 'library' | 'explorer' | 'proposals' | 'editor' | 'export';

export interface Job extends JobEvent {
	label: string;
	startedAt: number;
}

export interface Toast {
	id: number;
	kind: 'info' | 'error';
	text: string;
}

const LAST_KEY = 'destiny.lastProject';
// Préférence de confort : stockage du navigateur, protégé (fenêtre privée, accès refusé).
function readLast(): string | null {
	try {
		return localStorage.getItem(LAST_KEY);
	} catch {
		return null;
	}
}
function writeLast(path: string): void {
	try {
		localStorage.setItem(LAST_KEY, path);
	} catch {
		/* sans importance */
	}
}

/** Délai de regroupement des frappes clavier en un seul commit. */
export const TYPING_DEBOUNCE_MS = 400;

class Studio {
	view = $state<View>('library');
	root = $state('');
	library = $state<LibraryEntry[]>([]);
	/** Spectacle choisi pour l'explorateur et les propositions. */
	show = $state<LibraryEntry | null>(null);

	/** Dernier état renvoyé par le backend (historique compris). */
	server = $state.raw<ProjectState | null>(null);
	/** Projet affiché : égal à `server.project`, ou en avance pendant une édition. */
	project = $state.raw<Project | null>(null);
	/** Montages créés par « Proposer » pendant la session. */
	proposals = $state<string[]>([]);

	jobs = $state<Job[]>([]);
	/** Plage maître choisie dans l'explorateur, reprise par les propositions. */
	range = $state<[number, number] | null>(null);
	/** Transcription active (chemin `.cache/transcript_*.json`). */
	transcript = $state<string | null>(null);
	/** Segments suspects (chuchotements) de la dernière analyse, temps maître. */
	suspects = $state<Suspect[]>([]);
	toasts = $state<Toast[]>([]);

	#queue: Promise<unknown> = Promise.resolve();
	#inflight = 0;
	#pending: { key: string; label: string; timer: ReturnType<typeof setTimeout> } | null = null;
	#jobCallbacks = new Map<string, (e: JobEvent) => void>();
	#toastSeq = 0;
	#started = false;

	/** Abonnement aux jobs et chargement de la bibliothèque (une fois). */
	async init(): Promise<void> {
		if (this.#started) return;
		this.#started = true;
		await api.onJob((e) => this.#onJob(e));
		try {
			this.root = await api.defaultRoot();
			await this.refreshLibrary();
		} catch (e) {
			this.error(e);
		}
		// Comme DaVinci : on retrouve le dernier montage ouvert, directement sur sa timeline.
		const last = readLast();
		if (last && this.library.some((s) => s.projects.includes(last))) await this.open(last);
	}

	async refreshLibrary(): Promise<void> {
		try {
			this.library = await api.library(this.root);
			if (this.show) this.show = this.library.find((l) => l.dir === this.show!.dir) ?? null;
		} catch (e) {
			this.error(e);
		}
	}

	// -------------------------------------------------------------------------
	// Projet et historique
	// -------------------------------------------------------------------------

	get path(): string | null {
		return this.server?.path ?? null;
	}

	async open(path: string): Promise<void> {
		await this.flush();
		try {
			this.#adopt(await api.openProject(path), true);
			this.view = 'editor';
			writeLast(path);
		} catch (e) {
			this.error(e);
		}
	}

	/** Édition depuis l'UI. Avec `debounceKey`, les éditions successives de même clé
	 * (frappe dans un champ) sont regroupées en un seul commit après 400 ms. */
	edit(next: Project, label: string, debounceKey?: string): void {
		if (this.#pending && this.#pending.key !== debounceKey) this.#flushPending();
		this.project = next;
		if (debounceKey) {
			if (this.#pending) clearTimeout(this.#pending.timer);
			this.#pending = {
				key: debounceKey,
				label,
				timer: setTimeout(() => this.#flushPending(), TYPING_DEBOUNCE_MS)
			};
		} else {
			this.#enqueue(() => api.commitProject(next, label));
		}
	}

	/** Envoie immédiatement l'édition en attente et attend la fin de la file. */
	async flush(): Promise<void> {
		this.#flushPending();
		await this.#queue;
	}

	async applyPatch(patch: Parameters<typeof api.applyPatch>[0], label: string): Promise<boolean> {
		this.#flushPending();
		return this.#enqueue(() => api.applyPatch(patch, label));
	}

	undo(): void {
		this.#flushPending();
		if (this.server?.canUndo || this.#inflight > 0) void this.#enqueue(() => api.undo());
	}

	redo(): void {
		this.#flushPending();
		if (this.server?.canRedo || this.#inflight > 0) void this.#enqueue(() => api.redo());
	}

	#flushPending(): void {
		const p = this.#pending;
		if (!p) return;
		clearTimeout(p.timer);
		this.#pending = null;
		const snapshot = this.project!;
		void this.#enqueue(() => api.commitProject(snapshot, p.label));
	}

	/** Exécute les appels qui modifient le projet un par un, dans l'ordre. */
	#enqueue(call: () => Promise<ProjectState>): Promise<boolean> {
		this.#inflight++;
		const run = this.#queue.then(async () => {
			try {
				this.#adopt(await call());
				return true;
			} catch (e) {
				this.error(e);
				// Le backend a refusé : on revient à son état.
				if (this.server && !this.#pending) this.project = this.server.project;
				return false;
			} finally {
				this.#inflight--;
			}
		});
		this.#queue = run;
		return run;
	}

	#adopt(ps: ProjectState, force = false): void {
		this.server = ps;
		// Pas d'écrasement du brouillon tant que d'autres éditions sont en route.
		if (force || (this.#inflight <= 1 && !this.#pending)) this.project = ps.project;
	}

	// -------------------------------------------------------------------------
	// Jobs
	// -------------------------------------------------------------------------

	/** Lance un job ; `onDone` reçoit l'événement final (réussi ou en erreur). */
	async startJob(label: string, start: () => Promise<string>, onDone?: (e: JobEvent) => void): Promise<string | null> {
		try {
			const id = await start();
			const existing = this.jobs.find((j) => j.id === id);
			if (existing) existing.label = label;
			else
				this.jobs.unshift({ id, kind: '', stage: 'En attente', progress: 0, done: false, error: null, result: null, label, startedAt: Date.now() });
			if (onDone) {
				if (existing?.done) onDone(existing);
				else this.#jobCallbacks.set(id, onDone);
			}
			return id;
		} catch (e) {
			this.error(e);
			return null;
		}
	}

	#onJob(e: JobEvent): void {
		const j = this.jobs.find((x) => x.id === e.id);
		if (j) Object.assign(j, e, { kind: e.kind === 'cancel' ? j.kind : e.kind });
		else this.jobs.unshift({ ...e, label: e.kind, startedAt: Date.now() });
		if (e.done) {
			const cb = this.#jobCallbacks.get(e.id);
			this.#jobCallbacks.delete(e.id);
			if (e.error) this.error(`${j?.label ?? e.kind} : ${e.error}`);
			cb?.(e);
		}
	}

	job(id: string | null): Job | undefined {
		return id ? this.jobs.find((j) => j.id === id) : undefined;
	}

	// -------------------------------------------------------------------------
	// Messages
	// -------------------------------------------------------------------------

	info(text: string): void {
		this.#toast('info', text);
	}

	error(e: unknown): void {
		this.#toast('error', typeof e === 'string' ? e : e instanceof Error ? e.message : JSON.stringify(e));
	}

	#toast(kind: Toast['kind'], text: string): void {
		const id = ++this.#toastSeq;
		this.toasts.push({ id, kind, text });
		setTimeout(() => (this.toasts = this.toasts.filter((t) => t.id !== id)), kind === 'error' ? 7000 : 3500);
	}
}

export const studio = new Studio();
