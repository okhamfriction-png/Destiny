import 'dart:io';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/location_details.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/relation_cheatsheet.dart';
import 'package:destiny/application/state/troupe_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/entities/exercice.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/presentation/accueil/decouvrir_screen.dart';
import 'package:destiny/presentation/bibliotheque/bibliotheque_screen.dart';
import 'package:destiny/presentation/bibliotheque/livret_screen.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/exercices/exercices_screen.dart';
import 'package:destiny/presentation/exercices/fiche_exercice_screen.dart';
import 'package:destiny/presentation/reglages/reglages_destiny_screen.dart';
import 'package:destiny/presentation/screens/about_screen.dart';
import 'package:destiny/presentation/screens/settings_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:destiny/presentation/troupe/troupe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late TextesDestiny t;
late CatalogueDeTest catalogue;

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// Ouvre [page] sur un téléphone de 390 px, avec un texte agrandi de
/// [echelle] (réglage d'accessibilité du téléphone).
Future<void> _ouvrir(WidgetTester tester, Widget page, {double echelle = 1.6, bool sombre = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(chargee.grammaire, sombre: sombre),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)),
      child: DestinyDonnees(grammaire: chargee.grammaire, textes: t, child: child!),
    ),
    home: page,
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    chargee = await chargerGrammaire();
    t = chargee.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  test('les couleurs du texte se lisent, en clair comme en sombre (contraste AA)', () {
    for (final sombre in [false, true]) {
      final c = DestinyCouleurs.depuisGrammaire(chargee.grammaire, sombre: sombre);
      for (final fond in [c.fond, c.carte]) {
        for (final (nom, couleur) in [
          ('texte', c.texte),
          ('secondaire', c.texteSecondaire),
          ('titre', c.titre),
          ('bleu', c.bleuTexte),
        ]) {
          expect(_contraste(couleur, fond), greaterThanOrEqualTo(4.5),
              reason: '$nom sur ${fond == c.fond ? 'le fond' : 'une carte'} (${sombre ? 'sombre' : 'clair'})');
        }
      }
      expect(_contraste(c.kidsTexte, c.kidsFond), greaterThanOrEqualTo(4.5));
    }
  });

  test('chaque bouton-icône a un libellé pour les lecteurs d\'écran', () {
    final sansLibelle = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      for (final m in RegExp(r'IconButton(?:\.\w+)?\(').allMatches(s)) {
        var i = m.end;
        var profondeur = 1;
        while (profondeur > 0 && i < s.length) {
          if (s[i] == '(') profondeur++;
          if (s[i] == ')') profondeur--;
          i++;
        }
        if (!s.substring(m.start, i).contains('tooltip')) {
          sansLibelle.add('${f.path}:${'\n'.allMatches(s.substring(0, m.start)).length + 1}');
        }
      }
    }
    expect(sansLibelle, isEmpty);
  });

  test('la régie, le rituel et la Série ne dépendent pas du réseau', () {
    final reseau = RegExp(r"import '[^']*(llm_service|package:http)[^']*';");
    for (final dossier in ['lib/presentation/troupe', 'lib/presentation/destiny', 'lib/presentation/serie']) {
      for (final f in Directory(dossier).listSync(recursive: true).whereType<File>()) {
        expect(reseau.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    }
  });

  group('un texte très agrandi tient sur un téléphone', () {
    testWidgets('Troupe', (tester) async {
      final ctx = ContexteTroupe(
        store: TroupeStore(),
        reglages: ReglagesDestiny(),
        catalogue: catalogue,
        audio: AudioService()..setMuted(true),
        musique: MusicController(),
        visuels: VisualSettings(),
      );
      await _ouvrir(
        tester,
        Scaffold(body: TroupeScreen(contexte: ctx, versJouer: () {}, versExercices: () {}, versBibliotheque: () {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Découvrir Destiny, ses quatre écrans', (tester) async {
      await _ouvrir(tester, const DecouvrirScreen(), sombre: true);
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull, reason: 'écran ${i + 1}');
        await tester.tap(find.text(t.t('decouvrir.suivant')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: 'écran 4');
    });

    testWidgets('la Bibliothèque et le livret', (tester) async {
      await _ouvrir(
          tester, BibliothequeScreen(contexte: ContexteBibliotheque(catalogue: catalogue, visuels: VisualSettings())));
      expect(tester.takeException(), isNull);
      await _ouvrir(tester, const LivretScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('les Exercices et une fiche', (tester) async {
      await _ouvrir(
        tester,
        Scaffold(
          body: ExercicesScreen(
            audioService: AudioService()..setMuted(true),
            carnet: const CarnetExercices(
              exercices: [Exercice(id: 'a', nom: 'La machine collective', consigne: 'Un geste, un son.', duree: 180, categorie: 'Échauffement')],
              principes: ['Accepter l\'offre.'],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final e = chargee.grammaire.exercices.firstWhere((x) => x.id == 'trois_phrases');
      await _ouvrir(tester, FicheExerciceScreen(exercice: e, audio: AudioService()..setMuted(true)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('les Réglages, Destiny et À propos', (tester) async {
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
      expect(tester.takeException(), isNull);
      await _ouvrir(
          tester, ReglagesDestinyScreen(reglages: r, audio: AudioService()..setMuted(true), musique: MusicController()));
      expect(tester.takeException(), isNull);
      await _ouvrir(tester, const AboutScreen());
      expect(tester.takeException(), isNull);
    });
  });
}
