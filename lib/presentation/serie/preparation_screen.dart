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

/// Préparer un épisode : le présage (en saison), le lieu et le danger tirés
/// du catalogue de Destiny (avec leur image et leur fiche), les figurants du
/// lieu, le groupe, les objets et le mystère, le vouloir de chacun, ce qu'on
/// ressort du registre, le chrono et le micro.
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
  final Map<String, TextEditingController> _champs = {};
  List<EntreeRegistre> _suggestions = const [];
  final Map<String, String> _commentaires = {};
  bool _iaEnCours = false;
  bool _micDispo = false;
  late final List<String> _ideesVouloir;

  Serie get s => widget.serie;
  EpisodeSerie get e => widget.episode;

  @override
  void initState() {
    super.initState();
    for (final p in s.personnagesActifs) {
      if (e.role(p.id) == null) e.roles.add(RoleEpisode(personnageId: p.id));
    }
    _ideesVouloir = ([...widget.contexte.store.catalogue.vouloirs]..shuffle(_hasard)).take(4).toList();
    _suggestions = suggestionsRegistre(s.registre,
        dejaRessortis: [for (final x in s.episodes) if (x != e) ...x.registreRessorti], hasard: _hasard);
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

  void _ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _champ(String cle, String valeur) => _champs[cle] ??= TextEditingController(text: valeur);

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

  Future<void> _demanderIa() async {
    setState(() => _iaEnCours = true);
    try {
      final candidats = [
        for (final r in s.registre)
          if (r.categorie != CategorieRegistre.mort && r.statut != StatutRegistre.tombe) r,
      ];
      final choix = await widget.contexte.store
          .proposerRessortis(s, candidats, prochain: [e.lieuNom, e.dangerNom, e.presage].where((x) => x.isNotEmpty).join(' · '));
      if (!mounted) return;
      setState(() {
        _suggestions = [for (final c in choix) candidats[c.numero - 1]];
        _commentaires
          ..clear()
          ..addAll({for (final c in choix) candidats[c.numero - 1].id: c.comment});
      });
    } catch (_) {
      // L'IA n'a pas répondu : on garde les suggestions locales.
    } finally {
      if (mounted) setState(() => _iaEnCours = false);
    }
  }

  Future<void> _commencer() async {
    final chronos = widget.contexte.reglages.chronos;
    if (e.dureeMinutes > 0 && e.destinyMinutes.length != 3) {
      final ch = chronos.firstWhere((c) => c.dureeMinutes == e.dureeMinutes, orElse: () => chronos.first);
      e.destinyMinutes = [...ch.destinyMinutes];
    }
    e
      ..etape = EtapeEpisode.jeu
      ..palierAtteint = 1;
    await _sauver();
    if (mounted) await ouvrirEpisode(context, widget.contexte, s, e, remplacer: true);
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
      if (e.groupe.trim().isEmpty) m('groupe').toLowerCase(),
      if (e.dangerNom.isEmpty) m('danger').toLowerCase(),
    ];

    return PageDestiny(
      titre: e.saison == 0 && s.saisons.isEmpty ? k('titre_seul') : k('titre', {'n': '${e.numero}'}),
      enfants: [
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
        SectionDestiny(titre: m('groupe'), enfants: [
          Text(m('groupe_aide'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          ChampAvecIdees(
            controleur: _champ('groupe', e.groupe),
            libelle: m('groupe'),
            idees: t.liste('mise_en_place.groupes'),
            onChange: (v) {
              setState(() => e.groupe = v.trim());
              _sauver();
            },
          ),
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
        SectionDestiny(titre: m('objets'), enfants: [
          Text(m('objets_aide'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _champ('objet$i', i < e.objets.length ? e.objets[i] : ''),
                decoration: InputDecoration(labelText: m('objet', {'n': '${i + 1}'}), isDense: true),
                onChanged: (v) {
                  while (e.objets.length < 3) {
                    e.objets.add('');
                  }
                  e.objets[i] = v.trim();
                  _sauver();
                },
              ),
            ),
          const SizedBox(height: 6),
          TextField(
            controller: _champ('mystere', e.mystere),
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(labelText: m('mystere'), helperText: m('mystere_aide'), helperMaxLines: 2),
            onChanged: (v) {
              e.mystere = v.trim();
              _sauver();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _champ('reponse', e.reponseMystere),
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(labelText: m('reponse'), helperText: m('reponse_aide'), helperMaxLines: 2),
            onChanged: (v) {
              e.reponseMystere = v.trim();
              _sauver();
            },
          ),
        ]),
        SectionDestiny(titre: k('vouloirs'), enfants: [
          Text(k('vouloir_aide'), style: Theme.of(context).textTheme.bodySmall),
          for (final p in s.personnagesActifs)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ChampAvecIdees(
                controleur: _champ('vouloir.${p.id}', e.role(p.id)?.vouloir ?? ''),
                libelle: '${[p.appel, g.archetype(p.archetypeId)?.nom ?? ''].where((x) => x.isNotEmpty).join(' · ')} — ${k('vouloir')}',
                idees: _ideesVouloir,
                onChange: (v) {
                  e.role(p.id)?.vouloir = v.trim();
                  _sauver();
                },
              ),
            ),
        ]),
        if (s.reglages.registre)
          SectionDestiny(titre: k('registre'), enfants: [
            Text(k('registre_aide'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            if (s.registre.isEmpty) Paragraphe(k('registre_vide'), italique: true),
            for (final r in _suggestions)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: e.registreRessorti.contains(r.id),
                title: Text('${t.t('serie.registre.categories.${r.categorie.name}')} · ${r.nom}'),
                subtitle: Text([r.detail, _commentaires[r.id] ?? ''].where((x) => x.isNotEmpty).join('\n')),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      e.registreRessorti.add(r.id);
                    } else {
                      e.registreRessorti.remove(r.id);
                    }
                  });
                  _sauver();
                },
              ),
            if (s.registre.isNotEmpty && widget.contexte.store.iaConfiguree)
              OutlinedButton.icon(
                onPressed: _iaEnCours ? null : _demanderIa,
                icon: _iaEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, color: DestinyCouleurs.ia),
                label: Text(k('registre_ia')),
              ),
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
          subtitle: Text(_micDispo ? k('micro_aide') : k('micro_absent')),
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
          onPressed: manque.isEmpty ? _commencer : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(k('commencer')),
        ),
      ],
    );
  }
}
