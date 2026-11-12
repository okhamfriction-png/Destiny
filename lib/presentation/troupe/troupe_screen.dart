import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/son/regie_son.dart';
import '../../application/services/assistant_jeu.dart';
import '../../application/services/audio_service.dart';
import '../../application/state/location_details.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../application/state/relation_cheatsheet.dart';
import '../../application/state/troupe_store.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/chronos.dart';
import '../../domain/grammaire/textes.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'debrief_screen.dart';
import 'echauffement_screen.dart';
import 'historique_screen.dart';
import 'preparer_screen.dart';

/// Ce dont le mode Troupe a besoin de l'appli. Tout fonctionne sans réseau.
/// Le tirage de l'accueil (la règle d'or ou la réplique du jour), fait une
/// fois par lancement de l'appli.
final int _tirageAccueil = Random().nextInt(1 << 30);

class ContexteTroupe implements SourcesSon {
  const ContexteTroupe({
    required this.store,
    required this.reglages,
    required this.catalogue,
    required this.audio,
    required this.musique,
    required this.visuels,
    this.relations,
    this.detailsLieux,
    this.ia,
    this.regieSon,
  });

  final TroupeStore store;
  @override
  final ReglagesDestiny reglages;
  final CatalogStore catalogue;
  @override
  final AudioService audio;
  @override
  final MusicController musique;
  final VisualSettings visuels;
  final RelationCheatsheet? relations;
  final LocationDetailsStore? detailsLieux;

  /// L'IA au service du jeu (facultative).
  final AssistantJeu? ia;

  /// La régie son du spectacle : pack audio, réglages et conduite automatique
  /// (facultative : sans elle, la régie garde son comportement d'avant).
  @override
  final RegieSon? regieSon;
}

/// Ouvre l'écran de l'étape où en est la session.
Future<void> ouvrirEtape(BuildContext context, ContexteTroupe ctx, SessionTroupe s,
    {bool remplacer = false}) {
  // Le théâtre se joue toujours en mode adulte : le mode enfant est celui du
  // jeu de rôle. Une ancienne session marquée kids repasse en adulte.
  if (s.kids) {
    s.kids = false;
    ctx.store.enregistrer(s);
  }
  final Widget page = switch (s.etape) {
    EtapeSession.preparation => PreparerScreen(contexte: ctx, session: s),
    // Le jeu porte le spectacle ; la régie s'y ouvre en pop-up (2.2.0). Une
    // ancienne session à la mise en place reprend au jeu.
    EtapeSession.echauffement || EtapeSession.miseEnPlace || EtapeSession.regie =>
      EchauffementScreen(contexte: ctx, session: s),
    EtapeSession.debrief => DebriefScreen(contexte: ctx, session: s),
    EtapeSession.terminee => FicheSession(contexte: ctx, session: s),
  };
  final route = MaterialPageRoute<void>(builder: (_) => page);
  final nav = Navigator.of(context);
  return remplacer ? nav.pushReplacement(route) : nav.push(route);
}

/// Le chrono du spectacle : sa durée et ses trois Destiny.
void appliquerChrono(SessionTroupe s, ChronoSpectacle chrono) {
  s
    ..dureeMinutes = chrono.dureeMinutes
    ..destinyMinutes = [...chrono.destinyMinutes];
}

/// Tire le groupe s'il n'est pas encore choisi, comme le lieu et le danger :
/// on peut le changer, mais rien ne bloque.
void tirerGroupeSiVide(SessionTroupe s, TextesDestiny t, {Random? hasard}) {
  if (s.groupe.trim().isNotEmpty) return;
  final groupes = t.liste('mise_en_place.groupes');
  if (groupes.isEmpty) return;
  s.groupe = groupes[(hasard ?? Random()).nextInt(groupes.length)];
}

/// Va directement à une étape du spectacle (le fil des étapes), la régie
/// comprise. Ce qui n'a pas encore été fait est rempli d'office : le chrono
/// des réglages en quittant la préparation.
Future<void> allerAEtape(BuildContext context, ContexteTroupe ctx, SessionTroupe s, EtapeSession etape) async {
  if (etape == s.etape) return;
  if (s.etape == EtapeSession.preparation) appliquerChrono(s, ctx.reglages.chrono);
  s.etape = etape;
  await ctx.store.enregistrer(s);
  if (context.mounted) ouvrirEtape(context, ctx, s, remplacer: true);
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
    // Tirées au hasard à chaque ouverture de l'appli (et pas à chaque
    // reconstruction de l'écran) : une autre réplique à chaque chargement.
    final jour = _tirageAccueil;
    final regle = g.reglesDOr[jour % g.reglesDOr.length];
    final animal = g.animaux[(jour ~/ 2) % g.animaux.length];
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
                  // La règle d'or ou la réplique du jour, au hasard.
                  if (jour.isEven)
                    CadreLisere(
                      couleur: c.or,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Surtitre(t.t('troupe.regle_du_jour')),
                        const SizedBox(height: 6),
                        Text(regle.titre,
                            style: TextStyle(
                                fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 17.5, color: c.titre)),
                        const SizedBox(height: 4),
                        Text(regle.texte,
                            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 15, height: 1.45, color: c.texte)),
                      ]),
                    )
                  else
                    CadreLisere(
                      couleur: couleurAnimal,
                      child: Row(children: [
                        MedaillonAnimal(animal, taille: 56, source: contexte.visuels.source),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _Surtitre(t.t('troupe.replique_du_jour')),
                            const SizedBox(height: 8),
                            EncartReplique(animal.replique, couleur: couleurAnimal),
                          ]),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 20),
                  if (enCours != null) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => ouvrirEtape(context, contexte, enCours),
                      // La partie en cours, quelle que soit l'étape : spectacle ou répétition.
                      label: Text(t.t('troupe.reprendre_type.${enCours.type.name}')),
                    ),
                    const SizedBox(height: 12),
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
                  const SizedBox(height: 24),
                  ElementListe(
                    titre: t.t('troupe.entrees.jouer'),
                    devant: const Icon(Icons.auto_stories_rounded, color: DestinyCouleurs.corail),
                    onTap: versJouer,
                  ),
                  ElementListe(
                    titre: t.t('troupe.entrees.bibliotheque'),
                    devant: Icon(Icons.menu_book_rounded, color: c.or),
                    onTap: versBibliotheque,
                  ),
                  ElementListe(
                    titre: t.t('troupe.entrees.exercice'),
                    devant: const Icon(Icons.self_improvement_rounded, color: DestinyCouleurs.turquoise),
                    onTap: versExercices,
                  ),
                  ElementListe(
                    titre: t.t('troupe.entrees.historique'),
                    devant: const Icon(Icons.history_rounded, color: DestinyCouleurs.ciel),
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
    if (context.mounted) await ouvrirEtape(context, contexte, s);
  }
}

/// Le surtitre d'un encart (« La règle du jour », « La réplique du jour »).
class _Surtitre extends StatelessWidget {
  const _Surtitre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Text(
        texte.toUpperCase(),
        style: TextStyle(
          fontFamily: kPoliceTexte,
          fontSize: 12.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: context.destiny.texteSecondaire,
        ),
      );
}
