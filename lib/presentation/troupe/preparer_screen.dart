import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/session.dart';
import '../bibliotheque/archetypes_screen.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../bibliotheque/dangers_lieux_screen.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'troupe_screen.dart';

/// Préparer une répétition ou un spectacle. Sans prénoms : on se les donne
/// sur le plateau. « Tirer » donne d'un seul geste le lieu, le danger et la
/// distribution des archétypes, chacun avec ses deux animaux possibles, et
/// un bouton pour en savoir plus à chaque niveau.
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
  List<Location> _lieux = const [];
  List<Danger> _dangers = const [];
  bool _catalogueCharge = false;

  SessionTroupe get s => widget.session;
  Grammaire get g => context.grammaire;

  ContexteBibliotheque get _bibliotheque => ContexteBibliotheque(
        catalogue: widget.contexte.catalogue,
        visuels: widget.contexte.visuels,
        detailsLieux: widget.contexte.detailsLieux,
      );

  @override
  void initState() {
    super.initState();
    final nouvelle = s.personnages.isEmpty;
    if (nouvelle) {
      final n = widget.contexte.reglages.joueursParDefaut;
      s.personnages = [for (var i = 0; i < n; i++) PersonnageTroupe(joueur: '', archetypeId: '')];
    }
    _chargerCatalogue().then((_) {
      if (!mounted) return;
      // À l'arrivée, tout est déjà tiré : on n'a plus qu'à jouer.
      if (nouvelle && _mode != 'concerte') _distribuer();
      if (s.lieuNom.isEmpty) _tirerLieu();
      if (s.dangerNom.isEmpty) _tirerDanger();
      _sauver();
    });
  }

  Future<void> _chargerCatalogue() async {
    final lieux = await widget.contexte.catalogue.getLocations();
    final dangers = await widget.contexte.catalogue.getDangers();
    if (!mounted) return;
    setState(() {
      _lieux = lieux;
      _dangers = dangers;
      _catalogueCharge = true;
    });
  }

  List<Location> get _lieuxPossibles => [
        for (final l in _lieux)
          if (l.actif && (!s.kids || l.kids)) l
      ];
  List<Danger> get _dangersPossibles => [
        for (final d in _dangers)
          if (d.actif && d.paliers.length == 4 && (!s.kids || d.kids)) d
      ];

  Location? get _lieu {
    for (final l in _lieux) {
      if (l.id == s.lieuId) return l;
    }
    return null;
  }

  Danger? get _danger {
    for (final d in _dangers) {
      if (d.id == s.dangerId) return d;
    }
    return null;
  }

  T? _autre<T>(List<T> liste, bool Function(T) estActuel) {
    final choix = [
      for (final e in liste)
        if (!estActuel(e)) e
    ];
    final pool = choix.isEmpty ? liste : choix;
    return pool.isEmpty ? null : pool[_hasard.nextInt(pool.length)];
  }

  void _tirerLieu() {
    final l = _autre(_lieuxPossibles, (l) => l.id == s.lieuId);
    setState(() {
      s.lieuId = l?.id ?? '';
      s.lieuNom = l?.name ?? '';
    });
  }

  void _tirerDanger() {
    final d = _autre(_dangersPossibles, (d) => d.id == s.dangerId);
    setState(() {
      s.dangerId = d?.id ?? '';
      s.dangerNom = d?.name ?? '';
      s.paliers = d?.paliersPour(kids: s.kids) ?? [];
    });
  }

  /// « Tirer » : le lieu, le danger et la distribution, d'un seul geste.
  void _toutTirer() {
    _tirerLieu();
    _tirerDanger();
    if (_mode == 'exemple') _exemple++;
    if (_mode != 'concerte') _distribuer();
    _sauver();
  }

  void _changerNombre(int n) {
    setState(() {
      while (s.personnages.length < n) {
        s.personnages.add(PersonnageTroupe(joueur: '', archetypeId: ''));
      }
      while (s.personnages.length > n) {
        s.personnages.removeLast();
      }
    });
    if (_mode != 'concerte') _distribuer();
    _sauver();
  }

  void _changerKids(bool kids) {
    setState(() => s.kids = kids);
    // En kids, seuls les lieux et les dangers kids se jouent.
    if (_lieu != null && kids && !_lieu!.kids) _tirerLieu();
    if (_danger != null && kids && !_danger!.kids) _tirerDanger();
    if (_danger != null) s.paliers = _danger!.paliersPour(kids: kids);
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
      _attribuer(
          tirerDistribution(g, n, hasard: _hasard, leaderObligatoire: widget.contexte.reglages.leaderObligatoire));
    }
  }

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  void _ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

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
    final verdict = validerDistribution(g, ids, leaderObligatoire: widget.contexte.reglages.leaderObligatoire);
    String p(String k, [Map<String, String> v = const {}]) => t.t('preparer.$k', v);

    return PageDestiny(
      titre: p('titre'),
      enfants: [
        SegmentedButton<TypeSession>(
          segments: [
            for (final ty in [TypeSession.repetition, TypeSession.spectacle])
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
          title: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [Text(p('kids')), const SigleKids(petit: true)],
          ),
          value: s.kids,
          onChanged: _changerKids,
        ),
        SectionDestiny(titre: p('joueurs'), espace: 8, enfants: [
          SegmentedButton<int>(
            segments: [
              for (final n in [4, 5, 6]) ButtonSegment(value: n, label: Text('$n'))
            ],
            selected: {s.personnages.length},
            onSelectionChanged: (v) => _changerNombre(v.first),
          ),
        ]),
        SectionDestiny(titre: p('distribution'), enfants: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final m in ['tirage', 'exemple', 'concerte'])
              ChoiceChip(
                label: Text(t.t('distribution.modes.$m')),
                selected: _mode == m,
                onSelected: (_) {
                  setState(() => _mode = m);
                  if (_mode != 'concerte') _distribuer();
                },
              ),
          ]),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _toutTirer,
            icon: const Icon(Icons.shuffle_rounded),
            label: Text(p('tirer')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontFamily: kPoliceTexte, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(p('tirer_aide'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
        SectionDestiny(titre: p('tirage'), enfants: [
          if (_catalogueCharge && _lieuxPossibles.isEmpty && _dangersPossibles.isEmpty)
            Paragraphe(p('catalogue_vide'), italique: true)
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _VignetteTirage(
                  dossier: 'locations',
                  id: s.lieuId,
                  surtitre: p('lieu'),
                  nom: s.lieuNom,
                  icone: Icons.place_rounded,
                  source: widget.contexte.visuels.source,
                  onRelancer: () {
                    _tirerLieu();
                    _sauver();
                  },
                  relancer: p('autre_lieu'),
                  onInfo: _lieu == null ? null : () => _ouvrir(FicheLieu(lieu: _lieu!, contexte: _bibliotheque)),
                  info: p('info_de', {'nom': s.lieuNom}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VignetteTirage(
                  dossier: 'dangers',
                  id: s.dangerId,
                  surtitre: p('danger'),
                  nom: s.dangerNom,
                  icone: Icons.bolt_rounded,
                  source: widget.contexte.visuels.source,
                  onRelancer: () {
                    _tirerDanger();
                    _sauver();
                  },
                  relancer: p('autre_danger'),
                  onInfo: _danger == null ? null : () => _ouvrir(FicheDanger(danger: _danger!)),
                  info: p('info_de', {'nom': s.dangerNom}),
                ),
              ),
            ]),
        ]),
        SectionDestiny(titre: p('archetypes'), enfants: [
          Text(p('animaux_aide'), style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
          const SizedBox(height: 8),
          for (var i = 0; i < s.personnages.length; i++) _ligneArchetype(i),
          _Verdict(
            ok: verdict.valide,
            texte: verdict.raison(g, t),
            correction: verdict.phraseCorrection(g, t),
            onCorriger: verdict.correction == null ? null : () => _attribuer(verdict.correction!.appliquer(ids)),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: verdict.valide
                ? () async {
                    s.etape = EtapeSession.echauffement;
                    await _sauver();
                    if (context.mounted) ouvrirEtape(context, widget.contexte, s, remplacer: true);
                  }
                : null,
            icon: const Icon(Icons.self_improvement_rounded),
            label: Text(p('vers_echauffement')),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _abandonner(context),
          child: Text(t.t('troupe.abandonner'), style: TextStyle(color: c.texteSecondaire)),
        ),
      ],
    );
  }

  /// Un archétype, en version compacte : son nom, ce qu'il fait, et ses deux
  /// animaux possibles, avec un bouton info à chaque niveau.
  Widget _ligneArchetype(int i) {
    final t = context.textes;
    final c = context.destiny;
    final pers = s.personnages[i];
    final arch = g.archetype(pers.archetypeId);
    final couleur = arch == null ? c.filet : c.famille(arch.famille);
    String p(String k, [Map<String, String> v = const {}]) => t.t('preparer.$k', v);
    return CadreLisere(
      couleur: couleur,
      marge: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              arch?.nom ?? p('choisir_archetype'),
              style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 16, color: c.texte),
            ),
          ),
          IconButton(
            tooltip: p('changer_archetype'),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.swap_horiz_rounded, color: c.texteSecondaire),
            onPressed: () => _choisirArchetype(i),
          ),
          if (arch != null)
            IconButton(
              tooltip: p('info_de', {'nom': arch.nom}),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.info_outline_rounded, color: c.titre),
              onPressed: () => _ouvrir(FicheArchetype(archetypeId: arch.id, contexte: _bibliotheque)),
            ),
        ]),
        if (arch != null) ...[
          Text(arch.ceQuIlFait,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, height: 1.3, color: c.texteSecondaire)),
          const SizedBox(height: 6),
          Row(children: [
            for (final (j, a) in g.animauxDe(arch.id).indexed) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(
                child: _PuceAnimal(
                  animal: a,
                  choisi: pers.animalId == a.id,
                  couleur: couleur,
                  source: widget.contexte.visuels.source,
                  onChoisir: () {
                    setState(() => pers.animalId = pers.animalId == a.id ? '' : a.id);
                    _sauver();
                  },
                  info: p('info_de', {'nom': a.nom}),
                  onInfo: () => _ouvrir(FicheAnimal(animalId: a.id, contexte: _bibliotheque)),
                ),
              ),
            ],
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

/// La vignette du lieu ou du danger tiré : son image, son nom, un bouton pour
/// en tirer un autre et un bouton pour en savoir plus.
class _VignetteTirage extends StatelessWidget {
  const _VignetteTirage({
    required this.dossier,
    required this.id,
    required this.surtitre,
    required this.nom,
    required this.icone,
    required this.source,
    required this.onRelancer,
    required this.relancer,
    required this.onInfo,
    required this.info,
  });

  final String dossier;
  final String id;
  final String surtitre;
  final String nom;
  final IconData icone;
  final VisualSource source;
  final VoidCallback onRelancer;
  final String relancer;
  final VoidCallback? onInfo;
  final String info;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    Widget repli() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.orFonce, c.nuit],
            ),
          ),
          child: Center(child: Icon(icone, size: 48, color: c.orClair)),
        );
    Widget bouton(IconData i, String tip, VoidCallback? onTap) => Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tip,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            color: Colors.white,
            icon: Icon(i),
            onPressed: onTap,
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 0.85,
        child: Stack(fit: StackFit.expand, children: [
          if (id.isNotEmpty && source == VisualSource.ai)
            Image.asset('assets/images/$dossier/$id.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => repli())
          else
            repli(),
          // Le dégradé du bas, pour que le nom se lise sur l'image.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Colors.transparent, Color(0xE6000000)],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(surtitre.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: kPoliceTexte,
                      fontSize: 10.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE8D5A8))),
              const SizedBox(height: 2),
              Text(nom.isEmpty ? '—' : nom,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
            ]),
          ),
          Positioned(top: 6, left: 6, child: bouton(Icons.shuffle_rounded, relancer, onRelancer)),
          Positioned(top: 6, right: 6, child: bouton(Icons.info_outline_rounded, info, onInfo)),
        ]),
      ),
    );
  }
}

/// Un des deux animaux possibles d'un archétype : on le touche pour le
/// choisir (facultatif), et « i » ouvre sa fiche.
class _PuceAnimal extends StatelessWidget {
  const _PuceAnimal({
    required this.animal,
    required this.choisi,
    required this.couleur,
    required this.source,
    required this.onChoisir,
    required this.info,
    required this.onInfo,
  });

  final Animal animal;
  final bool choisi;
  final Color couleur;
  final VisualSource source;
  final VoidCallback onChoisir;
  final String info;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Material(
      color: choisi ? couleur.withValues(alpha: c.sombre ? 0.22 : 0.12) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: choisi ? couleur : c.filet, width: choisi ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChoisir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
          child: Row(children: [
            MedaillonAnimal(animal, taille: 30, source: source),
            const SizedBox(width: 6),
            Expanded(
              child: Text(animal.nom,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 13.5, color: c.texte)),
            ),
            IconButton(
              tooltip: info,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(Icons.info_outline_rounded, color: c.texteSecondaire),
              onPressed: onInfo,
            ),
          ]),
        ),
      ),
    );
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
