import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/grammaire/distribution.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'troupe_screen.dart';

/// Préparer : le nombre de joueurs, leurs prénoms, la distribution des
/// archétypes (concertée, tirée ou d'après un exemple) et le choix des animaux.
class PreparerScreen extends StatefulWidget {
  const PreparerScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<PreparerScreen> createState() => _PreparerScreenState();
}

class _PreparerScreenState extends State<PreparerScreen> {
  final Random _hasard = Random();
  late String _mode = widget.contexte.reglages.modeDistribution;
  int _exemple = 0;
  final List<TextEditingController> _prenoms = [];

  SessionTroupe get s => widget.session;

  @override
  void initState() {
    super.initState();
    if (s.personnages.isEmpty) {
      final n = widget.contexte.reglages.joueursParDefaut;
      s.personnages = [for (var i = 0; i < n; i++) PersonnageTroupe(joueur: '', archetypeId: '')];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mode != 'concerte') _distribuer();
      });
    }
    _synchroniserChamps();
  }

  void _synchroniserChamps() {
    while (_prenoms.length < s.personnages.length) {
      _prenoms.add(TextEditingController(text: s.personnages[_prenoms.length].joueur));
    }
    while (_prenoms.length > s.personnages.length) {
      _prenoms.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _prenoms) {
      c.dispose();
    }
    super.dispose();
  }

  Grammaire get g => context.grammaire;

  void _changerNombre(int n) {
    setState(() {
      while (s.personnages.length < n) {
        s.personnages.add(PersonnageTroupe(joueur: '', archetypeId: ''));
      }
      while (s.personnages.length > n) {
        s.personnages.removeLast();
      }
      _synchroniserChamps();
    });
    if (_mode != 'concerte') _distribuer();
    _sauver();
  }

  void _attribuer(List<String> ids) {
    setState(() {
      for (var i = 0; i < s.personnages.length && i < ids.length; i++) {
        final p = s.personnages[i];
        if (p.archetypeId != ids[i]) {
          p.archetypeId = ids[i];
          p.animalId = '';
        }
      }
    });
    _sauver();
  }

  void _distribuer() {
    final n = s.personnages.length;
    if (_mode == 'exemple') {
      final exemples = exemplesDistribution(g, n);
      _attribuer(exemples[_exemple % exemples.length]..shuffle(_hasard));
    } else {
      _attribuer(tirerDistribution(g, n,
          hasard: _hasard, leaderObligatoire: widget.contexte.reglages.leaderObligatoire));
    }
  }

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  Future<void> _choisirArchetype(int i) async {
    final c = context.destiny;
    final choisi = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(context.textes.t('preparer.choisir_archetype'),
                style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
            for (final f in FamilleId.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: PuceFamille(f),
              ),
              for (final a in g.archetypesDe(f))
                ElementListe(
                  titre: a.nom,
                  sousTitre: a.ceQuIlFait,
                  couleur: c.famille(f),
                  onTap: () => Navigator.of(ctx).pop(a.id),
                ),
            ],
          ],
        ),
      ),
    );
    if (choisi != null) {
      setState(() {
        s.personnages[i].archetypeId = choisi;
        s.personnages[i].animalId = '';
      });
      _sauver();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final ids = [for (final p in s.personnages) p.archetypeId];
    final verdict = validerDistribution(g, ids,
        leaderObligatoire: widget.contexte.reglages.leaderObligatoire);
    final animauxChoisis = s.personnages.every((p) => p.animalId.isNotEmpty);
    String p(String k) => t.t('preparer.$k');

    return PageDestiny(
      titre: p('titre'),
      enfants: [
        SegmentedButton<TypeSession>(
          segments: [
            for (final ty in TypeSession.values)
              ButtonSegment(value: ty, label: Text(t.t('troupe.types.${ty.name}'))),
          ],
          selected: {s.type},
          onSelectionChanged: (v) {
            setState(() => s.type = v.first);
            _sauver();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(p('kids')), const SigleKids(petit: true)]),
          value: s.kids,
          onChanged: (v) {
            setState(() => s.kids = v);
            _sauver();
          },
        ),
        SectionDestiny(titre: p('joueurs'), enfants: [
          SegmentedButton<int>(
            segments: [for (final n in [4, 5, 6]) ButtonSegment(value: n, label: Text('$n'))],
            selected: {s.personnages.length},
            onSelectionChanged: (v) => _changerNombre(v.first),
          ),
        ]),
        SectionDestiny(titre: p('distribution'), enfants: [
          SegmentedButton<String>(
            segments: [
              for (final m in ['concerte', 'tirage', 'exemple'])
                ButtonSegment(value: m, label: Text(t.t('distribution.modes.$m'))),
            ],
            selected: {_mode},
            onSelectionChanged: (v) {
              setState(() => _mode = v.first);
              if (_mode != 'concerte') _distribuer();
            },
          ),
          const SizedBox(height: 8),
          if (_mode == 'tirage')
            OutlinedButton.icon(
              onPressed: _distribuer,
              icon: const Icon(Icons.shuffle_rounded),
              label: Text(p('tirer')),
            ),
          if (_mode == 'exemple')
            OutlinedButton.icon(
              onPressed: () {
                _exemple++;
                _distribuer();
              },
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(p('autre_exemple')),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < s.personnages.length; i++) _ligneJoueur(i),
          _Verdict(
            ok: verdict.valide,
            texte: verdict.raison(g, t),
            correction: verdict.phraseCorrection(g, t),
            onCorriger: verdict.correction == null ? null : () => _attribuer(verdict.correction!.appliquer(ids)),
          ),
          if (verdict.valide && !animauxChoisis)
            Paragraphe(p('animaux_manquants'), italique: true),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: verdict.valide && animauxChoisis
              ? () async {
                  s.etape = EtapeSession.echauffement;
                  await _sauver();
                  if (context.mounted) ouvrirEtape(context, widget.contexte, s, remplacer: true);
                }
              : null,
          icon: const Icon(Icons.self_improvement_rounded),
          label: Text(p('vers_echauffement')),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _abandonner(context),
          child: Text(t.t('troupe.abandonner'), style: TextStyle(color: c.texteSecondaire)),
        ),
      ],
    );
  }

  Widget _ligneJoueur(int i) {
    final t = context.textes;
    final c = context.destiny;
    final pers = s.personnages[i];
    final arch = g.archetype(pers.archetypeId);
    final couleur = arch == null ? c.filet : c.famille(arch.famille);
    return CadreLisere(
      couleur: couleur,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _prenoms[i],
              decoration: InputDecoration(labelText: '${t.t('preparer.prenom')} ${i + 1}', isDense: true),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) {
                pers.joueur = v.trim();
                _sauver();
              },
            ),
          ),
          const SizedBox(width: 10),
          ActionChip(
            avatar: arch == null ? const Icon(Icons.add, size: 16) : null,
            label: Text(arch?.nom ?? t.t('preparer.choisir_archetype')),
            side: BorderSide(color: couleur),
            onPressed: () => _choisirArchetype(i),
          ),
        ]),
        if (arch != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            for (final a in g.animauxDe(arch.id))
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => pers.animalId = a.id);
                    _sauver();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pers.animalId == a.id ? couleur : c.filet,
                        width: pers.animalId == a.id ? 2 : 1,
                      ),
                      color: pers.animalId == a.id ? couleur.withValues(alpha: 0.12) : null,
                    ),
                    child: Row(children: [
                      MedaillonAnimal(a, taille: 36, source: widget.contexte.visuels.source),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(a.nom,
                            style: TextStyle(
                                fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
                      ),
                      if (pers.animalId == a.id) Icon(Icons.check_circle_rounded, color: couleur, size: 18),
                    ]),
                  ),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _abandonner(BuildContext context) async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('troupe.abandonner_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('troupe.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('troupe.oui'))),
        ],
      ),
    );
    if (ok == true) {
      await widget.contexte.store.supprimer(s.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.ok, required this.texte, required this.correction, this.onCorriger});

  final bool ok;
  final String texte;
  final String correction;
  final VoidCallback? onCorriger;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final couleur = ok ? c.famille(FamilleId.tient) : c.famille(FamilleId.fissure);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: couleur),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: TextStyle(fontFamily: kPoliceTexte, color: c.texte))),
        ]),
        if (!ok && correction.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(correction, style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
          if (onCorriger != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onCorriger, child: Text(context.textes.t('preparer.appliquer'))),
            ),
        ],
      ]),
    );
  }
}
