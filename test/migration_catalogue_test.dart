import 'dart:convert';
import 'dart:io';

import 'package:destiny/infrastructure/datasources/sqlite_catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'outils/grammaire_partagee.dart';

/// Construit une base « 1.5.7 » (schéma version 4) avec les textes d'origine.
Future<void> _creerBase157(String chemin) async {
  final ref = jsonDecode(File('assets/data/migration/catalogue_1_5_7.json').readAsStringSync())
      as Map<String, dynamic>;
  final db = await databaseFactoryFfi.openDatabase(chemin,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, v) async {
          await db.execute('CREATE TABLE locations (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
              'roles TEXT NOT NULL, rue INTEGER NOT NULL, actif INTEGER NOT NULL, sort INTEGER NOT NULL)');
          await db.execute('CREATE TABLE dangers (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
              'style TEXT NOT NULL, rue INTEGER NOT NULL, theatre INTEGER NOT NULL, '
              "actif INTEGER NOT NULL, paliers TEXT NOT NULL DEFAULT '[]', sort INTEGER NOT NULL)");
          await db.execute('CREATE TABLE IF NOT EXISTS dilemmas (id TEXT PRIMARY KEY, nom TEXT NOT NULL, '
              'source_reelle TEXT NOT NULL, moteur TEXT NOT NULL, danger_lie TEXT NOT NULL, '
              'situation TEXT NOT NULL, choix_a TEXT NOT NULL, choix_b TEXT NOT NULL, sort INTEGER NOT NULL)');
        },
      ));
  var i = 0;
  for (final e in (ref['dangers'] as Map<String, dynamic>).entries) {
    final v = e.value as Map<String, dynamic>;
    var paliers = List<String>.from(v['paliers'] as List);
    if (e.key == 'tempete') paliers = ['Mon palier à moi', ...paliers.skip(1)];
    if (e.key == 'zombies') continue; // supprimé par l'utilisateur
    await db.insert('dangers', {
      'id': e.key, 'name': v['nom'], 'style': 'Catastrophe', 'rue': 1, 'theatre': 1,
      'actif': 1, 'paliers': jsonEncode(paliers), 'sort': i++,
    });
  }
  await db.insert('dangers', {
    'id': 'mon_danger', 'name': 'Mon danger', 'style': 'Thriller', 'rue': 0, 'theatre': 1,
    'actif': 1, 'paliers': jsonEncode(['a', 'b', 'c', 'd']), 'sort': i++,
  });
  i = 0;
  for (final e in (ref['lieux'] as Map<String, dynamic>).entries) {
    final v = e.value as Map<String, dynamic>;
    await db.insert('locations', {
      'id': e.key, 'name': v['nom'], 'roles': jsonEncode(v['roles']), 'rue': 0,
      'actif': 1, 'sort': i++,
    });
  }
  await db.close();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dossier;
  setUp(() async => dossier = await Directory.systemTemp.createTemp('destiny_catalogue'));
  tearDown(() async => dossier.delete(recursive: true));

  test('une base 1.5.7 reçoit la grammaire sans perdre les modifications', () async {
    await _creerBase157('${dossier.path}/destiny_catalog.db');
    final store = SqliteCatalogStore(
        seedSource: donneesDeTest(), dossier: () async => dossier.path);
    final g = (await chargerGrammaire()).grammaire;

    final dangers = {for (final d in await store.getDangers()) d.id: d};
    // Non modifié : reçoit les textes de la grammaire.
    expect(dangers['incendie']!.paliers, g.dangerNomme('Un incendie')!.textes);
    // Modifié par l'utilisateur : gardé tel quel.
    expect(dangers['tempete']!.paliers.first, 'Mon palier à moi');
    // Supprimé : ne revient pas. Ajouté : intouché.
    expect(dangers.containsKey('zombies'), isFalse);
    expect(dangers['mon_danger']!.paliers, ['a', 'b', 'c', 'd']);

    final lieux = {for (final l in await store.getLocations()) l.id: l};
    expect(lieux['banque']!.espaces, g.lieuNomme('Banque')!.espaces);
    // Les drapeaux kids arrivent aussi dans une base 1.5.7.
    expect(lieux['banque']!.kids, g.lieuNomme('Banque')!.kids);
    expect(lieux['casino']!.kids, isFalse);
    expect(dangers['incendie']!.kids, g.dangerNomme('Un incendie')!.kids);
    expect(dangers.values.where((d) => d.kids), isNotEmpty);
    expect(dangers.values.where((d) => d.kids).every((d) => d.palier4Kids.isNotEmpty), isTrue);

    final rapport = await store.dernierRapport();
    expect(rapport, isNotNull);
    expect(rapport!.gardes, contains('Une tempête'));
    expect(rapport.absents, contains('Une invasion de zombies'));
    expect(rapport.dangersMisAJour, greaterThan(0));
    expect(rapport.sansCorrespondance, isEmpty);
  });

  test('une nouvelle installation part directement de la grammaire', () async {
    final store = SqliteCatalogStore(
        seedSource: donneesDeTest(), dossier: () async => dossier.path);
    final g = (await chargerGrammaire()).grammaire;
    final dangers = await store.getDangers();
    expect(dangers, hasLength(38));
    for (final d in dangers) {
      expect(d.paliers, g.dangerNomme(d.name)!.textes);
    }
    final lieux = await store.getLocations();
    expect(lieux.every((l) => l.espaces.length == 4), isTrue);
  });

  test('une modification faite après la mise à jour reste à l\'abri', () async {
    final chemin = dossier.path;
    var store = SqliteCatalogStore(seedSource: donneesDeTest(), dossier: () async => chemin);
    final d = (await store.getDangers()).first;
    await store.saveDanger(d.copyWith(paliers: ['x', 'y', 'z', 'w']));
    // Nouvelle ouverture : la grammaire n'a pas changé, rien ne bouge.
    store = SqliteCatalogStore(seedSource: donneesDeTest(), dossier: () async => chemin);
    final relu = (await store.getDangers()).firstWhere((x) => x.id == d.id);
    expect(relu.paliers, ['x', 'y', 'z', 'w']);
  });
}
