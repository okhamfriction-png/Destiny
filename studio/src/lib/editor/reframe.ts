// Recadrage automatique sur les comédiens (détection Vision côté Rust), annulable.

import { api } from '$lib/api';
import { studio } from '$lib/state.svelte';

let busy = false;

/** Recadre les plans `ids` (ou tous) et enregistre le résultat comme une édition. */
export async function reframeClips(ids: string[] | null): Promise<void> {
	if (busy || !studio.project) return;
	busy = true;
	studio.info(ids ? `Détection des comédiens dans ${ids.join(', ')}…` : 'Détection des comédiens dans tous les plans…');
	try {
		await studio.flush();
		const { project, clips } = await api.reframe(ids);
		const done = clips.filter((c) => c.crop);
		if (!done.length) {
			studio.info(clips.length ? 'Personne détecté : cadrage inchangé.' : 'Recadrage indisponible ici.');
			return;
		}
		studio.edit(project, ids?.length === 1 ? `Recadrer ${ids[0]} sur les comédiens` : 'Recadrer sur les comédiens');
		const most = Math.max(...done.map((c) => c.people));
		studio.info(`${done.length} plan${done.length > 1 ? 's' : ''} recadré${done.length > 1 ? 's' : ''} (jusqu'à ${most} comédien${most > 1 ? 's' : ''}).`);
	} catch (e) {
		studio.error(e);
	} finally {
		busy = false;
	}
}
