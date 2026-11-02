import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/regles_serie.dart';
import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'personnages_screen.dart';
import 'traitre_screen.dart';

/// Une nouvelle saison : le protagoniste visé, le méchant (son reflet), et
/// ses quatre présages, validés par le maître du jeu. Avec [depuisEpisode],
/// l'épisode déjà joué devient le premier de la saison (« Faire la suite »).
class SaisonScreen extends StatefulWidget {
  const SaisonScreen({super.key, required this.contexte, required this.serie, this.depuisEpisode});

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie? depuisEpisode;

  @override
  State<SaisonScreen> createState() => _SaisonScreenState();
}

class _SaisonScreenState extends State<SaisonScreen> {
  final Random _hasard = Random();
  String _cibleId = '';
  String _mechantId = '';
  final List<TextEditingController> _presages = [for (var i = 0; i < 4; i++) TextEditingController()];
  bool _iaEnCours = false;
  String _iaErreur = '';

  Serie get s => widget.serie;
  int get _numero => s.saisons.length + 1;
  List<PersonnageSerie> get _protagonistes => [for (final p in s.personnagesActifs) if (!p.pnj) p];

  @override
  void initState() {
    super.initState();
    if (_protagonistes.isNotEmpty) _cibleId = _protagonistes.first.id;
  }

  @override
  void dispose() {
    for (final c in _presages) {
      c.dispose();
    }
    super.dispose();
  }

  PersonnageSerie? get _cible => s.personnage(_cibleId);

  void _choisirMechant(Mechant m) {
    final connus = presagesConnus(widget.contexte.store.catalogue, m.id);
    setState(() {
      _mechantId = m.id;
      for (var i = 0; i < 4; i++) {
        _presages[i].text = connus[i];
      }
    });
  }

  void _auHasard() {
    final g = context.grammaire;
    final m = tirerMechant(
      g,
      widget.contexte.store.catalogue,
      kids: s.kids,
      archetypeId: _cible?.archetypeId ?? '',
      univers: s.univers,
      exclus: [for (final x in s.saisons) x.mechantId],
      hasard: _hasard,
    );
    if (m != null) _choisirMechant(m);
  }

  Future<void> _proposerIa() async {
    final g = context.grammaire;
    final m = widget.contexte.mechant(g, _mechantId);
    if (m == null) return;
    setState(() {
      _iaEnCours = true;
      _iaErreur = '';
    });
    try {
      final p = await widget.contexte.store.proposerPresages(s, m, paliers: [for (final x in g.paliers) x.nom]);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 4; i++) {
          if (p[i].isNotEmpty) _presages[i].text = p[i];
        }
      });
    } catch (e) {
      if (mounted) setState(() => _iaErreur = '$e');
    } finally {
      if (mounted) setState(() => _iaEnCours = false);
    }
  }

  Future<void> _valider() async {
    final g = context.grammaire;
    final saison = SaisonSerie(
      numero: _numero,
      mechantId: _mechantId,
      cibleId: _cibleId,
      presages: [for (final c in _presages) c.text.trim()],
      presagesValides: true,
    );
    // Le besoin appartient à la saison : une nouvelle saison, un nouveau
    // besoin.
    if (_numero > 1) {
      for (final p in s.personnages) {
        p
          ..besoin = ''
          ..besoinNomme = false
          ..besoinPaye = false;
        // En kids, personne ne meurt : qui avait quitté l'histoire revient.
        if (s.kids) p.sorti = false;
      }
    }
    s.saisons.add(saison);
    final e = widget.depuisEpisode;
    if (e != null) {
      e
        ..saison = saison.numero
        ..numero = 1
        ..presage = saison.presageDe(1)
        ..mechantId = saison.mechantId;
    }
    final mechant = widget.contexte.mechant(g, _mechantId);
    final traitre = s.reglages.traitre ? tirerTraitre(s.personnages, cibleId: _cibleId, hasard: _hasard) : null;
    if (traitre != null) saison.traitre = TraitreSaison(personnageId: traitre.id);
    await widget.contexte.store.enregistrer(s);
    if (!mounted) return;

    if (traitre != null && mechant != null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TraitreScreen(contexte: widget.contexte, serie: s, saison: saison, mechant: mechant),
      ));
      if (!mounted) return;
    }
    if (e != null) {
      Navigator.of(context).pop();
      return;
    }
    final nouveau = await nouvelEpisode(widget.contexte, s);
    if (mounted) await ouvrirEpisode(context, widget.contexte, s, nouveau, remplacer: true);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.saison.$x', v);

    if (_protagonistes.isEmpty) {
      return PageDestiny(titre: k('titre', {'n': '$_numero'}), enfants: [
        Paragraphe(k('personnages_d_abord')),
        FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) => PersonnagesScreen(contexte: widget.contexte, serie: s, apres: ApresPersonnages.saison),
          )),
          child: Text(t.t('serie.personnages.titre')),
        ),
      ]);
    }

    final cible = _cible;
    final reflets = cible == null
        ? const <Mechant>[]
        : mechantsReflets(g, widget.contexte.store.catalogue,
            archetypeId: cible.archetypeId, kids: s.kids, univers: s.univers);
    final mechant = widget.contexte.mechant(g, _mechantId);
    final precedente = s.saisons.isEmpty ? null : s.saisons.last;
    final pret = _mechantId.isNotEmpty && _presages.every((p) => p.text.trim().isNotEmpty);

    return PageDestiny(
      titre: k('titre', {'n': '$_numero'}),
      enfants: [
        Paragraphe(k('intro')),
        if (widget.depuisEpisode != null) Paragraphe(k('depuis_episode'), italique: true),
        if (precedente != null && precedente.ceQuIlLaisse.isNotEmpty)
          SectionDestiny(titre: k('herite'), enfants: [Paragraphe(precedente.ceQuIlLaisse)]),
        if (s.kids && _numero > 1) Paragraphe(k('nouveaux_pouvoirs'), italique: true),
        SectionDestiny(titre: k('cible'), espace: 0, enfants: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in _protagonistes)
              ChoiceChip(
                label: Text([p.appel, g.archetype(p.archetypeId)?.nom ?? ''].where((x) => x.isNotEmpty).join(' · ')),
                selected: _cibleId == p.id,
                onSelected: (_) => setState(() {
                  _cibleId = p.id;
                  _mechantId = '';
                }),
              ),
          ]),
        ]),
        SectionDestiny(titre: k('reflets'), enfants: [
          if (reflets.isEmpty) Paragraphe(k('aucun'), italique: true),
          for (final m in reflets)
            ElementListe(
              titre: m.nom,
              sousTitre: [m.animal, m.histoirePour(kids: s.kids)].where((x) => x.isNotEmpty).join(' · '),
              couleur: _mechantId == m.id ? c.titre : c.famille(g.archetype(m.archetypeId)?.famille ?? FamilleId.fissure),
              devant: Icon(_mechantId == m.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _mechantId == m.id ? c.titre : c.texteSecondaire),
              apres: m.kids ? const SigleKids(petit: true) : null,
              onTap: () => _choisirMechant(m),
            ),
          OutlinedButton.icon(onPressed: _auHasard, icon: const Icon(Icons.shuffle_rounded), label: Text(k('tirer'))),
        ]),
        if (mechant != null) ...[
          SectionDestiny(titre: k('choisi'), enfants: [
            ElementListe(
              titre: mechant.nom,
              sousTitre: mechant.veut,
              couleur: c.titre,
              apres: const Icon(Icons.open_in_full_rounded),
              onTap: () => ouvrirCarteMechant(context, mechant, kids: s.kids),
            ),
          ]),
          SectionDestiny(titre: k('presages'), enfants: [
            Text(k('presages_aide'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _presages[i],
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: k('presage_n', {'n': '${i + 1}', 'palier': g.paliers[i].nom}),
                    isDense: true,
                    labelStyle: TextStyle(color: c.palier(PalierId.values[i])),
                  ),
                ),
              ),
            if (widget.contexte.store.iaConfiguree)
              OutlinedButton.icon(
                onPressed: _iaEnCours ? null : _proposerIa,
                icon: _iaEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, color: DestinyCouleurs.ia),
                label: Text(_iaEnCours ? k('ia_en_cours') : k('proposer_ia')),
              )
            else
              Paragraphe(k('ia_absente'), italique: true),
            if (_iaErreur.isNotEmpty) Paragraphe(k('ia_echec', {'erreur': _iaErreur})),
          ]),
        ],
        const SizedBox(height: 18),
        if (mechant != null && !pret) Paragraphe(k('presages_manquants'), italique: true),
        FilledButton.icon(
          onPressed: pret ? _valider : null,
          icon: const Icon(Icons.check_rounded),
          label: Text(k('valider')),
        ),
      ],
    );
  }
}
