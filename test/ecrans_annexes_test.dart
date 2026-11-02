import 'dart:convert';
import 'dart:io';

import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/location_details.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/relation_cheatsheet.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
import 'package:destiny/application/state/spectacle_store.dart';
import 'package:destiny/domain/entities/chat_story.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/screens/ai_config_screen.dart';
import 'package:destiny/presentation/screens/chat_archives_screen.dart';
import 'package:destiny/presentation/screens/location_details_screen.dart';
import 'package:destiny/presentation/screens/music_screen.dart';
import 'package:destiny/presentation/screens/relation_cheatsheet_screen.dart';
import 'package:destiny/presentation/screens/spectacle_archives_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:destiny/presentation/widgets/sound_mixer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'serie_test.dart' show FauxLlm;
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late TextesDestiny t;
late CatalogueDeTest catalogue;

/// Les écrans annexes passés au design Destiny (thème clair et sombre).
const List<String> _ecransAnnexes = [
  'lib/presentation/screens/ai_config_screen.dart',
  'lib/presentation/screens/music_screen.dart',
  'lib/presentation/widgets/sound_mixer_sheet.dart',
  'lib/presentation/screens/relation_cheatsheet_screen.dart',
  'lib/presentation/screens/location_details_screen.dart',
  'lib/presentation/widgets/location_detail_section.dart',
  'lib/presentation/screens/chat_archives_screen.dart',
  'lib/presentation/screens/spectacle_archives_screen.dart',
];

/// Ouvre [page] sur un téléphone de 390 × 844, dans le thème demandé.
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

/// Une bibliothèque musicale chargée (les manifestes viennent des assets).
Future<MusicController> _musique(WidgetTester tester) async {
  final m = (await tester.runAsync(() async {
    final m = MusicController();
    for (var i = 0; i < 200 && m.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return m;
  }))!;
  expect(m.loading, isFalse);
  expect(m.tracks, isNotEmpty);
  return m;
}

/// Le lecteur audio n'existe pas en test : ses canaux répondent « rien ».
void _lecteurMuet() {
  final messager = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messager.allMessagesHandler = (canal, gestionnaire, message) {
    if (canal.startsWith('xyz.luan/audioplayers')) {
      return Future<ByteData?>.value(const StandardMethodCodec().encodeSuccessEnvelope(null));
    }
    return gestionnaire != null ? gestionnaire(message) : messager.delegate.send(canal, message);
  };
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    chargee = await chargerGrammaire();
    t = chargee.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
    _lecteurMuet();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final sombre in [false, true]) {
    group(sombre ? 'thème sombre' : 'thème clair', () {
      testWidgets('configurer l\'IA', (tester) async {
        final ia = (await tester.runAsync(AiSettings.load))!;
        await _ouvrir(tester, AiConfigScreen(settings: ia), sombre: sombre);
        expect(find.text(t.t('ia_config.titre')), findsOneWidget);
        expect(find.text(t.t('ia_config.a_configurer')), findsOneWidget);
        expect(find.text(t.t('ia_config.styles.${ia.narration.name}.aide')), findsOneWidget);
        // La clé se montre et se cache.
        await tester.tap(find.byTooltip(t.t('accessibilite.afficher')));
        await tester.pump();
        expect(find.byTooltip(t.t('accessibilite.masquer')), findsOneWidget);
        // Une clé saisie : l'IA est prête.
        await tester.enterText(find.byType(TextField).last, 'sk-test');
        await tester.pumpAndSettle();
        expect(ia.token, 'sk-test');
        expect(find.text(t.t('ia_config.prete', {'fournisseur': ia.provider.label, 'modele': ia.model})),
            findsOneWidget);
        // Un autre style du maître du destin.
        final normal = find.text(t.t('ia_config.styles.normal.nom'));
        await tester.ensureVisible(normal);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(normal);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(ia.narration, NarrationStyle.normal);
        expect(find.text(t.t('ia_config.styles.normal.aide')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('la musique, puis la barre de lecture', (tester) async {
        final musique = await _musique(tester);
        await _ouvrir(
          tester,
          Scaffold(appBar: AppBar(title: Text(t.t('navigation.musique'))), body: MusicScreen(controller: musique)),
          sombre: sombre,
        );
        final premiere = musique.categories.first;
        expect(
            find.text(t.t('musique.categorie', {'nom': premiere, 'n': '${musique.tracksOf(premiere).length}'})),
            findsOneWidget);
        expect(find.text(t.t('musique.tri_az')), findsOneWidget);
        await tester.tap(find.text(t.t('musique.tri_az')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('musique.tri_za')), findsOneWidget);
        // Une piste choisie (le lecteur audio n'existe pas en test).
        await tester.runAsync(() => musique
            .playTrack(musique.tracksOf(premiere).first)
            .timeout(const Duration(milliseconds: 200))
            .catchError((_) {}));
        await tester.pumpAndSettle();
        expect(find.byTooltip(t.t('accessibilite.arreter')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('la régie son', (tester) async {
        final musique = await _musique(tester);
        await _ouvrir(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(onPressed: () => showSoundMixer(context, musique), child: const Text('ouvrir')),
              ),
            ),
          ),
          sombre: sombre,
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();
        expect(find.byType(SoundMixerSheet), findsOneWidget);
        expect(find.text(t.t('navigation.regie_son')), findsOneWidget);
        expect(find.text(t.t('musique.boucle')), findsOneWidget);
        // La boucle se coupe et se remet.
        final boucle = musique.boucle;
        await tester.tap(find.text(t.t('musique.boucle')));
        await tester.pumpAndSettle();
        expect(musique.boucle, !boucle);
        // Une piste en pause : le bandeau du haut.
        await tester.runAsync(() => musique
            .playTrack(musique.tracksOf(musique.categories.first).first)
            .timeout(const Duration(milliseconds: 200))
            .catchError((_) {}));
        await tester.pumpAndSettle();
        expect(find.textContaining(t.t('musique.en_pause', {'titre': ''})), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('l\'antisèche de relations', (tester) async {
        final antiseche = RelationCheatsheet();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await _ouvrir(tester, RelationCheatsheetScreen(cheatsheet: antiseche), sombre: sombre);
        expect(find.text(t.t('relations.titre')), findsOneWidget);
        expect(find.text(antiseche.links.first.texte), findsOneWidget);
        // Un nouveau lien, ajouté puis supprimé.
        await tester.tap(find.text(t.t('relations.ajouter')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('relations.nouveau')), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Elle lui a sauvé la mise, il ne le sait pas.');
        await tester.runAsync(() async {
          await tester.tap(find.text(t.t('relations.valider')));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(antiseche.links.last.texte, 'Elle lui a sauvé la mise, il ne le sait pas.');
        final avant = antiseche.links.length;
        final premier = antiseche.links.first.texte;
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip(t.t('accessibilite.supprimer')).first);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(antiseche.links, hasLength(avant - 1));
        expect(find.text(premier), findsNothing);
        // Restaurer demande d'abord.
        await tester.tap(find.byTooltip(t.t('relations.restaurer')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('relations.restaurer_texte')), findsOneWidget);
        await tester.tap(find.text(t.t('relations.annuler')));
        await tester.pumpAndSettle();
        // La vue en lecture seule.
        await _ouvrir(
          tester,
          Scaffold(body: SingleChildScrollView(child: RelationCheatsheetView(cheatsheet: antiseche))),
          sombre: sombre,
        );
        expect(find.text(t.t('relations.intro')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('les détails des lieux : la liste, la fiche, l\'édition', (tester) async {
        final store = LocationDetailsStore();
        await tester.runAsync(store.load);
        expect(store.locations, isNotEmpty);
        final lieu = store.locations.firstWhere((l) => !(store.byId(l.id)?.isEmpty ?? true));
        await tester.runAsync(() => store.setDetails(lieu.id, const LocationDetails(sousEspaces: ['la cuisine'])));
        await _ouvrir(tester, LocationDetailsListScreen(store: store), sombre: sombre);
        expect(find.text(t.t('details_lieux.titre')), findsOneWidget);
        expect(tester.takeException(), isNull);
        // L'édition d'un lieu.
        final element = find.text(lieu.name);
        await tester.ensureVisible(element);
        await tester.pumpAndSettle();
        await tester.tap(element);
        await tester.pumpAndSettle();
        expect(find.text(t.t('details_lieux.modifier', {'nom': lieu.name})), findsOneWidget);
        expect(find.text(t.t('details_lieux.vocabulaire').toUpperCase()), findsOneWidget);
        expect(find.text(t.t('details_lieux.restaurer')), findsOneWidget);
        final ajouter = find.text(t.t('details_lieux.ajouter')).first;
        final champs = find.byType(TextField).evaluate().length;
        await tester.tap(ajouter);
        await tester.pumpAndSettle();
        expect(find.byType(TextField).evaluate().length, champs + 1);
        await tester.enterText(find.byType(TextField).at(1), 'la cave');
        await tester.runAsync(() async {
          await tester.tap(find.text(t.t('details_lieux.enregistrer')));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(store.byId(lieu.id)!.sousEspaces, ['la cuisine', 'la cave']);
        expect(find.text(t.t('details_lieux.titre')), findsOneWidget);
        // La fiche en lecture seule.
        await _ouvrir(tester, LocationDetailsScreen(store: store, locationName: lieu.name), sombre: sombre);
        expect(find.text('la cave'), findsOneWidget);
        expect(find.text(t.t('details_lieux.sous_espaces_aide')), findsOneWidget);
        await _ouvrir(tester, LocationDetailsScreen(store: store, locationName: 'Nulle part'), sombre: sombre);
        expect(find.text(t.t('details_lieux.vide')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('les histoires archivées', (tester) async {
        final ia = (await tester.runAsync(AiSettings.load))!;
        final c = ChatController(
          chatStore: InMemoryChatStore(),
          llm: FauxLlm('Un résumé.'),
          aiSettings: ia,
          catalogue: catalogue,
          grammaire: chargee,
        );
        await _ouvrir(tester, ChatArchivesScreen(controller: c), sombre: sombre);
        expect(find.text(t.t('archives.histoires.vide')), findsOneWidget);
        c.stories = [
          for (final (id, titre) in [('a', 'Le phare dans la tempête'), ('b', 'La cave aux secrets')])
            ChatStory(id: id, title: titre, createdAt: 1, context: '', messages: const [], archived: true),
        ];
        await _ouvrir(tester, ChatArchivesScreen(controller: c), sombre: sombre);
        expect(find.text('Le phare dans la tempête'), findsOneWidget);
        expect(find.byTooltip(t.t('archives.histoires.desarchiver')), findsNWidgets(2));
        // La sélection.
        await tester.tap(find.byTooltip(t.t('archives.histoires.selectionner')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('archives.histoires.selection_un', {'n': '0'})), findsOneWidget);
        await tester.tap(find.byTooltip(t.t('archives.histoires.tout_selectionner')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('archives.histoires.selection', {'n': '2'})), findsOneWidget);
        await tester.tap(find.byTooltip(t.t('archives.histoires.supprimer_selection')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('archives.histoires.supprimer_n', {'n': '2'})), findsOneWidget);
        await tester.tap(find.text(t.t('archives.histoires.annuler')));
        await tester.pumpAndSettle();
        expect(c.archivedStories, hasLength(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('les parties archivées et leur débrief', (tester) async {
        SharedPreferences.setMockInitialValues({
          'spectacle_history': jsonEncode([
            {
              'lieu': 'Le phare',
              'danger': 'La tempête',
              'archetype': 'Lion',
              'mode': 'classique',
              'createdAt': 1700000000000,
              'log': [
                {'isPlayer': false, 'archetype': 'Rat', 'personnage': 'Raoul', 'texte': 'Vous sentez ?', 'didascalie': 'Il renifle.'},
                {'isPlayer': true, 'personnage': 'Mila', 'texte': 'Non.', 'success': true},
                {'isPlayer': true, 'texte': 'Peut-être.', 'success': false},
              ],
              'debrief': {
                'Ce qui a marché': ['L\'écoute', 'Le statut'],
                'La suite': 'Le rythme',
              },
            },
          ]),
        });
        final ia = (await tester.runAsync(AiSettings.load))!;
        final c = SpectacleController(
          catalogue: catalogue,
          grammaire: chargee,
          llm: FauxLlm(''),
          aiSettings: ia,
          store: SpectacleStore(),
        );
        await _ouvrir(tester, SpectacleArchivesScreen(controller: c), sombre: sombre);
        expect(find.text(t.t('archives.spectacles.titre')), findsOneWidget);
        expect(find.text('Le phare · La tempête'), findsOneWidget);
        await tester.tap(find.text('Le phare · La tempête'));
        await tester.pumpAndSettle();
        expect(find.text('Il renifle.'), findsOneWidget);
        expect(find.text(t.t('archives.spectacles.toi_personnage', {'personnage': 'Mila'})), findsOneWidget);
        expect(find.text(t.t('archives.spectacles.toi')), findsOneWidget);
        final debrief = find.text(t.t('archives.spectacles.debrief'));
        await tester.ensureVisible(debrief);
        await tester.pumpAndSettle();
        expect(find.text('La suite'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Vider demande d'abord.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(t.t('archives.spectacles.vider')));
        await tester.pumpAndSettle();
        expect(find.text(t.t('archives.spectacles.vider_texte')), findsOneWidget);
        await tester.tap(find.text(t.t('archives.spectacles.annuler')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  }

  test('chaque texte des écrans annexes existe', () {
    expect(textesManquants(_ecransAnnexes), isEmpty);
    // Les clés composées à l'exécution.
    for (final s in NarrationStyle.values) {
      expect(t.t('ia_config.styles.${s.name}.nom'), isNotEmpty, reason: s.name);
      expect(t.t('ia_config.styles.${s.name}.aide'), isNotEmpty, reason: s.name);
    }
    for (final cle in ['sous_espaces', 'fonctions', 'vocabulaire']) {
      expect(t.t('details_lieux.$cle'), isNotEmpty, reason: cle);
      expect(t.t('details_lieux.${cle}_aide'), isNotEmpty, reason: cle);
    }
  });

  test('les textes des écrans annexes ne parlent pas du dé', () {
    final de = RegExp(r'(^|[^\p{L}])(dé|dés|Dé|Dés)([^\p{L}]|$)', unicode: true);
    final textes = jsonDecode(File('assets/data/destiny_textes.json').readAsStringSync()) as Map<String, dynamic>;
    void parcourir(Object? v, String chemin) {
      if (v is String) {
        expect(de.hasMatch(v), isFalse, reason: '$chemin : $v');
      } else if (v is Map) {
        v.forEach((k, x) => parcourir(x, '$chemin.$k'));
      } else if (v is List) {
        for (final x in v) {
          parcourir(x, chemin);
        }
      }
    }

    for (final section in ['ia_config', 'musique', 'relations', 'details_lieux', 'archives']) {
      expect(textes[section], isA<Map<String, dynamic>>(), reason: section);
      parcourir(textes[section], section);
    }
  });

  test('les écrans annexes suivent le thème : plus de couleurs du vieux thème sombre', () {
    final interdits = [
      RegExp(r'Colors\.white\d+'),
      RegExp(r'Colors\.black\d+'),
      RegExp(r'Color\(0xFF141029\)'),
      RegExp(r'Color\(0xFF0A0818\)'),
      RegExp(r'Color\(0xFF120F1E\)'),
      RegExp(r'ThemeSombre\('),
      RegExp(r'EcranSombre\('),
    ];
    // Colors.white n'est permis que comme cible d'éclaircissement
    // (Color.lerp) et pour l'icône blanche sur la vignette colorée d'une piste.
    bool blancPermis(String ligne) =>
        ligne.contains('Color.lerp(') || ligne.contains('Icon(_iconFor(track), color: Colors.white');
    final fautes = <String>[];
    for (final chemin in [
      ..._ecransAnnexes,
      'lib/presentation/screens/settings_screen.dart',
      'lib/presentation/screens/root_screen.dart',
    ]) {
      final lignes = File(chemin).readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        for (final r in interdits) {
          if (r.hasMatch(ligne)) fautes.add('$chemin:${i + 1} : ${r.pattern}');
        }
        if (RegExp(r'Colors\.white\b(?!\d)').hasMatch(ligne) && !blancPermis(ligne)) {
          fautes.add('$chemin:${i + 1} : Colors.white');
        }
      }
    }
    expect(fautes, isEmpty);
  });
}
