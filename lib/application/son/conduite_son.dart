import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/son/manifeste_audio.dart';
import '../../domain/son/resolution_son.dart';
import '../services/audio_service.dart';
import 'lecteur_son.dart';
import 'pack_audio.dart';
import 'reglages_regie_son.dart';

/// Les cinq voies de la régie : aucune ne coupe une autre.
enum BusSon { musique, destiny, bruitageA, bruitageB, stinger }

/// Une étape de la conduite, pour savoir où l'on en est (et pour les tests).
enum EtapeConduite { repos, ouverture, sortieMusique, sonDestiny, reveal, bruitage, silence, musique, fin }

/// La conduite son automatique du spectacle : une musique par lieu et par
/// acte, le son Destiny, le stinger de révélation et le bruitage du danger au
/// bon palier, enchaînés. Elle tourne quand le pack est importé et actif ;
/// sinon la régie garde son comportement d'avant.
///
/// Toute séquence porte un numéro : annuler (pause, sortie de l'écran, son
/// coupé) change le numéro, et chaque étape vérifie le sien avant d'agir. Pas
/// de fondu ni de son orphelin.
class ConduiteSon extends ChangeNotifier {
  ConduiteSon({
    required this.pack,
    required this.reglages,
    bool Function()? muet,
    ValueListenable<bool>? muetNotifier,
    LecteurSon Function(BusSon bus)? fabrique,
    Future<void> Function(Duration)? attendre,
    Random? hasard,
    this.avantMusique,
    this.choixSansPack,
    this.delaiSecurite = const Duration(seconds: 90),
  })  : _muet = muet ?? (() => false),
        _attendre = attendre ?? ((d) => Future<void>.delayed(d)),
        _hasard = hasard ?? Random() {
    final f = fabrique ?? (_) => LecteurAudioplayers(pack.versSource);
    lecteurs = {for (final b in BusSon.values) b: f(b)};
    for (final l in lecteurs.values) {
      l.addListener(notifyListeners);
    }
    _muetNotifier = muetNotifier;
    muetNotifier?.addListener(_surMuet);
  }

  final PackAudio pack;
  final ReglagesRegieSon reglages;

  /// Appelé avant de lancer une musique : coupe la musique « hors conduite »
  /// de l'appli (le lecteur de la bibliothèque), pour ne jamais en avoir deux.
  final VoidCallback? avantMusique;

  /// Sans pack : la musique de chaque acte vient des réglages de Destiny
  /// (« aucune », « lieu » pour l'ambiance du lieu, ou une piste embarquée
  /// `music/…`).
  final String Function(int acte)? choixSansPack;

  /// Au-delà, on n'attend plus la fin d'un son (un lecteur muet ne bloque
  /// jamais la suite).
  final Duration delaiSecurite;

  final bool Function() _muet;
  final Future<void> Function(Duration) _attendre;
  final Random _hasard;
  ValueListenable<bool>? _muetNotifier;
  late final Map<BusSon, LecteurSon> lecteurs;

  static const Duration _pas = Duration(milliseconds: 50);

  ValeursRegieSon get _v => reglages.v;
  ManifesteAudio? get _m => pack.manifeste;

  // ------------------------------------------------------------- contexte

  String? _lieuId;
  String? _dangerId;
  int _acte = 1;
  EtapeConduite _etape = EtapeConduite.repos;

  String? get lieuId => _lieuId;
  String? get dangerId => _dangerId;

  /// L'acte en cours (1 à 4) ; c'est aussi le palier du danger.
  int get acte => _acte;
  EtapeConduite get etape => _etape;

  bool _ouverte = false;

  /// L'ouverture a déjà été jouée pour ce lieu et ce danger (le minuteur du
  /// jeu ou le chrono) : on ne la rejoue pas une seconde fois.
  bool get ouverte => _ouverte;

  /// Prépare le spectacle : le lieu, le danger et l'acte où l'on en est.
  void preparer({required String lieuId, required String dangerId, int acte = 1}) {
    if (lieuId != _lieuId || dangerId != _dangerId) _ouverte = false;
    _lieuId = lieuId;
    _dangerId = dangerId;
    _acte = acte.clamp(1, 4);
    notifyListeners();
  }

  /// Le pack est importé, activé, et connaît le lieu : les musiques de
  /// chaque lieu et les bruitages du danger. Sans lui, la conduite enchaîne
  /// de la même façon avec les sons embarqués (musiques des réglages,
  /// ambiance du lieu), sans bruitage.
  bool get active =>
      _v.packActif && pack.disponible && _lieuId != null && (_m?.lieux.containsKey(_lieuId) ?? false);

  bool get _peutJouer => _lieuId != null && !_muet();

  void _etapeVers(EtapeConduite e) {
    _etape = e;
    notifyListeners();
  }

  // ------------------------------------------------------- volumes et fondus

  final Map<BusSon, double> _niveau = {for (final b in BusSon.values) b: 1.0};
  final Map<BusSon, double> _gain = {for (final b in BusSon.values) b: 1.0};
  final Map<BusSon, int> _jetonFondu = {};

  /// Le fader de la table de régie (0 à 1), multiplié à tout le reste.
  double gain(BusSon b) => _gain[b]!;

  /// Le niveau donné par la conduite (avant le fader).
  double niveau(BusSon b) => _niveau[b]!;

  Future<void> reglerGain(BusSon b, double g) async {
    _gain[b] = g.clamp(0.0, 1.0);
    await _appliquer(b);
    notifyListeners();
  }

  /// Le facteur de l'atténuation progressive (voie musique seulement).
  double _facteur = 1;

  double _volumeDe(BusSon b) =>
      (_niveau[b]! * _gain[b]! * (b == BusSon.musique ? _facteur : 1)).clamp(0.0, 1.0);

  Future<void> _appliquer(BusSon b) => lecteurs[b]!.regler(_volumeDe(b));

  void _annulerFondu(BusSon b) => _jetonFondu[b] = (_jetonFondu[b] ?? 0) + 1;

  /// Amène le niveau de [b] à [cible] en [secondes], par pas de 50 ms. Un
  /// fondu plus récent sur la même voie annule celui-ci.
  Future<void> _fondre(BusSon b, double cible, double secondes) async {
    final jeton = (_jetonFondu[b] ?? 0) + 1;
    _jetonFondu[b] = jeton;
    final depart = _niveau[b]!;
    final n = (secondes * 1000 / _pas.inMilliseconds).round();
    if (n <= 0) {
      _niveau[b] = cible;
      await _appliquer(b);
      return;
    }
    for (var i = 1; i <= n; i++) {
      await _attendre(_pas);
      if (_jetonFondu[b] != jeton) return;
      _niveau[b] = depart + (cible - depart) * i / n;
      await _appliquer(b);
    }
  }

  Future<void> _jouerSur(BusSon b, SourceSon s, {required double niveau, bool boucle = false}) {
    _annulerFondu(b);
    _niveau[b] = niveau;
    if (b == BusSon.musique) {
      _jetonDecrescendo++;
      _facteur = 1;
    }
    return lecteurs[b]!.jouer(s, volume: _volumeDe(b), boucle: boucle);
  }

  int _jetonDecrescendo = 0;

  /// La courbe de volume de la musique qui vient de partir : depuis [base]
  /// (le volume de l'acte), elle passe par chaque repère de [points], en ligne
  /// droite de l'un à l'autre ; avec [finAZero], elle arrive à 0 à la fin du
  /// morceau, où elle s'arrête. [dureeS] : la durée si on la connaît
  /// (manifeste) ; sinon le lecteur la donne.
  Future<void> _courbe(SourceSon source, double? dureeS, List<PointVolume> points, bool finAZero, double base) async {
    final zero = finAZero && !_v.boucle;
    if (points.isEmpty && !zero) return;
    final jeton = _jetonDecrescendo;
    final l = lecteurs[BusSon.musique]!;
    bool toujours() => jeton == _jetonDecrescendo && l.enCours == source;
    var duree = dureeS;
    for (var i = 0; zero && duree == null && i < 20; i++) {
      final d = await l.duree();
      if (d != null && d > Duration.zero) {
        duree = d.inMilliseconds / 1000;
      } else {
        await _attendre(const Duration(milliseconds: 300));
      }
      if (!toujours()) return;
    }
    final repere = <(double, double)>[
      (0, base),
      for (final p in [...points]..sort((a, b) => a.secondes.compareTo(b.secondes)))
        if (p.secondes > 0 && (duree == null || p.secondes < duree)) (p.secondes, p.volume),
      if (zero && duree != null) (duree, 0),
    ];
    if (repere.length < 2) return;
    double volumeA(double t) {
      for (var i = 1; i < repere.length; i++) {
        final (t0, v0) = repere[i - 1];
        final (t1, v1) = repere[i];
        if (t <= t1) return t1 <= t0 ? v1 : v0 + (v1 - v0) * (t - t0) / (t1 - t0);
      }
      return repere.last.$2;
    }

    const pas = 0.25;
    final fin = repere.last.$1;
    for (var t = 0.0;; t += pas) {
      if (!toujours()) return;
      final ici = min(t, fin);
      _facteur = (volumeA(ici) / max(base, 0.01)).clamp(0.0, 1.0);
      await _appliquer(BusSon.musique);
      if (ici >= fin) break;
      await _attendre(_s(pas));
    }
    if (zero && duree != null && toujours()) await l.arreter();
  }

  /// La musique en cours sort en fondu, puis s'arrête (échauffement en pause).
  Future<void> couperMusique({double fondu = 2}) async {
    _jetonMusique++;
    final l = lecteurs[BusSon.musique]!;
    if (!l.actif) return;
    final source = l.enCours;
    await _fondre(BusSon.musique, 0, fondu);
    if (l.enCours == source) await l.arreter();
  }

  /// Attend la fin de ce qui joue sur [b], sans jamais dépasser [max].
  Future<void> _attendreFin(BusSon b, {Duration? max}) =>
      Future.any([lecteurs[b]!.fin, _attendre(max ?? delaiSecurite)]);

  static Duration _s(double secondes) => Duration(milliseconds: (secondes * 1000).round());

  // ------------------------------------------------------------- séquences

  int _seq = 0;
  int _jetonBruitage = 0;
  bool _attenue = false;
  double _volumeMusique = 0.7;
  final Map<String, int> _suivant = {};

  /// La musique est atténuée sous un bruitage.
  bool get attenue => _attenue;

  /// Lancement du chrono : le son Destiny, puis, dès qu'il est fini, la
  /// musique de l'acte 1 en fondu, en boucle. Pas de bruitage : le palier 1
  /// se joue à la main (« Danger »).
  Future<void> ouverture() async {
    if (!_peutJouer) return;
    _ouverte = true;
    final seq = ++_seq;
    _jetonMusique++;
    _acte = 1;
    _etapeVers(EtapeConduite.ouverture);
    if (lecteurs[BusSon.musique]!.actif) {
      await _fondre(BusSon.musique, 0, _v.fonduSortie);
      if (seq != _seq) return;
      await lecteurs[BusSon.musique]!.arreter();
    }
    // Le spectacle démarre par la musique de l'acte 1 (un son d'ouverture
    // avant, seulement si on en a choisi un).
    if (AudioService.assetsEffets.containsKey(_v.sonOuverture)) {
      _etapeVers(EtapeConduite.sonDestiny);
      await _sonDestiny(_v.sonOuverture, seq);
      if (seq != _seq) return;
    }
    _etapeVers(EtapeConduite.musique);
    await _lancerMusique(1, seq);
    if (seq == _seq) _etapeVers(EtapeConduite.repos);
  }

  /// Le [numero]-ième DESTINY (1 à 3) ouvre l'acte [numero] + 1 : sortie de
  /// la musique, son Destiny jusqu'à sa vraie fin, stinger éventuel, bruitage
  /// du nouveau palier, silence, puis la musique de l'acte (atténuée tant que
  /// le bruitage joue).
  Future<void> destiny(int numero) async {
    if (!_peutJouer) return;
    final seq = ++_seq;
    _jetonMusique++;
    final acte = (numero + 1).clamp(1, 4);
    _acte = acte;
    _jetonBruitage++;
    _etapeVers(EtapeConduite.sortieMusique);
    // La musique sort en fondu, et le bruitage de l'acte d'avant avec elle.
    const sortants = [BusSon.musique, BusSon.bruitageA, BusSon.bruitageB];
    await Future.wait([
      for (final b in sortants)
        if (lecteurs[b]!.actif) _fondre(b, 0, _v.fonduSortie),
    ]);
    if (seq != _seq) return;
    for (final b in sortants) {
      await lecteurs[b]!.arreter();
    }
    _attenue = false;
    _etapeVers(EtapeConduite.sonDestiny);
    await _sonDestiny(_v.sonDestiny, seq);
    if (seq != _seq) return;
    if (active && _v.revealActe[acte - 1]) {
      _etapeVers(EtapeConduite.reveal);
      await _reveal(seq);
      if (seq != _seq) return;
    }
    if (active && _v.bruitageAuto[acte - 1]) {
      _etapeVers(EtapeConduite.bruitage);
      // Pas attendu : la musique entre pendant le bruitage, atténuée.
      unawaited(_jouerBruitages(bruitagesDuPalier(acte), seq));
    }
    _etapeVers(EtapeConduite.musique);
    await _lancerMusique(acte, seq);
    if (seq == _seq) _etapeVers(EtapeConduite.repos);
  }

  /// Bouton « Danger » : rejoue le bruitage du palier en cours, musique
  /// atténuée.
  Future<void> danger() async {
    if (!_peutJouer || !active || _dangerId == null) return;
    await _jouerBruitages(bruitagesDuPalier(_acte), _seq);
  }

  /// Bouton « Autre » : le candidat suivant pour chaque code du palier, joué
  /// aussitôt.
  Future<void> autre() async {
    final d = _m?.dangers[_dangerId];
    if (d == null) return;
    for (final code in d.codes(_acte)) {
      _suivant[code] = (_suivant[code] ?? 0) + 1;
    }
    await danger();
  }

  /// « Fondu de fin » : tout s'éteint ensemble, puis s'arrête.
  Future<void> fonduFin([double? secondes]) async {
    final seq = ++_seq;
    _jetonMusique++;
    _jetonBruitage++;
    _etapeVers(EtapeConduite.fin);
    await Future.wait([
      for (final b in BusSon.values)
        if (lecteurs[b]!.actif) _fondre(b, 0, secondes ?? _v.fonduFin),
    ]);
    if (seq != _seq) return;
    await _toutArreter();
    _etapeVers(EtapeConduite.repos);
  }

  /// Arrête net la séquence en cours (Destiny, stinger, bruitages) ; la
  /// musique reste où elle en est.
  Future<void> annulerSequence() async {
    _seq++;
    _jetonBruitage++;
    for (final b in [BusSon.destiny, BusSon.stinger, BusSon.bruitageA, BusSon.bruitageB]) {
      _annulerFondu(b);
      await lecteurs[b]!.arreter();
    }
    if (_attenue) {
      _attenue = false;
      _annulerFondu(BusSon.musique);
      _niveau[BusSon.musique] = _volumeMusique;
      await _appliquer(BusSon.musique);
    }
    _etapeVers(EtapeConduite.repos);
  }

  /// Arrête tout, tout de suite.
  Future<void> stopTout() async {
    _seq++;
    _jetonMusique++;
    _jetonBruitage++;
    await _toutArreter();
    _etapeVers(EtapeConduite.repos);
  }

  Future<void> _toutArreter() async {
    _attenue = false;
    for (final b in BusSon.values) {
      _annulerFondu(b);
      await lecteurs[b]!.arreter();
    }
  }

  void _surMuet() {
    if (_muetNotifier?.value ?? false) unawaited(stopTout());
  }

  // --------------------------------------------------------- les morceaux

  Future<void> _sonDestiny(String cle, int seq) async {
    final asset = AudioService.assetsEffets[cle];
    if (asset == null) return; // « aucun »
    final l = lecteurs[BusSon.destiny]!;
    await _jouerSur(BusSon.destiny, SourceAsset(asset, titre: 'Destiny'), niveau: 1);
    if (_v.chevauchement > 0) {
      final d = await l.duree();
      if (d != null) {
        final avant = d - _s(_v.chevauchement);
        if (avant > Duration.zero) await _attendreFin(BusSon.destiny, max: avant);
        return;
      }
    }
    await _attendreFin(BusSon.destiny);
  }

  /// Le stinger de révélation, coupé en fondu à sa durée maximale.
  Future<void> _reveal(int seq) async {
    final m = _m;
    if (m == null) return;
    final candidats = candidatsReveal(m, pack.index);
    if (candidats.isEmpty) return;
    final rang = _v.revealFichier == kCandidatAleatoire
        ? _hasard.nextInt(candidats.length)
        : _v.revealFichier.clamp(0, candidats.length - 1);
    final chemin = candidats[rang];
    await _jouerSur(BusSon.stinger, SourcePack(chemin, titre: 'REVEAL'), niveau: 1);
    final duree = m.dureeDe(chemin);
    if (duree != null && duree <= _v.revealMax) {
      await _attendreFin(BusSon.stinger, max: _s(duree + 1));
      return;
    }
    final fondu = min(1.0, _v.revealMax / 4);
    await _attendreFin(BusSon.stinger, max: _s(_v.revealMax - fondu));
    if (seq != _seq || !lecteurs[BusSon.stinger]!.actif) return;
    await _fondre(BusSon.stinger, 0, fondu);
    if (seq == _seq) await lecteurs[BusSon.stinger]!.arreter();
  }

  /// Les bruitages du palier [palier] pour le danger en cours.
  List<BruitageResolu> bruitagesDuPalier(int palier) {
    final m = _m;
    final d = _dangerId;
    if (m == null || d == null) return const [];
    return resoudreBruitage(m, pack.index, d, palier,
        choix: _v.choixCandidat, suivant: _suivant, hasard: _hasard);
  }

  /// Joue [liste] : le 2ᵉ code décalé, chacun coupé à la durée maximale avec
  /// un fondu ; la musique est atténuée pendant, puis remonte.
  Future<void> _jouerBruitages(List<BruitageResolu> liste, int seq) async {
    if (liste.isEmpty) return;
    final jeton = ++_jetonBruitage;
    _attenuer();
    var finMax = 0.0;
    for (var i = 0; i < liste.length; i++) {
      final b = liste[i];
      if (i > 0) {
        await _attendre(_s(_v.decalageCodes));
        if (seq != _seq || jeton != _jetonBruitage) return;
      }
      final bus = i.isEven ? BusSon.bruitageA : BusSon.bruitageB;
      final source = SourcePack(b.chemin, titre: _m?.sons[b.codeJoue]?.nom ?? b.codeJoue);
      await _jouerSur(bus, source, niveau: (_v.volumeBruitage * _v.volumeDe(b.codeJoue)).clamp(0.0, 1.0));
      final duree = min(b.dureeS ?? _v.dureeMaxBruitage, _v.dureeMaxBruitage);
      finMax = max(finMax, i * _v.decalageCodes + duree);
      if ((b.dureeS ?? double.infinity) > _v.dureeMaxBruitage) {
        unawaited(_couperApres(bus, source, _v.dureeMaxBruitage - _v.fonduBruitage, _v.fonduBruitage));
      }
    }
    await _attendre(_s(max(0, finMax - (liste.length - 1) * _v.decalageCodes)));
    if (jeton != _jetonBruitage) return; // un bruitage plus récent gère la musique
    _remonter();
  }

  Future<void> _couperApres(BusSon b, SourceSon source, double apres, double fondu) async {
    await _attendre(_s(max(0, apres)));
    if (lecteurs[b]!.enCours != source) return;
    await _fondre(b, 0, fondu);
    if (lecteurs[b]!.enCours == source) await lecteurs[b]!.arreter();
  }

  void _attenuer() {
    _attenue = true;
    if (lecteurs[BusSon.musique]!.actif) {
      unawaited(_fondre(BusSon.musique, _volumeMusique * _v.attenuation, 0.3));
    }
    notifyListeners();
  }

  void _remonter() {
    _attenue = false;
    if (lecteurs[BusSon.musique]!.actif) unawaited(_fondre(BusSon.musique, _volumeMusique, _v.remontee));
    notifyListeners();
  }

  /// La musique de l'acte [acte] pour le lieu en cours.
  MusiqueResolue musiqueDe(int acte) {
    final m = _m;
    final l = _lieuId;
    if (m == null || l == null) return MusiqueResolue.aucune;
    return resoudreMusique(m, pack.index, l, acte, repliFamille: _v.repliFamille);
  }

  /// La musique de l'acte [acte], à jouer : celle du pack pour le lieu, ou,
  /// sans pack, celle des réglages de Destiny. null : pas de musique (acte
  /// désactivé, « aucune », ou rien de trouvé).
  SourceSon? sourceActe(int acte) {
    if (acte < 1 || acte > 4 || !_v.musiqueActe[acte - 1]) return null;
    if (active) {
      final chemin = musiqueDe(acte).chemin;
      return chemin == null ? null : SourcePack(chemin, titre: titreMusique(acte));
    }
    final lieu = _lieuId;
    final choix = choixSansPack?.call(acte) ?? '';
    if (choix.isEmpty || choix == 'aucune' || choix == 'aleatoire') return null;
    if (choix == 'lieu') {
      return lieu == null ? null : SourceAsset(cheminAmbiance(lieu), titre: titreMusique(acte));
    }
    return SourceAsset(choix, titre: titreMusique(acte));
  }

  /// L'ambiance embarquée d'un lieu.
  static String cheminAmbiance(String lieuId) => 'audio/ambiences/$lieuId.m4a';

  /// L'acte dont la musique joue en ce moment (null : autre chose, ou rien).
  int? get acteEnCours {
    final l = lecteurs[BusSon.musique]!;
    return l.enCours != null && identical(l.enCours, _sourceActe) ? _acteSource : null;
  }

  /// L'ambiance du lieu joue en ce moment.
  bool get ambianceEnCours {
    final l = lecteurs[BusSon.musique]!;
    return l.enCours != null && identical(l.enCours, _sourceAmbiance);
  }

  SourceSon? _sourceActe;
  int? _acteSource;
  SourceSon? _sourceAmbiance;

  /// La musique de l'acte [acte], puis, à sa vraie fin, le bruitage du palier
  /// et l'ambiance du lieu. Sans musique pour cet acte, on passe tout de suite
  /// à la suite.
  Future<void> _lancerMusique(int acte, int seq) async {
    final source = sourceActe(acte);
    if (source == null) {
      unawaited(_apresMusique(acte, null));
      return;
    }
    avantMusique?.call();
    _volumeMusique = _v.volumeActe[acte - 1];
    _sourceActe = source;
    _acteSource = acte;
    await _jouerSur(BusSon.musique, source, niveau: 0, boucle: _v.boucle);
    if (seq != _seq) {
      await lecteurs[BusSon.musique]!.arreter();
      return;
    }
    unawaited(_courbe(source, _dureeMusique(acte, source.chemin), _v.courbes[acte - 1], _v.finAZero[acte - 1], _volumeMusique));
    unawaited(_apresMusique(acte, source));
    await _fondre(BusSon.musique, _attenue ? _volumeMusique * _v.attenuation : _volumeMusique, _v.fonduEntree[acte - 1]);
  }

  /// Change à chaque intervention de la régie sur la musique (Destiny, Stop,
  /// autre pad…) : seule une musique arrivée à sa vraie fin appelle le
  /// bruitage.
  int _jetonMusique = 0;

  /// Quand la musique de l'acte [acte] arrive à sa vraie fin (ou tout de
  /// suite, s'il n'y en a pas) : le bruitage du palier (avec le pack), puis
  /// l'ambiance du lieu, en fond, jusqu'au Destiny suivant.
  Future<void> _apresMusique(int acte, SourceSon? source) async {
    final jeton = _jetonMusique;
    final l = lecteurs[BusSon.musique]!;
    if (source != null) await l.fin;
    bool toujours() => jeton == _jetonMusique && l.enCours == null && _peutJouer && _acte == acte;
    if (!toujours()) return;
    if (active && _v.bruitageFinMusique[acte - 1]) {
      _etapeVers(EtapeConduite.bruitage);
      await _jouerBruitages(bruitagesDuPalier(acte), _seq);
      if (_etape == EtapeConduite.bruitage) _etapeVers(EtapeConduite.repos);
      if (!toujours()) return;
    }
    if (_v.ambianceApresMusique) await jouerAmbiance();
  }

  /// L'ambiance du lieu (`assets/audio/ambiences/<lieu>.m4a`), en boucle et
  /// basse (15 % par défaut) : le fond entre la musique d'un acte et le
  /// Destiny suivant.
  Future<void> jouerAmbiance() async {
    final lieu = _lieuId;
    if (lieu == null) return;
    final source = SourceAsset(cheminAmbiance(lieu), titre: 'Ambiance · ${_m?.lieux[lieu]?.nom ?? lieu}');
    _sourceAmbiance = source;
    await jouerMusique(source, volume: _v.volumeAmbiance, boucle: true, fondu: 3);
  }

  /// La durée de la musique d'un acte, si le manifeste la donne pour ce fichier.
  double? _dureeMusique(int acte, String chemin) {
    if (!active) return null;
    final m = _m?.lieux[_lieuId]?.musiques[acte];
    if (m != null && pack.index.trouver(m.fichier) == chemin) return m.dureeS;
    for (final l in _m?.lieux.values ?? const <LieuPack>[]) {
      for (final x in l.musiques.values) {
        if (pack.index.trouver(x.fichier) == chemin) return x.dureeS;
      }
    }
    return null;
  }

  /// « Acte 2 · Église » : le nom affiché de la musique d'un acte.
  String titreMusique(int acte) {
    final nom = _m?.lieux[_lieuId]?.nom ?? _lieuId;
    return nom == null ? 'Acte $acte' : 'Acte $acte · $nom';
  }

  // ------------------------------------------------- la table de régie

  /// Un pad de musique : enchaîne en fondu sur la voie musique (une seule
  /// musique à la fois).
  Future<void> jouerMusique(SourceSon source,
      {double volume = 0.7, bool? boucle, double fondu = 1.5, double? dureeS, int? courbeActe}) async {
    if (_muet()) return;
    final seq = ++_seq;
    _jetonMusique++;
    if (lecteurs[BusSon.musique]!.actif) {
      await _fondre(BusSon.musique, 0, 0.8);
      if (seq != _seq) return;
    }
    avantMusique?.call();
    _volumeMusique = volume;
    _attenue = false;
    _sourceActe = courbeActe == null ? null : source;
    _acteSource = courbeActe;
    await _jouerSur(BusSon.musique, source, niveau: 0, boucle: boucle ?? _v.boucle);
    if (seq != _seq) return;
    // La courbe de l'acte, pour la musique d'un acte (pas pour les pads ni
    // l'ambiance).
    if (courbeActe != null) {
      unawaited(_courbe(source, dureeS, _v.courbes[courbeActe - 1], _v.finAZero[courbeActe - 1], volume));
    }
    await _fondre(BusSon.musique, volume, fondu);
  }

  /// Le pad d'un acte : la musique de cet acte pour le lieu en cours.
  Future<void> musiqueActe(int acte) async {
    final source = sourceActe(acte);
    if (source == null) return;
    await jouerMusique(source,
        volume: _v.volumeActe[acte - 1], fondu: 2, dureeS: _dureeMusique(acte, source.chemin), courbeActe: acte);
  }

  /// Un pad d'effet ponctuel (stinger, Destiny, son embarqué) sur sa voie.
  Future<void> jouerEffet(SourceSon source, {BusSon bus = BusSon.stinger, double niveau = 1}) async {
    if (_muet()) return;
    await _jouerSur(bus, source, niveau: niveau);
  }

  /// Un pad de la banque : un code de bruitage, avec atténuation de la musique.
  Future<void> jouerCode(String code) async {
    final m = _m;
    if (m == null || _muet()) return;
    final r = resoudreCode(m, pack.index, code, choix: _v.choixCandidat, suivant: _suivant, hasard: _hasard);
    if (r == null) return;
    await _jouerBruitages([r], _seq);
  }

  /// Appui long sur un pad de la banque : le candidat suivant de ce code.
  Future<void> autreCode(String code) async {
    _suivant[code] = (_suivant[code] ?? 0) + 1;
    await jouerCode(code);
  }

  /// Le pad du son Destiny, sans rien enchaîner.
  Future<void> jouerSonDestiny() async {
    final asset = AudioService.assetsEffets[_v.sonDestiny] ?? AudioService.stormAsset;
    await jouerEffet(SourceAsset(asset, titre: 'Destiny'), bus: BusSon.destiny);
  }

  /// Le pad REVEAL : un stinger de révélation, sans enchaîner.
  Future<void> jouerReveal() async {
    if (_muet()) return;
    await _reveal(_seq);
  }

  /// Arrête une voie (bouton stop d'une tranche).
  Future<void> arreterBus(BusSon b) async {
    if (b == BusSon.musique) _jetonMusique++;
    _annulerFondu(b);
    await lecteurs[b]!.arreter();
    if (b == BusSon.bruitageA || b == BusSon.bruitageB) {
      if (!lecteurs[BusSon.bruitageA]!.actif && !lecteurs[BusSon.bruitageB]!.actif && _attenue) _remonter();
    }
  }

  /// La musique de conclusion (option « à la fin du chrono »).
  Future<void> conclusion() => jouerMusique(const SourceAsset('music/02_conclusionainsique.m4a', titre: 'Conclusion'),
      volume: 0.8, boucle: false, fondu: 3);

  @override
  void dispose() {
    _muetNotifier?.removeListener(_surMuet);
    for (final l in lecteurs.values) {
      l.removeListener(notifyListeners);
      l.liberer();
    }
    super.dispose();
  }
}
