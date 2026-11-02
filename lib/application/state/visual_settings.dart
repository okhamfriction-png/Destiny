import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Source des visuels des cartes.
enum VisualSource {
  /// Les illustrations embarquées (assets/images).
  ai,

  /// Rendu vectoriel stylisé, hors ligne.
  vector,

  /// Visuel minimal : la première lettre, sans image.
  minimal,
}

/// Réglages d'apparence : visuels des cartes, texte de l'histoire avec l'IA,
/// mode admin. Les anciens réglages du chrono TOP et du dé restent dans la
/// mémoire du téléphone, mais l'appli ne les lit plus.
class VisualSettings extends ChangeNotifier {
  VisualSettings() {
    _load();
  }

  static const _kTextScale = 'text_scale';
  static const _kHandwritten = 'chat_handwritten';
  static const _kSource = 'visual_source';
  static const _kAdmin = 'admin_mode';

  VisualSource _source = VisualSource.ai;
  double _textScale = 1.0;
  bool _handwritten = false;
  bool _adminMode = false;

  VisualSource get source => _source;

  /// Facteur d'échelle du texte de l'histoire avec l'IA. Bornes [0.8, 1.6].
  double get textScale => _textScale;

  /// Écriture manuscrite dans l'histoire avec l'IA (police Patrick Hand).
  bool get handwritten => _handwritten;
  static const String handwrittenFamily = 'PatrickHand';

  /// Mode admin : montre les outils de vérification de la grammaire.
  bool get adminMode => _adminMode;

  Future<void> _ecrire(Future<void> Function(SharedPreferences p) f) async {
    try {
      await f(await SharedPreferences.getInstance());
    } catch (_) {
      // Persistance indisponible : ignorée.
    }
  }

  Future<void> setAdminMode(bool value) async {
    if (value == _adminMode) return;
    _adminMode = value;
    notifyListeners();
    await _ecrire((p) => p.setBool(_kAdmin, value));
  }

  Future<void> setSource(VisualSource source) async {
    if (_source == source) return;
    _source = source;
    notifyListeners();
    await _ecrire((p) => p.setString(_kSource, source.name));
  }

  Future<void> setTextScale(double value) async {
    final v = value.clamp(0.8, 1.6);
    if (v == _textScale) return;
    _textScale = v;
    notifyListeners();
    await _ecrire((p) => p.setDouble(_kTextScale, v));
  }

  Future<void> setHandwritten(bool value) async {
    if (value == _handwritten) return;
    _handwritten = value;
    notifyListeners();
    await _ecrire((p) => p.setBool(_kHandwritten, value));
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _textScale = prefs.getDouble(_kTextScale) ?? 1.0;
      _handwritten = prefs.getBool(_kHandwritten) ?? false;
      _source = VisualSource.values.firstWhere((s) => s.name == prefs.getString(_kSource),
          orElse: () => VisualSource.ai);
      _adminMode = prefs.getBool(_kAdmin) ?? false;
      notifyListeners();
    } catch (_) {
      // Valeurs par défaut conservées.
    }
  }
}
