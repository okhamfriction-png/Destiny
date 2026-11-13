import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../application/services/export_pdf.dart';
import '../../domain/grammaire/modeles.dart';
import '../destiny/cartes.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'bibliotheque_screen.dart';
import 'fiches.dart';
import 'mechants_screen.dart';
import 'oeuvres_screen.dart';

/// Les 12 archétypes, rangés par famille, avec un filtre.
class ArchetypesScreen extends StatefulWidget {
  const ArchetypesScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  State<ArchetypesScreen> createState() => _ArchetypesScreenState();
}

class _ArchetypesScreenState extends State<ArchetypesScreen> {
  FamilleId? _famille;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final familles = _famille == null ? FamilleId.values : [_famille!];
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.archetypes.titre'),
      actions: [
        IconButton(
          tooltip: t.t('bibliotheque.imprimer.titre'),
          icon: const Icon(Icons.print_outlined),
          onPressed: () => imprimerCartes(context),
        ),
      ],
      entete: FiltresPuces<FamilleId?>(
        valeurs: const [null, ...FamilleId.values],
        libelle: (f) => f == null ? t.t('bibliotheque.toutes') : g.famille(f).nom,
        choisi: _famille,
        onChoix: (f) => setState(() => _famille = f),
        couleur: (f) => f == null ? null : c.famille(f),
      ),
      enfants: [
        // Le principe des cartes, en tête de page.
        EncartReplique(t.t('bibliotheque.archetypes_principe'), couleur: c.or),
        const SizedBox(height: 8),
        for (final f in familles) ...[
          SectionDestiny(titre: g.famille(f).nom, enfants: [
            Paragraphe(g.famille(f).idee, italique: true),
            Paragraphe(g.famille(f).pourquoi),
          ]),
          for (final a in g.archetypesDe(f))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FicheArchetype(archetypeId: a.id, contexte: widget.contexte))),
                  child: CarteArchetype.archetype(a.id, source: widget.contexte.visuels.source),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Propose d'imprimer les cartes d'archétypes (un recto par archétype ou
/// par animal, verso Destiny), puis partage le PDF.
Future<void> imprimerCartes(BuildContext context) async {
  final g = context.grammaire;
  final t = context.textes;
  final messager = ScaffoldMessenger.of(context);
  String k(String x) => t.t('bibliotheque.imprimer.$x');
  final parAnimal = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(k('titre'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Paragraphe(k('aide')),
          ElementListe(
            titre: k('par_archetype'),
            sousTitre: k('par_archetype_aide'),
            devant: const Icon(Icons.style_outlined),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ElementListe(
            titre: k('par_animal'),
            sousTitre: k('par_animal_aide'),
            devant: const Icon(Icons.pets_outlined),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ]),
      ),
    ),
  );
  if (parAnimal == null) return;
  messager.showSnackBar(SnackBar(content: Text(k('en_cours'))));
  try {
    final polices = await PolicesPdf.chargerDepuisAssets();
    final octets = await cartesArchetypesPdf(g: g, t: t, polices: polices, parAnimal: parAnimal);
    await Printing.sharePdf(
        bytes: octets, filename: parAnimal ? 'destiny-cartes-animaux.pdf' : 'destiny-cartes-archetypes.pdf');
  } catch (_) {
    messager.showSnackBar(SnackBar(content: Text(k('echec'))));
  }
}

/// La fiche détaillée d'un archétype.
class FicheArchetype extends StatelessWidget {
  const FicheArchetype({super.key, required this.archetypeId, required this.contexte});

  final String archetypeId;
  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final a = g.archetype(archetypeId)!;
    final couleur = c.famille(a.famille);
    String f(String k) => t.t('bibliotheque.fiche.$k');
    final direction = g.directionDe(a.id);
    final modeles = g.modelesDe(a.id);
    final reflets = g.mechantsReflets(a.id);
    return PageDestiny(
      titre: a.nom,
      enfants: [
        Center(child: CarteArchetype.archetype(a.id, source: contexte.visuels.source)),
        SectionDestiny(titre: f('animaux'), enfants: [
          for (final animal in g.animauxDe(a.id)) ...[
            Row(children: [
              MedaillonAnimal(animal, taille: 52, source: contexte.visuels.source),
              const SizedBox(width: 12),
              Expanded(
                child: Text(animal.nom,
                    style: TextStyle(
                        fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 18, color: c.texte)),
              ),
              PastilleStatut(animal.statutDepart),
            ]),
            const SizedBox(height: 8),
            LigneInfo(f('posture'), animal.posture),
            LigneInfo(f('port'), animal.port, italique: true),
            LigneInfo(f('temperament'), animal.temperament),
            EncartReplique(animal.replique, couleur: couleur),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text('${f('source')} ${animal.sourceReplique}',
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
            ),
            LigneInfo(f('corps'), ''),
            for (final p in PalierId.values)
              Puce('${g.palier(p).nom} : ${animal.corpsA(p)}'),
            const SizedBox(height: 10),
          ],
        ]),
        if (direction != null)
          SectionDestiny(titre: f('exemple'), enfants: [CarteDirection(direction)]),
        if (modeles.isNotEmpty)
          SectionDestiny(titre: f('modeles'), enfants: [
            for (final m in modeles)
              ElementListe(
                titre: m.personnage.nom,
                sousTitre: '${m.oeuvre.titre} · ${m.personnage.animalNom}\n${m.personnage.besoin}',
                couleur: couleur,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FicheOeuvre(oeuvre: m.oeuvre, contexte: contexte))),
              ),
          ]),
        if (reflets.isNotEmpty)
          SectionDestiny(titre: f('reflets'), enfants: [
            for (final m in reflets)
              ElementListe(
                titre: m.nom,
                sousTitre: m.veut,
                couleur: couleur,
                apres: m.kids ? const SigleKids(petit: true) : null,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => FicheMechant(mechant: m))),
              ),
          ]),
      ],
    );
  }
}

/// Les 24 animaux.
class AnimauxScreen extends StatelessWidget {
  const AnimauxScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.animaux.titre'),
      enfants: [
        for (final a in g.animaux)
          ElementListe(
            titre: a.nom,
            sousTitre: '${g.archetype(a.archetypeId)?.nom ?? ''} · ${a.posture}\n« ${a.replique} »',
            couleur: c.famille(g.archetype(a.archetypeId)!.famille),
            devant: MedaillonAnimal(a, taille: 44, source: contexte.visuels.source),
            pied: ExempleVouloir(a.exempleVouloir, taille: 13.5),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => FicheAnimal(animalId: a.id, contexte: contexte))),
          ),
      ],
    );
  }
}

/// La fiche d'un animal : sa carte, son corps à chaque palier, sa réplique et
/// sa source.
class FicheAnimal extends StatelessWidget {
  const FicheAnimal({super.key, required this.animalId, required this.contexte, this.kids = false});

  final String animalId;
  final ContexteBibliotheque contexte;

  /// Ouverte depuis une séance kids : l'exemple de vouloir des enfants
  /// (jamais l'exemple adulte).
  final bool kids;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final a = g.animal(animalId)!;
    final arch = g.archetype(a.archetypeId)!;
    final couleur = c.famille(arch.famille);
    String f(String k) => t.t('bibliotheque.fiche.$k');
    return PageDestiny(
      titre: a.nom,
      enfants: [
        Center(child: CarteArchetype.animal(a.id, source: contexte.visuels.source)),
        SectionDestiny(titre: f('archetype'), enfants: [
          Align(
            alignment: Alignment.centerLeft,
            child: PuceArchetype(arch.id,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FicheArchetype(archetypeId: arch.id, contexte: contexte)))),
          ),
          const SizedBox(height: 8),
          LigneInfo(f('temperament'), a.temperament),
          LigneInfo(f('posture'), a.posture),
        ]),
        SectionDestiny(titre: f('replique'), enfants: [
          EncartReplique(a.replique, couleur: couleur),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${f('source')} ${a.sourceReplique}',
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
          ),
          if (a.exempleVouloirPour(kids: kids).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ExempleVouloir(a.exempleVouloirPour(kids: kids)),
          ],
          if (a.repliqueKids.isNotEmpty && a.repliqueKids != a.replique) ...[
            const SizedBox(height: 10),
            Row(children: [
              Text(f('replique_kids'),
                  style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texteSecondaire)),
              const SizedBox(width: 8),
              const SigleKids(petit: true),
            ]),
            const SizedBox(height: 4),
            EncartReplique(a.repliqueKids, couleur: couleur),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${f('source')} ${a.sourceRepliqueKids}',
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
            ),
          ],
        ]),
        SectionDestiny(titre: f('corps'), enfants: [
          FrisePaliers(textes: [for (final p in PalierId.values) a.corpsA(p)]),
        ]),
        SectionDestiny(titre: f('montee'), enfants: [
          FrisePaliers(textes: [for (final p in PalierId.values) arch.monteeA(p)], compacte: true),
        ]),
      ],
    );
  }
}
