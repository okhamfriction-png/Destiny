// Pose d'un morceau de rush dans le montage (boutons, F9/F10, glisser-déposer).

import { placeClip, type PlaceMode, type SourceClip } from '$lib/edit';
import { editor } from '$lib/editor.svelte';
import { clock } from '$lib/format';
import { studio } from '$lib/state.svelte';

const VERB: Record<PlaceMode, string> = { overwrite: 'Écraser', insert: 'Insérer' };

/** Pose `clip` à `at` sur V1/A1, sélectionne le nouveau plan et place la tête de lecture
 * juste après, comme DaVinci après une édition. */
export function place(clip: SourceClip, at: number, mode: PlaceMode): void {
	const p = studio.project;
	if (!p) return;
	if (editor.locked.video || editor.locked.voice) {
		studio.info('Pistes V1 ou A1 verrouillées : déverrouillez-les pour ajouter un rush.');
		return;
	}
	const { project, ref } = placeClip(p, clip, at, mode);
	studio.edit(project, `${VERB[mode]} ${clip.source.id} ${clock(clip.in)} → ${clock(clip.out)}`);
	editor.selection = ref;
	editor.seek(Math.max(0, at) + clip.out - clip.in);
}
