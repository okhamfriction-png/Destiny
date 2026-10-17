// Contrat entre le front et le backend Rust (commandes Tauri).
// Dans Tauri : `invoke` / `listen`. Dans un navigateur (`npm run dev`) : backend
// simulé en mémoire (./mock.ts) pour que toute l'interface reste utilisable.

import type { Operation } from 'fast-json-patch';
import type { MusicAnalysis } from './bindings/MusicAnalysis';
import type { Preset } from './bindings/Preset';
import type { Project } from './bindings/Project';
import type { Report } from './bindings/Report';
import type { ShortOpts } from './bindings/ShortOpts';
import type { Suspect } from './bindings/Suspect';

export type { Operation };

/** Un spectacle (ou une répétition) dans le dossier de travail. */
/** Résumé d'un montage pour la vue « Tous les projets ». */
export interface MontageInfo {
	path: string;
	name: string;
	preset: Preset;
	/** Durée de la vidéo finale (s). */
	duration: number;
	/** Dernière modification (secondes Unix). */
	modified: number;
	/** `project.json` de l'ingest : les rushes du spectacle, pas un montage. */
	master: boolean;
}

export interface LibraryEntry {
	dir: string;
	name: string;
	/** Chemins absolus des montages `*.json` (dossier du spectacle et `montages/`). */
	projects: string[];
	/** Les mêmes, résumés, du plus récent au plus ancien. */
	montages: MontageInfo[];
	hasIngest: boolean;
	transcripts: string[];
	/** Planches contact (jpg). */
	sheets: string[];
	/** Dernière modification (secondes Unix). */
	modified: number;
}

/** Projet ouvert côté backend, avec l'état de l'historique. */
export interface ProjectState {
	path: string;
	project: Project;
	canUndo: boolean;
	canRedo: boolean;
	undoLabel: string | null;
	redoLabel: string | null;
}

/** Progression d'un job long (événement `job`). */
export interface JobEvent {
	id: string;
	kind: string;
	stage: string;
	/** 0..1 */
	progress: number;
	done: boolean;
	error: string | null;
	result: unknown | null;
}

export interface AnalyzeResult {
	transcript: string;
	suspects: Suspect[];
}

export interface RenderResult {
	out: string;
	report: Report;
}

export interface ClaudeAnswer {
	patch: Operation[];
	explanation: string;
}

export type RenderQuality = 'preview' | 'delivery';

/** Toutes les commandes exposées par le backend (noms Tauri en snake_case,
 * arguments en camelCase : Tauri les convertit). */
export interface Backend {
	defaultRoot(): Promise<string>;
	library(root: string): Promise<LibraryEntry[]>;
	openProject(path: string): Promise<ProjectState>;
	/** Copie un montage sous un nom libre (`nom_2.json`…) et renvoie son chemin. */
	duplicateProject(path: string): Promise<string>;
	commitProject(project: Project, label: string): Promise<ProjectState>;
	applyPatch(patch: Operation[], label: string): Promise<ProjectState>;
	undo(): Promise<ProjectState>;
	redo(): Promise<ProjectState>;
	readJson<T = unknown>(path: string): Promise<T>;
	musicAnalysis(file: string): Promise<MusicAnalysis>;
	proposeShort(args: {
		from: number;
		to: number;
		opts: ShortOpts;
		transcript: string | null;
		out: string;
	}): Promise<string>;
	ingest(args: { dir: string; projectDir: string; proxies: boolean; sheets: boolean }): Promise<string>;
	analyze(args: { from: number; to: number; model: string | null }): Promise<string>;
	render(args: { quality: RenderQuality; out: string | null }): Promise<string>;
	snapshot(t: number): Promise<string>;
	/** Aperçu live du moteur B (trailers, reels) : URL de la composition HTML/GSAP du
	 * projet ouvert, réécrite à chaque appel ; `null` pour les shorts ou hors Tauri. */
	composePreview(): Promise<string | null>;
	exportProject(targets: string[] | null): Promise<string>;
	cancelJob(id: string): Promise<void>;
	askClaude(instruction: string): Promise<ClaudeAnswer>;
	/** Abonnement aux événements `job` ; renvoie la fonction de désabonnement. */
	onJob(cb: (e: JobEvent) => void): Promise<() => void>;
	/** URL affichable d'un fichier local (vidéo, image). */
	fileSrc(path: string): string;
}

export const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

/** Les erreurs Rust arrivent comme chaînes ; on garantit un message lisible. */
function errorMessage(e: unknown): string {
	if (typeof e === 'string') return e;
	if (e instanceof Error) return e.message;
	return JSON.stringify(e);
}

async function tauriBackend(): Promise<Backend> {
	const { invoke, convertFileSrc } = await import('@tauri-apps/api/core');
	const { listen } = await import('@tauri-apps/api/event');
	const call = async <T>(cmd: string, args?: Record<string, unknown>): Promise<T> => {
		try {
			return await invoke<T>(cmd, args);
		} catch (e) {
			throw errorMessage(e);
		}
	};
	return {
		defaultRoot: () => call('default_root'),
		library: (root) => call('library', { root }),
		openProject: (path) => call('open_project', { path }),
		duplicateProject: (path) => call('duplicate_project', { path }),
		commitProject: (project, label) => call('commit_project', { project, label }),
		applyPatch: (patch, label) => call('apply_patch', { patch, label }),
		undo: () => call('undo'),
		redo: () => call('redo'),
		readJson: (path) => call('read_json', { path }),
		musicAnalysis: (file) => call('music_analysis', { file }),
		proposeShort: (args) => call('propose_short', { ...args }),
		ingest: (args) => call('ingest', { ...args }),
		analyze: (args) => call('analyze', { ...args }),
		render: (args) => call('render', { ...args }),
		snapshot: (t) => call('snapshot', { t }),
		composePreview: async () => {
			const v = await call<string | null>('compose_preview');
			if (!v) return null;
			// Protocole `comp` de src-tauri (Windows l'expose en http://comp.localhost).
			const base = navigator.userAgent.includes('Windows') ? 'http://comp.localhost' : 'comp://localhost';
			return `${base}/index.html?overlay=1&v=${v}`;
		},
		exportProject: (targets) => call('export_project', { targets }),
		cancelJob: (id) => call('cancel_job', { id }),
		askClaude: (instruction) => call('ask_claude', { instruction }),
		onJob: (cb) => listen<JobEvent>('job', (e) => cb(e.payload)),
		fileSrc: (path) => convertFileSrc(path)
	};
}

let backend: Promise<Backend> | null = null;

/** Backend actif (Tauri ou simulé), chargé une seule fois. */
export function getBackend(): Promise<Backend> {
	backend ??= isTauri ? tauriBackend() : import('./mock').then((m) => m.createMockBackend());
	return backend;
}

/** Raccourci : `const api = await getBackend()` est inutile partout ailleurs. */
export const api = new Proxy({} as { [K in keyof Backend]: Backend[K] }, {
	get(_t, key: keyof Backend) {
		if (key === 'fileSrc') {
			// Synchrone : utilisé dans le rendu. Le mock renvoie le chemin tel quel.
			return (path: string) => (resolved ? resolved.fileSrc(path) : path);
		}
		return async (...args: unknown[]) => {
			const b = await getBackend();
			return (b[key] as (...a: unknown[]) => unknown)(...args);
		};
	}
});

let resolved: Backend | null = null;
void getBackend().then((b) => (resolved = b));
