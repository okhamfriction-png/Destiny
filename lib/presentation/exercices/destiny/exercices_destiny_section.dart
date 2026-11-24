import 'package:flutter/material.dart';

import '../../../application/exercices/seance_exercice_destiny.dart';
import '../../../application/services/audio_service.dart';
import '../../../application/son/regie_son.dart';
import '../../../application/son/pack_audio.dart';
import '../../../application/son/reglages_regie_son.dart';
import '../../../application/state/music_controller.dart';
import '../../../domain/entities/danger.dart';
import '../../../domain/entities/exercice.dart';
import '../../../domain/exercices/exercices_destiny.dart';
import '../../../domain/grammaire/modeles.dart' show Grammaire;
import '../../../domain/repositories/catalog_store.dart';
import '../../destiny/donnees.dart';
import '../../destiny/page.dart';
import '../../theme/destiny_theme.dart';
import 'exercice_destiny_screen.dart';

/// Ce dont les exercices Destiny ont besoin : le pack et les réglages de la
/// régie (la musique de chaque lieu), le catalogue (lieux et dangers), le son
/// de l'appli et leurs propres réglages.
class ContexteExercicesDestiny {
  ContexteExercicesDestiny({
    required this.audio,
    required this.reglages,
    required this.carnet,
    this.regieSon,
    this.musique,
    this.catalogue,
  });

  final AudioService audio;
  final ReglagesExercicesDestinyStore reglages;
  final CarnetExercices carnet;
  final RegieSon? regieSon;
  final MusicController? musique;
  final CatalogStore? catalogue;

  PackAudio? _packVide;
  PackAudio get pack => regieSon?.pack ?? (_packVide ??= PackAudio());

  bool get avecPack => regieSon?.pack.disponible ?? false;

  /// La consigne d'un exercice, dans le carnet.
  String consigne(ExerciceDestiny e) {
    for (final x in carnet.exercices) {
      if (x.id == e.idCarnet) return x.consigne;
    }
    return '';
  }

  /// Les lieux : les 40 du pack, sinon ceux du catalogue.
  Future<List<LieuExercice>> lieux() async {
    final m = regieSon?.pack.manifeste;
    final List<LieuExercice> l;
    if (avecPack && m != null) {
      l = [for (final x in m.lieux.values) (id: x.id, nom: x.nom)];
    } else {
      final c = catalogue;
      l = c == null ? [] : [for (final x in await c.getLocations()) if (x.actif) (id: x.id, nom: x.name)];
    }
    return l..sort((a, b) => Grammaire.normaliser(a.nom).compareTo(Grammaire.normaliser(b.nom)));
  }

  Future<List<Danger>> dangers() async => await catalogue?.getDangers() ?? const <Danger>[];

  /// Un exercice prêt à lancer.
  SeanceExerciceDestiny seance({
    required ExerciceDestiny exercice,
    required List<LieuExercice> lieux,
    required String lieuId,
    required int dureeS,
    int acte = 1,
    int protagonistes = 4,
    List<int>? moments,
    List<Danger> dangers = const [],
  }) =>
      SeanceExerciceDestiny(
        exercice: exercice,
        pack: pack,
        regie: regieSon?.reglages.v ?? ValeursRegieSon(),
        reglages: reglages.v,
        lieux: lieux,
        lieuId: lieuId,
        dureeS: dureeS,
        acte: acte,
        protagonistes: protagonistes,
        momentsDestinyS: moments,
        dangers: dangers,
        muet: () => audio.muted,
        // Une seule musique à la fois : la bibliothèque et la régie du
        // spectacle se taisent.
        avantMusique: () {
          if (musique?.playing ?? false) musique!.stop();
          final r = regieSon?.conduite;
          if (r != null && r.lecteurs.values.any((l) => l.actif)) r.stopTout();
        },
      );
}

/// « 2 min », « 1 min 30 ».
String dureeLisible(BuildContext context, int secondes) {
  final t = context.textes;
  final m = secondes ~/ 60;
  final s = secondes % 60;
  if (m == 0) return t.t('exercices.destiny.secondes', {'n': '$s'});
  if (s == 0) return t.t('exercices.destiny.duree_min', {'m': '$m'});
  return t.t('exercices.destiny.duree_min_s', {'m': '$m', 's': s.toString().padLeft(2, '0')});
}

/// « 12:30 ».
String minutesSecondes(int secondes) {
  final s = secondes < 0 ? 0 : secondes;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

IconData iconeExerciceDestiny(ExerciceDestiny e) => switch (e) {
      ExerciceDestiny.duo => Icons.people_alt_rounded,
      ExerciceDestiny.improFilee => Icons.swap_horiz_rounded,
      ExerciceDestiny.trio => Icons.groups_rounded,
      ExerciceDestiny.longForm => Icons.theater_comedy_rounded,
    };

String nomExerciceDestiny(BuildContext context, ExerciceDestiny e) => context.textes.t('exercices.destiny.${switch (e) {
      ExerciceDestiny.duo => 'duo',
      ExerciceDestiny.improFilee => 'impro_filee',
      ExerciceDestiny.trio => 'trio',
      ExerciceDestiny.longForm => 'long_form',
    }}');

/// La section Destiny, en tête des Exercices : les quatre exercices et leurs
/// réglages.
class SectionExercicesDestiny extends StatelessWidget {
  const SectionExercicesDestiny({required this.contexte, super.key});

  final ContexteExercicesDestiny contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
    return ListenableBuilder(
      listenable: contexte.reglages,
      builder: (context, _) {
        final r = contexte.reglages.v;
        return CadreLisere(
          couleur: c.or,
          marge: 16,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              PastilleIcone(Icons.bolt_rounded, couleur: c.or, taille: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(k('titre'),
                    style: TextStyle(
                        fontFamily: kPoliceTitres, fontSize: 21, fontWeight: FontWeight.w900, color: c.titre)),
              ),
              IconButton(
                key: const ValueKey('reglages_exercices_destiny'),
                tooltip: k('reglages'),
                icon: Icon(Icons.tune_rounded, color: c.texteSecondaire),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ReglagesExercicesDestinySheet(store: contexte.reglages),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(k('aide'), style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, color: c.texteSecondaire)),
            ),
            for (final e in ExerciceDestiny.values)
              ElementListe(
                key: ValueKey('exercice_destiny_${e.name}'),
                titre: nomExerciceDestiny(context, e),
                sousTitre: contexte.consigne(e),
                devant: PastilleIcone(iconeExerciceDestiny(e), couleur: c.or),
                apres: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(dureeLisible(context, r.dureeDe(e)),
                      style: TextStyle(
                          fontFamily: kPoliceTexte, fontSize: 13.5, fontWeight: FontWeight.w700, color: c.titre)),
                  Text(e == ExerciceDestiny.longForm ? k('trois_destiny') : k('joueurs', {'n': '${e.joueurs}'}),
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
                ]),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PreparationExerciceDestinyScreen(contexte: contexte, exercice: e),
                )),
              ),
          ]),
        );
      },
    );
  }
}

/// L'écran de préparation : réglé pour lancer tout de suite.
class PreparationExerciceDestinyScreen extends StatefulWidget {
  const PreparationExerciceDestinyScreen({required this.contexte, required this.exercice, super.key});

  final ContexteExercicesDestiny contexte;
  final ExerciceDestiny exercice;

  @override
  State<PreparationExerciceDestinyScreen> createState() => _PreparationExerciceDestinyScreenState();
}

class _PreparationExerciceDestinyScreenState extends State<PreparationExerciceDestinyScreen> {
  List<LieuExercice>? _lieux;
  List<Danger> _dangers = const [];

  /// null : au hasard.
  String? _lieu;
  int _acte = 1;
  late int _dureeS = widget.contexte.reglages.v.dureeDe(widget.exercice);
  int _protagonistes = 4;
  late List<int> _moments = _momentsAuProrata();

  bool get _longForm => widget.exercice == ExerciceDestiny.longForm;

  List<int> _momentsAuProrata() {
    final r = widget.contexte.reglages.v;
    return momentsAuProrata(r.momentsDestinyMin, r.dureeDe(ExerciceDestiny.longForm), _dureeS);
  }

  @override
  void initState() {
    super.initState();
    () async {
      final lieux = await widget.contexte.lieux();
      final dangers = _longForm ? await widget.contexte.dangers() : const <Danger>[];
      if (!mounted) return;
      setState(() {
        _lieux = lieux;
        _dangers = dangers;
      });
    }();
  }

  void _changerDuree(int s) => setState(() {
        _dureeS = s.clamp(30, 4 * 3600);
        if (_longForm) _moments = _momentsAuProrata();
      });

  Future<void> _dureeLibre() async {
    final t = context.textes;
    final champ = TextEditingController(text: (_dureeS / 60).toStringAsFixed(_dureeS % 60 == 0 ? 0 : 1));
    final minutes = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('exercices.destiny.duree_libre_titre')),
        content: TextField(
          key: const ValueKey('duree_libre'),
          controller: champ,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.t('exercices.fermer'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(champ.text.replaceAll(',', '.'))),
            child: Text(t.t('reglages.valider')),
          ),
        ],
      ),
    );
    champ.dispose();
    if (minutes != null && minutes > 0) _changerDuree((minutes * 60).round());
  }

  void _lancer() {
    final lieux = _lieux ?? const <LieuExercice>[];
    final lieu = _lieu ?? tirerLieu(lieux);
    if (lieu == null) return;
    final seance = widget.contexte.seance(
      exercice: widget.exercice,
      lieux: lieux,
      lieuId: lieu,
      dureeS: _dureeS,
      acte: _acte,
      protagonistes: _protagonistes,
      moments: _longForm ? _moments : null,
      dangers: _dangers,
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExerciceDestinyScreen(
        seance: seance,
        titre: nomExerciceDestiny(context, widget.exercice),
        consigne: widget.contexte.consigne(widget.exercice),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
    final lieux = _lieux;
    final style = TextStyle(fontFamily: kPoliceTexte, fontSize: 14, color: c.texteSecondaire);
    Widget puce(String texte, bool choisi, VoidCallback onTap, {Key? key}) => ChoiceChip(
          key: key,
          label: Text(texte),
          selected: choisi,
          showCheckmark: false,
          selectedColor: c.or.withValues(alpha: 0.3),
          side: BorderSide(color: choisi ? c.titre : c.filet),
          onSelected: (_) => onTap(),
        );
    Widget pas(String texte, VoidCallback? moins, VoidCallback? plus, {Key? key}) => Row(key: key, children: [
          IconButton(tooltip: t.t('exercices.destiny.moins'), onPressed: moins, icon: const Icon(Icons.remove_circle_outline_rounded)),
          Expanded(
            child: Text(texte,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontFamily: kPoliceTexte, fontSize: 17, fontWeight: FontWeight.w800, color: c.texte)),
          ),
          IconButton(tooltip: t.t('exercices.destiny.plus'), onPressed: plus, icon: const Icon(Icons.add_circle_outline_rounded)),
        ]);

    return Scaffold(
      appBar: AppBar(title: Text(nomExerciceDestiny(context, widget.exercice))),
      body: lieux == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Paragraphe(widget.contexte.consigne(widget.exercice)),
                    if (!widget.contexte.avecPack) Text(k('sans_pack'), style: style),
                    SectionDestiny(titre: k('lieu'), espace: 14, enfants: [
                      DropdownButtonFormField<String?>(
                        key: const ValueKey('choix_lieu'),
                        initialValue: _lieu,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: null, child: Text(k('au_hasard'))),
                          for (final l in lieux) DropdownMenuItem(value: l.id, child: Text(l.nom)),
                        ],
                        onChanged: (x) => setState(() => _lieu = x),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('nouveau_lieu_preparation'),
                          onPressed: lieux.isEmpty ? null : () => setState(() => _lieu = tirerLieu(lieux, sauf: _lieu)),
                          icon: const Icon(Icons.casino_outlined, size: 18),
                          label: Text(k('nouveau_lieu')),
                        ),
                      ),
                    ]),
                    if (!_longForm)
                      SectionDestiny(titre: k('acte'), espace: 14, enfants: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (var a = 1; a <= 4; a++)
                            puce(k('acte_n', {'n': '$a'}), _acte == a, () => setState(() => _acte = a),
                                key: ValueKey('acte_$a')),
                        ]),
                      ]),
                    if (_longForm)
                      SectionDestiny(titre: k('protagonistes'), espace: 14, enfants: [
                        pas(
                          '$_protagonistes',
                          _protagonistes > 2 ? () => setState(() => _protagonistes--) : null,
                          _protagonistes < 8 ? () => setState(() => _protagonistes++) : null,
                          key: const ValueKey('protagonistes'),
                        ),
                      ]),
                    SectionDestiny(titre: _longForm ? k('duree_totale') : k('duree'), espace: 14, enfants: [
                      if (_longForm)
                        pas(
                          dureeLisible(context, _dureeS),
                          _dureeS > 300 ? () => _changerDuree(_dureeS - 300) : () => _changerDuree(_dureeS - 60),
                          () => _changerDuree(_dureeS + 300),
                          key: const ValueKey('duree_totale'),
                        ),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (!_longForm)
                          for (final s in kDureesProposeesS)
                            puce(dureeLisible(context, s), _dureeS == s, () => _changerDuree(s), key: ValueKey('duree_$s')),
                        puce(
                          _longForm || kDureesProposeesS.contains(_dureeS)
                              ? k('duree_libre')
                              : '${k('duree_libre')} · ${dureeLisible(context, _dureeS)}',
                          !_longForm && !kDureesProposeesS.contains(_dureeS),
                          _dureeLibre,
                          key: const ValueKey('duree_libre_bouton'),
                        ),
                      ]),
                    ]),
                    if (_longForm)
                      SectionDestiny(titre: k('moments'), espace: 14, enfants: [
                        Text(k('moments_aide'), style: style),
                        for (var i = 0; i < 3; i++)
                          Row(children: [
                            SizedBox(
                              width: 120,
                              child: Text(k('destiny_n', {'n': '${i + 1}'}),
                                  style: TextStyle(
                                      fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.titre)),
                            ),
                            Expanded(
                              child: pas(
                                minutesSecondes(_moments[i]),
                                _moments[i] > (i == 0 ? 60 : _moments[i - 1] + 60)
                                    ? () => setState(() => _moments[i] -= 60)
                                    : null,
                                _moments[i] + 60 < (i == 2 ? _dureeS : _moments[i + 1])
                                    ? () => setState(() => _moments[i] += 60)
                                    : null,
                                key: ValueKey('moment_$i'),
                              ),
                            ),
                          ]),
                      ]),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('lancer_exercice_destiny'),
                      onPressed: lieux.isEmpty ? null : _lancer,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(k('lancer')),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

/// « Réglages des exercices Destiny » : peu de choses, toutes avec une
/// valeur par défaut.
class ReglagesExercicesDestinySheet extends StatelessWidget {
  const ReglagesExercicesDestinySheet({required this.store, super.key});

  final ReglagesExercicesDestinyStore store;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final r = store.v;
        Widget ligne(String libelle, String valeur, VoidCallback? moins, VoidCallback? plus, {Key? key}) =>
            Row(key: key, children: [
              Expanded(child: Text(libelle, style: TextStyle(fontFamily: kPoliceTexte, color: c.texte))),
              IconButton(tooltip: t.t('exercices.destiny.moins'), onPressed: moins, icon: const Icon(Icons.remove_rounded)),
              SizedBox(
                width: 76,
                child: Text(valeur,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w800, color: c.titre)),
              ),
              IconButton(tooltip: t.t('exercices.destiny.plus'), onPressed: plus, icon: const Icon(Icons.add_rounded)),
            ]);
        String pc(double x) => k('pourcent', {'n': '${(x * 100).round()}'});
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(k('reglages'),
                    style: TextStyle(fontFamily: kPoliceTitres, fontSize: 19, fontWeight: FontWeight.w900, color: c.titre)),
                const SizedBox(height: 8),
                ligne(k('maintien'), k('secondes', {'n': '${r.maintienS.round()}'}),
                    r.maintienS > 0 ? () => store.modifier((v) => v.maintienS = (v.maintienS - 5).clamp(0, 600)) : null,
                    () => store.modifier((v) => v.maintienS = (v.maintienS + 5).clamp(0, 600)),
                    key: const ValueKey('reglage_maintien')),
                ligne(k('descente'), k('secondes', {'n': '${r.descenteS.round()}'}),
                    r.descenteS > 1 ? () => store.modifier((v) => v.descenteS = (v.descenteS - 1).clamp(1, 120)) : null,
                    () => store.modifier((v) => v.descenteS = (v.descenteS + 1).clamp(1, 120))),
                ligne(k('fond_minute'), pc(r.fondMinute),
                    r.fondMinute > 0 ? () => store.modifier((v) => v.fondMinute = (v.fondMinute - 0.05).clamp(0, 1)) : null,
                    () => store.modifier((v) => v.fondMinute = (v.fondMinute + 0.05).clamp(0, 1))),
                ligne(
                    k('fond_long_form'),
                    pc(r.fondLongForm),
                    r.fondLongForm > 0
                        ? () => store.modifier((v) => v.fondLongForm = (v.fondLongForm - 0.05).clamp(0, 1))
                        : null,
                    () => store.modifier((v) => v.fondLongForm = (v.fondLongForm + 0.05).clamp(0, 1))),
                SectionDestiny(titre: k('durees'), espace: 14, enfants: [
                  for (final e in ExerciceDestiny.values)
                    ligne(
                      nomExerciceDestiny(context, e),
                      dureeLisible(context, r.dureeDe(e)),
                      r.dureeDe(e) > 30
                          ? () => store.modifier((v) => v.dureesS[e] = v.dureeDe(e) - (e.minute ? 30 : 300))
                          : null,
                      () => store.modifier((v) => v.dureesS[e] = v.dureeDe(e) + (e.minute ? 30 : 300)),
                    ),
                ]),
                SectionDestiny(titre: k('moments'), espace: 14, enfants: [
                  for (var i = 0; i < 3; i++)
                    ligne(
                      k('destiny_n', {'n': '${i + 1}'}),
                      k('minutes', {'n': r.momentsDestinyMin[i].round().toString()}),
                      r.momentsDestinyMin[i] > (i == 0 ? 1 : r.momentsDestinyMin[i - 1] + 1)
                          ? () => store.modifier((v) => v.momentsDestinyMin[i] -= 1)
                          : null,
                      i == 2 || r.momentsDestinyMin[i] + 1 < r.momentsDestinyMin[i + 1]
                          ? () => store.modifier((v) => v.momentsDestinyMin[i] += 1)
                          : null,
                    ),
                ]),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('valeurs_defaut_exercices'),
                  onPressed: store.remettre,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(k('valeurs_defaut')),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
