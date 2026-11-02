import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/troupe/session.dart';

/// L'historique des spectacles et répétitions de la troupe, et la session en
/// cours. Tout reste sur l'appareil (aucun réseau).
class TroupeStore extends ChangeNotifier {
  static const String _cle = 'troupe_sessions_v1';

  final List<SessionTroupe> _sessions = [];
  bool _lectureEchouee = false;

  /// Les sessions, de la plus récente à la plus ancienne.
  List<SessionTroupe> get sessions =>
      List.unmodifiable([..._sessions]..sort((a, b) => b.date.compareTo(a.date)));

  /// La session en cours (pas encore terminée), s'il y en a une.
  SessionTroupe? get enCours {
    for (final s in sessions) {
      if (s.etape != EtapeSession.terminee) return s;
    }
    return null;
  }

  Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut != null) {
        _sessions
          ..clear()
          ..addAll([
            for (final e in jsonDecode(brut) as List)
              SessionTroupe.depuisJson(Map<String, dynamic>.from(e as Map)),
          ]);
      }
    } catch (_) {
      // Jamais d'écriture par-dessus des données qu'on n'a pas su lire.
      _lectureEchouee = true;
    }
    notifyListeners();
  }

  /// Crée une nouvelle session et la rend « en cours ».
  Future<SessionTroupe> nouvelle({TypeSession type = TypeSession.repetition}) async {
    final s = SessionTroupe(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      type: type,
    );
    _sessions.add(s);
    await enregistrer(s);
    return s;
  }

  /// Enregistre une session modifiée.
  Future<void> enregistrer(SessionTroupe s) async {
    if (!_sessions.contains(s)) {
      _sessions.removeWhere((x) => x.id == s.id);
      _sessions.add(s);
    }
    notifyListeners();
    await _sauver();
  }

  Future<void> supprimer(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
    await _sauver();
  }

  Future<void> _sauver() async {
    if (_lectureEchouee) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, jsonEncode([for (final s in _sessions) s.versJson()]));
    } catch (_) {}
  }
}
