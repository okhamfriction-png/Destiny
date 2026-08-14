import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/archetype.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/player_assignment.dart';
import '../../domain/entities/story.dart';
import 'story_state.dart';

/// La dernière scène générée (histoire / rue / dilemme), avec son mode.
class LastGeneration {
  const LastGeneration({required this.story, required this.mode});

  final Story story;
  final GeneratorMode mode;
}

/// Persiste la dernière génération pour la restaurer au redémarrage.
class LastGenerationStore {
  static const _kKey = 'last_generation';

  Future<void> save(Story story, GeneratorMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(_toJson(story, mode)));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
    } catch (_) {}
  }

  Future<LastGeneration?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return null;
      return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toJson(Story s, GeneratorMode mode) => {
        'mode': mode.name,
        'location': s.location.toJson(),
        'danger': s.danger.toJson(),
        'players': [
          for (final p in s.players)
            {
              'playerIndex': p.playerIndex,
              'role': p.role,
              'archetype': p.archetype.toJson(),
            },
        ],
        'dilemma': s.dilemma?.toJson(),
        'cycle': s.cycle,
        'usedCount': s.usedCount,
        'totalCombos': s.totalCombos,
      };

  static LastGeneration _fromJson(Map<String, dynamic> j) {
    final mode = GeneratorMode.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => GeneratorMode.histoire,
    );
    final story = Story(
      location: Location.fromJson(j['location'] as Map<String, dynamic>),
      danger: Danger.fromJson(j['danger'] as Map<String, dynamic>),
      players: [
        for (final p in (j['players'] as List<dynamic>? ?? const []))
          PlayerAssignment(
            playerIndex: (p as Map<String, dynamic>)['playerIndex'] as int,
            role: p['role'] as String? ?? '',
            archetype:
                Archetype.fromJson(p['archetype'] as Map<String, dynamic>),
          ),
      ],
      dilemma: j['dilemma'] == null
          ? null
          : Dilemma.fromJson(j['dilemma'] as Map<String, dynamic>),
      cycle: j['cycle'] as int? ?? 1,
      usedCount: j['usedCount'] as int? ?? 1,
      totalCombos: j['totalCombos'] as int? ?? 1,
    );
    return LastGeneration(story: story, mode: mode);
  }
}
