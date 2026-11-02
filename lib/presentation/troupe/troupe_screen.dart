import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/location_details.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../application/state/relation_cheatsheet.dart';
import '../../application/state/troupe_store.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'debrief_screen.dart';
import 'echauffement_screen.dart';
import 'historique_screen.dart';
import 'mise_en_place_screen.dart';
import 'preparer_screen.dart';
import 'regie_screen.dart';

/// Ce dont le mode Troupe a besoin de l'appli. Tout fonctionne sans réseau.
class ContexteTroupe {
  const ContexteTroupe({
    required this.store,
    required this.reglages,
    required this.catalogue,
    required this.audio,
    required this.musique,
    required this.visuels,
    this.relations,
    this.detailsLieux,
  });

  final TroupeStore store;
  final ReglagesDestiny reglages;
  final CatalogStore catalogue;
  final AudioService audio;
  final MusicController musique;
  final VisualSettings visuels;
  final RelationCheatsheet? relations;
  final LocationDetailsStore? detailsLieux;
}

/// Ouvre l'écran de l'étape où en est la session.
Future<void> ouvrirEtape(BuildContext context, ContexteTroupe ctx, SessionTroupe s,
    {bool remplacer = false}) {
  final Widget page = switch (s.etape) {
    EtapeSession.preparation => PreparerScreen(contexte: ctx, session: s),
    EtapeSession.echauffement => EchauffementScreen(contexte: ctx, session: s),
    EtapeSession.miseEnPlace => MiseEnPlaceScreen(contexte: ctx, session: s),
    EtapeSession.regie => RegieScreen(contexte: ctx, session: s),
    EtapeSession.debrief => DebriefScreen(contexte: ctx, session: s),
    EtapeSession.terminee => FicheSession(contexte: ctx, session: s),
  };
  final route = MaterialPageRoute<void>(builder: (_) => page);
  final nav = Navigator.of(context);
  return remplacer ? nav.pushReplacement(route) : nav.push(route);
}

/// L'onglet Troupe : l'accueil, la règle ou la réplique du jour, et le
/// spectacle en cours.
class TroupeScreen extends StatelessWidget {
  const TroupeScreen({
    super.key,
    required this.contexte,
    required this.versJouer,
    required this.versExercices,
    required this.versBibliotheque,
  });

  final ContexteTroupe contexte;
  final VoidCallback versJouer;
  final VoidCallback versExercices;
  final VoidCallback versBibliotheque;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final jour = DateTime.now().difference(DateTime(2026)).inDays;
    final regle = g.reglesDOr[jour % g.reglesDOr.length];
    final animal = g.animaux[jour % g.animaux.length];
    final couleurAnimal = c.famille(g.archetype(animal.archetypeId)!.famille);

    return ListenableBuilder(
      listenable: contexte.store,
      builder: (context, _) {
        final enCours = contexte.store.enCours;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  BandeauAffiche(titre: g.nom.toUpperCase(), surtitre: t.t('troupe.titre'), sousTitre: g.promesse),
                  const SizedBox(height: 14),
                  // La règle d'or ou la réplique du jour, en alternance.
                  if (jour.isEven)
                    CadreLisere(
                      couleur: c.or,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.t('troupe.regle_du_jour').toUpperCase(),
                            style: TextStyle(
                                fontFamily: kPoliceTexte, fontSize: 11, letterSpacing: 1.6, color: c.texteSecondaire)),
                        const SizedBox(height: 4),
                        Text(regle.titre,
                            style: TextStyle(
                                fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 17, color: c.titre)),
                        Text(regle.texte, style: TextStyle(fontFamily: kPoliceTexte, color: c.texte)),
                      ]),
                    )
                  else
                    CadreLisere(
                      couleur: couleurAnimal,
                      child: Row(children: [
                        MedaillonAnimal(animal, taille: 48, source: contexte.visuels.source),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.t('troupe.replique_du_jour').toUpperCase(),
                                style: TextStyle(
                                    fontFamily: kPoliceTexte,
                                    fontSize: 11,
                                    letterSpacing: 1.6,
                                    color: c.texteSecondaire)),
                            const SizedBox(height: 4),
                            EncartReplique(animal.replique, couleur: couleurAnimal),
                          ]),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  if (enCours != null) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => ouvrirEtape(context, contexte, enCours),
                      label: Text(t.t('troupe.reprendre', {'etape': t.t('troupe.etapes.${enCours.etape.name}')})),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _nouveau(context),
                      label: Text(t.t('troupe.preparer')),
                    ),
                  ] else
                    FilledButton.icon(
                      icon: const Icon(Icons.theater_comedy_outlined),
                      onPressed: () => _nouveau(context),
                      label: Text(t.t('troupe.preparer')),
                    ),
                  const SizedBox(height: 18),
                  ElementListe(
                    titre: t.t('troupe.entrees.jouer'),
                    devant: Icon(Icons.auto_stories_outlined, color: c.titre),
                    onTap: versJouer,
                  ),
                  ElementListe(
                    titre: t.t('troupe.entrees.bibliotheque'),
                    devant: Icon(Icons.menu_book_rounded, color: c.titre),
                    onTap: versBibliotheque,
                  ),
                  ElementListe(
                    titre: t.t('troupe.entrees.exercice'),
                    devant: Icon(Icons.self_improvement_rounded, color: c.titre),
                    onTap: versExercices,
                  ),
                  ElementListe(
                    titre: t.t('troupe.entrees.historique'),
                    devant: Icon(Icons.history_rounded, color: c.titre),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => HistoriqueScreen(contexte: contexte))),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _nouveau(BuildContext context) async {
    final s = await contexte.store.nouvelle();
    s.kids = contexte.reglages.kidsParDefaut;
    if (context.mounted) await ouvrirEtape(context, contexte, s);
  }
}
