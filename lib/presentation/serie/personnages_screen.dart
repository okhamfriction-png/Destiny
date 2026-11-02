import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/grammaire/controle_besoin.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/regles_serie.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'saison_screen.dart';

/// Ce qui vient après les personnages.
enum ApresPersonnages { episode, saison, fiche }

/// Les personnages de la série : un archétype et un animal par joueur, leur
/// nom, leur place dans le lieu, leur blessure, leur besoin, et leur pouvoir
/// en kids. À moins de quatre joueurs, l'alarmiste est tenu par le maître du
/// jeu.
class PersonnagesScreen extends StatefulWidget {
  const PersonnagesScreen({super.key, required this.contexte, required this.serie, required this.apres});

  final ContexteSerie contexte;
  final Serie serie;
  final ApresPersonnages apres;

  @override
  State<PersonnagesScreen> createState() => _PersonnagesScreenState();
}

class _PersonnagesScreenState extends State<PersonnagesScreen> {
  final Random _hasard = Random();
  final Map<String, Map<String, TextEditingController>> _champs = {};

  Serie get s => widget.serie;
  List<PersonnageSerie> get _joueurs => [for (final p in s.personnages) if (!p.pnj) p];

  @override
  void initState() {
    super.initState();
    if (s.personnages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _changerNombre(widget.contexte.reglages.joueursParDefaut.clamp(1, 8));
      });
    }
  }

  @override
  void dispose() {
    for (final m in _champs.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  TextEditingController _champ(PersonnageSerie p, String cle, String valeur) =>
      (_champs[p.id] ??= {})[cle] ??= TextEditingController(text: valeur);

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  /// Nouveau nombre de joueurs : on garde les prénoms et les noms, et on
  /// retire une distribution équilibrée.
  void _changerNombre(int n) {
    final g = context.grammaire;
    setState(() {
      final joueurs = _joueurs;
      while (joueurs.length < n) {
        joueurs.add(PersonnageSerie(id: widget.contexte.store.nouvelId('p'), archetypeId: ''));
      }
      while (joueurs.length > n) {
        joueurs.removeLast();
      }
      final pnj = [for (final p in s.personnages) if (p.pnj) p];
      s.personnages
        ..clear()
        ..addAll(joueurs)
        ..addAll(pnj);
      _distribuer(g);
    });
    _sauver();
  }

  void _distribuer(Grammaire g) {
    final joueurs = _joueurs;
    final d = tirerDistributionJeu(g, joueurs.length, hasard: _hasard);
    for (var i = 0; i < joueurs.length; i++) {
      if (joueurs[i].archetypeId != d.joueurs[i]) {
        joueurs[i]
          ..archetypeId = d.joueurs[i]
          ..animalId = tirerAnimal(g, d.joueurs[i], hasard: _hasard);
      }
    }
    _ajusterAlarmiste(g);
  }

  /// L'alarmiste tenu par le maître du jeu existe quand il manque un
  /// alarmiste parmi les joueurs.
  void _ajusterAlarmiste(Grammaire g) {
    final manque = !_joueurs.any((p) => p.archetypeId == Grammaire.alarmisteId);
    final pnj = s.personnages.where((p) => p.pnj && p.archetypeId == Grammaire.alarmisteId).toList();
    if (manque && pnj.isEmpty) {
      s.personnages.add(PersonnageSerie(
        id: widget.contexte.store.nouvelId('p'),
        archetypeId: Grammaire.alarmisteId,
        animalId: tirerAnimal(g, Grammaire.alarmisteId, hasard: _hasard),
        pnj: true,
      ));
    } else if (!manque && pnj.isNotEmpty) {
      s.personnages.removeWhere((p) => p.pnj && p.archetypeId == Grammaire.alarmisteId);
    }
  }

  Future<void> _changerArchetype(PersonnageSerie p) async {
    final g = context.grammaire;
    final id = await choisirArchetype(context);
    if (id == null || id == p.archetypeId) return;
    setState(() {
      p
        ..archetypeId = id
        ..animalId = tirerAnimal(g, id, hasard: _hasard);
      _ajusterAlarmiste(g);
    });
    _sauver();
  }

  Future<void> _continuer() async {
    await _sauver();
    if (!mounted) return;
    switch (widget.apres) {
      case ApresPersonnages.fiche:
        Navigator.of(context).pop();
      case ApresPersonnages.saison:
        await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => SaisonScreen(contexte: widget.contexte, serie: s),
        ));
      case ApresPersonnages.episode:
        final e = await nouvelEpisode(widget.contexte, s);
        if (mounted) await ouvrirEpisode(context, widget.contexte, s, e, remplacer: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String k(String x) => t.t('serie.personnages.$x');
    final joueurs = _joueurs;
    final ids = [for (final p in joueurs) p.archetypeId];
    final verdict = joueurs.length >= 4 && joueurs.length <= 6 ? validerDistribution(g, ids) : null;
    final complet = s.personnages.every((p) => p.archetypeId.isNotEmpty && p.animalId.isNotEmpty);

    return PageDestiny(
      titre: k('titre'),
      enfants: [
        Paragraphe(k('intro')),
        SectionDestiny(titre: k('joueurs'), espace: 0, enfants: [
          Row(children: [
            IconButton.outlined(
              tooltip: context.textes.t('accessibilite.moins'),
              onPressed: joueurs.length > 1 ? () => _changerNombre(joueurs.length - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Text('${joueurs.length}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            ),
            IconButton.outlined(
              tooltip: context.textes.t('accessibilite.plus'),
              onPressed: joueurs.length < 8 ? () => _changerNombre(joueurs.length + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _distribuer(g));
              _sauver();
            },
            icon: const Icon(Icons.shuffle_rounded),
            label: Text(k('tirer')),
          ),
          if (verdict != null && !verdict.valide) ...[
            const SizedBox(height: 8),
            Paragraphe(verdict.raison(g, t), italique: true),
          ],
        ]),
        const SizedBox(height: 12),
        for (final p in s.personnages) _carte(p),
        if (!complet) Paragraphe(k('manquants'), italique: true),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: complet ? _continuer : null,
          icon: Icon(switch (widget.apres) {
            ApresPersonnages.saison => Icons.local_fire_department_outlined,
            ApresPersonnages.episode => Icons.play_arrow_rounded,
            ApresPersonnages.fiche => Icons.check_rounded,
          }),
          label: Text(switch (widget.apres) {
            ApresPersonnages.saison => k('vers_saison'),
            ApresPersonnages.episode => k('vers_episode'),
            ApresPersonnages.fiche => k('enregistrer'),
          }),
        ),
      ],
    );
  }

  Widget _carte(PersonnageSerie p) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x) => t.t('serie.personnages.$x');
    final arch = g.archetype(p.archetypeId);
    final couleur = arch == null ? c.filet : c.famille(arch.famille);
    final peuples = s.univers.isEmpty ? const <String>[] : widget.contexte.store.catalogue.peuplesPour(s.univers, s.lore);
    final avis = controlerBesoin(p.besoin, t);
    final messageBesoinTexte = p.besoin.trim().isEmpty ? '' : messageBesoin(avis, g, t);

    void champ(String cle, String v) {
      switch (cle) {
        case 'joueur':
          p.joueur = v.trim();
        case 'nom':
          p.nom = v.trim();
        case 'fonction':
          p.fonction = v.trim();
        case 'blessure':
          p.blessure = v.trim();
        case 'besoin':
          p.besoin = v.trim();
        case 'pouvoir':
          p.pouvoir = v.trim();
      }
      setState(() {});
      _sauver();
    }

    Widget texte(String cle, String valeur, String libelle, {String? aide, int lignes = 1, List<String> idees = const []}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChampAvecIdees(
            controleur: _champ(p, cle, valeur),
            libelle: libelle,
            aide: aide,
            idees: idees,
            lignes: lignes,
            onChange: (v) => champ(cle, v),
          ),
        );

    return CadreLisere(
      couleur: couleur,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: p.pnj
                ? Text(p.archetypeId == Grammaire.alarmisteId ? k('pnj_alarmiste') : k('pnj'),
                    style: Theme.of(context).textTheme.titleSmall)
                : TextField(
                    controller: _champ(p, 'joueur', p.joueur),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: k('prenom'), helperText: k('prenom_aide'), isDense: true),
                    onChanged: (v) => champ('joueur', v),
                  ),
          ),
          const SizedBox(width: 10),
          ActionChip(
            avatar: arch == null ? const Icon(Icons.add, size: 16) : null,
            label: Text(arch?.nom ?? t.t('preparer.choisir_archetype')),
            side: BorderSide(color: couleur),
            onPressed: p.pnj ? null : () => _changerArchetype(p),
          ),
        ]),
        if (p.anciensArchetypes.isNotEmpty)
          Text(
            k('archetype_change').replaceAll('{anciens}',
                p.anciensArchetypes.map((id) => g.archetype(id)?.nom ?? id).join(', ')),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (arch != null) ...[
          const SizedBox(height: 8),
          ChoixAnimal(
            archetypeId: arch.id,
            animalId: p.animalId,
            source: widget.contexte.visuels.source,
            onChoisi: (a) {
              setState(() => p.animalId = a);
              _sauver();
            },
          ),
        ],
        texte('nom', p.nom, k('nom')),
        texte('fonction', p.fonction, k('fonction')),
        if (peuples.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(k('peuple'), style: Theme.of(context).textTheme.bodySmall),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final pe in peuples)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text(pe),
                selected: p.peuple == pe,
                onSelected: (sel) {
                  setState(() => p.peuple = sel ? pe : '');
                  _sauver();
                },
              ),
          ]),
        ],
        texte('blessure', p.blessure, s.kids ? t.t('mode_enfant.mots.blessure') : k('blessure'),
            aide: k('blessure_aide'), idees: s.kids ? t.liste('mode_enfant.exemples_de_soucis') : const []),
        texte('besoin', p.besoin, k('besoin'), aide: k('besoin_aide')),
        if (messageBesoinTexte.isNotEmpty && avis != AvisBesoin.ok)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(messageBesoinTexte, style: TextStyle(color: c.famille(FamilleId.fissure), fontSize: 12.5)),
          ),
        if (s.kids)
          texte('pouvoir', p.pouvoir, k('pouvoir'),
              aide: k('pouvoir_aide'), idees: g.modeKids.pouvoirsExemples.take(8).toList()),
      ]),
    );
  }
}
