// Backend simulé pour le navigateur (`npm run dev` hors Tauri).
// Données : examples/serpent/project.json et examples/synthetic/transcript.json,
// complétées de quelques valeurs de démonstration (micros, répliques, musique)
// pour que chaque écran ait quelque chose à montrer. Les jobs sont des minuteries.

import { applyPatch, compare, deepClone, type Operation } from 'fast-json-patch';
import serpent from '../../examples/serpent/project.json';
import syntheticTranscript from '../../examples/synthetic/transcript.json';
import type { Backend, ClaudeAnswer, JobEvent, LibraryEntry, ProjectState } from './api';
import type { MicMap } from './bindings/MicMap';
import type { MusicAnalysis } from './bindings/MusicAnalysis';
import type { Project } from './bindings/Project';
import type { Report } from './bindings/Report';
import type { ShortOpts } from './bindings/ShortOpts';
import type { Suspect } from './bindings/Suspect';
import type { Transcript } from './bindings/Transcript';
import { graphics, normalizeProject, projectDuration, videoItems } from './project';

const ROOT = '/Users/marouene/DestinyStudio';
const SHOW = `${ROOT}/8 Octobre 2026`;
const SERPENT = `${SHOW}/montages/serpent_aux_yeux_verts.json`;
const now = () => Math.floor(Date.now() / 1000);
const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Générateur pseudo-aléatoire à graine fixe (données de démo reproductibles). */
function rng(seed: number) {
	let s = seed >>> 0;
	return () => {
		s = (s * 1664525 + 1013904223) >>> 0;
		return s / 2 ** 32;
	};
}

/** Projet « serpent » + données de démo (micros, répliques, coups de musique). */
function demoProject(): Project {
	const p = normalizeProject(serpent);
	p.mics = [
		{ id: 'm1', path: `${SHOW}/TX00_MIC001_20261008_194419_orig.wav`, rec: 0, actor: 'Jean' },
		{ id: 'm2', path: `${SHOW}/TX01_MIC002_20261008_194419_orig.wav`, rec: 0, actor: 'Bérangère' },
		{ id: 'm3', path: `${SHOW}/TX02_MIC003_20261008_194419_orig.wav`, rec: 0, actor: 'Osmo' }
	];
	p.mic_gates = { m2: [[5266.8, 5327.3]], m3: [] };
	p.markers = { music_hits: [12.6, 31.2], cuts: [62.5] };
	const subs = p.tracks.find((t) => t.kind === 'captions');
	if (subs?.kind === 'captions') {
		subs.items.push(
			{ start: 3.1, end: 5.0, text: "C'est pour toi ? Y a quelqu'un ?" },
			{ start: 7.4, end: 9.6, text: 'Attention, il a une morture au cou.', emphasis: ['morture'] },
			{ start: 12.6, end: 14.4, text: "Appuie sur la sonnette d'Allah !" },
			{ start: 16.0, end: 17.5, text: 'On court, on court !' }
		);
	}
	return p;
}

/** Vérifications minimales (le vrai contrôle est `Project::validate` côté Rust). */
function validate(p: Project): void {
	if (p.version !== 1) throw `version ${p.version} non prise en charge (attendu 1)`;
	const ids = new Set<string>();
	for (const c of videoItems(p)) {
		if (ids.has(c.id)) throw `identifiant de clip dupliqué : ${c.id}`;
		ids.add(c.id);
		if (!p.sources.some((s) => s.id === c.src)) throw `clip ${c.id} : source inconnue ${c.src}`;
		if (!(c.out > c.in) || c.in < 0 || c.at < 0) throw `clip ${c.id} : intervalle invalide`;
	}
	for (const g of graphics(p)) {
		if (g.type === 'hook' && g.lines.length > 2) throw 'hook : 2 lignes maximum';
		if (g.dur <= 0) throw `élément graphique de durée nulle : ${g.type}`;
	}
	for (const t of p.tracks)
		if (t.kind === 'captions')
			for (const c of t.items) if (!(c.end > c.start)) throw `sous-titre « ${c.text} » : fin avant début`;
}

interface Entry {
	label: string;
	before: Project;
	after: Project;
}

function syntheticMicMap(): MicMap {
	const r = rng(7);
	const t0 = 5250;
	const hop = 0.5;
	const n = 200;
	const mics = ['m1', 'm2', 'm3'];
	const levels = mics.map((_, m) =>
		Array.from({ length: n }, (_, k) => {
			const t = t0 + k * hop;
			const speaking = m === 0 ? Math.sin(t * 0.7) > -0.2 : m === 1 ? t > 5262 && t < 5300 : t > 5310 && t < 5322;
			const base = speaking ? -24 : -58;
			const whisper = m === 2 && speaking ? -38 : base;
			return Math.round((whisper + r() * 8 - 4) * 10) / 10;
		})
	);
	const dominant = Array.from({ length: n }, (_, k) => {
		let best: number | null = null;
		for (let m = 0; m < mics.length; m++)
			if (levels[m][k] > -50 && (best === null || levels[m][k] > levels[best][k])) best = m;
		return best;
	});
	const voicing = mics.map((_, m) => levels[m].map((db) => (m === 2 ? 0.2 : db > -45 ? 0.8 : 0.1)));
	return { t0, hop, mics, levels, dominant, voicing };
}

function syntheticSuspects(): Suspect[] {
	return [{ mic: 'm3', start: 5310.5, end: 5321.5, db: -38.2 }];
}

function syntheticMusic(file: string): MusicAnalysis {
	const duration = 89.2;
	const hop = 0.1;
	const r = rng(3);
	const env = Array.from({ length: Math.round(duration / hop) }, (_, k) => {
		const t = k * hop;
		let db = -26 + 10 * Math.min(1, t / 50) + 3 * Math.sin(t * 2.1) + r() * 3;
		if (t > 54 && t < 55.8) db = -48 + r() * 2;
		if (t > 78 && t < 83.5) db = -34 + r() * 3;
		if (Math.abs(t - 55.9) < 0.3 || Math.abs(t - 83.6) < 0.4) db = -4;
		return Math.round(db * 10) / 10;
	});
	const hits = [8.4, 21.1, 34.0, 55.9, 70.2, 83.6];
	return {
		file,
		duration,
		hop,
		env,
		onsets: [...hits, 4.2, 16.8, 27.5, 45.3, 62.1].sort((a, b) => a - b).map((t) => ({ t, strength: hits.includes(t) ? 18 : 9 })),
		hits,
		dips: [
			[54, 55.8],
			[78, 83]
		],
		biggest_hit: 83.6
	};
}

/** Image de remplacement pour « Image exacte » (le vrai rendu est un PNG ffmpeg). */
function snapshotSvg(p: Project, t: number): string {
	const { w, h } = p.format;
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
<rect width="100%" height="100%" fill="#14100c"/>
<rect x="40" y="40" width="${w - 80}" height="${h - 80}" fill="none" stroke="#e6b446" stroke-width="6" stroke-dasharray="24 16"/>
<text x="50%" y="48%" fill="#f7dc8a" font-family="Anton" font-size="${w / 12}" text-anchor="middle">IMAGE EXACTE</text>
<text x="50%" y="54%" fill="#f3ede4" font-family="Montserrat" font-size="${w / 28}" text-anchor="middle">snapshot simulé · t = ${t.toFixed(2)} s</text>
</svg>`;
	return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

export function createMockBackend(): Backend {
	const projects = new Map<string, Project>([[SERPENT, demoProject()]]);
	const extraShows: LibraryEntry[] = [];
	let currentPath: string | null = null;
	let undoStack: Entry[] = [];
	let redoStack: Entry[] = [];
	const listeners = new Set<(e: JobEvent) => void>();
	const timers = new Map<string, ReturnType<typeof setInterval>>();
	let jobSeq = 0;

	const current = (): Project => {
		if (!currentPath) throw 'aucun projet ouvert';
		return projects.get(currentPath)!;
	};

	const state = (): ProjectState => ({
		path: currentPath!,
		project: deepClone(current()),
		canUndo: undoStack.length > 0,
		canRedo: redoStack.length > 0,
		undoLabel: undoStack.at(-1)?.label ?? null,
		redoLabel: redoStack.at(-1)?.label ?? null
	});

	const commit = (next: Project, label: string): ProjectState => {
		validate(next);
		const before = current();
		// Comme `History::commit` : un commit sans différence n'entre pas dans l'historique.
		if (compare(before, next).length > 0) {
			undoStack.push({ label, before, after: deepClone(next) });
			redoStack = [];
			projects.set(currentPath!, deepClone(next));
		}
		return state();
	};

	const emit = (e: JobEvent) => listeners.forEach((cb) => cb(e));

	/** Job simulé : étapes successives, progression régulière, résultat final. */
	const fakeJob = (kind: string, stages: string[], durationMs: number, result: () => unknown): string => {
		const id = `job-${++jobSeq}`;
		const start = Date.now();
		emit({ id, kind, stage: stages[0], progress: 0, done: false, error: null, result: null });
		const timer = setInterval(() => {
			const progress = Math.min(1, (Date.now() - start) / durationMs);
			if (progress >= 1) {
				clearInterval(timer);
				timers.delete(id);
				emit({ id, kind, stage: 'Terminé', progress: 1, done: true, error: null, result: result() });
			} else {
				const stage = stages[Math.min(stages.length - 1, Math.floor(progress * stages.length))];
				emit({ id, kind, stage, progress, done: false, error: null, result: null });
			}
		}, 150);
		timers.set(id, timer);
		return id;
	};

	const report = (quality: string): Report => {
		const d = projectDuration(current());
		return {
			duration: d + 0.02,
			expected_duration: d,
			width: quality === 'preview' ? 540 : current().format.w,
			height: quality === 'preview' ? 960 : current().format.h,
			mean_volume_db: -19.4,
			integrated_lufs: -16.2,
			true_peak_db: -1.7,
			problems: quality === 'preview' ? [] : ['true peak −1,7 dBTP : marge faible (cible −1,5)']
		};
	};

	return {
		async defaultRoot() {
			return ROOT;
		},

		async library(root) {
			await delay(120);
			const serpentProjects = [...projects.keys()].filter((p) => p.startsWith(SHOW));
			return [
				{
					dir: SHOW,
					name: '8 Octobre 2026',
					projects: serpentProjects,
					hasIngest: true,
					transcripts: [`${SHOW}/.cache/transcript_5250_5350.json`],
					sheets: [1, 2, 3, 4].map((k) => `${SHOW}/.cache/sheets/sheet_${k}.jpg`),
					modified: now() - 3600
				},
				{
					dir: `${root}/Répétition 1er octobre`,
					name: 'Répétition 1er octobre',
					projects: [],
					hasIngest: false,
					transcripts: [],
					sheets: [],
					modified: now() - 86400 * 15
				},
				...extraShows
			];
		},

		async openProject(path) {
			await delay(80);
			if (!projects.has(path)) throw `fichier introuvable : ${path}`;
			currentPath = path;
			undoStack = [];
			redoStack = [];
			return state();
		},

		async commitProject(project, label) {
			return commit(deepClone(project), label);
		},

		async applyPatch(patch, label) {
			const next = deepClone(current());
			try {
				applyPatch(next, patch as Operation[], true);
			} catch (e) {
				throw `patch inapplicable : ${e instanceof Error ? e.message : String(e)}`;
			}
			return commit(next, label);
		},

		async undo() {
			const e = undoStack.pop();
			if (e) {
				projects.set(currentPath!, deepClone(e.before));
				redoStack.push(e);
			}
			return state();
		},

		async redo() {
			const e = redoStack.pop();
			if (e) {
				projects.set(currentPath!, deepClone(e.after));
				undoStack.push(e);
			}
			return state();
		},

		async readJson<T>(path: string): Promise<T> {
			await delay(60);
			const project = projects.get(path);
			if (project) return deepClone(project) as T;
			if (path.includes('transcript')) {
				// La transcription synthétique (0–36 s) est recalée sur la scène du serpent.
				const t = syntheticTranscript as Transcript;
				const shifted: Transcript = {
					segments: t.segments.map((s) => ({ ...s, start: s.start + 5260, end: s.end + 5260 }))
				};
				return shifted as T;
			}
			if (path.includes('micmap')) return syntheticMicMap() as T;
			if (path.includes('ingest')) {
				return {
					root: SHOW,
					files: [
						{ path: `${SHOW}/Spectacle 8 octbre 2026.mov`, kind: 'edit', duration: 7920, width: 3840, height: 2160, fps: 25, clock: null, proxy: null },
						{ path: `${SHOW}/Music/Ritual Pulse.m4a`, kind: 'music', duration: 89.2, width: null, height: null, fps: null, clock: null, proxy: null }
					]
				} as T;
			}
			throw `lecture simulée non prise en charge : ${path}`;
		},

		async musicAnalysis(file) {
			await delay(200);
			return syntheticMusic(file);
		},

		async proposeShort({ from, to, opts, out }) {
			await delay(400);
			const p = proposeFromSerpent(from, to, opts);
			projects.set(out, p);
			return out;
		},

		async ingest({ dir, projectDir, proxies, sheets }) {
			const stages = ['Analyse des fichiers (ffprobe)'];
			if (proxies) stages.push('Création des proxies 720p');
			if (sheets) stages.push('Planches contact');
			stages.push('Synchronisation des micros');
			return fakeJob('ingest', stages, 4000, () => {
				const name = projectDir.split('/').filter(Boolean).pop() ?? dir;
				// Ré-ingérer un spectacle connu ne crée pas de doublon.
				if (projectDir !== SHOW && !extraShows.some((s) => s.dir === projectDir))
					extraShows.push({ dir: projectDir, name, projects: [], hasIngest: true, transcripts: [], sheets: [], modified: now() });
				return `${projectDir}/.cache/ingest.json`;
			});
		},

		async analyze({ from, to }) {
			return fakeJob('analyze', ['Extraction audio', 'Détection de la parole', 'Transcription', 'Carte des micros'], 3500, () => ({
				transcript: `${SHOW}/.cache/transcript_${Math.round(from)}_${Math.round(to)}.json`,
				suspects: syntheticSuspects()
			}));
		},

		async render({ quality, out }) {
			const target = out ?? `${SHOW}/rendus/${current().export.name ?? 'montage'}_${quality}.mp4`;
			return fakeJob(
				'render',
				quality === 'preview' ? ['Filtergraph', 'Encodage aperçu', 'Vérifications'] : ['Filtergraph', 'Mixage audio', 'Encodage 1080×1920', 'Vérifications'],
				quality === 'preview' ? 3000 : 6000,
				() => ({ out: target, report: report(quality) })
			);
		},

		async snapshot(t) {
			await delay(500);
			return snapshotSvg(current(), t);
		},

		async exportProject(targets) {
			const dests = targets ?? current().export.targets;
			return fakeJob('export', ['Rendu livraison', 'Vérifications', ...dests.map((d) => `Copie vers ${d}`), 'Contrôle md5'], 7000, () => ({
				out: `${SHOW}/rendus/${current().export.name ?? 'montage'}.mp4`,
				report: report('delivery'),
				copied: dests
			}));
		},

		async cancelJob(id) {
			const t = timers.get(id);
			if (t) {
				clearInterval(t);
				timers.delete(id);
				emit({ id, kind: 'cancel', stage: 'Annulé', progress: 0, done: true, error: 'annulé par l’utilisateur', result: null });
			}
		},

		async askClaude(instruction) {
			await delay(900);
			return mockClaude(current(), instruction);
		},

		async onJob(cb) {
			listeners.add(cb);
			return () => listeners.delete(cb);
		},

		// Hors Tauri, les fichiers locaux ne sont pas lisibles : l'aperçu affiche une mire.
		fileSrc(path) {
			return path.startsWith('data:') || path.startsWith('http') ? path : '';
		}
	};
}

/** Proposition simulée : le projet serpent recadré sur l'intervalle demandé. */
function proposeFromSerpent(from: number, to: number, opts: ShortOpts): Project {
	const p = demoProject();
	const dur = Math.max(5, to - from);
	const total = dur + 4;
	p.tracks = [
		{
			id: 'v0',
			kind: 'video',
			items: [
				{
					id: 'c1',
					src: 'soiree',
					in: from,
					out: from + total,
					at: 0,
					crop: opts.crop ?? { cx: 0.5, cy: 0.5, zoom: 1 },
					fx: opts.punch_at != null ? { punch: true, punch_in: [opts.punch_at - from, opts.punch_at - from + 2] } : { punch: true }
				}
			]
		},
		{ id: 'a_voice', kind: 'voice', items: [{ id: 'v1', src: 'soiree', in: from, out: from + total, at: 0 }] },
		{
			id: 'g_text',
			kind: 'graphics',
			items: [
				...(opts.kicker ? [{ type: 'kicker' as const, at: 0, dur: total, text: opts.kicker }] : []),
				...(opts.hook.length ? [{ type: 'hook' as const, at: 0, dur: total, lines: opts.hook }] : []),
				{ type: 'tag', at: 0, dur: 6, text: "AUCUNE DE CES RÉPLIQUES N'A ÉTÉ ÉCRITE" },
				{ type: 'tag', at: 6, dur: dur - 6, text: "IMPRO DESTINY · RIEN N'EST ÉCRIT" },
				{ type: 'cta', at: dur, dur: 4, lines: opts.cta ?? ['VIENS VOIR DESTINY', 'LIEN EN BIO'] },
				{ type: 'progress', at: 0, dur: total }
			]
		},
		{
			id: 'subs',
			kind: 'captions',
			items: (syntheticTranscript as Transcript).segments
				.map((s) => ({ start: s.start + 5260 - from, end: s.end + 5260 - from, text: s.text, emphasis: opts.emphasis }))
				.filter((c) => c.start >= 0 && c.end <= dur)
		}
	];
	p.export = { ...p.export, name: (opts.hook[0] ?? 'short').toLowerCase().replace(/[^a-z0-9]+/g, '_') };
	return p;
}

/** Réponse simulée de « Demander à Claude » : un patch RFC 6902 plausible. */
function mockClaude(p: Project, instruction: string): ClaudeAnswer {
	const gi = p.tracks.findIndex((t) => t.kind === 'graphics');
	const vi = p.tracks.findIndex((t) => t.kind === 'video');
	const q = instruction.toLowerCase();
	if (gi >= 0 && /hook|accroche|titre/.test(q)) {
		const hi = p.tracks[gi].items.findIndex((g) => (g as { type: string }).type === 'hook');
		if (hi >= 0)
			return {
				explanation: "Hook raccourci et plus direct (2 lignes ≤ 20 caractères), conformément à la charte des shorts « scène ».",
				patch: [{ op: 'replace', path: `/tracks/${gi}/items/${hi}/lines`, value: ['UN SERPENT GÉANT', 'SURGIT EN PLEINE SCÈNE'] }]
			};
	}
	if (vi >= 0 && /zoom|serr|recadr|cadr/.test(q)) {
		return {
			explanation: 'Recadrage plus serré sur le premier plan (zoom 1,25) et centre légèrement décalé à droite, là où se trouvent les comédiens.',
			patch: [
				{ op: 'replace', path: `/tracks/${vi}/items/0/crop/zoom`, value: 1.25 },
				{ op: 'replace', path: `/tracks/${vi}/items/0/crop/cx`, value: 0.56 }
			]
		};
	}
	return {
		explanation: 'Ajout d’un flash blanc chaud à l’entrée du second plan pour marquer la coupe vers la réaction du public.',
		patch: vi >= 0 && p.tracks[vi].items.length > 1 ? [{ op: 'add', path: `/tracks/${vi}/items/1/fx/flash`, value: true }] : []
	};
}
