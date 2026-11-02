import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'bibliotheque_screen.dart';
import 'fiches.dart';

/// Les œuvres de référence et les scènes, filtrables par catégorie et par
/// archétype.
class OeuvresScreen extends StatefulWidget {
  const OeuvresScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  State<OeuvresScreen> createState() => _OeuvresScreenState();
}

class _OeuvresScreenState extends State<OeuvresScreen> {
  /// null = toutes ; 'scenes' = les scènes de Tarantino.
  String? _categorie;
  String? _archetype;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String cat(String k) => t.t('bibliotheque.oeuvres.categories.$k');
    final oeuvres = [
      for (final o in g.oeuvres)
        if ((_categorie == null || _categorie == o.categorie.name) &&
            (_archetype == null || o.personnages.any((p) => p.archetypeId == _archetype)))
          o,
    ];
    final scenes = _archetype == null && (_categorie == null || _categorie == 'scenes');
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.oeuvres.titre'),
      entete: Column(children: [
        FiltresPuces<String?>(
          valeurs: [null, ...CategorieOeuvre.values.map((c) => c.name), 'scenes'],
          libelle: (k) => k == null ? t.t('bibliotheque.toutes') : cat(k),
          choisi: _categorie,
          onChoix: (k) => setState(() => _categorie = k),
        ),
        const SizedBox(height: 6),
        FiltresPuces<String?>(
          valeurs: [null, ...g.archetypes.map((a) => a.id)],
          libelle: (id) => id == null ? t.t('bibliotheque.tous') : g.archetype(id)!.nom,
          choisi: _archetype,
          onChoix: (id) => setState(() => _archetype = id),
          couleur: (id) => id == null ? null : context.destiny.famille(g.archetype(id)!.famille),
        ),
      ]),
      enfants: [
        Paragraphe(t.t('bibliotheque.oeuvres.avertissement'), italique: true),
        if (_categorie != 'scenes')
          for (final o in oeuvres)
            ElementListe(
              titre: o.titre,
              sousTitre: '${o.fiche}\n${o.pitch}',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => FicheOeuvre(oeuvre: o, contexte: widget.contexte))),
            ),
        if (scenes) ...[
          SectionDestiny(titre: cat('scenes'), enfants: [
            for (final s in g.scenes)
              ElementListe(
                titre: s.titre,
                sousTitre: '${s.film}\n${s.lieu}',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FicheScene(scene: s))),
              ),
          ]),
        ],
      ],
    );
  }
}

class FicheOeuvre extends StatelessWidget {
  const FicheOeuvre({super.key, required this.oeuvre, required this.contexte});

  final Oeuvre oeuvre;
  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final g = context.grammaire;
    String f(String k) => t.t('bibliotheque.fiche.$k');
    return PageDestiny(
      titre: oeuvre.titre,
      enfants: [
        Paragraphe(oeuvre.fiche, italique: true),
        Paragraphe(oeuvre.pitch),
        Paragraphe(t.t('bibliotheque.oeuvres.avertissement'), italique: true),
        LigneInfo(f('lieu'), oeuvre.lieu),
        LigneInfo(f('groupe'), oeuvre.groupe),
        LigneInfo(f('danger'), oeuvre.danger),
        SectionDestiny(titre: f('paliers'), enfants: [FrisePaliers(textes: oeuvre.paliers)]),
        SectionDestiny(titre: f('personnages'), enfants: [
          for (final p in oeuvre.personnages)
            CadreLisere(
              couleur: c.famille(g.archetype(p.archetypeId)?.famille ?? FamilleId.tient),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(p.nom,
                        style: TextStyle(
                            fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 16, color: c.texte)),
                  ),
                  Flexible(child: PuceArchetype(p.archetypeId, suffixe: p.animalNom)),
                ]),
                const SizedBox(height: 8),
                LigneInfo(f('veut'), p.veut),
                LigneInfo(f('besoin'), p.besoin),
                LigneInfo(f('face_au_danger'), p.faceAuDanger),
                LigneInfo(f('choix'), p.choix),
              ]),
            ),
        ]),
        SectionDestiny(titre: f('lecon'), enfants: [Paragraphe(oeuvre.lecon, gras: true)]),
      ],
    );
  }
}

class FicheScene extends StatelessWidget {
  const FicheScene({super.key, required this.scene});

  final SceneReference scene;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String f(String k) => t.t('bibliotheque.fiche.$k');
    return PageDestiny(
      titre: scene.titre,
      enfants: [
        Paragraphe(scene.film, italique: true),
        LigneInfo(f('lieu'), scene.lieu),
        LigneInfo(f('danger'), scene.danger),
        SectionDestiny(titre: f('paliers'), enfants: [FrisePaliers(textes: scene.paliers)]),
        SectionDestiny(titre: f('lecon'), enfants: [Paragraphe(scene.lecon, gras: true)]),
      ],
    );
  }
}
