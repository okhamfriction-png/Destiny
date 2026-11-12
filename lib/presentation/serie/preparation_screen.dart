import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/services/transcription_service.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/regles_serie.dart';
import '../../domain/serie/serie.dart';
import '../bibliotheque/bibliotheque_screen.dart' show ContexteBibliotheque;
import '../bibliotheque/dangers_lieux_screen.dart' show FicheDanger, FicheLieu;
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'pbta_composants.dart';
import 'sante_serie.dart';

/// Préparer un épisode, aussi simple qu'au théâtre : le présage et le
/// méchant (en saison), le lieu et le danger tirés du catalogue de Destiny
/// (avec leur image et leur fiche), les figurants du lieu et les sbires du
/// méchant, le chrono, et le micro pour le compte rendu de l'IA.
class PreparationEpisodeScreen extends StatefulWidget {
  const PreparationEpisodeScreen({super.key, required this.contexte, required this.serie, required this.episode});

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie episode;

  @override
  State<PreparationEpisodeScreen> createState() => _PreparationEpisodeScreenState();
}

class _PreparationEpisodeScreenState extends State<PreparationEpisodeScreen> {
  final Random _hasard = Random();
  List<Location> _lieux = const [];
  List<Danger> _dangers = const [];
  bool _catalogueCharge = false;
  bool _micDispo = false;

  Serie get s => widget.serie;
  EpisodeSerie get e => widget.episode;

  @override
  void initState() {
    super.initState();
    for (final p in s.personnagesActifs) {
      if (e.role(p.id) == null) e.roles.add(s.nouveauRole(p.id, sauf: e));
    }
    _charger();
    TranscriptionService().disponible().then((d) {
      if (mounted) setState(() => _micDispo = d);
    });
  }

  Future<void> _charger() async {
    final lieux = await widget.contexte.catalogue.getLocations();
    final dangers = await widget.contexte.catalogue.getDangers();
    if (!mounted) return;
    setState(() {
      _lieux = [for (final l in lieux) if (l.actif && (!s.kids || l.kids)) l];
      _dangers = [for (final d in dangers) if (d.actif && d.paliers.length == 4 && (!s.kids || d.kids)) d];
      _catalogueCharge = true;
    });
    // À l'arrivée, le lieu et le danger sont déjà tirés : on peut les changer.
    if (e.lieuNom.isEmpty) _tirerLieu();
    if (e.dangerNom.isEmpty) _tirerDanger();
  }

  T? _auHasard<T>(List<T> l, bool Function(T) actuel) {
    final autres = [for (final x in l) if (!actuel(x)) x];
    final pool = autres.isEmpty ? l : autres;
    return pool.isEmpty ? null : pool[_hasard.nextInt(pool.length)];
  }

  void _tirerLieu() {
    final l = _auHasard(_lieux, (x) => x.id == e.lieuId);
    if (l != null) _choisirLieu(l);
  }

  void _tirerDanger() {
    final d = _auHasard(_dangers, (x) => x.id == e.dangerId);
    if (d != null) _choisirDanger(d);
  }

  Location? get _lieu {
    for (final l in _lieux) {
      if (l.id == e.lieuId) return l;
    }
    return null;
  }

  Danger? get _danger {
    for (final d in _dangers) {
      if (d.id == e.dangerId) return d;
    }
    return null;
  }

  /// Une fiche (lieu, danger, archétype, animal), dans une fenêtre.
  void _ouvrir(Widget page) => ouvrirEnFenetre(context, page);

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  Mechant? get _mechant => widget.contexte.mechant(context.grammaire, e.mechantId);

  ContexteBibliotheque get _bibliotheque =>
      ContexteBibliotheque(catalogue: widget.contexte.catalogue, visuels: widget.contexte.visuels);

  /// Les PNJ de l'épisode : les trois figurants du lieu de la grammaire (ou,
  /// pour un lieu ajouté à la main, trois figurants tirés), puis les sbires
  /// du méchant.
  void _composerPnj({List<FigurantPret> prets = const [], List<String> fonctions = const []}) {
    final g = context.grammaire;
    e.pnjs = [
      ...figurantsDuLieu(g, prets: prets, fonctions: fonctions, sortis: s.pnjSortis, prefixe: e.lieuId, hasard: _hasard),
      ...sbiresDuMechant(_mechant, sortis: s.pnjSortis),
    ];
  }

  void _choisirLieu(Location l) {
    final lg = context.grammaire.lieuNomme(l.name);
    setState(() {
      e
        ..lieuId = l.id
        ..lieuNom = l.name
        ..lieuDescription = ''
        ..espaces = [...l.espaces];
      _composerPnj(prets: lg?.figurants ?? const [], fonctions: l.roles);
    });
    _sauver();
  }

  void _choisirDanger(Danger d) {
    setState(() {
      e
        ..dangerId = d.id
        ..dangerNom = d.name
        ..paliers = d.paliersPour(kids: s.kids);
    });
    _sauver();
  }

  void _choisirMechantHorsSaison(String id) {
    setState(() {
      e.mechantId = id;
      e.pnjs = [for (final p in e.pnjs) if (!p.duMechant) p, ...sbiresDuMechant(_mechant, sortis: s.pnjSortis)];
    });
    _sauver();
  }

  Future<T?> _choixLibre<T>(List<T> liste, String Function(T) nom) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            children: [for (final x in liste) ListTile(title: Text(nom(x)), onTap: () => Navigator.pop(ctx, x))],
          ),
        ),
      );

  Future<void> _commencer({bool regie = false}) async {
    final chronos = widget.contexte.reglages.chronos;
    if (e.dureeMinutes > 0 && e.destinyMinutes.length != 3) {
      final ch = chronos.firstWhere((c) => c.dureeMinutes == e.dureeMinutes, orElse: () => chronos.first);
      e.destinyMinutes = [...ch.destinyMinutes];
    }
    e
      ..etape = EtapeEpisode.jeu
      ..palierAtteint = 1;
    await _sauver();
    if (mounted) await ouvrirEpisode(context, widget.contexte, s, e, remplacer: true, regie: regie);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.preparation.$x', v);
    String m(String x, [Map<String, String> v = const {}]) => t.t('mise_en_place.$x', v);
    final mechant = _mechant;
    final precedent = [for (final x in s.episodes) if (x != e && x.etape == EtapeEpisode.termine) x];
    final sortiePrecedente = precedent.isEmpty ? '' : precedent.last.sortie;
    final chronos = widget.contexte.reglages.chronos;
    final manque = [
      if (e.lieuNom.isEmpty) m('lieu').toLowerCase(),
      if (e.dangerNom.isEmpty) m('danger').toLowerCase(),
    ];

    return PageDestiny(
      titre: e.saison == 0 && s.saisons.isEmpty ? k('titre_seul') : k('titre', {'n': '${e.numero}'}),
      enfants: [
        FilEpisode(
          courante: EtapeFil.preparer,
          onJeu: manque.isEmpty ? _commencer : null,
          onRegie: manque.isEmpty ? () => _commencer(regie: true) : null,
        ),
        const SizedBox(height: 10),
        if (e.saison > 0)
          Text(t.t('serie.saison_n', {'n': '${e.saison}'}),
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (s.kids) const Center(child: SigleKids()),
        if (e.saison > 0) ...[
          SectionDestiny(titre: k('presage'), enfants: [
            EncartReplique(e.presage, couleur: c.palier(PalierId.deNumero(e.numero.clamp(1, 4)))),
            Paragraphe(
                mechantEnPersonne(saison: e.saison, numero: e.numero, aUnMechant: mechant != null) ? k('final') : k('ombre'),
                italique: true),
            if (mechant != null)
              ElementListe(
                titre: mechant.nom,
                sousTitre: mechant.veut,
                couleur: c.titre,
                apres: const Icon(Icons.open_in_full_rounded),
                onTap: () => ouvrirCarteMechant(context, mechant, kids: s.kids),
              ),
          ]),
        ],
        SectionDestiny(titre: k('lieu_danger'), enfants: [
          if (sortiePrecedente.isNotEmpty) Paragraphe(k('sortie_precedente', {'sortie': sortiePrecedente}), italique: true),
          if (e.saison > 0) Text(k('danger_aide'), style: Theme.of(context).textTheme.bodySmall),
          if (_catalogueCharge && _lieux.isEmpty && _dangers.isEmpty)
            Paragraphe(k('catalogue_vide'), italique: true)
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: VignetteCatalogue(
                  dossier: 'locations',
                  id: e.lieuId,
                  surtitre: m('lieu'),
                  nom: e.lieuNom,
                  icone: Icons.place_rounded,
                  source: widget.contexte.visuels.source,
                  onRelancer: _tirerLieu,
                  relancer: k('autre_lieu'),
                  onListe: () async {
                    final l = await _choixLibre(_lieux, (x) => x.name);
                    if (l != null) _choisirLieu(l);
                  },
                  liste: k('liste_lieux'),
                  onInfo: _lieu == null ? null : () => _ouvrir(FicheLieu(lieu: _lieu!, contexte: _bibliotheque)),
                  info: k('info_de', {'nom': e.lieuNom}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VignetteCatalogue(
                  dossier: 'dangers',
                  id: e.dangerId,
                  surtitre: m('danger'),
                  nom: e.dangerNom,
                  icone: Icons.bolt_rounded,
                  source: widget.contexte.visuels.source,
                  onRelancer: _tirerDanger,
                  relancer: k('autre_danger'),
                  onListe: () async {
                    final d = await _choixLibre(_dangers, (x) => x.name);
                    if (d != null) _choisirDanger(d);
                  },
                  liste: k('liste_dangers'),
                  onInfo: _danger == null ? null : () => _ouvrir(FicheDanger(danger: _danger!)),
                  info: k('info_de', {'nom': e.dangerNom}),
                ),
              ),
            ]),
          if (e.espaces.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(k('espaces'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final x in e.espaces) Chip(label: Text(x))]),
          ],
          if (e.paliers.isNotEmpty) ...[
            const SizedBox(height: 10),
            FrisePaliers(textes: e.paliers, compacte: true),
          ],
        ]),
        if (e.saison == 0)
          SectionDestiny(titre: k('mechant_hors_saison'), enfants: [
            Text(k('mechant_hors_saison_aide'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                  label: Text(k('aucun_mechant')),
                  selected: e.mechantId.isEmpty,
                  onSelected: (_) => _choisirMechantHorsSaison('')),
              if (mechant != null)
                ChoiceChip(
                  label: Text(mechant.nom),
                  selected: true,
                  onSelected: (_) => ouvrirCarteMechant(context, mechant, kids: s.kids),
                ),
              ActionChip(
                avatar: const Icon(Icons.list_rounded, size: 16),
                label: Text(k('choisir_mechant')),
                onPressed: () async {
                  final x = await _choixLibre(mechantsDisponibles(g, kids: s.kids), (y) => y.nom);
                  if (x != null) _choisirMechantHorsSaison(x.id);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.shuffle_rounded, size: 16),
                label: Text(k('mechant_hasard')),
                onPressed: () {
                  final x = tirerMechant(g, kids: s.kids, exclus: [e.mechantId], hasard: _hasard);
                  if (x != null) _choisirMechantHorsSaison(x.id);
                },
              ),
            ]),
          ]),
        if (e.pnjs.isNotEmpty)
          SectionDestiny(titre: k('pnjs'), enfants: [
            Text(k('pnjs_aide'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            for (final p in e.pnjs)
              LignePnj(
                pnj: p,
                kids: s.kids,
                source: widget.contexte.visuels.source,
                onMode: (mode) {
                  setState(() => p.mode = mode);
                  _sauver();
                },
              ),
            TextButton.icon(
              onPressed: () => ouvrirTypesFigurants(context),
              icon: const Icon(Icons.help_outline_rounded),
              label: Text(t.t('serie.jeu.types')),
            ),
          ]),
        SectionDestiny(titre: m('chrono'), enfants: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: Text(k('sans_chrono')),
              selected: e.dureeMinutes == 0,
              onSelected: (_) => setState(() {
                e
                  ..dureeMinutes = 0
                  ..destinyMinutes = [];
              }),
            ),
            for (final ch in chronos)
              ChoiceChip(
                label: Text(m('minutes', {'n': '${ch.dureeMinutes}'})),
                selected: e.dureeMinutes == ch.dureeMinutes,
                onSelected: (_) => setState(() {
                  e
                    ..dureeMinutes = ch.dureeMinutes
                    ..destinyMinutes = [...ch.destinyMinutes];
                }),
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            e.dureeMinutes == 0
                ? k('sans_chrono_aide')
                : m('destiny_a', {'liste': e.destinyMinutes.map((x) => '$x').join(' · ')}),
            style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k('micro')),
          subtitle: Text(_micDispo ? k('micro_aide_cr') : k('micro_absent')),
          value: e.transcrire && _micDispo,
          onChanged: _micDispo
              ? (v) {
                  setState(() => e.transcrire = v);
                  _sauver();
                }
              : null,
        ),
        const SizedBox(height: 18),
        if (manque.isNotEmpty) Paragraphe(k('manque', {'liste': manque.join(', ')}), italique: true),
        FilledButton.icon(
          key: const ValueKey('commencer_episode'),
          onPressed: manque.isEmpty ? _commencer : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(k('commencer')),
        ),
      ],
    );
  }
}
