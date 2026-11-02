import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/archetype.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/grammaire/modeles.dart' show Grammaire;
import 'grammaire_source.dart';

/// Les textes du catalogue 1.5.7, pour reconnaître à la migration ce que
/// l'utilisateur a modifié.
class ReferenceCatalogue {
  const ReferenceCatalogue({required this.paliers, required this.roles});

  /// Paliers des dangers, par identifiant.
  final Map<String, List<String>> paliers;

  /// Rôles des lieux, par identifiant.
  final Map<String, List<String>> roles;
}

/// Lit les données embarquées. Les paliers des dangers, les espaces et les
/// rôles des lieux viennent de la grammaire, rapprochés par le nom.
class LocalJsonDataSource {
  LocalJsonDataSource({
    GrammaireSource? grammaire,
    Future<String> Function(String chemin)? lire,
  })  : _lire = lire ?? rootBundle.loadString,
        grammaire = grammaire ?? GrammaireSource(lire: lire);

  final Future<String> Function(String) _lire;
  final GrammaireSource grammaire;

  Future<Map<String, dynamic>> _json(String chemin) async =>
      jsonDecode(await _lire(chemin)) as Map<String, dynamic>;

  Future<List<Dilemma>> loadDilemmas() async {
    final decoded = await _json('assets/data/dilemmas.json');
    final values = decoded['dilemmes'] as List<dynamic>;
    return values
        .map((item) => Dilemma.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Location>> loadLocations() async {
    final g = (await grammaire.charger()).grammaire;
    final decoded = await _json('assets/data/locations.json');
    return [
      for (final item in decoded['locations'] as List<dynamic>)
        _lieu(Map<String, dynamic>.from(item as Map), g),
    ];
  }

  Location _lieu(Map<String, dynamic> j, Grammaire g) {
    final lg = g.lieuNomme('${j['name']}');
    return Location.fromJson({
      ...j,
      'roles': lg?.roles ?? (j['roles'] as List? ?? const []),
      'espaces': lg?.espaces ?? (j['espaces'] as List? ?? const []),
      'kids': lg?.kids ?? false,
    });
  }

  Future<List<Danger>> loadDangers() async {
    final g = (await grammaire.charger()).grammaire;
    final decoded = await _json('assets/data/dangers.json');
    return [
      for (final item in decoded['dangers'] as List<dynamic>)
        _danger(Map<String, dynamic>.from(item as Map), g),
    ];
  }

  Danger _danger(Map<String, dynamic> j, Grammaire g) {
    final dg = g.dangerNomme('${j['name']}');
    return Danger.fromJson({
      ...j,
      'paliers': dg?.textes ?? (j['paliers'] as List? ?? const []),
      'kids': dg?.kids ?? false,
      'palier4_kids': dg?.supprimeKids ?? '',
    });
  }

  /// Les noms du catalogue embarqué qui n'ont pas d'équivalent dans la
  /// grammaire (à signaler, jamais à choisir seul).
  Future<List<String>> sansCorrespondance() async {
    final g = (await grammaire.charger()).grammaire;
    final d = await _json('assets/data/dangers.json');
    final l = await _json('assets/data/locations.json');
    return [
      for (final x in d['dangers'] as List)
        if (g.dangerNomme('${(x as Map)['name']}') == null) 'Danger : ${x['name']}',
      for (final x in l['locations'] as List)
        if (g.lieuNomme('${(x as Map)['name']}') == null) 'Lieu : ${x['name']}',
    ];
  }

  /// La photo du catalogue 1.5.7 (migration uniquement).
  Future<ReferenceCatalogue> loadReference157() async {
    final j = await _json('assets/data/migration/catalogue_1_5_7.json');
    List<String> ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
    return ReferenceCatalogue(
      paliers: {
        for (final e in (j['dangers'] as Map).entries)
          '${e.key}': ls((e.value as Map)['paliers']),
      },
      roles: {
        for (final e in (j['lieux'] as Map).entries)
          '${e.key}': ls((e.value as Map)['roles']),
      },
    );
  }

  Future<List<Archetype>> loadArchetypes() async {
    final decoded = await _json('assets/data/archetypes.json');
    final values = decoded['archetypes'] as List<dynamic>;
    return values
        .map((item) => Archetype.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
