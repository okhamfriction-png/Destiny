import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/entities/danger.dart';
import 'package:destiny/domain/entities/dilemma.dart';
import 'package:destiny/domain/entities/location.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/repositories/catalog_store.dart';
import 'package:destiny/domain/serie/univers.dart';
import 'package:destiny/presentation/bibliotheque/bibliotheque_screen.dart';
import 'package:destiny/presentation/bibliotheque/livret_screen.dart';
import 'package:destiny/presentation/bibliotheque/mechants_screen.dart';
import 'package:destiny/presentation/destiny/cartes.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/destiny/page.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/polices.dart';
import 'serie_test.dart' show chargerCatalogue;

/// Un catalogue déjà chargé (pas d'accès disque pendant le test).
class CatalogueDeTest implements CatalogStore {
  CatalogueDeTest(this.dangers, this.lieux);
  final List<Danger> dangers;
  final List<Location> lieux;
  @override
  Future<List<Danger>> getDangers() async => dangers;
  @override
  Future<List<Location>> getLocations() async => lieux;
  @override
  Future<List<Dilemma>> getDilemmas() async => const [];
  @override
  Future<RapportSynchroCatalogue?> dernierRapport() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late Grammaire g;
late TextesDestiny t;
late CatalogueDeTest catalogue;

Future<void> _ouvrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 40000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final visuels = VisualSettings();
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(g, sombre: true),
    builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
    home: BibliothequeScreen(
      contexte: ContexteBibliotheque(catalogue: catalogue, visuels: visuels),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _entrer(WidgetTester tester, String cle) async {
  await tester.tap(find.text(t.t('bibliotheque.entrees.$cle.titre')).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  testWidgets('le sommaire propose les treize entrées', (tester) async {
    await _ouvrir(tester);
    for (final cle in ['decouvrir', 'regles', 'archetypes', 'animaux', 'vouloir_besoin', 'dangers', 'lieux', 'oeuvres',
      'mechants', 'figurants', 'kids', 'outils', 'lexique']) {
      expect(find.text(t.t('bibliotheque.entrees.$cle.titre')), findsWidgets, reason: cle);
    }
  });

  testWidgets('chaque page s\'ouvre', (tester) async {
    await _ouvrir(tester);
    for (final cle in ['archetypes', 'animaux', 'vouloir_besoin', 'dangers', 'lieux', 'oeuvres',
      'mechants', 'figurants', 'kids', 'outils', 'lexique']) {
      await _entrer(tester, cle);
      expect(tester.takeException(), isNull, reason: cle);
      expect(find.byType(PageDestiny), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('le livret affiche les huit règles d\'or telles quelles', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'regles');
    expect(find.byType(LivretScreen), findsOneWidget);
    for (final r in g.reglesDOr) {
      expect(find.text(r.titre), findsWidgets);
      expect(find.text(r.texte), findsWidgets);
    }
  });

  testWidgets('archétypes : douze cartes, filtre par famille', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'archetypes');
    expect(find.byType(CarteArchetype), findsNWidgets(12));
    final puce = find.widgetWithText(ChoiceChip, g.famille(FamilleId.fissure).nom);
    await tester.ensureVisible(puce);
    await tester.pumpAndSettle();
    await tester.tap(puce);
    await tester.pumpAndSettle();
    expect(find.byType(CarteArchetype), findsNWidgets(4));
  });

  testWidgets('la fiche d\'un archétype donne la source des répliques et ses modèles', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'archetypes');
    await tester.tap(find.byType(CarteArchetype).first);
    await tester.pumpAndSettle();
    final lion = g.animal('lion')!;
    expect(find.textContaining(lion.sourceReplique), findsWidgets);
    expect(find.text(g.modelesDe('leader').first.personnage.nom), findsWidgets);
    expect(find.text(g.mechantsReflets('leader').first.nom), findsOneWidget);
  });

  testWidgets('dangers : recherche et filtre kids', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'dangers');
    await tester.enterText(find.byType(TextField), 'incendie');
    await tester.pumpAndSettle();
    expect(find.text('Un incendie'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('la fiche d\'un lieu montre ses espaces et ses trois figurants', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'lieux');
    await tester.tap(find.text('Aquarium'));
    await tester.pumpAndSettle();
    final lg = g.lieuNomme('Aquarium')!;
    for (final e in lg.espaces) {
      expect(find.text(e), findsOneWidget);
    }
    for (final f in lg.figurants) {
      expect(find.text(f.nom), findsOneWidget);
    }
  });

  testWidgets('œuvres : filtre théâtre et fiche', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'oeuvres');
    final puce = find.widgetWithText(ChoiceChip, t.t('bibliotheque.oeuvres.categories.theatre'));
    await tester.ensureVisible(puce);
    await tester.pumpAndSettle();
    await tester.tap(puce);
    await tester.pumpAndSettle();
    expect(find.text('Huis clos'), findsOneWidget);
    expect(find.text('Game of Thrones'), findsNothing);
    await tester.tap(find.text('Hamlet'));
    await tester.pumpAndSettle();
    expect(find.text(g.oeuvres.firstWhere((o) => o.titre == 'Hamlet').lecon), findsOneWidget);
  });

  testWidgets('méchants : 24, dont 16 kids, chacun avec ses deux sbires', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'mechants');
    expect(find.byType(CarteMechant), findsNWidgets(24));
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.byType(CarteMechant), findsNWidgets(16));
    final m = g.mechants.firstWhere((m) => m.kids);
    for (final s in m.sbires) {
      expect(find.text(s.nom), findsOneWidget);
    }
  });

  testWidgets('les 42 méchants des univers, rangés par univers, avec leurs présages', (tester) async {
    late CatalogueUnivers univers;
    await tester.runAsync(() async => univers = await chargerCatalogue(g));
    tester.view.physicalSize = const Size(900, 80000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: themeDestiny(g, sombre: true),
      builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
      home: MechantsScreen(
        contexte: ContexteBibliotheque(catalogue: catalogue, visuels: VisualSettings(), univers: univers),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.t('bibliotheque.serie.mechants_univers')));
    await tester.pumpAndSettle();
    expect(find.byType(CarteMechant), findsNWidgets(42));
    final m = univers.mechantsDe('pirates').first;
    expect(find.text(m.mechant.nom.toUpperCase()), findsOneWidget);
    expect(find.text(m.presages.first), findsOneWidget);
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.byType(CarteMechant), findsNWidgets(univers.mechants.where((x) => x.mechant.kids).length));
  });

  testWidgets('un sbire se joue depuis sa fiche', (tester) async {
    await _ouvrir(tester);
    await _entrer(tester, 'mechants');
    final s = g.mechants.first.sbires.first;
    await tester.tap(find.text(s.nom));
    await tester.pumpAndSettle();
    expect(find.text(s.fait), findsOneWidget);
    expect(find.byType(CarteArchetype), findsWidgets);
  });

  testWidgets('carte du méchant (rendu)', (tester) async {
    await tester.runAsync(chargerPolices);
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = g.mechants.firstWhere((m) => m.kids);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeDestiny(g, sombre: true),
      builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: RepaintBoundary(child: CarteMechant(m)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/carte_mechant.png'));
  });
}
