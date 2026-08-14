import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistance du Mode Spectacle : la partie en cours (reprise) et l'historique
/// des parties terminées.
class SpectacleStore {
  static const _kSession = 'spectacle_session';
  static const _kHistory = 'spectacle_history';
  static const _maxHistory = 40;

  // --- Partie en cours (un seul emplacement) ---

  Future<void> saveSession(Map<String, dynamic> snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSession, jsonEncode(snapshot));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSession);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSession);
    } catch (_) {}
  }

  // --- Historique des parties terminées ---

  Future<List<Map<String, dynamic>>> history() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistory);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addToHistory(Map<String, dynamic> record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await history();
      list.insert(0, record);
      if (list.length > _maxHistory) {
        list.removeRange(_maxHistory, list.length);
      }
      await prefs.setString(_kHistory, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kHistory);
    } catch (_) {}
  }
}
