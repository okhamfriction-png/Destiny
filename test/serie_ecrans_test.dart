import 'dart:convert';
import 'dart:io';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/serie_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/serie/regles_serie.dart';
import 'package:destiny/domain/serie/serie.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/serie/contexte_serie.dart';
import 'package:destiny/presentation/serie/saison_screen.dart';
import 'package:destiny/presentation/serie/series_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'troupe_test.dart' show CatalogueDeTest;

late Grammaire g;
late TextesDestiny t;
late CatalogueDeTest catalogue;

Future<ContexteSerie> _contexte(WidgetTester tester) async {
  final store = SerieStore(lire: lireFichier);
  await tester.runAsync(() => store.charger(grammaire: g));
  final reglages = ReglagesDestiny();
  return ContexteSerie(
    store: store,
    reglages: reglages,
    catalogue: catalogue,
    audio: AudioService()..setMuted(true),
    musique: MusicController(),
    visuels: VisualSettings(),
  );
}

Widget _appli(Widget home) => MaterialApp(
      theme: themeDestiny(g, sombre: true),
      builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
      home: home,
    );

/// La première puce dont le texte est dans [noms].
Finder _puce(Iterable<String> noms) {
  final ensemble = noms.toSet();
  return find.byWidgetPredicate((w) => w is ChoiceChip && w.label is Text && ensemble.contains((w.label as Text).data)).first;
}

Future<void> _taper(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 400, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  testWidgets('un épisode, puis « Faire la suite » : il devient le premier d\'une saison', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ctx = await _contexte(tester);
    await tester.pumpWidget(_appli(SeriesScreen(contexte: ctx)));
    await tester.pumpAndSettle();
    expect(find.text(t.t('serie.vide')), findsOneWidget);

    // Un nouvel épisode, pour des adultes, sans univers.
    await _taper(tester, find.text(t.t('serie.nouvel_episode')));
    await _taper(tester, find.text(t.t('serie.creer.suivant')));

    // Les personnages : quatre joueurs, une distribution équilibrée.
    final s = ctx.store.series.single;
    expect(s.personnages.where((p) => !p.pnj), hasLength(4));
    expect(s.personnages.every((p) => p.archetypeId.isNotEmpty && p.animalId.isNotEmpty), isTrue);
    expect(s.personnages.any((p) => p.archetypeId == Grammaire.alarmisteId), isTrue);
    await tester.enterText(find.byType(TextField).first, 'Naël');
    await tester.pump();
    expect(s.personnages.first.joueur, 'Naël');
    await _taper(tester, find.text(t.t('serie.personnages.vers_episode')));

    // La préparation : un lieu (et ses figurants), un groupe, un danger.
    final e = s.episodes.single;
    expect(e.saison, 0);
    await _taper(tester, _puce(catalogue.lieux.map((l) => l.name)));
    expect(e.lieuNom, isNotEmpty);
    expect(e.pnjs, hasLength(3));
    expect(e.pnjs.every((p) => p.mode == ModePnj.figurant), isTrue);
    await _taper(tester, find.text(t.liste('mise_en_place.groupes').first).first);
    await _taper(tester, _puce(catalogue.dangers.map((d) => d.name)));
    expect(e.paliers, hasLength(4));
    await _taper(tester, find.text(t.t('serie.preparation.commencer')));
    expect(e.etape, EtapeEpisode.jeu);

    // Le jeu : Destiny fait monter d'un palier, avec son rituel.
    await _taper(tester, find.text(t.t('regie.destiny').toUpperCase()));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    await _taper(tester, find.text(t.t('rituel.reprendre')));
    expect(e.palierAtteint, 2);
    expect(find.text(t.t('serie.jeu.rappel_fixer')), findsOneWidget);
    // Un figurant passe au service du méchant ? Pas sans méchant.
    expect(find.text(t.t('serie.jeu.accepte_offre')), findsNothing);
    // Un figurant change de mode.
    await _taper(tester, find.text(t.t('modes_pnj.figurant')).first);
    expect(e.pnjs.where((p) => p.mode == ModePnj.sbire), hasLength(1));
    await _taper(tester, find.text(t.t('serie.jeu.terminer')));
    await _taper(tester, find.text(t.t('serie.oui')));
    expect(e.etape, EtapeEpisode.bilan);

    // Le bilan, puis la fiche de la série.
    await _taper(tester, find.text(t.t('debrief.choix_besoin')).first);
    expect(e.roles.first.choix, ChoixFinal.besoin);
    await _taper(tester, find.text(t.t('serie.bilan.terminer')));
    expect(e.etape, EtapeEpisode.termine);
    expect(find.text(t.t('serie.fiche.faire_la_suite')), findsOneWidget);

    // Faire la suite : le méchant reflet du protagoniste visé.
    await _taper(tester, find.text(t.t('serie.fiche.faire_la_suite')));
    expect(find.text(t.t('serie.saison.depuis_episode')), findsOneWidget);
    final cible = s.personnages.firstWhere((p) => !p.pnj);
    final reflet = mechantsReflets(g, ctx.store.catalogue, archetypeId: cible.archetypeId, kids: false).first;
    await _taper(tester, find.text(reflet.nom).first);
    final champs = find.byType(TextField);
    expect(champs, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(champs.at(i), 'Présage ${i + 1}');
    }
    await tester.pump();
    await _taper(tester, find.text(t.t('serie.saison.valider')));

    expect(s.saisons.single.mechantId, reflet.id);
    expect(s.saisons.single.cibleId, cible.id);
    expect(e.saison, 1);
    expect(e.numero, 1);
    expect(e.presage, 'Présage 1');
    expect(s.nature, NatureSerie.saison);

    // L'épisode 2 : le méchant reste dans l'ombre, ses sbires sont là.
    await _taper(tester, find.text(t.t('serie.fiche.preparer', {'n': '2'})));
    expect(find.text(t.t('serie.preparation.ombre')), findsOneWidget);
    expect(find.textContaining('Présage 2'), findsWidgets);
    await _taper(tester, _puce(catalogue.lieux.map((l) => l.name)));
    final e2 = s.episodes.last;
    expect(e2.numero, 2);
    expect(e2.pnjs.where((p) => p.duMechant), hasLength(reflet.sbires.length));

    // Tout est gardé.
    final prefs = await SharedPreferences.getInstance();
    final relu = Serie.depuisJson(
        (jsonDecode(prefs.getString(SerieStore.cleSeries)!) as List).first as Map<String, dynamic>);
    expect(relu.saisons.single.presages, ['Présage 1', 'Présage 2', 'Présage 3', 'Présage 4']);
  });

  testWidgets('le traître : un seul joueur voit l\'offre, écran caché', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ctx = await _contexte(tester);
    final s = await ctx.store.creer(reglages: ReglagesSerie(traitre: true));
    s.personnages.addAll([
      PersonnageSerie(id: 'a', joueur: 'Léa', archetypeId: 'leader', animalId: 'lion'),
      PersonnageSerie(id: 'b', joueur: 'Tom', archetypeId: 'cynique', animalId: 'singe'),
      PersonnageSerie(id: 'c', archetypeId: 'alarmiste', animalId: 'rat', pnj: true),
    ]);
    await tester.pumpWidget(_appli(SaisonScreen(contexte: ctx, serie: s)));
    await tester.pumpAndSettle();
    final reflet = g.mechantsReflets('leader').first;
    await _taper(tester, find.text(reflet.nom).first);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'P$i');
    }
    await tester.pump();
    await _taper(tester, find.text(t.t('serie.saison.valider')));

    // Le traître n'est ni la cible (Léa), ni le personnage du maître du jeu.
    expect(s.saisons.single.traitre!.personnageId, 'b');
    expect(find.text(t.t('serie.traitre.passer', {'joueur': 'Tom'})), findsOneWidget);
    expect(find.text(reflet.offreAuTraitre), findsNothing);
    await _taper(tester, find.text(t.t('serie.traitre.voir')));
    expect(find.text(reflet.offreAuTraitre), findsOneWidget);
    await _taper(tester, find.text(t.t('serie.traitre.accepte')));
    expect(s.saisons.single.traitre!.accepte, isTrue);
    expect(find.text(t.t('serie.traitre.fin')), findsOneWidget);
  });

  test('chaque texte des écrans de la Série existe', () {
    final textes = jsonDecode(File('assets/data/destiny_textes.json').readAsStringSync()) as Map<String, dynamic>;
    bool existe(String chemin) {
      Object? v = textes;
      for (final cle in chemin.split('.')) {
        if (v is! Map) return false;
        v = v[cle];
      }
      return v is String || v is List || v is Map;
    }

    final manquants = <String>[];
    for (final f in Directory('lib/presentation/serie').listSync().whereType<File>()) {
      final code = f.readAsStringSync();
      // Les chemins écrits en entier.
      for (final m in RegExp(r"t\.t\('((?:serie|regie|mise_en_place|debrief|modes_pnj|navigation|bibliotheque|preparer|rituel|mode_enfant|ia_jeu)\.[a-z_\.]+)'").allMatches(code)) {
        if (!existe(m.group(1)!)) manquants.add('${f.path} : ${m.group(1)}');
      }
      // Les raccourcis locaux : String k(String x) => t.t('serie.saison.$x').
      final prefixes = {
        for (final m in RegExp(r"String (\w+)\(String \w+(?:, \[Map<String, String> \w+ = const \{\}\])?\) => t\.t\('([a-z_\.]+)\.\$").allMatches(code))
          m.group(1)!: _prefixes(code, m.group(1)!),
      };
      for (final e in prefixes.entries) {
        for (final m in RegExp("\\b${e.key}\\('([a-z_\\.]+)'").allMatches(code)) {
          if (!e.value.any((p) => existe('$p.${m.group(1)}'))) manquants.add('${f.path} : ${e.key}(${m.group(1)})');
        }
      }
    }
    expect(manquants, isEmpty);
  });
}

/// Tous les préfixes qu'un raccourci prend dans un fichier.
List<String> _prefixes(String code, String nom) => [
      for (final m in RegExp("String $nom\\(String \\w+(?:, \\[Map<String, String> \\w+ = const \\{\\}\\])?\\) => t\\.t\\('([a-z_\\.]+)\\.\\\$")
          .allMatches(code))
        m.group(1)!,
    ];
