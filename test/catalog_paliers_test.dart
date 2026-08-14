import 'dart:convert';
import 'dart:io';

import 'package:destiny/infrastructure/datasources/sqlite_catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paliersBackfill', () {
    test('recomplète un danger aux paliers vides depuis la référence', () {
      final current = {
        'incendie': <String>[],
        'tempete': ['déjà là'],
      };
      final seed = {
        'incendie': ['p1', 'p2', 'p3', 'p4'],
        'tempete': ['s1', 's2'],
      };
      final fix = SqliteCatalogStore.paliersBackfill(current, seed);
      expect(fix.keys, ['incendie']);
      expect(fix['incendie'], ['p1', 'p2', 'p3', 'p4']);
    });

    test('ne touche pas les paliers déjà présents', () {
      final fix = SqliteCatalogStore.paliersBackfill(
        {'x': ['a']},
        {'x': ['b', 'c']},
      );
      expect(fix, isEmpty);
    });

    test('ignore un danger absent de la référence ou sans paliers', () {
      final fix = SqliteCatalogStore.paliersBackfill(
        {'x': <String>[], 'y': <String>[]},
        {'y': <String>[]},
      );
      expect(fix, isEmpty);
    });
  });

  test('les 38 dangers de référence ont tous leurs 4 paliers', () {
    final raw = File('assets/data/dangers.json').readAsStringSync();
    final decoded = jsonDecode(raw);
    final list = (decoded is Map ? decoded['dangers'] : decoded) as List;
    expect(list.length, greaterThanOrEqualTo(38));
    for (final d in list) {
      final m = d as Map<String, dynamic>;
      final paliers = (m['paliers'] as List?) ?? const [];
      expect(paliers.length, 4,
          reason: 'Le danger ${m['id']} doit avoir 4 paliers');
    }
  });
}
