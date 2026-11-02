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
      final relu = ReglagesDestiny();
      await relu.charger();
      expect(relu.declenchement, Declenchement.manuel);
      expect(relu.musiqueFin, 'aucune');
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

  testWidgets('un spectacle de bout en bout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 6000);
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

    // L'échauffement, puis l'écran d'avant scène.
    expect(find.text(g.personnage.echauffement.questions.first), findsOneWidget);
    await tester.tap(find.text(t.t('echauffement.vers_avant_scene')));
    await tester.pumpAndSettle();
    expect(find.textContaining(g.personnage.phraseCle), findsOneWidget);
    await tester.tap(find.text(t.t('avant_scene.entrer')));
    await tester.pumpAndSettle();

    // La mise en place : lieu, groupe et danger.
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump();
    await tester.tap(find.text(t.liste('mise_en_place.groupes').first));
    await tester.pump();
    final puceDanger = find.byType(ChoiceChip).at(3);
    await tester.tap(puceDanger);
    await tester.pumpAndSettle();
    expect(s.dangerNom, isNotEmpty);
    expect(s.paliers, hasLength(4));
    await tester.tap(find.text(t.t('mise_en_place.lever_rideau')));
    await tester.pumpAndSettle();

    // La régie : le bouton Destiny fait monter d'un palier.
    expect(find.text(g.palier(PalierId.signale).nom), findsWidgets);
    await tester.tap(find.text(t.t('regie.destiny').toUpperCase()));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(s.paliers[1]), findsWidgets); // la nouvelle de l'alarmiste
    await tester.tap(find.text(t.t('rituel.reprendre')));
    await tester.pumpAndSettle();
    expect(s.palierAtteint, 2);
    expect(s.destinys.single.manuel, isTrue);
    await tester.enterText(find.byType(TextField).last, 'Un silence magnifique');
    await tester.tap(find.text(t.t('regie.noter')));
    await tester.pump();
    expect(s.notes.single.texte, 'Un silence magnifique');

    // Terminer, puis le débrief.
    await tester.tap(find.text(t.t('regie.terminer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.t('troupe.oui')));
    await tester.pumpAndSettle();
    expect(find.text(t.t('debrief.intro')), findsOneWidget);
    await tester.tap(find.text(t.t('debrief.enregistrer')));
    await tester.pumpAndSettle();
    expect(s.etape, EtapeSession.terminee);
    expect(find.text(t.t('historique.exporter')), findsOneWidget);
  });
}
