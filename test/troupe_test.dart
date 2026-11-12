import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/services/export_pdf.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/troupe_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/entities/danger.dart';
import 'package:destiny/domain/entities/dilemma.dart';
import 'package:destiny/domain/entities/location.dart';
import 'package:destiny/domain/grammaire/distribution.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/repositories/catalog_store.dart';
import 'package:destiny/domain/troupe/session.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:destiny/presentation/destiny/composants.dart';
import 'package:destiny/presentation/troupe/composants_troupe.dart';
import 'package:destiny/presentation/troupe/echauffement_screen.dart';
import 'package:destiny/presentation/troupe/regie_screen.dart';
import 'package:destiny/presentation/troupe/troupe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';

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

SessionTroupe _sessionComplete() => SessionTroupe(
      id: '1',
      date: DateTime(2026, 11, 2),
      personnages: [
        PersonnageTroupe(joueur: 'Léa', archetypeId: 'alarmiste', animalId: 'rat', fixeBesoin: 'oser parler'),
        PersonnageTroupe(joueur: 'Tom', archetypeId: 'leader', animalId: 'lion', choixFinal: ChoixFinal.besoin),
      ],
      lieuNom: 'Aquarium',
      groupe: 'une famille',
      dangerNom: 'Un incendie',
      paliers: g.dangerNomme('Un incendie')!.textes,
      objets: ['une clé', 'une lampe', 'une photo'],
      mystere: 'Qui a fermé la vanne ?',
      destinys: [const EvenementDestiny(numero: 1, secondes: 600, manuel: true)],
      notes: [const NoteRegie(secondes: 1390, texte: 'La sœur nomme le besoin du frère')],
      ceQuiAMarche: ['Le silence de l\'acte 3'],
      palierAtteint: 2,
    );

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  group('Session', () {
    test('se relit à l\'identique depuis le JSON', () {
      final s = _sessionComplete();
      final relu = SessionTroupe.depuisJson(jsonDecode(jsonEncode(s.versJson())) as Map<String, dynamic>);
      expect(jsonEncode(relu.versJson()), jsonEncode(s.versJson()));
      expect(relu.notes.single.horodatage, '23:10');
      expect(relu.personnages.last.choixFinal, ChoixFinal.besoin);
    });

    test('le store garde l\'historique et la session en cours', () async {
      SharedPreferences.setMockInitialValues({});
      final store = TroupeStore();
      await store.charger();
      final s = await store.nouvelle();
      expect(store.enCours?.id, s.id);
      s.etape = EtapeSession.terminee;
      await store.enregistrer(s);
      expect(store.enCours, isNull);
      final relu = TroupeStore();
      await relu.charger();
      expect(relu.sessions.single.etape, EtapeSession.terminee);
    });

    test('une sauvegarde illisible n\'est jamais écrasée', () async {
      SharedPreferences.setMockInitialValues({'troupe_sessions_v1': 'pas du json'});
      final store = TroupeStore();
      await store.charger();
      await store.nouvelle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('troupe_sessions_v1'), 'pas du json');
    });

    test('les réglages Destiny se gardent', () async {
      SharedPreferences.setMockInitialValues({'son_destiny': 'thunder'});
      final r = ReglagesDestiny();
      await r.charger();
      expect(r.sonDestiny, 'thunder'); // repris des réglages 1.x
      expect(r.chronos.map((c) => c.dureeMinutes), [20, 30, 45]);
      await r.changer(declenchement: Declenchement.manuel, musiqueFin: 'aucune');
      await r.changerMusiqueActe(2, 'music/atm_cave.m4a');
      final relu = ReglagesDestiny();
      await relu.charger();
      expect(relu.declenchement, Declenchement.manuel);
      expect(relu.musiqueFin, 'aucune');
      expect(relu.musiquesActes, [ChoixMusique.commencement, 'music/atm_cave.m4a', ChoixMusique.lieu, 'aucune']);
      expect(relu.regieSon, isTrue);
    });

    test('les musiques d\'avant la 2.0.3 deviennent celles des actes 1, 3 et 4', () async {
      SharedPreferences.setMockInitialValues({
        'reglages_destiny_v1': jsonEncode({
          'musique_debut': 'music/a.m4a',
          'ambiance_acte2': 'music/b.m4a',
          'musique_fin': 'music/c.m4a',
        }),
      });
      final r = ReglagesDestiny();
      await r.charger();
      expect(r.musiquesActes, ['music/a.m4a', ChoixMusique.aucune, 'music/b.m4a', 'music/c.m4a']);
      // Une version plus ancienne relit toujours ses clés.
      expect(r.versJson()['musique_fin'], 'music/c.m4a');
      expect(r.versJson()['ambiance_acte2'], 'music/b.m4a');
    });
  });

  test('la fiche PDF d\'un spectacle', () async {
    Future<ByteData> f(String n) async =>
        ByteData.sublistView(Uint8List.fromList(await File('assets/fonts/$n').readAsBytes()));
    final octets = await fichePdfSession(
      s: _sessionComplete(),
      g: g,
      t: t,
      polices: PolicesPdf(
        titre: await f('Cinzel-Bold.ttf'),
        texte: await f('Montserrat-Regular.ttf'),
        texteGras: await f('Montserrat-Bold.ttf'),
        italique: await f('Montserrat-Italic.ttf'),
      ),
    );
    expect(String.fromCharCodes(octets.take(4)), '%PDF');
    expect(octets.length, greaterThan(2000));
  });

  testWidgets('l\'accueil reprend la partie en cours, spectacle ou répétition, quelle que soit l\'étape', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TroupeStore();
    await tester.runAsync(store.charger);
    for (final type in TypeSession.values) {
      final s = (await tester.runAsync(store.nouvelle))!
        ..type = type
        ..etape = EtapeSession.regie;
      await tester.runAsync(() => store.enregistrer(s));
      final ctx = ContexteTroupe(
        store: store,
        reglages: ReglagesDestiny(),
        catalogue: catalogue,
        audio: AudioService()..setMuted(true),
        musique: MusicController(),
        visuels: VisualSettings(),
      );
      await tester.pumpWidget(MaterialApp(
        key: UniqueKey(),
        theme: themeDestiny(g, sombre: true),
        builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
        home: Scaffold(
          body: TroupeScreen(contexte: ctx, versJouer: () {}, versExercices: () {}, versBibliotheque: () {}),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(t.t('troupe.reprendre_type.${type.name}')), findsOneWidget, reason: type.name);
      expect(find.text(t.t('troupe.reprendre', {'etape': t.t('troupe.etapes.regie')})), findsNothing);
    }
  });

  testWidgets('un spectacle de bout en bout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = TroupeStore();
    final reglages = ReglagesDestiny();
    final audio = AudioService()..setMuted(true);
    final ctx = ContexteTroupe(
      store: store,
      reglages: reglages,
      catalogue: catalogue,
      audio: audio,
      musique: MusicController(),
      visuels: VisualSettings(),
    );
    await tester.pumpWidget(MaterialApp(
      theme: themeDestiny(g, sombre: true),
      builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
      home: Scaffold(
        body: TroupeScreen(contexte: ctx, versJouer: () {}, versExercices: () {}, versBibliotheque: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    // Préparer : un tirage équilibré à 4, puis chacun choisit son animal.
    await tester.tap(find.text(t.t('troupe.preparer')));
    await tester.pumpAndSettle();
    final s = store.enCours!;
    expect(s.personnages, hasLength(4));
    expect(validerDistribution(g, [for (final p in s.personnages) p.archetypeId]).valide, isTrue);
    expect(find.text(t.t('distribution.ok')), findsOneWidget);
    for (final p in s.personnages) {
      await tester.tap(find.text(g.animauxDe(p.archetypeId).first.nom).first);
      await tester.pump();
    }
    await tester.tap(find.text(t.t('preparer.vers_echauffement')));
    await tester.pumpAndSettle();

    // Le jeu (chaque archétype en petit rectangle, les paliers du danger).
    // Plus de mise en place dans le fil.
    expect(find.text(t.t('echauffement.titre')), findsWidgets);
    expect(find.byType(RectangleArchetype), findsNWidgets(4));
    expect(find.byType(FrisePaliers), findsOneWidget);
    expect(find.text(t.t('troupe.fil.miseEnPlace')), findsNothing);
    expect(s.paliers, hasLength(4));

    // « Régie » : la régie s'ouvre en pop-up par-dessus le jeu. Le chrono, la
    // frise des trois Destiny, la régie son ; DESTINY fait monter d'un palier.
    await tester.tap(find.text(t.t('troupe.fil.regie')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RegieScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('fermer_popup')), findsOneWidget);
    expect(find.text(g.palier(PalierId.signale).nom), findsWidgets);
    for (final n in [1, 2, 3]) {
      expect(find.byKey(ValueKey('repere_destiny_$n')), findsWidgets);
    }
    expect(find.byKey(const ValueKey('bouton_regie_son')), findsOneWidget);
    expect(find.text(t.t('regie.son_acte', {'n': '1'})), findsNothing, reason: 'la régie son est rangée dans sa fenêtre');
    await tester.tap(find.byKey(const ValueKey('bouton_destiny')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(s.paliers[1]), findsWidgets); // la nouvelle de l'alarmiste
    await tester.tap(find.text(t.t('rituel.reprendre')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(s.palierAtteint, 2);
    expect(s.destinys.single.manuel, isTrue);
    // Plus de groupe, de mystère, de moments forts ni de « Pour la régie ».
    expect(find.text(t.t('regie.noter')), findsNothing);
    expect(find.text(t.t('regie.mystere').toUpperCase()), findsNothing);
    expect(find.text(t.t('regie.rappel').toUpperCase()), findsNothing);
    expect(find.text(t.t('mise_en_place.groupe').toUpperCase()), findsNothing);

    // Terminer : plus de débrief, retour à l'accueil.
    final terminer = find.text(t.t('regie.terminer'));
    await tester.ensureVisible(terminer);
    await tester.pumpAndSettle();
    await tester.tap(terminer);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.t('troupe.oui')));
    await tester.pumpAndSettle();
    expect(find.text(t.t('debrief.intro')), findsNothing);
    expect(find.byType(TroupeScreen), findsOneWidget);
    expect(find.byType(RegieScreen), findsNothing);
    expect(find.byType(EchauffementScreen), findsNothing);
    expect(s.etape, EtapeSession.terminee);
  });
}
