import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'bibliotheque_screen.dart';
import 'fiches.dart';

/// Les grands méchants de saison, avec la règle du reflet et un filtre kids.
class MechantsScreen extends StatefulWidget {
  const MechantsScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  State<MechantsScreen> createState() => _MechantsScreenState();
}

class _MechantsScreenState extends State<MechantsScreen> {
  bool _kids = false;
  String? _archetype;

  /// Les grands méchants, ou ceux des univers.
  bool _univers = false;

  bool _garde(Mechant m) => (!_kids || m.kids) && (_archetype == null || m.archetypeId == _archetype);

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final mechants = [for (final m in g.mechants) if (_garde(m)) m];
    final cat = widget.contexte.univers;
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.mechants.titre'),
      entete: Column(children: [
        if (cat.mechants.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, children: [
              ChoiceChip(
                label: Text(t.t('bibliotheque.serie.grands_mechants')),
                selected: !_univers,
                onSelected: (_) => setState(() => _univers = false),
              ),
              ChoiceChip(
                label: Text(t.t('bibliotheque.serie.mechants_univers')),
                selected: _univers,
                onSelected: (_) => setState(() => _univers = true),
              ),
            ]),
          ),
        FiltresPuces<String?>(
          valeurs: [null, ...g.archetypes.map((a) => a.id)],
          libelle: (id) => id == null ? t.t('bibliotheque.tous') : g.archetype(id)!.nom,
          choisi: _archetype,
          onChoix: (id) => setState(() => _archetype = id),
          couleur: (id) => id == null ? null : c.famille(g.archetype(id)!.famille),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(t.t('bibliotheque.kids_seulement')),
              const SizedBox(width: 6),
              const SigleKids(petit: true),
            ]),
            selected: _kids,
            onSelected: (v) => setState(() => _kids = v),
          ),
        ),
      ]),
      enfants: [
        if (_archetype == null && !_kids)
          SectionDestiny(titre: t.t('bibliotheque.serie.regles_mechant'), espace: 0, enfants: [
            for (final (i, r) in g.serie.reglesDuMechant.indexed) Puce(r, numero: i + 1),
          ]),
        const SizedBox(height: 10),
        if (!_univers)
          for (final m in mechants) CarteMechant(m, kids: _kids)
        else ...[
          Paragraphe(t.t('bibliotheque.serie.mechants_univers_aide'), italique: true),
          for (final u in cat.univers)
            if (cat.mechantsDe(u.id).any((mu) => _garde(mu.mechant)))
              SectionDestiny(titre: u.nom, enfants: [
                for (final mu in cat.mechantsDe(u.id))
                  if (_garde(mu.mechant)) CarteMechant(mu.mechant, kids: _kids, presages: mu.presages),
              ]),
        ],
      ],
    );
  }
}

/// La carte d'un méchant : nom en Cinzel, son animal, le sigle KIDS, son
/// inspiration, sa posture, son histoire, ce qu'il veut, ce dont il a besoin,
/// sa faille, sa cible, son offre au traître, et ses deux sbires en petit.
class CarteMechant extends StatelessWidget {
  const CarteMechant(this.m, {super.key, this.kids = false, this.presages = const []});

  final Mechant m;

  /// Ses quatre présages, quand ils sont écrits (méchants d'univers).
  final List<String> presages;

  /// Montrer les textes kids.
  final bool kids;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String f(String k) => t.t('bibliotheque.fiche.$k');
    final arch = g.archetype(m.archetypeId);
    final couleur = arch == null ? c.or : c.famille(arch.famille);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.carte,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: couleur, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: c.sombre ? Color.lerp(c.nuit, couleur, 0.2) : c.familleClaire(arch?.famille ?? FamilleId.tient),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text(m.nom.toUpperCase(),
                    style: TextStyle(
                        fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 18, color: c.titre)),
              ),
              if (m.kids) const SigleKids(petit: true),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: c.or),
                ),
                child: Text(m.animal,
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, fontSize: 13.5, color: c.texte)),
              ),
              const SizedBox(width: 8),
              if (arch != null) PuceFamille(arch.famille, compacte: true),
              const Spacer(),
              if (arch != null)
                Text(arch.nom,
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: couleur)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LigneInfo(f('inspiration'), m.inspiration, italique: true),
            LigneInfo(f('posture'), m.posture),
            LigneInfo(kids ? f('version_kids') : f('histoire'), m.histoirePour(kids: kids)),
            LigneInfo(f('il_veut'), m.veut),
            LigneInfo(f('il_a_besoin'), m.besoin),
            LigneInfo(kids ? f('faille_kids') : f('faille'), m.faillePour(kids: kids)),
            LigneInfo(f('cible'), m.cible),
            LigneInfo(f('traitre'), m.offreAuTraitre),
            if (!kids && m.kids) LigneInfo(f('version_kids'), m.versionKids, italique: true),
            if (presages.isNotEmpty) ...[
              Text(t.t('bibliotheque.serie.presages'),
                  style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 12.5, color: c.texteSecondaire)),
              const SizedBox(height: 4),
              for (final (i, p) in presages.indexed) Puce(p, numero: i + 1),
              const SizedBox(height: 8),
            ],
            Text(f('sbires'),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 12.5, color: c.texteSecondaire)),
            const SizedBox(height: 6),
            for (final s in m.sbires) CarteSbire(s),
          ]),
        ),
      ]),
    );
  }
}

/// La fiche d'un méchant seul.
class FicheMechant extends StatelessWidget {
  const FicheMechant({super.key, required this.mechant});

  final Mechant mechant;

  @override
  Widget build(BuildContext context) =>
      PageDestiny(titre: mechant.nom, enfants: [CarteMechant(mechant)]);
}
