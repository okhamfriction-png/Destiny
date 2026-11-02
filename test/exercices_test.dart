import 'dart:convert';
import 'dart:io';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/entities/exercice.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/presentation/bibliotheque/bibliotheque_screen.dart';
import 'package:destiny/presentation/bibliotheque/pages_textes.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/exercices/chrono_exercice_screen.dart';
import 'package:destiny/presentation/exercices/exercices_screen.dart';
import 'package:destiny/presentation/exercices/fiche_exercice_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late TextesDestiny t;
late CarnetExercices carnet;
late ContexteBibliotheque bibliotheque;

Future<void> _ouvrir(WidgetTester tester, Widget page, {bool sombre = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(chargee.grammaire, sombre: sombre),
    builder: (context, child) => DestinyDonnees(grammaire: chargee.grammaire, textes: t, child: child!),
    home: Scaffold(body: page),
  ));
  await tester.pumpAndSettle();
}

Finder _onglet(String nom) => find.descendant(of: find.byType(TabBar), matching: find.text(nom));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    chargee = await chargerGrammaire();
    t = chargee.textes;
    carnet = CarnetExercices.depuisJson(
        jsonDecode(File('assets/data/exercices.json').readAsStringSync()) as Map<String, dynamic>);
    final d = donneesDeTest();
    bibliotheque = ContexteBibliotheque(
      catalogue: CatalogueDeTest(await d.loadDangers(), await d.loadLocations()),
      visuels: VisualSettings(),
    );
  });

  group('le carnet', () {
    test('les anciens thèmes restent, intacts', () {
      expect(carnet.exercices, hasLength(32));
      expect({for (final e in carnet.exercices) e.categorie},
          {'Échauffement', 'Statut', 'Spontanéité', 'Écoute', 'Dialogue', 'Imagination'});
      expect(carnet.virelangues, hasLength(50));
      expect(carnet.principes, isNotEmpty);
    });

    test('le principe du jour tient toute la journée et change le lendemain', () {
      final matin = DateTime(2026, 11, 2, 8);
      final soir = DateTime(2026, 11, 2, 23, 30);
      expect(carnet.principeDuJour(matin), carnet.principeDuJour(soir));
      expect(carnet.principeDuJour(matin), isNot(carnet.principeDuJour(DateTime(2026, 11, 3, 8))));
    });

    test('un carnet abîmé ne bloque rien', () {
      final c = CarnetExercices.depuisJson({
        'exercices': [
          {'id': 'a', 'nom': 'A', 'consigne': 'x', 'duree': 60, 'categorie': 'Statut'},
          {'nom': 'sans id'},
          'pas un exercice',
        ],
        'principes': ['p', 3],
      });
      expect(c.exercices.map((e) => e.id), ['a']);
      expect(c.principes, ['p']);
      expect(c.virelangues, isEmpty);
      expect(CarnetExercices.vide.principeDuJour(DateTime(2026)), '');
    });

    test('les durées de la grammaire donnent des chronos', () {
      expect(minutesDuree('5 à 10 min'), [5, 10]);
      expect(minutesDuree('30 min avant de jouer'), [30]);
      expect(minutesDuree('2 à 3 min par scène, puis le débrief'), [2, 3]);
      expect(minutesDuree('le temps qu\'il faut'), [5]);
      for (final e in chargee.grammaire.exercices) {
        expect(minutesDuree(e.duree), isNotEmpty, reason: e.id);
      }
    });
  });

  group('les exercices de la grammaire', () {
    test('les 19 exercices sont rangés dans les trois thèmes', () {
      final g = chargee.grammaire;
      expect(g.exercices, hasLength(19));
      for (final th in g.themesExercices) {
        expect(g.exercices.where((e) => e.themeId == th.id), isNotEmpty, reason: th.id);
        expect(th.principe, contains('Mark Jane'));
      }
      expect(g.exercices.every((e) => g.themesExercices.any((th) => th.id == e.themeId)), isTrue);
    });

    test('chaque exercice renvoie à une notion de la Bibliothèque', () {
      final cles = {for (final (k, _, _) in entreesBibliotheque(bibliotheque)) k};
      for (final e in chargee.grammaire.exercices) {
        expect(cles, contains(notionExercice(e)), reason: e.id);
      }
      expect(kNotionsExercices.keys.toSet(), {for (final e in chargee.grammaire.exercices) e.id});
    });

    test('chaque texte des exercices existe', () {
      expect(textesManquants(['lib/presentation/exercices']), isEmpty);
    });
  });

  group('l\'écran', () {
    for (final sombre in [true, false]) {
      testWidgets('les trois nouveaux onglets à côté des anciens (${sombre ? 'sombre' : 'clair'})', (tester) async {
        await _ouvrir(tester, ExercicesScreen(audioService: AudioService()..setMuted(true), carnet: carnet),
            sombre: sombre);
        for (final nom in ['Échauffement', 'Statut', 'Imagination', 'CROW', 'Lieu', 'Destiny', t.t('exercices.solo')]) {
          expect(_onglet(nom), findsOneWidget, reason: nom);
        }
        // L'onglet ouvert d'abord : Échauffement, avec le principe du jour.
        expect(find.text(t.t('exercices.principe_du_jour').toUpperCase()), findsOneWidget);
        expect(find.text(carnet.principeDuJour(DateTime.now())), findsOneWidget);

        await tester.ensureVisible(_onglet('CROW'));
        await tester.pumpAndSettle();
        await tester.tap(_onglet('CROW'));
        await tester.pumpAndSettle();
        final crow = chargee.grammaire.themesExercices.firstWhere((th) => th.id == 'crow');
        expect(find.text(crow.principe), findsOneWidget);
        expect(find.text(crow.explication), findsOneWidget);
        expect(find.text('Plans de genre en 10 secondes'), findsOneWidget);
        expect(find.byType(BadgeMarkJane), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un exercice du carnet garde son chrono', (tester) async {
      await _ouvrir(tester, ExercicesScreen(audioService: AudioService()..setMuted(true), carnet: carnet));
      final premier = carnet.exercices.firstWhere((e) => e.categorie == 'Échauffement');
      await tester.tap(find.text(premier.nom));
      await tester.pumpAndSettle();
      expect(find.byType(ChronoExerciceScreen), findsOneWidget);
      expect(find.text(t.t('exercices.prets')), findsOneWidget);
      await tester.tap(find.text(t.t('exercices.demarrer')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(t.t('exercices.parti')), findsOneWidget);
      await tester.tap(find.text(t.t('exercices.pause')));
      await tester.pump();
      expect(find.text(t.t('exercices.prets')), findsOneWidget);
    });

    testWidgets('la fiche : cartes à tirer, débrief, chrono et Bibliothèque', (tester) async {
      final e = chargee.grammaire.exercices.firstWhere((x) => x.id == 'trois_phrases');
      final theme = chargee.grammaire.themesExercices.firstWhere((th) => th.id == e.themeId);
      await _ouvrir(
        tester,
        FicheExerciceScreen(exercice: e, theme: theme, audio: AudioService()..setMuted(true), bibliotheque: bibliotheque),
      );
      expect(find.text(e.titre), findsOneWidget);
      expect(find.byType(BadgeMarkJane), findsOneWidget);

      final tirer = find.text(t.t('exercices.tirer'));
      await tester.scrollUntilVisible(tirer, 200);
      await tester.ensureVisible(tirer);
      await tester.pumpAndSettle();
      expect(find.text(t.t('exercices.cartes_vide')), findsOneWidget);
      await tester.tap(tirer);
      await tester.pumpAndSettle();
      final tiree = e.cartesATirer.where((c) => find.text(c).evaluate().isNotEmpty).toList();
      expect(tiree, hasLength(1));

      // Jamais deux fois la même carte de suite.
      for (var i = 0; i < 5; i++) {
        final avant = e.cartesATirer.firstWhere((c) => find.text(c).evaluate().isNotEmpty);
        await tester.tap(tirer);
        await tester.pumpAndSettle();
        expect(find.text(avant), findsNothing);
      }

      final debrief = find.text('« ${e.debrief} »');
      await tester.scrollUntilVisible(debrief, 200);
      expect(debrief, findsOneWidget);

      final biblio = find.text(t.t('exercices.voir_bibliotheque'));
      await tester.scrollUntilVisible(biblio, 200);
      await tester.ensureVisible(biblio);
      await tester.pumpAndSettle();
      expect(find.text(t.t('exercices.minutes', {'n': '15'})), findsOneWidget);
      expect(find.text(t.t('exercices.minutes', {'n': '20'})), findsOneWidget);
      await tester.tap(biblio);
      await tester.pumpAndSettle();
      expect(find.byType(VouloirBesoinScreen), findsOneWidget);
    });

    testWidgets('chaque fiche tient sur un téléphone', (tester) async {
      for (final e in chargee.grammaire.exercices) {
        await _ouvrir(
          tester,
          FicheExerciceScreen(exercice: e, audio: AudioService()..setMuted(true), bibliotheque: bibliotheque),
        );
        expect(tester.takeException(), isNull, reason: e.id);
      }
    });
  });
}
