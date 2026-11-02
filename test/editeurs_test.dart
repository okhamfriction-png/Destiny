import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/infrastructure/datasources/in_memory_catalog_store.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/reglages/editeur_catalogue_screen.dart';
import 'package:destiny/presentation/reglages/editeur_dilemmes_screen.dart';
import 'package:destiny/presentation/screens/about_screen.dart';
import 'package:destiny/presentation/screens/contact_screen.dart';
import 'package:destiny/presentation/screens/credits_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';

late GrammaireChargee chargee;
late TextesDestiny t;

Future<void> _ouvrir(WidgetTester tester, Widget page, {bool sombre = false, double hauteur = 844}) async {
  tester.view.physicalSize = Size(390, hauteur);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(chargee.grammaire, sombre: sombre),
    builder: (context, child) => DestinyDonnees(grammaire: chargee.grammaire, textes: t, child: child!),
    home: page,
  ));
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    chargee = await chargerGrammaire();
    t = chargee.textes;
  });

  test('un identifiant lisible et unique', () {
    expect(identifiantDepuis('Le Phare du Nord', {}), 'le_phare_du_nord');
    expect(identifiantDepuis('Écluse', {'ecluse'}), 'ecluse_1');
    expect(identifiantDepuis('!!!', {}, defaut: 'lieu'), 'lieu');
  });

  testWidgets('un nouveau lieu : espaces, rôles, KIDS', (tester) async {
    final store = InMemoryCatalogStore(seedSource: donneesDeTest());
    final avant = (await tester.runAsync(store.getLocations))!.length;
    await _ouvrir(tester, EditeurCatalogueScreen(catalogue: store), hauteur: 1500);
    expect(find.text(t.t('editeurs.catalogue.lieux', {'n': '$avant'})), findsOneWidget);
    await tester.tap(find.text(t.t('editeurs.catalogue.ajouter_lieu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nom')), 'Le phare du Nord');
    await tester.enterText(find.byKey(const Key('espaces')), 'la lanterne\n\nla cuisine\n');
    final kids = find.widgetWithText(SwitchListTile, t.t('editeurs.catalogue.kids'));
    await _visible(tester, kids);
    await tester.tap(kids);
    await tester.pumpAndSettle();
    final enregistrer = find.text(t.t('editeurs.catalogue.enregistrer'));
    await _visible(tester, enregistrer);
    await tester.runAsync(() async {
      await tester.tap(enregistrer);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final lieux = (await tester.runAsync(store.getLocations))!;
    expect(lieux, hasLength(avant + 1));
    final phare = lieux.firstWhere((l) => l.id == 'le_phare_du_nord');
    expect(phare.espaces, ['la lanterne', 'la cuisine']);
    expect(phare.kids, isTrue);
    expect(phare.actif, isTrue);
  });

  testWidgets('un danger : les quatre paliers portent les noms de la grammaire', (tester) async {
    final store = InMemoryCatalogStore(seedSource: donneesDeTest());
    final dangers = (await tester.runAsync(store.getDangers))!;
    final d = dangers.first;
    await _ouvrir(tester, FicheDangerEditeur(catalogue: store, danger: d, existants: {for (final x in dangers) x.id}),
        hauteur: 1500);
    for (final p in chargee.grammaire.paliers) {
      expect(find.text('${p.numero}. ${p.nom}'), findsOneWidget);
    }
    // Les anciens libellés ont disparu.
    expect(find.textContaining('climax'), findsNothing);
    await tester.enterText(find.byKey(const Key('palier_supprime')), 'Les portes se verrouillent.');
    final enregistrer = find.text(t.t('editeurs.catalogue.enregistrer'));
    await _visible(tester, enregistrer);
    await tester.runAsync(() async {
      await tester.tap(enregistrer);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final relu = (await tester.runAsync(store.getDangers))!.firstWhere((x) => x.id == d.id);
    expect(relu.paliers.last, 'Les portes se verrouillent.');
    expect(relu.name, d.name);
  });

  testWidgets('les dilemmes de l\'acte 4 : le genre, plus le moteur', (tester) async {
    final store = InMemoryCatalogStore(seedSource: donneesDeTest());
    await tester.runAsync(() async {
      await store.getDangers();
      await store.getDilemmas();
    });
    await _ouvrir(tester, EditeurDilemmesScreen(catalogue: store), sombre: true);
    expect(find.text(t.t('editeurs.dilemmes.intro')), findsOneWidget);
    expect(find.textContaining('moteur'), findsNothing);
    expect(find.textContaining('mode Dilemme'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (nom, page) in [
    ('À propos', const AboutScreen()),
    ('Crédits', const CreditsScreen()),
    ('Contact', const ContactScreen()),
  ]) {
    testWidgets('$nom : sur un téléphone, sans le dé', (tester) async {
      await _ouvrir(tester, page);
      expect(tester.takeException(), isNull);
      final de = RegExp(r'(^|[^\p{L}])(dé|dés|Dé|Dés)([^\p{L}]|$)', unicode: true);
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        expect(de.hasMatch(w.data ?? ''), isFalse, reason: w.data);
      }
      expect(find.byIcon(Icons.casino), findsNothing);
    });
  }

  test('chaque texte des éditeurs et des pages d\'aide existe', () {
    expect(
      textesManquants([
        'lib/presentation/reglages/editeur_catalogue_screen.dart',
        'lib/presentation/reglages/editeur_dilemmes_screen.dart',
        'lib/presentation/screens/about_screen.dart',
        'lib/presentation/screens/credits_screen.dart',
        'lib/presentation/screens/contact_screen.dart',
      ]),
      isEmpty,
    );
  });
}
