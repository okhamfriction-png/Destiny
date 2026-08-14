import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/spectacle_turn.dart';

/// Historique persistant des spin-off générés (mode Générateur). Sert aussi à
/// ne jamais retirer deux fois le même film tant que l'historique n'est pas vidé.
class SpinoffHistory extends ChangeNotifier {
  SpinoffHistory() {
    _load();
  }

  static const _kKey = 'spinoff_history';
  static const _max = 200;

  List<Map<String, dynamic>> _records = const [];
  List<Map<String, dynamic>> get records => List.unmodifiable(_records);

  /// Titres déjà tirés (pour les fournir à l'IA comme films à éviter).
  List<String> get titles => [
        for (final r in _records)
          ((r['context'] as Map?)?['film'] ?? '').toString(),
      ].where((t) => t.isNotEmpty).toList();

  static String _norm(String s) => s.toLowerCase().trim();

  bool contains(String title) {
    final n = _norm(title);
    if (n.isEmpty) return false;
    return titles.any((t) => _norm(t) == n);
  }

  Future<void> add({
    required FilmContext film,
    required String decade,
    required String genre,
  }) async {
    _records = [
      {
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'decade': decade,
        'genre': genre,
        'context': film.toJson(),
      },
      ..._records,
    ];
    if (_records.length > _max) _records = _records.sublist(0, _max);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _records = const [];
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      _records = (jsonDecode(raw) as List<dynamic>)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(_records));
    } catch (_) {}
  }
}
