import 'dart:io';
import 'dart:typed_data';

import 'package:destiny/application/livret/livret.dart';
import 'package:destiny/application/services/export_pdf.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/serie/pbta.dart';
import 'package:destiny/presentation/accueil/decouvrir_screen.dart';
import 'package:destiny/presentation/bibliotheque/livret_screen.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';

late Grammaire g;
late TextesDestiny t;
late Livret livret;

Future<PolicesPdf> _polices() async {
  Future<ByteData> f(String n) async =>
      ByteData.sublistView(Uint8List.fromList(await File('assets/fonts/$n').readAsBytes()));
  return PolicesPdf(
    titre: await f('Cinzel-Bold.ttf'),
    texte: await f('Montserrat-Regular.ttf'),
    texteGras: await f('Montserrat-Bold.ttf'),
    italique: await f('Montserrat-Italic.ttf'),
  );
}

/// Le nombre de pages d'un PDF.
int _pages(Uint8List pdf) => RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(pdf)).length;

Future<void> _ouvrir(WidgetTester tester, Widget page, {Size taille = const Size(390, 844)}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: themeDestiny(g, sombre: false),
    builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
    home: page,
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    livret = construireLivret(g, t);
  });

  group('le livret', () {
    String tout() => [for (final s in livret.sections) for (final b in s.blocs) b.texte].join('\n');

    test('huit sections, dans l\'ordre du cahier des charges, aucune vide', () {
      expect(livret.sections.map((s) => s.id), kSectionsLivret);
      expect(livret.sections.map((s) => s.titre),
          ['Le but', 'Le matériel', 'Les rôles', 'La mise en place', 'Le déroulé', 'La fin', 'Les variantes', 'Les règles d\'or']);
      for (final s in livret.sections) {
        expect(s.blocs, isNotEmpty, reason: s.id);
      }
    });

    test('chaque règle vient de la grammaire', () {
      final texte = tout();
      for (final r in g.reglesDOr) {
        expect(texte, contains(r.titre));
        expect(texte, contains(r.texte));
      }
      for (final p in g.paliers) {
        expect(texte, contains(p.nom));
      }
      for (final ge in g.personnage.acteParActe) {
        expect(texte, contains(ge.verbe));
      }
      expect(g.personnage.acteParActe.map((e) => e.verbe), ['Dire', 'Fixer', 'Bloquer', 'Nommer', 'Choisir']);
      expect(texte, contains(g.personnage.phraseCle));
      expect(texte, contains(g.rituel.premierFige));
      for (final q in g.personnage.echauffement.questions) {
        expect(texte, contains(q));
      }
      for (final r in g.serie.reglesDuMechant) {
        expect(texte, contains(r));
      }
      for (final r in g.modeKids.regles) {
        expect(texte, contains(r.texte));
      }
      expect(texte, contains(t.t('module_traitre.explication')));
    });

    test('les variantes : Série et son jeu de rôle, méchants, sbires, figurants, registre, traître, kids, 4 à 6 joueurs', () {
      final variantes = livret.sections.firstWhere((s) => s.id == 'variantes');
      final intertitres = [for (final b in variantes.blocs) if (b is IntertitreLivret) b.texte];
      expect(intertitres, [
        for (final k in ['a_456', 'serie']) t.t('livret.sous.$k'),
        for (final k in [
          'piece.titre',
          'bonus.titre',
          'mouvements_titre',
          'agenda_titre',
          'principes_titre',
          'mouvements_mj.titre',
          'horloges.titre',
          'blessures.titre',
        ])
          t.t('pbta.$k'),
        for (final k in ['mechants', 'sbires', 'figurants', 'registre', 'traitre', 'kids']) t.t('livret.sous.$k'),
      ]);
    });

    test('le jeu de rôle de la Série : la pièce BRAVE / SMART, les mouvements, le Maître du destin, les blessures', () {
      final variantes = livret.sections.firstWhere((s) => s.id == 'variantes');
      final texte = [for (final b in variantes.blocs) b.texte].join('\n');
      final r = ReglesPbta.depuis(t);
      for (final cle in ['piece.principe', 'piece.succes_texte', 'piece.echec_texte', 'piece.doux', 'piece.dur', 'bonus.principe', 'bonus.seconde_chance', 'bonus.gene']) {
        expect(texte, contains(t.t('pbta.$cle')), reason: cle);
      }
      for (final f in FacePiece.values) {
        expect(texte, contains(t.t('pbta.piece.faces.${f.name}.approche')));
      }
      for (final m in r.mouvements) {
        expect(texte, contains(m.nom));
        expect(texte, contains(m.quand));
        expect(texte, contains(m.avecPiece ? m.echec : m.effet));
      }
      for (final x in [...r.agenda, ...r.principes]) {
        expect(texte, contains(x));
      }
      for (final m in r.mouvementsMj) {
        expect(texte, contains(m.texte));
      }
      for (final x in [...r.blessures(kids: false), ...r.blessures(kids: true)]) {
        expect(texte, contains(x));
      }
      expect(texte, contains(t.t('pbta.horloges.saison')));
    });

    test('aucun texte manquant, ni dé, ni sidéré', () {
      for (final s in livret.sections) {
        for (final b in s.blocs) {
          if (b is InfoLivret) expect(b.libelle.trim(), isNotEmpty, reason: b.valeur);
          if (b is IntertitreLivret) expect(b.texte.trim(), isNotEmpty);
          if (b is PucesLivret) expect(b.items.every((i) => i.trim().isNotEmpty), isTrue);
        }
      }
      final texte = tout().toLowerCase();
      expect(RegExp(r'(^|[^\p{L}])(dé|dés)([^\p{L}]|$)', unicode: true).hasMatch(texte), isFalse);
      expect(texte, isNot(contains('sidéré')));
    });

    test('le PDF du livret', () async {
      final pdf = await livretPdf(livret: livret, g: g, polices: await _polices());
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(_pages(pdf), greaterThanOrEqualTo(4));
    });
  });

  group('les cartes à imprimer', () {
    test('un recto par archétype : 12 cartes, 2 pages de rectos et leurs 2 pages de versos', () async {
      final pdf = await cartesArchetypesPdf(g: g, t: t, polices: await _polices());
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(_pages(pdf), 4);
    });

    test('un recto par animal : 24 cartes, 3 pages de rectos et 3 de versos', () async {
      final pdf = await cartesArchetypesPdf(g: g, t: t, polices: await _polices(), parAnimal: true);
      expect(_pages(pdf), 6);
    });
  });

  group('l\'écran du livret', () {
    testWidgets('tient sur un téléphone, avec son sommaire et l\'export', (tester) async {
      await _ouvrir(tester, const LivretScreen());
      expect(tester.takeException(), isNull);
      expect(find.byTooltip(t.t('livret.exporter')), findsOneWidget);
      for (final s in livret.sections) {
        expect(find.widgetWithText(ActionChip, s.titre), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(ActionChip, t.t('livret.sections.variantes')));
      await tester.pumpAndSettle();
      expect(find.text(t.t('livret.sous.kids')), findsOneWidget);
    });
  });

  group('Découvrir Destiny', () {
    testWidgets('quatre écrans, de la promesse aux personnages', (tester) async {
      var fini = 0;
      await _ouvrir(tester, DecouvrirScreen(quandFini: () => fini++), taille: const Size(360, 640));
      expect(find.text(g.promesse), findsOneWidget);
      await tester.tap(find.text(t.t('decouvrir.suivant')));
      await tester.pumpAndSettle();
      expect(find.text(g.reglesDOr.first.titre), findsOneWidget);
      await tester.tap(find.text(t.t('decouvrir.suivant')));
      await tester.pumpAndSettle();
      expect(find.text(t.t('decouvrir.ecrans.danger.rituel')), findsOneWidget);
      for (final p in g.paliers) {
        expect(find.textContaining(p.nom), findsWidgets);
      }
      await tester.tap(find.text(t.t('decouvrir.suivant')));
      await tester.pumpAndSettle();
      expect(find.text(t.t('decouvrir.ecrans.personnages.titre')), findsOneWidget);
      expect(find.text(t.t('decouvrir.passer')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(t.t('decouvrir.commencer')));
      await tester.pumpAndSettle();
      expect(fini, 1);
    });

    test('vu une fois, il ne revient pas', () async {
      SharedPreferences.setMockInitialValues({});
      final r = ReglagesDestiny();
      await r.charger();
      expect(r.decouverteVue, isFalse);
      await r.changer(decouverteVue: true);
      final relu = ReglagesDestiny();
      await relu.charger();
      expect(relu.decouverteVue, isTrue);
    });

    test('chaque texte de l\'accueil existe', () {
      expect(textesManquants(['lib/presentation/accueil', 'lib/presentation/bibliotheque/livret_screen.dart']), isEmpty);
    });
  });
}
