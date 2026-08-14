import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/story.dart';

/// Une entrée d'historique du générateur (ce qui a été tiré).
class GenerationRecord {
  const GenerationRecord({
    required this.createdAt,
    required this.location,
    required this.danger,
    required this.dangerStyle,
    required this.paliers,
    required this.archetypes,
    required this.roles,
    required this.rue,
    this.mode = 'histoire',
    this.dilemma = '',
  });

  final int createdAt; // epoch ms
  final String location;
  final String danger;
  final String dangerStyle;
  final List<String> paliers;
  final List<String> archetypes;
  final List<String> roles;
  final bool rue;

  /// Mode de génération : histoire / rue / dilemme.
  final String mode;

  /// Nom du dilemme (mode Dilemme).
  final String dilemma;

  factory GenerationRecord.fromStory(Story s,
          {required bool rue, String mode = 'histoire'}) =>
      GenerationRecord(
        createdAt: DateTime.now().millisecondsSinceEpoch,
        location: s.location.name,
        danger: s.danger.name,
        dangerStyle: s.danger.style,
        paliers: s.danger.paliers,
        archetypes: s.players.map((p) => p.archetype.name).toList(),
        roles: s.players.map((p) => p.role).toList(),
        rue: rue,
        mode: mode,
        dilemma: s.dilemma?.nom ?? '',
      );

  factory GenerationRecord.fromJson(Map<String, dynamic> j) => GenerationRecord(
        createdAt: j['createdAt'] as int? ?? 0,
        location: j['location'] as String? ?? '',
        danger: j['danger'] as String? ?? '',
        dangerStyle: j['dangerStyle'] as String? ?? '',
        paliers: (j['paliers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        archetypes: (j['archetypes'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        roles:
            (j['roles'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        rue: j['rue'] as bool? ?? false,
        mode: j['mode'] as String? ?? 'histoire',
        dilemma: j['dilemma'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt,
        'location': location,
        'danger': danger,
        'dangerStyle': dangerStyle,
        'paliers': paliers,
        'archetypes': archetypes,
        'roles': roles,
        'rue': rue,
        'mode': mode,
        'dilemma': dilemma,
      };
}

/// Historique persistant des scènes générées (shared_preferences, plafonné).
class GenerationHistory extends ChangeNotifier {
  GenerationHistory() {
    _load();
  }

  static const _kKey = 'generation_history';
  static const _max = 60;

  List<GenerationRecord> _records = const [];
  List<GenerationRecord> get records => _records;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        _records = (jsonDecode(raw) as List<dynamic>)
            .map((e) => GenerationRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> add(GenerationRecord record) async {
    _records = [record, ..._records];
    if (_records.length > _max) {
      _records = _records.sublist(0, _max);
    }
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _records = const [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kKey, jsonEncode(_records.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }
}
