import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Source des visuels d'entités.
enum VisualSource {
  /// Images réalistes générées (IA), embarquées en local (assets/images).
  ai,

  /// Rendu vectoriel stylisé, hors-ligne.
  vector,

  /// Visuel minimal : dégradé sobre, sans icône ni image.
  minimal;

  String get label {
    switch (this) {
      case VisualSource.ai:
        return 'Réaliste';
      case VisualSource.vector:
        return 'Vectoriel';
      case VisualSource.minimal:
        return 'Minimal';
    }
  }
}

/// Disposition du résultat du générateur.
enum ResultLayout {
  /// Lieu et danger côte à côte (compact).
  cote,

  /// Images en grand, plein largeur (façon mode Rue).
  grand,

  /// Full : tout condensé pour tenir sur un seul écran.
  full;

  String get label {
    switch (this) {
      case ResultLayout.cote:
        return 'Côté';
      case ResultLayout.grand:
        return 'Grand';
      case ResultLayout.full:
        return 'Full';
    }
  }
}

/// Réglages d'apparence : source des visuels + taille du texte (persistée).
class VisualSettings extends ChangeNotifier {
  VisualSettings() {
    _load();
  }

  static const _kTextScale = 'text_scale';
  static const _kHandwritten = 'chat_handwritten';
  static const _kBigImages = 'big_images'; // ancienne clé (bool) → migrée
  static const _kLayout = 'result_layout';
  static const _kSource = 'visual_source';
  static const _kTopSeconds = 'top_seconds';
  static const _kWArch = 'destiny_w_arch';
  static const _kWDang = 'destiny_w_dang';
  static const _kWDest = 'destiny_w_dest';
  static const _kCubeAnim = 'cube_animation';
  static const _kAdmin = 'admin_mode';

  VisualSource _source = VisualSource.ai;
  double _textScale = 1.0;
  bool _handwritten = false;
  ResultLayout _layout = ResultLayout.cote;
  int _topSeconds = 30;
  // Poids du dé DESTINY : archétype / danger / destin (0 = désactivé).
  int _wArch = 3;
  int _wDang = 2;
  int _wDest = 7;
  // Animation du cube DESTINY (dés + lancement du chrono). Désactivée par défaut.
  bool _cubeAnimation = false;
  // Mode admin : autorise l'édition du Guide et de la config. Désactivé par défaut
  // (les comédiens sont en lecture seule sur le Guide).
  bool _adminMode = false;

  VisualSource get source => _source;

  /// Mode admin : déverrouille l'édition du Guide et la configuration des
  /// tableaux. Désactivé par défaut.
  bool get adminMode => _adminMode;

  Future<void> setAdminMode(bool value) async {
    if (value == _adminMode) return;
    _adminMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAdmin, _adminMode);
    } catch (_) {}
  }

  /// Animation du cube doré (au lancer des dés et au lancement du chrono).
  /// Désactivée par défaut.
  bool get cubeAnimation => _cubeAnimation;

  Future<void> setCubeAnimation(bool value) async {
    if (value == _cubeAnimation) return;
    _cubeAnimation = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCubeAnim, _cubeAnimation);
    } catch (_) {}
  }

  /// Facteur d'échelle du texte (1.0 = normal). Bornes [0.8, 1.6].
  double get textScale => _textScale;

  /// Écriture manuscrite dans le Chat (police Patrick Hand).
  bool get handwritten => _handwritten;
  static const String handwrittenFamily = 'PatrickHand';

  /// Disposition du résultat : côté / grand / full.
  ResultLayout get resultLayout => _layout;

  /// Images du résultat EN GRAND (plein largeur) plutôt qu'à côté.
  bool get bigImages => _layout == ResultLayout.grand;

  /// Mode « full » : tout condensé sur un seul écran.
  bool get fullMode => _layout == ResultLayout.full;

  /// Durée du chrono « TOP » (secondes). 30 par défaut.
  int get topSeconds => _topSeconds;

  Future<void> setTopSeconds(int value) async {
    if (value == _topSeconds) return;
    _topSeconds = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kTopSeconds, _topSeconds);
    } catch (_) {}
  }

  /// Poids du dé DESTINY (proportion de chance). 0 = ce type ne tombe jamais.
  int get destinyWeightArchetype => _wArch;
  int get destinyWeightDanger => _wDang;
  int get destinyWeightDestin => _wDest;

  Future<void> _saveInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {}
  }

  Future<void> setDestinyWeightArchetype(int v) async {
    v = v.clamp(0, 12);
    if (v == _wArch) return;
    _wArch = v;
    notifyListeners();
    await _saveInt(_kWArch, v);
  }

  Future<void> setDestinyWeightDanger(int v) async {
    v = v.clamp(0, 12);
    if (v == _wDang) return;
    _wDang = v;
    notifyListeners();
    await _saveInt(_kWDang, v);
  }

  Future<void> setDestinyWeightDestin(int v) async {
    v = v.clamp(0, 12);
    if (v == _wDest) return;
    _wDest = v;
    notifyListeners();
    await _saveInt(_kWDest, v);
  }

  Future<void> setResultLayout(ResultLayout value) async {
    if (value == _layout) return;
    _layout = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLayout, _layout.name);
    } catch (_) {}
  }

  Future<void> setSource(VisualSource source) async {
    if (_source == source) return;
    _source = source;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSource, _source.name);
    } catch (_) {}
  }

  Future<void> setTextScale(double value) async {
    final v = value.clamp(0.8, 1.6);
    if (v == _textScale) return;
    _textScale = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kTextScale, _textScale);
    } catch (_) {
      // Persistance indisponible : ignorée.
    }
  }

  Future<void> setHandwritten(bool value) async {
    if (value == _handwritten) return;
    _handwritten = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHandwritten, _handwritten);
    } catch (_) {
      // Persistance indisponible : ignorée.
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _textScale = prefs.getDouble(_kTextScale) ?? 1.0;
      _handwritten = prefs.getBool(_kHandwritten) ?? false;
      _source = _parseSource(prefs.getString(_kSource));
      _layout = _parseLayout(
        prefs.getString(_kLayout),
        legacyBig: prefs.getBool(_kBigImages) ?? false,
      );
      _topSeconds = prefs.getInt(_kTopSeconds) ?? 30;
      _wArch = prefs.getInt(_kWArch) ?? 3;
      _wDang = prefs.getInt(_kWDang) ?? 2;
      _wDest = prefs.getInt(_kWDest) ?? 7;
      _cubeAnimation = prefs.getBool(_kCubeAnim) ?? false;
      _adminMode = prefs.getBool(_kAdmin) ?? false;
      notifyListeners();
    } catch (_) {
      // Valeurs par défaut conservées.
    }
  }

  static VisualSource _parseSource(String? name) {
    for (final s in VisualSource.values) {
      if (s.name == name) return s;
    }
    return VisualSource.ai;
  }

  static ResultLayout _parseLayout(String? name, {required bool legacyBig}) {
    for (final l in ResultLayout.values) {
      if (l.name == name) return l;
    }
    // Migration depuis l'ancien réglage booléen « grandes images ».
    return legacyBig ? ResultLayout.grand : ResultLayout.cote;
  }
}
