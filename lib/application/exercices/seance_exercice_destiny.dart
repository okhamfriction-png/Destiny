import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/danger.dart';
import '../../domain/exercices/exercices_destiny.dart';
import '../../domain/son/resolution_son.dart';
import '../services/audio_service.dart';
import '../son/conduite_son.dart';
import '../son/lecteur_son.dart';
import '../son/pack_audio.dart';
import '../son/reglages_regie_son.dart';

/// Les réglages des exercices Destiny, gardés sur l'appareil. Ils ne
/// changent rien à la régie du spectacle.
class ReglagesExercicesDestinyStore extends ChangeNotifier {
  ReglagesExercicesDestinyStore([ReglagesExercicesDestiny? valeurs]) : _v = valeurs ?? ReglagesExercicesDestiny();

  static const String _cle = 'exercices_destiny_v1';

  ReglagesExercicesDestiny _v;
  ReglagesExercicesDestiny get v => _v;

  Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut != null) _v = ReglagesExercicesDestiny.depuisJson(jsonDecode(brut) as Map<String, dynamic>);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> modifier(void Function(ReglagesExercicesDestiny v) f) async {
    f(_v);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, jsonEncode(_v.versJson()));
    } catch (_) {}
  }

  /// « Valeurs par défaut ».
  Future<void> remettre() => modifier((_) => _v = ReglagesExercicesDestiny());
}

/// Les valeurs de régie d'un exercice Destiny : celles du spectacle (volume
/// de chaque acte, repli famille, prises choisies), avec l'enchaînement
/// fluide, le maintien, la descente et le niveau de fond des exercices, sans
/// bruitage de palier, sans REVEAL et sans ambiance.
ValeursRegieSon valeursPourExercice(ValeursRegieSon regie, ReglagesExercicesDestiny r, {required bool longForm}) {
  final fond = longForm ? r.fondLongForm : r.fondMinute;
  return ValeursRegieSon.depuisJson(regie.versJson())
    ..packActif = true
    ..fluide = true
    ..maintienOuverture = r.maintienS
    ..maintienDestiny = r.maintienS
    ..descenteFond = r.descenteS
    ..niveauFond = [fond, fond, fond, fond]
    ..musiqueActe = [true, true, true, true]
    ..bruitageAuto = [false, false, false, false]
    ..bruitageFinMusique = [false, false, false, false]
    ..revealActe = [false, false, false, false]
    ..ambianceApresMusique = false
    ..sonOuverture = 'aucun'
    ..chevauchement = 0
    // Le long form : la musique tourne au fond jusqu'au DESTINY suivant.
    ..boucle = longForm;
}

/// Les réglages que lit la conduite d'un exercice : recalculés au lancement.
class _ReglagesConduiteExercice extends ReglagesRegieSon {
  _ReglagesConduiteExercice(this._valeurs);

  ValeursRegieSon _valeurs;

  @override
  ValeursRegieSon get v => _valeurs;

  void remplacer(ValeursRegieSon v) => _valeurs = v;
}

/// Un lieu proposé pour un exercice.
typedef LieuExercice = ({String id, String nom});

/// Ce qui s'affiche en grand pendant un DESTINY du long form.
enum EcranDestiny { aucun, deDanger, eclair, deSurvivants }

/// Un exercice Destiny en cours : le chrono, la musique du lieu (par la
/// conduite son, en enchaînement fluide), la cloche de fin, et pour le long
/// form les trois DESTINY, le dé du danger et le dé des survivants.
class SeanceExerciceDestiny extends ChangeNotifier {
  SeanceExerciceDestiny({
    required this.exercice,
    required this.pack,
    required ValeursRegieSon regie,
    required this.reglages,
    required this.lieux,
    required String lieuId,
    required this.dureeS,
    this.acte = 1,
    int protagonistes = 4,
    List<int>? momentsDestinyS,
    this.dangers = const [],
    bool Function()? muet,
    VoidCallback? avantMusique,
    LecteurSon Function(BusSon bus)? fabrique,
    Future<void> Function(Duration)? attendre,
    Random? hasard,
    this.minuteur = true,
  })  : _regie = regie,
        _lieuId = lieuId,
        protagonistes = protagonistes.clamp(2, 8),
        _hasard = hasard ?? Random() {
    moments = momentsDestinyS ??
        momentsAuProrata(reglages.momentsDestinyMin, reglages.dureeDe(ExerciceDestiny.longForm), dureeS);
    _reglagesConduite = _ReglagesConduiteExercice(_valeurs());
    conduite = ConduiteSon(
      pack: pack,
      reglages: _reglagesConduite,
      muet: muet,
      avantMusique: avantMusique,
      fabrique: fabrique,
      attendre: attendre,
      hasard: _hasard,
      // Sans pack : l'ambiance embarquée du lieu.
      choixSansPack: (_) => 'lieu',
    );
    _reste = dureeS;
  }

  final ExerciceDestiny exercice;
  final PackAudio pack;
  final ReglagesExercicesDestiny reglages;
  final List<LieuExercice> lieux;
  final List<Danger> dangers;

  /// La durée totale, en secondes.
  final int dureeS;

  /// L'acte dont la musique accompagne un exercice minuté (1 à 4).
  final int acte;

  /// Le long form : le nombre de protagonistes (2 à 8).
  final int protagonistes;

  /// Le long form : les moments des trois DESTINY, en secondes.
  late List<int> moments;

  /// Faux dans les tests : le temps avance par [tic].
  final bool minuteur;

  final ValeursRegieSon _regie;
  final Random _hasard;
  late final _ReglagesConduiteExercice _reglagesConduite;
  late final ConduiteSon conduite;

  ValeursRegieSon _valeurs() => valeursPourExercice(_regie, reglages, longForm: exercice == ExerciceDestiny.longForm);

  String _lieuId;
  String get lieuId => _lieuId;
  String get nomLieu => lieux.firstWhere((l) => l.id == _lieuId, orElse: () => (id: _lieuId, nom: _lieuId)).nom;

  int _reste = 0;

  /// Le temps qui reste, en secondes.
  int get reste => _reste;

  /// Le temps écoulé, en secondes.
  int get ecoule => dureeS - _reste;

  bool _lance = false;
  bool _enPause = false;
  bool _fini = false;
  bool get lance => _lance;
  bool get enPause => _enPause;
  bool get fini => _fini;
  bool get enCours => _lance && !_enPause && !_fini;

  /// Un son du pack manque (pack pas encore réimporté) : un son embarqué
  /// l'a remplacé.
  bool _packIncomplet = false;
  bool get packIncomplet => _packIncomplet;

  // ----------------------------------------------------------- long form

  int _destinyFaits = 0;

  /// Le nombre de DESTINY déjà tombés (0 à 3).
  int get destinyFaits => _destinyFaits;

  /// L'instant du DESTINY suivant (null : les trois sont passés).
  int? get prochainDestiny => _destinyFaits < 3 && _destinyFaits < moments.length ? moments[_destinyFaits] : null;

  TypeDanger? _type;
  Danger? _danger;
  FaceSurvivants? _survivants;
  EcranDestiny _ecran = EcranDestiny.aucun;

  /// Le type tiré au DESTINY n°1 (le dé du danger).
  TypeDanger? get typeDanger => _type;

  /// Le danger du soir, tiré dans ce type.
  Danger? get danger => _danger;

  /// Le résultat du dé des survivants (DESTINY n°3).
  FaceSurvivants? get survivants => _survivants;

  EcranDestiny get ecran => _ecran;

  Timer? _timer;

  // ------------------------------------------------------------ commandes

  /// Lance l'exercice : la musique de l'acte (l'acte 1 en long form) et le
  /// chrono.
  Future<void> lancer() async {
    _timer?.cancel();
    _reglagesConduite.remplacer(_valeurs());
    _reste = dureeS;
    _lance = true;
    _enPause = false;
    _fini = false;
    _destinyFaits = 0;
    _type = null;
    _danger = null;
    _survivants = null;
    _ecran = EcranDestiny.aucun;
    conduite.preparer(lieuId: _lieuId, dangerId: '', acte: 1);
    _demarrerMinuteur();
    notifyListeners();
    await conduite.ouverture(acte: exercice == ExerciceDestiny.longForm ? 1 : acte);
  }

  void _demarrerMinuteur() {
    _timer?.cancel();
    if (minuteur) _timer = Timer.periodic(const Duration(seconds: 1), (_) => tic());
  }

  /// Une seconde de plus : le DESTINY du moment, puis la fin.
  void tic() {
    if (!enCours) return;
    _reste = max(0, _reste - 1);
    final p = prochainDestiny;
    if (exercice == ExerciceDestiny.longForm && p != null && ecoule >= p && _reste > 0) {
      unawaited(destinyMaintenant());
    }
    if (_reste == 0) unawaited(_terminer());
    notifyListeners();
  }

  Future<void> _terminer() async {
    _timer?.cancel();
    _fini = true;
    _ecran = EcranDestiny.aucun;
    notifyListeners();
    if (exercice == ExerciceDestiny.longForm) {
      await conduite.fonduFin();
    } else {
      await conduite.stopTout();
      await sonnerCloche();
    }
  }

  /// Pause : le chrono s'arrête et la musique sort en fondu.
  Future<void> pause() async {
    if (!enCours) return;
    _timer?.cancel();
    _enPause = true;
    notifyListeners();
    await conduite.annulerSequence();
    await conduite.couperMusique();
  }

  /// Reprise : le chrono repart (la musique, elle, ne revient pas).
  void reprendre() {
    if (!_lance || _fini || !_enPause) return;
    _enPause = false;
    _demarrerMinuteur();
    notifyListeners();
  }

  /// Arrêter : tout s'arrête, on revient à la préparation.
  Future<void> arreter() async {
    _timer?.cancel();
    _lance = false;
    _enPause = false;
    _fini = false;
    _ecran = EcranDestiny.aucun;
    notifyListeners();
    await conduite.stopTout();
  }

  /// Relancer, sur le même lieu.
  Future<void> relancer() async {
    await conduite.stopTout();
    await lancer();
  }

  /// Un autre lieu, au hasard, puis on relance.
  Future<void> nouveauLieu() async {
    _lieuId = tirerLieu(lieux, sauf: _lieuId, hasard: _hasard) ?? _lieuId;
    notifyListeners();
    if (_lance) await relancer();
  }

  /// Le DESTINY suivant, tout de suite (bouton « DESTINY maintenant »), ou
  /// à son moment.
  Future<void> destinyMaintenant() async {
    if (exercice != ExerciceDestiny.longForm || !_lance || _fini || _destinyFaits >= 3) return;
    final numero = ++_destinyFaits;
    switch (numero) {
      case 1:
        _type = TypeDanger.values[_hasard.nextInt(TypeDanger.values.length)];
        _danger = tirerDanger(dangers, _type!, hasard: _hasard);
        _ecran = EcranDestiny.deDanger;
        notifyListeners();
        await conduite.destiny(1);
      case 2:
        _ecran = EcranDestiny.eclair;
        notifyListeners();
        await conduite.destiny(2, son: sonDestiny2());
      default:
        final faces = facesSurvivants(protagonistes);
        _survivants = faces[_hasard.nextInt(faces.length)];
        _ecran = EcranDestiny.deSurvivants;
        notifyListeners();
        await conduite.destiny(3);
    }
  }

  /// « Retirer un danger », dans le même type.
  void retirerDanger() {
    final t = _type;
    if (t == null) return;
    _danger = tirerDanger(dangers, t, sauf: _danger?.id, hasard: _hasard) ?? _danger;
    notifyListeners();
  }

  /// Ferme l'écran du DESTINY (le jeu continue).
  void fermerEcran() {
    _ecran = EcranDestiny.aucun;
    notifyListeners();
  }

  // ---------------------------------------------------------------- sons

  /// Le son du DESTINY n°2 du type tiré (null : le son Destiny habituel, le
  /// pack n'a pas encore ce son).
  SourceSon? sonDestiny2() {
    final code = _type?.codeDestiny2;
    if (code == null) return null;
    final r = _resoudre(code);
    if (r == null) {
      _packIncomplet = true;
      notifyListeners();
      return null;
    }
    return SourcePack(r.chemin, titre: pack.manifeste?.sons[r.codeJoue]?.nom ?? code);
  }

  /// La cloche de fin d'exercice, une fois (sans pack : le son du REVEAL
  /// embarqué).
  Future<void> sonnerCloche() async {
    final r = _resoudre(kCodeCloche);
    final SourceSon source;
    if (r == null) {
      _packIncomplet = true;
      notifyListeners();
      source = const SourceAsset(AudioService.revealAsset, titre: 'Fin');
    } else {
      source = SourcePack(r.chemin, titre: pack.manifeste?.sons[kCodeCloche]?.nom ?? kCodeCloche);
    }
    await conduite.jouerEffet(source);
  }

  BruitageResolu? _resoudre(String code) {
    final m = pack.manifeste;
    if (m == null || !pack.disponible) return null;
    return resoudreCode(m, pack.index, code, choix: _regie.choixCandidat, hasard: _hasard);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(conduite.stopTout());
    conduite.dispose();
    super.dispose();
  }
}

/// Un lieu au hasard dans [lieux], autre que [sauf] s'il y en a d'autres.
String? tirerLieu(List<LieuExercice> lieux, {String? sauf, Random? hasard}) {
  if (lieux.isEmpty) return null;
  final choix = lieux.length > 1 ? lieux.where((l) => l.id != sauf).toList() : lieux;
  return choix[(hasard ?? Random()).nextInt(choix.length)].id;
}

/// Un danger actif du type [type], autre que [sauf] s'il y en a d'autres.
Danger? tirerDanger(List<Danger> dangers, TypeDanger type, {String? sauf, Random? hasard}) {
  final duType = [
    for (final d in dangers)
      if (d.actif && TypeDanger.deStyle(d.style) == type) d,
  ];
  if (duType.isEmpty) return null;
  final choix = duType.length > 1 ? duType.where((d) => d.id != sauf).toList() : duType;
  return choix[(hasard ?? Random()).nextInt(choix.length)];
}
