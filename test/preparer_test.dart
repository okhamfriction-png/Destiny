import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/troupe_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/distribution.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/troupe/session.dart';
import 'package:destiny/presentation/bibliotheque/archetypes_screen.dart';
import 'package:destiny/presentation/bibliotheque/dangers_lieux_screen.dart';
import 'package:destiny/presentation/destiny/cartes.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:destiny/presentation/troupe/preparer_screen.dart';
import 'package:destiny/presentation/troupe/troupe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'troupe_test.dart' show CatalogueDeTest;

late Grammaire g;
late TextesDestiny t;
late CatalogueDeTest catalogue;

Future<(TroupeStore, SessionTroupe)> _preparer(WidgetTester tester,
    {bool sombre = true, double echelle = 1, double hauteur = 3000}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(390, hauteur);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = TroupeStore();
  final s = (await tester.runAsync(store.nouvelle))!;
  final ctx = ContexteTroupe(
    store: store,
    reglages: ReglagesDestiny(),
    catalogue: catalogue,
    audio: AudioService()..setMuted(true),
    musique: MusicController(),
    visuels: VisualSettings(),
  );
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(g, sombre: sombre),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)),
      child: DestinyDonnees(grammaire: g, textes: t, child: child!),
    ),
    home: PreparerScreen(contexte: ctx, session: s),
  ));
  await tester.pumpAndSettle();
  return (store, s);
}

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  testWidgets('à l\'arrivée : une répétition, tout est déjà tiré, sans prénoms', (tester) async {
    final (_, s) = await _preparer(tester);
    expect(s.type, TypeSession.repetition);
    expect(find.byType(TextField), findsNothing, reason: 'plus de prénoms en spectacle ni en répétition');
    expect(s.lieuNom, isNotEmpty);
    expect(s.dangerNom, isNotEmpty);
    expect(s.paliers, hasLength(4));
    expect(s.personnages, hasLength(4));
    expect(validerDistribution(g, [for (final p in s.personnages) p.archetypeId]).valide, isTrue);
    expect(find.text(s.lieuNom), findsOneWidget);
    expect(find.text(s.dangerNom), findsOneWidget);
    for (final p in s.personnages) {
      expect(find.text(g.archetype(p.archetypeId)!.nom), findsOneWidget);
      for (final a in g.animauxDe(p.archetypeId)) {
        expect(find.text(a.nom), findsWidgets);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('on passe à l\'échauffement sans choisir d\'animal', (tester) async {
    final (_, s) = await _preparer(tester);
    expect(s.personnages.every((p) => p.animalId.isEmpty), isTrue);
    final bouton = find.widgetWithText(FilledButton, t.t('preparer.vers_echauffement'));
    expect(tester.widget<FilledButton>(bouton).onPressed, isNotNull);
    await tester.tap(bouton);
    await tester.pumpAndSettle();
    expect(s.etape, EtapeSession.echauffement);
    // Sans animal choisi, l'échauffement montre l'archétype et ses deux animaux.
    expect(find.byType(CarteArchetype), findsNWidgets(4));
  });

  testWidgets('choisir un animal est facultatif, et se défait', (tester) async {
    final (_, s) = await _preparer(tester);
    final p = s.personnages.first;
    final animal = g.animauxDe(p.archetypeId).last;
    await tester.tap(find.text(animal.nom).first);
    await tester.pump();
    expect(p.animalId, animal.id);
    await tester.tap(find.text(animal.nom).first);
    await tester.pump();
    expect(p.animalId, isEmpty);
  });

  testWidgets('« Tirer » et « un autre lieu » changent le tirage', (tester) async {
    final (_, s) = await _preparer(tester);
    final lieu = s.lieuId;
    await tester.tap(find.byTooltip(t.t('preparer.autre_lieu')));
    await tester.pump();
    expect(s.lieuId, isNot(lieu));
    final danger = s.dangerId;
    await tester.tap(find.byTooltip(t.t('preparer.autre_danger')));
    await tester.pump();
    expect(s.dangerId, isNot(danger));
    final avant = (s.lieuId, s.dangerId);
    await tester.tap(find.text(t.t('preparer.tirer')));
    await tester.pumpAndSettle();
    expect((s.lieuId, s.dangerId), isNot(avant));
    expect(validerDistribution(g, [for (final p in s.personnages) p.archetypeId]).valide, isTrue);
  });

  testWidgets('un bouton info à chaque niveau : lieu, danger, archétype, animal', (tester) async {
    final (_, s) = await _preparer(tester);
    Future<void> info(String nom, Type fiche) async {
      await tester.tap(find.byTooltip(t.t('preparer.info_de', {'nom': nom})).first);
      await tester.pumpAndSettle();
      expect(find.byType(fiche), findsOneWidget, reason: nom);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await info(s.lieuNom, FicheLieu);
    await info(s.dangerNom, FicheDanger);
    final arch = g.archetype(s.personnages.first.archetypeId)!;
    await info(arch.nom, FicheArchetype);
    await info(g.animauxDe(arch.id).first.nom, FicheAnimal);
  });

  testWidgets('en kids, le lieu et le danger sont kids', (tester) async {
    final (_, s) = await _preparer(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(s.kids, isTrue);
    expect(catalogue.lieux.firstWhere((l) => l.id == s.lieuId).kids, isTrue);
    expect(catalogue.dangers.firstWhere((d) => d.id == s.dangerId).kids, isTrue);
  });

  for (final sombre in [true, false]) {
    testWidgets('tient sur un téléphone, texte agrandi (${sombre ? 'sombre' : 'clair'})', (tester) async {
      await _preparer(tester, sombre: sombre, echelle: 1.6, hauteur: 844);
      expect(tester.takeException(), isNull);
    });
  }

  test('chaque texte de Préparer existe', () {
    expect(textesManquants(['lib/presentation/troupe/preparer_screen.dart']), isEmpty);
  });
}
