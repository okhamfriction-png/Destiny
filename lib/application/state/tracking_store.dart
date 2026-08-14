import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une relation entre deux joueurs (indices 1-based), partagée par les 3 actes.
class TrackRelation {
  const TrackRelation({required this.id, required this.a, required this.b});
  final String id;
  final int a;
  final int b;

  Map<String, dynamic> toJson() => {'id': id, 'a': a, 'b': b};
  factory TrackRelation.fromJson(Map<String, dynamic> j) => TrackRelation(
        id: j['id'] as String,
        a: j['a'] as int,
        b: j['b'] as int,
      );
}

/// Suivi de répétition Destiny : joueurs + relations (créés à l'Acte 1, hérités
/// aux Actes 2 et 3) et cellules à 3 états (0 vide, 1 rond, 2 croix). Persisté.
///
/// N'écrit JAMAIS dans le générateur : il ne fait qu'importer (lecture) le
/// nombre de joueurs et les archétypes de l'histoire tirée.
class TrackingStore extends ChangeNotifier {
  TrackingStore() {
    _seedDefaultRelations();
    _load();
  }

  /// Boucle standard de l'Acte 1 : J1–J2, J3–J4, J2–J3, J4–J1.
  void _seedDefaultRelations() {
    _relations
      ..clear()
      ..add(const TrackRelation(id: 'r1', a: 1, b: 2))
      ..add(const TrackRelation(id: 'r2', a: 3, b: 4))
      ..add(const TrackRelation(id: 'r3', a: 2, b: 3))
      ..add(const TrackRelation(id: 'r4', a: 4, b: 1));
    _nextRel = 5;
  }

  static const _kKey = 'tracking_store_v1';

  // --- Config partagée (les 3 actes) ---
  int _playerCount = 4;
  List<String> _playerLabels = const []; // archétypes/noms (optionnel)
  final List<TrackRelation> _relations = [];
  int _nextRel = 1;
  // Intitulés des colonnes de l'Acte 1 (C · O · W · A), éditables.
  List<String> _act1Cols = const ['C', 'O', 'W', 'A'];

  // --- États des cellules (clé → 0/1/2) ---
  final Map<String, int> _act1Cells = {}; // "p|col"
  final Map<String, int> _act1Rel = {}; // relId (relation validée à l'Acte 1)
  // Actes 2 et 3 : tableau O + A par joueur. Valeurs REPORTÉES de l'acte
  // précédent tant qu'on n'a pas d'override explicite pour cet acte.
  final Map<String, int> _act2O = {}; // "p"
  final Map<String, int> _act2A = {}; // "p"
  final Map<String, int> _act3O = {}; // "p"
  final Map<String, int> _act3A = {}; // "p"
  // Relations reportées d'un acte à l'autre (état par acte).
  final Map<String, int> _act2Rel = {}; // relId
  final Map<String, int> _act3Rel = {}; // relId

  // --------------------------------------------------------------- getters
  int get playerCount => _playerCount;
  List<TrackRelation> get relations => List.unmodifiable(_relations);
  List<String> get act1Cols => List.unmodifiable(_act1Cols);

  /// Étiquette d'un joueur (archétype importé sinon « Jn »).
  String playerLabel(int index) {
    if (index >= 1 && index <= _playerLabels.length) {
      final l = _playerLabels[index - 1].trim();
      if (l.isNotEmpty) return l;
    }
    return 'J$index';
  }

  String relationLabel(TrackRelation r) =>
      '${playerLabel(r.a)} – ${playerLabel(r.b)}';

  int act1Cell(int player, int col) => _act1Cells['$player|$col'] ?? 0;
  int act1RelState(String relId) => _act1Rel[relId] ?? 0;

  // Colonnes O (index 1) et A (index 3) du tableau, reportées d'un acte à
  // l'autre : Acte 1 → Acte 2 → Acte 3.
  static const int colO = 1;
  static const int colA = 3;
  int act2OState(int p) => _act2O['$p'] ?? act1Cell(p, colO);
  int act2AState(int p) => _act2A['$p'] ?? act1Cell(p, colA);
  int act3OState(int p) => _act3O['$p'] ?? act2OState(p);
  int act3AState(int p) => _act3A['$p'] ?? act2AState(p);

  // Relations : reportées Acte 1 → Acte 2 → Acte 3.
  int act2RelState(String relId) => _act2Rel[relId] ?? act1RelState(relId);
  int act3RelState(String relId) => _act3Rel[relId] ?? act2RelState(relId);

  /// Nombre de relations validées à l'Acte 1 (croix). Sert au rappel « min 2 ».
  int get validatedRelationsAct1 =>
      _relations.where((r) => act1RelState(r.id) >= 2).length;

  // --------------------------------------------------------------- édition
  int _cycle(Map<String, int> m, String key) {
    final next = ((m[key] ?? 0) + 1) % 3;
    if (next == 0) {
      m.remove(key);
    } else {
      m[key] = next;
    }
    _bump();
    return next;
  }

  void cycleAct1Cell(int player, int col) => _cycle(_act1Cells, '$player|$col');
  void cycleAct1Rel(String relId) => _cycle(_act1Rel, relId);

  // Actes reportés : on stocke un override explicite (0 compris) pour pouvoir
  // repasser sous la valeur héritée de l'acte précédent.
  void _cycleReportedKey(Map<String, int> m, String key, int currentEff) {
    m[key] = (currentEff + 1) % 3;
    _bump();
  }

  void _cycleReported(Map<String, int> m, int player, int currentEff) =>
      _cycleReportedKey(m, '$player', currentEff);

  void cycleAct2O(int p) => _cycleReported(_act2O, p, act2OState(p));
  void cycleAct2A(int p) => _cycleReported(_act2A, p, act2AState(p));
  void cycleAct3O(int p) => _cycleReported(_act3O, p, act3OState(p));
  void cycleAct3A(int p) => _cycleReported(_act3A, p, act3AState(p));
  void cycleAct2Rel(String id) =>
      _cycleReportedKey(_act2Rel, id, act2RelState(id));
  void cycleAct3Rel(String id) =>
      _cycleReportedKey(_act3Rel, id, act3RelState(id));

  Future<void> setPlayerCount(int n) async {
    n = n.clamp(2, 10);
    if (n == _playerCount) return;
    _playerCount = n;
    // Retire les relations qui pointent vers un joueur disparu.
    _relations.removeWhere((r) => r.a > n || r.b > n);
    notifyListeners();
    await _save();
  }

  Future<void> setColumnLabel(int index, String label) async {
    if (index < 0 || index >= _act1Cols.length) return;
    final cols = List.of(_act1Cols);
    cols[index] = label.trim().isEmpty ? _act1Cols[index] : label.trim();
    _act1Cols = cols;
    notifyListeners();
    await _save();
  }

  Future<void> addRelation(int a, int b) async {
    if (a == b || a < 1 || b < 1 || a > _playerCount || b > _playerCount) {
      return;
    }
    _relations.add(TrackRelation(id: 'r${_nextRel++}', a: a, b: b));
    notifyListeners();
    await _save();
  }

  Future<void> removeRelation(String relId) async {
    _relations.removeWhere((r) => r.id == relId);
    _act1Rel.remove(relId);
    _act2Rel.remove(relId);
    _act3Rel.remove(relId);
    notifyListeners();
    await _save();
  }

  /// Importe le nombre de joueurs + les archétypes depuis l'histoire tirée
  /// (lecture seule du générateur). Ne crée pas de relations.
  Future<void> importFromStory(int count, List<String> archetypes) async {
    _playerCount = count.clamp(2, 10);
    _playerLabels = List.of(archetypes);
    _relations.removeWhere((r) => r.a > _playerCount || r.b > _playerCount);
    notifyListeners();
    await _save();
  }

  /// Efface uniquement les coches (garde joueurs + relations).
  Future<void> clearChecks() async {
    _act1Cells.clear();
    _act1Rel.clear();
    _act2O.clear();
    _act2A.clear();
    _act3O.clear();
    _act3A.clear();
    _act2Rel.clear();
    _act3Rel.clear();
    notifyListeners();
    await _save();
  }

  /// Réinitialise tout (joueurs, relations, coches) et re-sème la boucle.
  Future<void> resetAll() async {
    _playerCount = 4;
    _playerLabels = const [];
    _act1Cols = const ['C', 'O', 'W', 'A'];
    _seedDefaultRelations();
    await clearChecks();
  }

  // Regroupe notify + save (débounce léger implicite via microtask).
  bool _saving = false;
  void _bump() {
    notifyListeners();
    if (_saving) return;
    _saving = true;
    Future.microtask(() async {
      _saving = false;
      await _save();
    });
  }

  // --------------------------------------------------------------- persist
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _playerCount = (j['playerCount'] as int? ?? 4).clamp(2, 10);
      _playerLabels =
          (j['playerLabels'] as List<dynamic>? ?? []).map((e) => '$e').toList();
      _act1Cols = (j['act1Cols'] as List<dynamic>?)?.map((e) => '$e').toList() ??
          const ['C', 'O', 'W', 'A'];
      _nextRel = j['nextRel'] as int? ?? 1;
      _relations
        ..clear()
        ..addAll((j['relations'] as List<dynamic>? ?? [])
            .map((e) => TrackRelation.fromJson(e as Map<String, dynamic>)));
      void loadMap(String k, Map<String, int> m) {
        m.clear();
        final src = j[k] as Map<String, dynamic>?;
        if (src != null) {
          src.forEach((key, v) => m[key] = v as int);
        }
      }

      loadMap('act1Cells', _act1Cells);
      loadMap('act1Rel', _act1Rel);
      loadMap('act2O', _act2O);
      loadMap('act2A', _act2A);
      loadMap('act3O', _act3O);
      loadMap('act3A', _act3A);
      loadMap('act2Rel', _act2Rel);
      loadMap('act3Rel', _act3Rel);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final j = {
        'playerCount': _playerCount,
        'playerLabels': _playerLabels,
        'act1Cols': _act1Cols,
        'nextRel': _nextRel,
        'relations': _relations.map((r) => r.toJson()).toList(),
        'act1Cells': _act1Cells,
        'act1Rel': _act1Rel,
        'act2O': _act2O,
        'act2A': _act2A,
        'act3O': _act3O,
        'act3A': _act3A,
        'act2Rel': _act2Rel,
        'act3Rel': _act3Rel,
      };
      await prefs.setString(_kKey, jsonEncode(j));
    } catch (_) {}
  }
}
