import 'dart:convert';
import 'dart:io';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/serie_store.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/entities/chat_message.dart';
import 'package:destiny/domain/entities/chat_story.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/serie/univers.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/jouer/jouer_screen.dart';
import 'package:destiny/presentation/jouer/univers_ia.dart';
import 'package:destiny/presentation/screens/chat_screen.dart';
import 'package:destiny/presentation/screens/spectacle_screen.dart';
import 'package:destiny/presentation/serie/contexte_serie.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'serie_test.dart' show FauxLlm, chargerCatalogue;
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late TextesDestiny t;
late CatalogueDeTest catalogue;
late CatalogueUnivers univers;

const _ecranHistoire = 'lib/presentation/screens/chat_screen.dart';
const _ecranSpectacle = 'lib/presentation/screens/spectacle_screen.dart';

/// Un téléphone de 390 × 844, dans le thème clair ou sombre de l'appli.
Future<void> _ouvrir(WidgetTester tester, Widget page, {required bool sombre}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(chargee.grammaire, sombre: sombre),
    builder: (context, child) => DestinyDonnees(grammaire: chargee.grammaire, textes: t, child: child!),
    home: page,
  ));
  await tester.pumpAndSettle();
}

/// Une histoire en cours : une narration avec DANGER, DONC et MAIS, une
/// action réussie, une ratée, puis deux choix BRAVE et SMART.
ChatStory _histoire() => ChatStory(
      id: 'h1',
      title: 'Lina — Contemporain',
      createdAt: 1,
      context: 'Contemporain · Le bar · Un incendie',
      versionPrompts: 'test',
      maxResponses: 30,
      players: const [ChatPlayer(name: 'Lina', archetypeId: 'leader', animalId: 'lion', archetype: 'Leader', emoji: '🦁')],
      // Une liste modifiable : la partie y ajoute ses messages.
      messages: [
        const ChatMessage(role: 'user', content: 'contexte'),
        const ChatMessage(
            role: 'assistant',
            content: 'Le bar est plein, donc tout le monde rit. Mais une odeur monte.\n'
                '⚡ DANGER : la fumée sort des cuisines.\nCHOIX:\n- [BRAVE] Tu fonces.\n- [SMART] Tu fais sortir les clients.'),
        const ChatMessage(role: 'user', content: 'x', display: 'Tu fonces.', kind: 'brave', result: 'success', actor: 'Lina'),
        const ChatMessage(role: 'user', content: 'x', display: 'Tu cries.', kind: 'smart', result: 'fail', actor: 'Lina'),
        const ChatMessage(
            role: 'assistant',
            content: 'La porte cède.\nCHOIX:\n- [BRAVE] Tu prends l\'extincteur.\n- [SMART] Tu coupes le gaz.'),
      ],
    );

/// Un tour du spectacle : une réplique, le coach, le CROW et un retour.
String _tour({String phase = 'jeu', Object? debrief}) => jsonEncode({
      'phase': phase,
      'acte': 1,
      'scene': 1,
      'palier': 1,
      'compteur': {'posees': 1, 'cible': 10},
      'didascalie': 'Raoul renifle.',
      'replique': {'personnage': 'Raoul', 'archetype': 'Rat', 'texte': 'Vous sentez ?'},
      'correction': {'defaut': 'Trop long', 'explication': 'Une phrase suffit.', 'modele': 'Non.'},
      'crow': {'prenom': true, 'fonction': false, 'liens': 1, 'objectif': true, 'where': true, 'trou': 'la fonction', 'moyen': 'un geste'},
      'feedback': {'juste': 'Ta réponse est courte.', 'travailler': ['Regarder le partenaire']},
      'propositions': [
        {'id': 1, 'texte': 'Non.', 'archetype': 'Âne', 'correcte': true},
        {'id': 2, 'texte': 'Peut-être.', 'archetype': 'Rat', 'correcte': false},
      ],
      if (debrief != null) 'debrief': debrief,
    });

void main() {
  setUpAll(() async {
    chargee = await chargerGrammaire();
    t = chargee.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
    univers = await chargerCatalogue(chargee.grammaire);
  });

  for (final sombre in [false, true]) {
    final theme = sombre ? 'sombre' : 'clair';

    testWidgets('l\'histoire avec l\'IA, en thème $theme : la liste, la nouvelle histoire, la partie', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ia = (await tester.runAsync(AiSettings.load))!;
      final store = InMemoryChatStore();
      await tester.runAsync(() => store.save(_histoire()));
      final llm = FauxLlm('La flamme recule.\nCHOIX:\n- [BRAVE] Tu cours.\n- [SMART] Tu attends.');
      final c = ChatController(chatStore: store, llm: llm, aiSettings: ia, catalogue: catalogue, grammaire: chargee);
      await _ouvrir(
        tester,
        ChatScreen(
          controller: c,
          audioService: AudioService()..setMuted(true),
          visualSettings: VisualSettings(),
          musicController: MusicController(),
          univers: univers,
        ),
        sombre: sombre,
      );
      expect(tester.takeException(), isNull);
      expect(Theme.of(tester.element(find.byType(ListView).first)).brightness,
          sombre ? Brightness.dark : Brightness.light);
      expect(find.text(t.t('histoire_ia.titre')), findsOneWidget);
      // Sans clé, on propose de configurer l'IA.
      expect(find.text(t.t('histoire_ia.sans_cle.configurer')), findsOneWidget);
      expect(find.text('Lina — Contemporain'), findsOneWidget);

      // La nouvelle histoire : univers, ton, héros, narration, longueur.
      await tester.tap(find.text(t.t('histoire_ia.nouvelle')).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(t.t('histoire_ia.creer.lancer')), findsOneWidget);
      expect(find.text(t.t('histoire_ia.creer.univers_aide')), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      for (final ton in t.liste('histoire_ia.tons')) {
        expect(find.text(ton), findsWidgets);
      }
      await tester.tap(find.text('Mystère').last);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 10)); // ferme la feuille
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // La partie : les bulles, les choix BRAVE et SMART, l'action libre.
      c.openStory(c.stories.single);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(t.t('histoire_ia.jeu.brave')), findsOneWidget);
      expect(find.text(t.t('histoire_ia.jeu.smart')), findsOneWidget);
      expect(find.text('Tu prends l\'extincteur.'), findsOneWidget);
      expect(find.text(t.t('histoire_ia.jeu.action_libre')), findsOneWidget);
      await tester.tap(find.text('Tu coupes le gaz.'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tu attends.'), findsOneWidget);

      // Le retour à la liste.
      await tester.tap(find.byTooltip(t.t('accessibilite.retour')));
      await tester.pumpAndSettle();
      expect(find.text(t.t('histoire_ia.nouvelle')), findsOneWidget);
    });

    testWidgets('le spectacle avec l\'IA, en thème $theme : réglages, décor, partie et débrief', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
      final ia = (await tester.runAsync(AiSettings.load))!;
      final llm = FauxLlm(_tour());
      final c = SpectacleController(catalogue: catalogue, grammaire: chargee, llm: llm, aiSettings: ia);
      await _ouvrir(tester, SpectacleScreen(controller: c, univers: univers), sombre: sombre);
      expect(tester.takeException(), isNull);
      expect(Theme.of(tester.element(find.byType(ListView).first)).brightness,
          sombre ? Brightness.dark : Brightness.light);
      expect(find.text(t.t('spectacle_ia.titre')), findsOneWidget);
      expect(find.byTooltip(t.t('spectacle_ia.historique')), findsOneWidget);
      expect(find.text('Contemporain'), findsWidgets);
      expect(find.text('Drame'), findsWidgets);

      final tirer = find.text(t.t('spectacle_ia.tirer'));
      await tester.scrollUntilVisible(tirer, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(tirer);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.draw!.archetypes, hasLength(4));
      expect(find.text(t.t('spectacle_ia.retirer')), findsOneWidget);
      final lever = find.text(t.t('spectacle_ia.lever'));
      await tester.scrollUntilVisible(lever, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(lever);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Vous sentez ?'), findsOneWidget);
      expect(find.text(t.t('spectacle_ia.jeu.retour')), findsOneWidget);
      expect(find.text(t.t('spectacle_ia.jeu.crow')), findsOneWidget);
      expect(find.text(t.t('spectacle_ia.rubriques.juste')), findsOneWidget);
      expect(find.text(t.t('regie.destiny').toUpperCase()), findsOneWidget);

      // Le débrief, avec le bouton pour un nouveau spectacle.
      llm.reponse = _tour(phase: 'debrief', debrief: {'ce_qui_a_marche': 'Tes silences.', 'a_essayer': 'Oser le non.'});
      await tester.tap(find.text('Non.'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(t.t('spectacle_ia.jeu.fin')), findsOneWidget);
      expect(find.text(t.t('spectacle_ia.rubriques.ce_qui_a_marche')), findsOneWidget);
      expect(find.text(t.t('spectacle_ia.jeu.nouveau')), findsOneWidget);
    });

    testWidgets('depuis Jouer, en thème $theme : les deux écrans suivent le thème de l\'appli', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ia = (await tester.runAsync(AiSettings.load))!;
      final store = SerieStore(lire: lireFichier);
      await tester.runAsync(() => store.charger(grammaire: chargee.grammaire));
      final audio = AudioService()..setMuted(true);
      final musique = MusicController();
      final visuels = VisualSettings();
      await _ouvrir(
        tester,
        Scaffold(
          body: JouerScreen(
            serie: ContexteSerie(
              store: store,
              reglages: ReglagesDestiny(),
              catalogue: catalogue,
              audio: audio,
              musique: musique,
              visuels: visuels,
            ),
            chatController: ChatController(
                chatStore: InMemoryChatStore(), llm: FauxLlm(''), aiSettings: ia, catalogue: catalogue, grammaire: chargee),
            spectacleController:
                SpectacleController(catalogue: catalogue, grammaire: chargee, llm: FauxLlm(''), aiSettings: ia),
            audioService: audio,
            visualSettings: visuels,
            musicController: musique,
          ),
        ),
        sombre: sombre,
      );
      for (final (cle, ecran) in [
        ('jouer.ia.histoire.titre', ChatScreen),
        ('jouer.ia.spectacle.titre', SpectacleScreen),
      ]) {
        final entree = find.text(t.t(cle));
        await tester.scrollUntilVisible(entree, 300, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(entree);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final page = find.byType(ecran);
        expect(page, findsOneWidget);
        expect(Theme.of(tester.element(page)).brightness, sombre ? Brightness.dark : Brightness.light);
        expect(Theme.of(tester.element(page)).scaffoldBackgroundColor, DestinyCouleurs.depuisGrammaire(chargee.grammaire, sombre: sombre).fond);
        // Une seule barre, avec son bouton retour.
        expect(find.descendant(of: page, matching: find.byType(AppBar)), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    });
  }

  test('chaque texte des deux écrans IA existe', () {
    expect(textesManquants([_ecranHistoire, _ecranSpectacle, 'lib/presentation/jouer']), isEmpty);
  });

  test('les deux écrans IA n\'imposent plus le noir : plus de couleurs codées en dur pour le texte et les fonds', () {
    const interdits = [
      'Colors.white70',
      'Colors.white60',
      'Colors.white54',
      'Colors.white38',
      'Colors.redAccent',
      'Color(0xFF141029)',
      'Color(0xFF0A0818)',
      'Color(0xFFFFC24B)',
      'EcranSombre',
      'ThemeSombre',
    ];
    for (final f in [_ecranHistoire, _ecranSpectacle, 'lib/presentation/jouer/jouer_screen.dart']) {
      final code = File(f).readAsStringSync();
      for (final x in interdits) {
        expect(code.contains(x), isFalse, reason: '$f contient $x');
      }
    }
  });

  test('les tons ne changent pas : ils partent dans les consignes et les parties sauvegardées', () {
    expect(t.liste('histoire_ia.tons'),
        ['Aventure', 'Humour', 'Drame', 'Épique', 'Voyage initiatique', 'Romance', 'Mystère', 'Action']);
    expect(tonsPourIa(t).map((x) => x.name), contains('Drame')); // le ton par défaut du spectacle
  });

  test('les textes des écrans IA ne parlent pas de dé', () {
    final de = RegExp(r'(^|[^\p{L}])(dé|dés|Dé|Dés)([^\p{L}]|$)', unicode: true);
    void verifier(Object? v, String chemin) {
      if (v is String) expect(de.hasMatch(v), isFalse, reason: '$chemin : $v');
      if (v is List) {
        for (final (i, x) in v.indexed) {
          verifier(x, '$chemin.$i');
        }
      }
      if (v is Map) {
        for (final e in v.entries) {
          verifier(e.value, '$chemin.${e.key}');
        }
      }
    }

    for (final section in ['histoire_ia', 'spectacle_ia']) {
      final table = t.table(section);
      expect(table, isNotEmpty, reason: section);
      verifier(table, section);
    }
  });
}
