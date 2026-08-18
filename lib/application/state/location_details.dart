import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Détails d'un lieu : sous-espaces jouables + vocabulaire propre au lieu.
class LocationDetails {
  const LocationDetails({
    required this.sousEspaces,
    required this.vocabulaire,
  });

  final List<String> sousEspaces;
  final List<String> vocabulaire;

  bool get isEmpty => sousEspaces.isEmpty && vocabulaire.isEmpty;

  Map<String, dynamic> toJson() =>
      {'sousEspaces': sousEspaces, 'vocabulaire': vocabulaire};

  factory LocationDetails.fromJson(Map<String, dynamic> j) => LocationDetails(
        sousEspaces: (j['sousEspaces'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList(),
        vocabulaire: (j['vocabulaire'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList(),
      );
}

/// Sous-espaces + vocabulaire par lieu. Valeurs par défaut chargées depuis
/// `assets/data/location_details.json`, surchargées (éditées) via
/// shared_preferences. Mapping nom → id pour retrouver un lieu par son nom.
class LocationDetailsStore extends ChangeNotifier {
  static const _kKey = 'location_details_overrides_v1';

  Map<String, LocationDetails> _defaults = {};
  final Map<String, LocationDetails> _overrides = {};
  final Map<String, String> _nameToId = {};
  final List<({String id, String name})> _locations = [];

  List<({String id, String name})> get locations =>
      List.unmodifiable(_locations);

  /// À appeler au démarrage (charge assets + overrides persistés).
  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/location_details.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _defaults = {
        for (final e in map.entries)
          e.key: LocationDetails.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {}
    try {
      final rawLoc = await rootBundle.loadString('assets/data/locations.json');
      final decoded = jsonDecode(rawLoc);
      final list = decoded is Map<String, dynamic>
          ? (decoded['locations'] as List<dynamic>? ?? const [])
          : (decoded as List<dynamic>);
      _locations.clear();
      _nameToId.clear();
      for (final l in list) {
        final m = l as Map<String, dynamic>;
        final id = m['id'] as String? ?? '';
        final name = m['name'] as String? ?? '';
        if (id.isEmpty) continue;
        _locations.add((id: id, name: name));
        _nameToId[name] = id;
      }
      _locations.sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {}
    await _loadOverrides();
    notifyListeners();
  }

  Future<void> _loadOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _overrides.clear();
      for (final e in map.entries) {
        _overrides[e.key] =
            LocationDetails.fromJson(e.value as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _saveOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kKey,
          jsonEncode(
              {for (final e in _overrides.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }

  LocationDetails? byId(String id) => _overrides[id] ?? _defaults[id];

  String? idForName(String name) => _nameToId[name];

  LocationDetails? byName(String name) {
    final id = _nameToId[name];
    return id == null ? null : byId(id);
  }

  /// Édite (surcharge) les détails d'un lieu.
  Future<void> setDetails(String id, LocationDetails details) async {
    _overrides[id] = details;
    notifyListeners();
    await _saveOverrides();
  }

  /// Restaure les valeurs d'origine d'un lieu (retire la surcharge).
  Future<void> resetToDefault(String id) async {
    _overrides.remove(id);
    notifyListeners();
    await _saveOverrides();
  }

  bool hasOverride(String id) => _overrides.containsKey(id);
}
