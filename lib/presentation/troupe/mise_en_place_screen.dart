import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/troupe/session.dart';
import '../bibliotheque/dangers_lieux_screen.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'regie_screen.dart';
import 'troupe_screen.dart';

/// La mise en place : le lieu et le danger tirés à la préparation (chacun
/// avec sa bulle d'info), que le public peut changer par un vote ; le chrono
/// et ses trois Destiny. Plus de groupe ni de mystère au spectacle (2.2.0) :
/// leurs champs restent dans la session, pour les anciennes sauvegardes.
class MiseEnPlaceScreen extends StatefulWidget {
  const MiseEnPlaceScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<MiseEnPlaceScreen> createState() => _MiseEnPlaceScreenState();
}

class _MiseEnPlaceScreenState extends State<MiseEnPlaceScreen> {
  final Random _hasard = Random();
  List<Location> _lieux = const [];
  List<Danger> _dangers = const [];
  List<Location> _propLieux = const [];
  List<Danger> _propDangers = const [];
  /// Le chrono de la session parmi ceux des réglages, reconnu à sa durée
  /// (ses Destiny ont pu être déplacés à la main) ; celui des réglages sinon.
  late int _chrono = _chronoDeLaSession() ?? widget.contexte.reglages.chronoChoisi;

  int? _chronoDeLaSession() {
    final chronos = widget.contexte.reglages.chronos;
    for (var i = 0; i < chronos.length; i++) {
      if (chronos[i].dureeMinutes == s.dureeMinutes) return i;
    }
    return null;
  }

  /// Fait glisser un Destiny sur la frise : mêmes règles qu'à la régie.
  bool _placer(int index, int minute) {
    if (refusDestiny(s, index: index, minute: minute, ecouleSecondes: 0) != null) return false;
    setState(() => s.destinyMinutes = [...s.destinyMinutes]..[index] = minute);
    widget.contexte.store.enregistrer(s);
    return true;
  }

  SessionTroupe get s => widget.session;

  @override
  void initState() {
    super.initState();
    _charger();
    // La session a toujours un chrono : le fil des étapes peut mener à la
    // régie sans passer par « Lever le rideau ». Les Destiny déplacés à la
    // main restent.
    if (_chronoDeLaSession() == null) appliquerChrono(s, widget.contexte.reglages.chronos[_chrono]);
  }

  Future<void> _charger() async {
    final lieux = await widget.contexte.catalogue.getLocations();
    final dangers = await widget.contexte.catalogue.getDangers();
    if (!mounted) return;
    setState(() {
      _lieux = [for (final l in lieux) if (l.actif && (!s.kids || l.kids)) l];
      _dangers = [for (final d in dangers) if (d.actif && d.paliers.length == 4 && (!s.kids || d.kids)) d];
      _proposerLieux();
      _proposerDangers();
    });
  }

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

  /// Une fiche (lieu, danger, archétype, animal), dans une fenêtre.
  void _ouvrir(Widget page) => ouvrirEnFenetre(context, page);

  List<T> _trois<T>(List<T> liste) => ([...liste]..shuffle(_hasard)).take(3).toList();
  void _proposerLieux() => _propLieux = _trois(_lieux);
  void _proposerDangers() => _propDangers = _trois(_dangers);

  @override
  void dispose() {
    super.dispose();
  }

  void _choisirLieu(Location l) => setState(() {
        s.lieuId = l.id;
        s.lieuNom = l.name;
      });

  void _choisirDanger(Danger d) => setState(() {
        s.dangerId = d.id;
        s.dangerNom = d.name;
        s.paliers = d.paliersPour(kids: s.kids);
      });

  Future<T?> _choixLibre<T>(List<T> liste, String Function(T) nom) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            children: [for (final e in liste) ListTile(title: Text(nom(e)), onTap: () => Navigator.pop(ctx, e))],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String m(String k, [Map<String, String> v = const {}]) => t.t('mise_en_place.$k', v);
    final chronos = widget.contexte.reglages.chronos;
    final pret = s.lieuNom.isNotEmpty && s.dangerNom.isNotEmpty;
    final source = widget.contexte.visuels.source;

    return PageDestiny(
      titre: m('titre'),
      enfants: [
        FilEtapes(contexte: widget.contexte, session: s, courante: EtapeSession.miseEnPlace),
        const SizedBox(height: 14),
        Paragraphe(m('intro')),
        SectionDestiny(titre: m('lieu'), enfants: [
          LigneDecor(
            dossier: 'locations',
            id: s.lieuId,
            nom: s.lieuNom,
            icone: Icons.place_rounded,
            source: source,
            detail: _lieu?.espaces.join(' · '),
            onInfo: _lieu == null
                ? null
                : () => _ouvrir(FicheLieu(lieu: _lieu!, contexte: bibliothequeDe(widget.contexte))),
          ),
          _Vote<Location>(
            consigne: m('vote'),
            propositions: _propLieux,
            nom: (l) => l.name,
            choisi: (l) => l.id == s.lieuId,
            onChoisir: _choisirLieu,
            nouvelles: m('nouvelles'),
            onNouvelles: () => setState(_proposerLieux),
            choixLibre: m('choix_libre'),
            onChoixLibre: () async {
              final l = await _choixLibre(_lieux, (x) => x.name);
              if (l != null) _choisirLieu(l);
            },
          ),
        ]),
        SectionDestiny(titre: m('danger'), enfants: [
          LigneDecor(
            dossier: 'dangers',
            id: s.dangerId,
            nom: s.dangerNom,
            icone: Icons.bolt_rounded,
            source: source,
            onInfo: _danger == null ? null : () => _ouvrir(FicheDanger(danger: _danger!)),
          ),
          _Vote<Danger>(
            consigne: m('vote'),
            propositions: _propDangers,
            nom: (d) => d.name,
            choisi: (d) => d.id == s.dangerId,
            onChoisir: _choisirDanger,
            nouvelles: m('nouvelles'),
            onNouvelles: () => setState(_proposerDangers),
            choixLibre: m('choix_libre'),
            onChoixLibre: () async {
              final d = await _choixLibre(_dangers, (x) => x.name);
              if (d != null) _choisirDanger(d);
            },
          ),
          if (s.paliers.isNotEmpty) ...[
            const SizedBox(height: 14),
            FrisePaliers(textes: s.paliers),
          ],
        ]),
        SectionDestiny(titre: m('chrono'), enfants: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < chronos.length; i++)
              ChoiceChip(
                label: Text(m('minutes', {'n': '${chronos[i].dureeMinutes}'})),
                selected: _chrono == i,
                onSelected: (_) => setState(() {
                  _chrono = i;
                  appliquerChrono(s, chronos[i]);
                }),
              ),
          ]),
          const SizedBox(height: 14),
          FriseDestiny(
            totalSecondes: s.dureeMinutes * 60,
            ecouleSecondes: 0,
            curseur: false,
            reperes: reperesDestiny(s),
            deplacer: _placer,
          ),
          const SizedBox(height: 6),
          Text(m('destiny_a', {'liste': s.destinyMinutes.map((x) => '$x').join(' · ')}),
              style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
        ]),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: pret
              ? () async {
                  s.etape = EtapeSession.regie;
                  await widget.contexte.store.enregistrer(s);
                  if (context.mounted) ouvrirEtape(context, widget.contexte, s, remplacer: true);
                }
              : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(m('lever_rideau')),
        ),
      ],
    );
  }
}

/// Le vote à main levée : trois propositions, trois autres, ou le choix libre.
class _Vote<T> extends StatelessWidget {
  const _Vote({
    required this.consigne,
    required this.propositions,
    required this.nom,
    required this.choisi,
    required this.onChoisir,
    required this.nouvelles,
    required this.onNouvelles,
    required this.choixLibre,
    required this.onChoixLibre,
  });

  final String consigne;
  final List<T> propositions;
  final String Function(T) nom;
  final bool Function(T) choisi;
  final ValueChanged<T> onChoisir;
  final String nouvelles;
  final VoidCallback onNouvelles;
  final String choixLibre;
  final VoidCallback onChoixLibre;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 2),
      Text(
        consigne,
        style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.35, color: c.texteSecondaire),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in propositions)
          ChoiceChip(
            label: Text(nom(e)),
            selected: choisi(e),
            onSelected: (_) => onChoisir(e),
          ),
      ]),
      Wrap(spacing: 4, children: [
        TextButton.icon(onPressed: onNouvelles, icon: const Icon(Icons.refresh_rounded), label: Text(nouvelles)),
        TextButton.icon(onPressed: onChoixLibre, icon: const Icon(Icons.list_rounded), label: Text(choixLibre)),
      ]),
    ]);
  }
}
