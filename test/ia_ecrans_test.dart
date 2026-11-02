import 'dart:convert';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/serie/univers.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/jouer/univers_ia.dart';
import 'package:destiny/presentation/screens/chat_screen.dart';
import 'package:destiny/presentation/screens/spectacle_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'serie_test.dart' show FauxLlm, chargerCatalogue;
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late CatalogueDeTest catalogue;
late CatalogueUnivers univers;

Widget _appli(GrammaireChargee c, Widget home) => MaterialApp(
      theme: themeDestiny(c.grammaire, sombre: true),
      builder: (context, child) => DestinyDonnees(grammaire: c.grammaire, textes: c.textes, child: child!),
      home: Scaffold(body: home),
    );

void main() {
  setUpAll(() async {
    chargee = await chargerGrammaire();
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
    univers = await chargerCatalogue(chargee.grammaire);
  });

  testWidgets('l\'histoire avec l\'IA : on choisit un archétype, puis un de ses deux animaux', (tester) async {
    SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ia = (await tester.runAsync(AiSettings.load))!;
    final c = ChatController(
      chatStore: InMemoryChatStore(),
      llm: FauxLlm('DONC.\nCHOIX:\n- [BRAVE] a\n- [SMART] b'),
      aiSettings: ia,
      catalogue: catalogue,
      grammaire: chargee,
    );
    await tester.pumpWidget(_appli(
      chargee,
      ChatScreen(
        controller: c,
        audioService: AudioService()..setMuted(true),
        visualSettings: VisualSettings(),
        musicController: MusicController(),
        univers: univers,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle histoire').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    final leader = chargee.grammaire.archetype('leader')!;
    await tester.tap(find.text(leader.nom).last);
    await tester.pumpAndSettle();
    expect(find.text(leader.ceQuIlFait), findsOneWidget);
    for (final a in chargee.grammaire.animauxDe('leader')) {
      expect(find.text(a.nom), findsWidgets);
    }
  });

  testWidgets('le spectacle avec l\'IA : quatre personnages, puis le bouton Destiny', (tester) async {
    SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ia = (await tester.runAsync(AiSettings.load))!;
    final c = SpectacleController(
      catalogue: catalogue,
      grammaire: chargee,
      llm: FauxLlm(jsonEncode({
        'phase': 'jeu',
        'acte': 1,
        'scene': 1,
        'palier': 1,
        'compteur': {'posees': 1, 'cible': 10},
        'replique': {'personnage': 'Raoul', 'archetype': 'Rat', 'texte': 'Vous sentez ?'},
        'propositions': [
          {'id': 1, 'texte': 'Non.', 'archetype': 'Âne', 'correcte': true},
        ],
      })),
      aiSettings: ia,
    );
    await tester.pumpWidget(_appli(chargee, SpectacleScreen(controller: c, univers: univers)));
    await tester.pumpAndSettle();
    // Les univers viennent de univers.json ; « Contemporain » par défaut.
    expect(universPourIa(univers, kids: false).map((u) => u.name), contains('Contemporain'));
    expect(universPourIa(univers, kids: true).map((u) => u.name), contains('Pirates'));
    expect(find.text('Contemporain'), findsWidgets);
    await tester.tap(find.text('Tirer le décor'));
    await tester.pumpAndSettle();
    expect(c.draw!.archetypes, hasLength(4));
    expect(find.text('DESTINY'), findsNothing);
    await tester.scrollUntilVisible(find.text('Lever le rideau'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lever le rideau'));
    await tester.pumpAndSettle();
    expect(find.text('Vous sentez ?'), findsOneWidget);
    expect(find.text('DESTINY'), findsOneWidget);
  });
}
