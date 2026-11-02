import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/location_details.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/relation_cheatsheet.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/reglages/reglages_destiny_screen.dart';
import 'package:destiny/presentation/screens/appearance_screen.dart';
import 'package:destiny/presentation/screens/settings_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late TextesDestiny t;
late CatalogueDeTest catalogue;

Future<void> _ouvrir(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(chargee.grammaire, sombre: false),
    builder: (context, child) => DestinyDonnees(grammaire: chargee.grammaire, textes: t, child: child!),
    home: page,
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    chargee = await chargerGrammaire();
    t = chargee.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  test('les nouveaux réglages se gardent', () async {
    SharedPreferences.setMockInitialValues({});
    final r = ReglagesDestiny();
    await r.charger();
    expect(r.theme, ThemeDestiny.sombre);
    expect(r.evolutionArchetype, isTrue);
    await r.changer(theme: ThemeDestiny.clair, registreParDefaut: false, evolutionArchetype: false);
    final relu = ReglagesDestiny();
    await relu.charger();
    expect(relu.theme, ThemeDestiny.clair);
    expect(relu.registreParDefaut, isFalse);
    expect(relu.evolutionArchetype, isFalse);
  });

  testWidgets('les réglages Destiny : un chrono se modifie, un chrono invalide est refusé', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final r = ReglagesDestiny();
    await tester.runAsync(r.charger);
    await _ouvrir(tester, ReglagesDestinyScreen(reglages: r, audio: AudioService()..setMuted(true), musique: MusicController()));
    expect(find.text(t.t('reglages.chronos').toUpperCase()), findsOneWidget);
    // Le chrono de 20 min : Destiny 1 à 8 min. On l'avance d'une minute.
    final plus = find.byIcon(Icons.add_circle_outline);
    await tester.tap(plus.at(1));
    await tester.pumpAndSettle();
    expect(r.chronos.first.destinyMinutes.first, 9);
    // Réduire la durée sous le dernier Destiny est refusé.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();
    }
    expect(r.chronos.first.dureeMinutes, greaterThan(r.chronos.first.destinyMinutes.last));
    expect(find.text(t.t('reglages.chrono_invalide')), findsOneWidget);
    // Le déclenchement.
    await tester.tap(find.text(t.t('reglages.declenchements.manuel')));
    await tester.pumpAndSettle();
    expect(r.declenchement, Declenchement.manuel);
  });

  testWidgets('l\'apparence : le thème clair', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final r = ReglagesDestiny();
    await tester.runAsync(r.charger);
    await _ouvrir(tester, AppearanceScreen(visualSettings: VisualSettings(), reglages: r));
    await tester.tap(find.text(t.t('reglages.themes.clair')));
    await tester.pumpAndSettle();
    expect(r.theme, ThemeDestiny.clair);
  });

  testWidgets('les réglages tiennent sur un téléphone, sans le dé', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final r = ReglagesDestiny();
    await tester.runAsync(r.charger);
    final ia = (await tester.runAsync(AiSettings.load))!;
    await _ouvrir(
      tester,
      SettingsScreen(
        reglages: r,
        visualSettings: VisualSettings(),
        catalogStore: catalogue,
        aiSettings: ia,
        relationCheatsheet: RelationCheatsheet(),
        locationDetails: LocationDetailsStore(),
        audioService: AudioService()..setMuted(true),
        musicController: MusicController(),
      ),
    );
    expect(find.text(t.t('reglages.destiny')), findsOneWidget);
    expect(find.textContaining('dé'), findsNothing);
    expect(find.textContaining('2.0.0'), findsOneWidget);
  });

  test('chaque texte des réglages existe', () {
    expect(
      textesManquants([
        'lib/presentation/reglages',
        'lib/presentation/screens/settings_screen.dart',
        'lib/presentation/screens/appearance_screen.dart',
        'lib/presentation/troupe',
        'lib/presentation/jouer',
        'lib/presentation/bibliotheque',
        'lib/presentation/destiny',
      ]),
      isEmpty,
    );
  });
}
