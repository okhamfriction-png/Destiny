import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/archetype.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';

class LocalJsonDataSource {
  Future<List<Dilemma>> loadDilemmas() async {
    final raw = await rootBundle.loadString('assets/data/dilemmas.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final values = decoded['dilemmes'] as List<dynamic>;
    return values
        .map((item) => Dilemma.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Location>> loadLocations() async {
    final raw = await rootBundle.loadString('assets/data/locations.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final values = decoded['locations'] as List<dynamic>;
    return values
        .map((item) => Location.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Danger>> loadDangers() async {
    final raw = await rootBundle.loadString('assets/data/dangers.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final values = decoded['dangers'] as List<dynamic>;
    return values
        .map((item) => Danger.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Archetype>> loadArchetypes() async {
    final raw = await rootBundle.loadString('assets/data/archetypes.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final values = decoded['archetypes'] as List<dynamic>;
    return values
        .map((item) => Archetype.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
