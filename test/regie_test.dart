import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/son/conduite_son.dart';
import 'package:destiny/application/son/pack_audio.dart';
import 'package:destiny/application/son/regie_son.dart';
import 'package:destiny/application/son/reglages_regie_son.dart';
import 'package:destiny/domain/son/manifeste_audio.dart';
import 'package:destiny/domain/son/resolution_son.dart';
import 'package:destiny/presentation/regie_son/table_regie.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/troupe_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/troupe/session.dart';
import 'package:destiny/presentation/bibliotheque/archetypes_screen.dart';
import 'package:destiny/presentation/bibliotheque/dangers_lieux_screen.dart';
import 'package:destiny/presentation/destiny/cartes.dart';
import 'package:destiny/presentation/destiny/composants.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:destiny/presentation/troupe/composants_troupe.dart';
import 'package:destiny/presentation/troupe/debrief_screen.dart';
import 'package:destiny/presentation/troupe/echauffement_screen.dart';
import 'package:destiny/presentation/troupe/mise_en_place_screen.dart';
import 'package:destiny/presentation/troupe/regie_screen.dart';
import 'package:destiny/presentation/troupe/troupe_screen.dart';
import 'package:destiny/presentation/widgets/sound_mixer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'regie_son_test.dart' show LecteurFactice, fichiersDuManifeste;
import 'troupe_test.dart' show CatalogueDeTest;

late Grammaire g;
late TextesDestiny t;
late CatalogueDeTest catalogue;

/// Une musique qui note ce qu'on lui demande, sans rien jouer.
class MusiqueFactice extends MusicController {
  final List<String> joues = [];
  final List<String> destiny = [];
  int arrets = 0;

  @override
  Future<void> jouerChoix(String choix, {String lieu = ''}) async => joues.add(choix);

  @override
  Future<void> jouerDestiny(String selection) async => destiny.add(selection);

  @override
  Future<void> stop() async => arrets++;
}

/// Des effets sonores qui notent ce qu'on leur demande.
class AudioFactice extends AudioService {
  AudioFactice({this.muet = false});

  bool muet;
  final List<String> effets = [];

  @override
  bool get muted => muet;

  @override
  void setMuted(bool value) => muet = value;

  @override
  Future<void> playEffet(String key) async => effets.add(key);

  @override
  Future<void> playCrack() async => effets.add('crack');

  @override
  Future<void> playThunder() async => effets.add('thunder');

  @override
  Future<void> playShine() async => effets.add('shine');

  @override
  Future<void> stopStorm() async => effets.add('stop');
}

class Banc {
  Banc(this.contexte, this.session);

  final ContexteTroupe contexte;
  final SessionTroupe session;

  MusiqueFactice get musique => contexte.musique as MusiqueFactice;
  AudioFactice get audio => contexte.audio as AudioFactice;
  TroupeStore get store => contexte.store;
}

String _rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);

/// Une session prête pour la régie : quatre personnages (deux avec un
/// animal), un lieu et un danger du catalogue.
Future<Banc> _banc(
  WidgetTester tester, {
  List<int> destiny = const [10, 18, 27],
  int duree = 30,
  Declenchement declenchement = Declenchement.lesDeux,
  bool muet = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = TroupeStore();
  final reglages = ReglagesDestiny();
  await tester.runAsync(() async {
    await store.charger();
    await reglages.changer(declenchement: declenchement);
  });
  final s = (await tester.runAsync(store.nouvelle))!;
  final lieu = catalogue.lieux.firstWhere((l) => l.actif && l.id == 'aquarium');
  final danger = catalogue.dangers.firstWhere((d) => d.actif && d.paliers.length == 4);
  s
    ..type = TypeSession.spectacle
    ..etape = EtapeSession.regie
    ..personnages = [
      PersonnageTroupe(joueur: '', archetypeId: 'alarmiste', animalId: 'rat'),
      PersonnageTroupe(joueur: '', archetypeId: 'leader'),
      PersonnageTroupe(joueur: '', archetypeId: 'cynique', animalId: 'singe'),
      PersonnageTroupe(joueur: '', archetypeId: 'paranoiaque'),
    ]
    ..lieuId = lieu.id
    ..lieuNom = lieu.name
    ..groupe = 'une famille'
    ..dangerId = danger.id
    ..dangerNom = danger.name
    ..paliers = danger.paliersPour(kids: false)
    ..mystere = 'Qui a fermé la vanne ?'
    ..dureeMinutes = duree
    ..destinyMinutes = [...destiny];
  return Banc(
    ContexteTroupe(
      store: store,
      reglages: reglages,
      catalogue: catalogue,
      audio: AudioFactice(muet: muet),
      musique: MusiqueFactice(),
      visuels: VisualSettings(),
    ),
    s,
  );
}

Future<void> _ouvrir(
  WidgetTester tester,
  Widget page, {
  bool sombre = true,
  double echelle = 1,
  Size taille = const Size(390, 3000),
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: themeDestiny(g, sombre: sombre),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)),
      child: DestinyDonnees(grammaire: g, textes: t, child: child!),
    ),
    home: page,
  ));
  await tester.pumpAndSettle();
}

Future<Banc> _regie(WidgetTester tester,
    {List<int> destiny = const [10, 18, 27],
    int duree = 30,
    Declenchement declenchement = Declenchement.lesDeux,
    bool muet = false}) async {
  final b = await _banc(tester, destiny: destiny, duree: duree, declenchement: declenchement, muet: muet);
  await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session));
  return b;
}

/// Ouvre la fenêtre de la régie son.
Future<void> _ouvrirSon(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('bouton_regie_son')));
  await tester.pumpAndSettle();
  expect(find.byType(TabletteSon), findsOneWidget);
}

/// Laisse passer le rituel Destiny, puis « Reprendre ».
Future<void> _finirRituel(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 10));
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(find.text(t.t('rituel.reprendre')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  group('les règles pour déplacer un Destiny', () {
    SessionTroupe s0() => SessionTroupe(id: 'x', date: DateTime(2026), dureeMinutes: 30, destinyMinutes: [10, 18, 27]);

    test('après le chrono, après le précédent, avant le suivant, avant la fin', () {
      final s = s0();
      expect(refusDestiny(s, index: 0, minute: 11, ecouleSecondes: 0), isNull);
      expect(refusDestiny(s, index: 0, minute: 5, ecouleSecondes: 300), RefusDestiny.avantChrono);
      expect(refusDestiny(s, index: 0, minute: 0, ecouleSecondes: 0), RefusDestiny.avantChrono);
      expect(refusDestiny(s, index: 0, minute: 18, ecouleSecondes: 0), RefusDestiny.apresSuivant);
      expect(refusDestiny(s, index: 1, minute: 10, ecouleSecondes: 0), RefusDestiny.avantPrecedent);
      expect(refusDestiny(s, index: 2, minute: 30, ecouleSecondes: 0), RefusDestiny.apresFin);
      expect(refusDestiny(s, index: 2, minute: 29, ecouleSecondes: 0), isNull);
    });

    test('un Destiny lancé ne bouge plus ; le suivant ne dépend plus de lui', () {
      final s = s0()..destinys.add(const EvenementDestiny(numero: 1, secondes: 300, manuel: true));
      expect(refusDestiny(s, index: 0, minute: 12, ecouleSecondes: 400), RefusDestiny.dejaLance);
      // Destiny 1 a été lancé tôt (à 5 min) : Destiny 2 peut passer avant sa
      // minute prévue (10), pourvu qu'il reste après le chrono.
      expect(refusDestiny(s, index: 1, minute: 8, ecouleSecondes: 400), isNull);
      expect(refusDestiny(s, index: 1, minute: 6, ecouleSecondes: 400), RefusDestiny.avantChrono);
    });
  });

  testWidgets('la frise montre les trois Destiny et leur heure ; plus de compte à rebours ni de « ±1 min »', (tester) async {
    await _regie(tester);
    for (final n in [1, 2, 3]) {
      expect(find.byKey(ValueKey('repere_destiny_$n')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('compte_a_rebours')), findsNothing);
    expect(find.text('−1 min'), findsNothing);
    expect(find.text('+1 min'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    expect(find.text('30:00'), findsOneWidget, reason: 'le temps qui reste, en grand');
    expect(find.text(_rg('destiny_n', {'n': '1'}).toUpperCase()), findsOneWidget);
    // L'heure de chaque Destiny, sous son repère.
    for (final (n, heure) in [(1, '10:00'), (2, '18:00'), (3, '27:00')]) {
      expect(tester.widget<Text>(find.byKey(ValueKey('heure_destiny_$n'))).data, heure);
    }
  });

  testWidgets('un Destiny lancé montre l\'heure où il l\'a été, les autres leur heure prévue', (tester) async {
    final b = await _banc(tester);
    b.session.destinys.add(const EvenementDestiny(numero: 1, secondes: 9 * 60 + 41, manuel: true));
    b.session.palierAtteint = 2;
    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session));
    expect(tester.widget<Text>(find.byKey(const ValueKey('heure_destiny_1'))).data, '09:41');
    expect(tester.widget<Text>(find.byKey(const ValueKey('heure_destiny_2'))).data, '18:00');
  });

  testWidgets('à la régie, on fait glisser le prochain Destiny ; un Destiny lancé ne bouge plus', (tester) async {
    final b = await _banc(tester);
    final s = b.session;
    s.destinys.add(const EvenementDestiny(numero: 1, secondes: 9 * 60 + 41, manuel: true));
    s.palierAtteint = 2;
    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session));
    await tester.drag(find.byKey(const ValueKey('repere_destiny_1')), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(s.destinys.single.secondes, 9 * 60 + 41);
    expect(s.destinyMinutes, [10, 18, 27]);
    await tester.drag(find.byKey(const ValueKey('repere_destiny_2')), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(s.destinyMinutes, [10, 26, 27]);
    expect(tester.widget<Text>(find.byKey(const ValueKey('heure_destiny_2'))).data, '26:00');
    // Jamais avant le chrono (il en est à 09:41).
    await tester.drag(find.byKey(const ValueKey('repere_destiny_2')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(s.destinyMinutes[1], 10);
  });

  testWidgets('déclenchement à la main : le prochain Destiny en retard a son heure en rouge', (tester) async {
    await _regie(tester, destiny: [1, 18, 27], declenchement: Declenchement.manuel);
    Color couleur() => tester.widget<Text>(find.byKey(const ValueKey('heure_destiny_1'))).style!.color!;
    final rouge = Theme.of(tester.element(find.byType(RegieScreen))).colorScheme.error;
    expect(couleur(), isNot(rouge));
    await tester.tap(find.byTooltip(_rg('demarrer')));
    for (var i = 0; i < 61; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(couleur(), rouge);
    await tester.tap(find.byTooltip(_rg('pause')));
    await tester.pump();
  });

  test('les heures des Destiny ne se chevauchent jamais, et restent dans la frise', () {
    for (final centres in [
      [10.0, 12.0, 14.0],
      [0.0, 150.0, 300.0],
      [290.0, 295.0, 300.0],
      [100.0, 101.0, 280.0],
    ]) {
      final g = FriseDestiny.placerHeures(centres, 300);
      for (var i = 0; i < g.length; i++) {
        expect(g[i], greaterThanOrEqualTo(0), reason: '$centres');
        expect(g[i] + 46, lessThanOrEqualTo(300.001), reason: '$centres');
        if (i > 0) expect(g[i] - g[i - 1], greaterThanOrEqualTo(46), reason: '$centres');
      }
    }
  });

  testWidgets('DESTINY lance le prochain tout de suite, même en déclenchement automatique', (tester) async {
    final b = await _regie(tester, declenchement: Declenchement.automatique);
    final bouton = find.byKey(const ValueKey('bouton_destiny'));
    expect(tester.widget<ButtonStyleButton>(bouton).onPressed, isNotNull);
    await tester.tap(bouton);
    await _finirRituel(tester);
    expect(b.session.palierAtteint, 2);
    expect(b.session.destinys.single.manuel, isTrue);
    expect(find.text(_rg('destiny_n', {'n': '2'}).toUpperCase()), findsOneWidget);
    expect(b.audio.effets, contains(b.contexte.reglages.sonDestiny));
  });

  testWidgets('le chrono lance tout seul le Destiny prévu, et la musique du début', (tester) async {
    final b = await _regie(tester, destiny: [1, 3, 4], duree: 5, declenchement: Declenchement.automatique);
    await tester.tap(find.byTooltip(_rg('demarrer')));
    await tester.pump();
    expect(b.musique.joues, [b.contexte.reglages.musiqueDebut]);
    for (var i = 0; i < 59; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(b.session.destinys, isEmpty);
    expect(find.text('04:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(b.session.destinys.single.manuel, isFalse);
    expect(b.session.palierAtteint, 2);
    await _finirRituel(tester);
    // On le met en pause avant de quitter.
    await tester.tap(find.byTooltip(_rg('pause')));
    await tester.pump();
  });

  testWidgets('la régie son : un bouton qui l\'ouvre dans une fenêtre, qu\'on ferme', (tester) async {
    await _regie(tester);
    expect(find.byType(TabletteSon), findsNothing, reason: 'elle ne prend plus de place à l\'écran');
    expect(find.text(_rg('son_acte', {'n': '1'})), findsNothing);
    await _ouvrirSon(tester);
    expect(find.text(_rg('son_acte', {'n': '1'})), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fermer_regie_son')));
    await tester.pumpAndSettle();
    expect(find.byType(TabletteSon), findsNothing);
    expect(find.byKey(const ValueKey('bouton_destiny')), findsOneWidget);
  });

  testWidgets('la régie son : chaque tuile fait jouer la régie', (tester) async {
    final b = await _regie(tester);
    final r = b.contexte.reglages;
    await _ouvrirSon(tester);
    Future<void> tuile(String cle, [Map<String, String> v = const {}]) async {
      await tester.tap(find.text(_rg(cle, v)));
      await tester.pump();
    }

    for (var acte = 1; acte <= 4; acte++) {
      await tuile('son_acte', {'n': '$acte'});
    }
    await tuile('son_lieu');
    // L'acte 2 n'a pas de musique par défaut : sa tuile joue l'ambiance du lieu.
    expect(b.musique.joues, [r.musiqueActe(1), ChoixMusique.lieu, r.musiqueActe(3), r.musiqueActe(4), ChoixMusique.lieu]);
    await tuile('son_destiny');
    expect(b.audio.effets, [r.sonDestiny]);
    await tuile('son_stop');
    expect(b.musique.arrets, 1);
    await tester.tap(find.text(_rg('son_mixeur')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SoundMixerSheet), findsOneWidget);
  });

  testWidgets('la régie son respecte le son coupé', (tester) async {
    final b = await _regie(tester, muet: true);
    await _ouvrirSon(tester);
    expect(find.text(_rg('son_coupe')), findsOneWidget);
    await tester.tap(find.text(_rg('son_acte', {'n': '1'})), warnIfMissed: false);
    await tester.tap(find.text(_rg('son_destiny')), warnIfMissed: false);
    await tester.pump();
    expect(b.musique.joues, isEmpty);
    expect(b.audio.effets, isEmpty);
    await tester.tap(find.text(_rg('son_remettre')));
    await tester.pump();
    expect(b.audio.muted, isFalse);
    await tester.tap(find.text(_rg('son_acte', {'n': '1'})));
    await tester.pump();
    expect(b.musique.joues, [b.contexte.reglages.musiqueActe(1)]);
  });

  testWidgets('la musique de chaque acte part toute seule, 15 s après chaque Destiny', (tester) async {
    final b = await _banc(tester);
    final r = b.contexte.reglages;
    await tester.runAsync(() async {
      await r.changerMusiqueActe(2, 'music/atm_forest.m4a');
      await r.changerMusiqueActe(3, ChoixMusique.aucune);
    });
    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session));
    await tester.tap(find.byTooltip(_rg('demarrer')));
    await tester.pump();
    expect(b.musique.joues, [r.musiqueActe(1)]);
    // Destiny 1 : l'acte 2 et sa musique.
    await tester.tap(find.byKey(const ValueKey('bouton_destiny')));
    await _finirRituel(tester);
    await tester.pump(const Duration(seconds: 15));
    expect(b.musique.joues, [r.musiqueActe(1), 'music/atm_forest.m4a']);
    // Destiny 2 : l'acte 3 n'a pas de musique, celle de l'acte 2 continue.
    await tester.tap(find.byKey(const ValueKey('bouton_destiny')));
    await _finirRituel(tester);
    await tester.pump(const Duration(seconds: 15));
    expect(b.musique.joues, [r.musiqueActe(1), 'music/atm_forest.m4a']);
    // Destiny 3 : la musique de l'acte 4.
    await tester.tap(find.byKey(const ValueKey('bouton_destiny')));
    await _finirRituel(tester);
    await tester.pump(const Duration(seconds: 15));
    expect(b.musique.joues.last, r.musiqueActe(4));
    await tester.tap(find.byTooltip(_rg('pause')));
    await tester.pump();
  });

  testWidgets('la régie son se retire dans les réglages : plus de bouton « Son »', (tester) async {
    final b = await _banc(tester);
    await tester.runAsync(() => b.contexte.reglages.changer(regieSon: false));
    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session));
    expect(find.byKey(const ValueKey('bouton_regie_son')), findsNothing);
    expect(find.byKey(const ValueKey('bouton_destiny')), findsOneWidget);
  });

  testWidgets('à la régie : la montée de chacun en petit rectangle, avec ses bulles d\'info', (tester) async {
    final b = await _regie(tester);
    expect(find.byType(RectangleArchetype), findsNWidgets(4));
    expect(find.byType(CarteArchetype), findsNothing);
    // On ne montre que l'archétype, et l'animal seulement s'il a été choisi.
    expect(find.byType(MedaillonAnimal), findsNWidgets(2));
    final alarmiste = g.archetype('alarmiste')!;
    expect(find.text(alarmiste.monteeA(PalierId.signale)), findsOneWidget);
    await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': alarmiste.nom})));
    await tester.pumpAndSettle();
    expect(find.byType(FicheArchetype), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fermer_fenetre')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': g.animal('rat')!.nom})));
    await tester.pumpAndSettle();
    expect(find.byType(FicheAnimal), findsOneWidget);
    expect(b.session.personnages, hasLength(4));
  });

  testWidgets('une bulle « i » ouvre la fiche dans une fenêtre : l\'écran reste dessous, le chrono aussi', (tester) async {
    final b = await _regie(tester);
    await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': b.session.lieuNom})).first);
    await tester.pumpAndSettle();
    expect(find.byType(FicheLieu), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(RegieScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing, reason: 'une croix, pas une flèche');
    await tester.tap(find.byKey(const ValueKey('fermer_fenetre')));
    await tester.pumpAndSettle();
    expect(find.byType(FicheLieu), findsNothing);
    expect(find.byKey(const ValueKey('bouton_destiny')), findsOneWidget);
  });

  testWidgets('le lieu et le danger ont leur bulle d\'info (régie, mise en place, débrief)', (tester) async {
    final b = await _banc(tester);
    final s = b.session;
    Future<void> bulles() async {
      await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': s.lieuNom})).first);
      await tester.pumpAndSettle();
      expect(find.byType(FicheLieu), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fermer_fenetre')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': s.dangerNom})).first);
      await tester.pumpAndSettle();
      expect(find.byType(FicheDanger), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fermer_fenetre')));
      await tester.pumpAndSettle();
    }

    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: s));
    await bulles();
    await _ouvrir(tester, MiseEnPlaceScreen(contexte: b.contexte, session: s));
    await bulles();
    await _ouvrir(tester, DebriefScreen(contexte: b.contexte, session: s));
    await bulles();
  });

  testWidgets('l\'échauffement : des petits rectangles, plus de grandes cartes', (tester) async {
    final b = await _banc(tester);
    // Au jeu (une session à la régie ouvrirait la régie par-dessus).
    b.session.etape = EtapeSession.echauffement;
    await _ouvrir(tester, EchauffementScreen(contexte: b.contexte, session: b.session));
    expect(find.byType(CarteArchetype), findsNothing);
    expect(find.byType(RectangleArchetype), findsNWidgets(4));
    final leader = g.archetype('leader')!;
    expect(find.text(leader.ceQuIlFait), findsOneWidget);
    await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': leader.nom})));
    await tester.pumpAndSettle();
    expect(find.byType(FicheArchetype), findsOneWidget);
  });

  for (final sombre in [true, false]) {
    final theme = sombre ? 'sombre' : 'clair';
    testWidgets('chaque écran Troupe tient sur un téléphone, texte agrandi ($theme)', (tester) async {
      final b = await _banc(tester);
      // Pour la mise en place : les trois Destiny de la session reprennent
      // ceux du chrono choisi.
      final pages = <String, Widget Function()>{
        'échauffement': () => EchauffementScreen(contexte: b.contexte, session: b.session),
        'mise en place': () => MiseEnPlaceScreen(contexte: b.contexte, session: b.session),
        'régie': () => RegieScreen(contexte: b.contexte, session: b.session),
        'débrief': () => DebriefScreen(contexte: b.contexte, session: b.session),
      };
      for (final MapEntry(key: nom, value: page) in pages.entries) {
        for (final taille in const [Size(390, 844), Size(390, 6000)]) {
          await _ouvrir(tester, page(), sombre: sombre, echelle: 1.6, taille: taille);
          expect(tester.takeException(), isNull, reason: '$nom, ${taille.height}');
        }
      }
    });
  }

  testWidgets('la régie tient aussi à l\'horizontale (le chrono défile alors avec le reste)', (tester) async {
    final b = await _banc(tester);
    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session), taille: const Size(844, 390));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('bouton_destiny')), findsOneWidget);
  });

  testWidgets('le chrono reste visible en haut quand on fait défiler la régie', (tester) async {
    final b = await _banc(tester);
    await _ouvrir(tester, RegieScreen(contexte: b.contexte, session: b.session),
        echelle: 1.6, taille: const Size(390, 844));
    final avant = tester.getTopLeft(find.byKey(const ValueKey('chrono_reste')));
    await tester.dragUntilVisible(find.text(_rg('terminer')), find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('chrono_reste'))), avant);
    expect(find.byKey(const ValueKey('bouton_destiny')).hitTestable(), findsOneWidget);
    expect(find.text(_rg('terminer')), findsOneWidget);
  });

  group('dès l\'échauffement', () {
    Future<Banc> echauffement(WidgetTester tester) async {
      final b = await _banc(tester);
      b.session
        ..etape = EtapeSession.echauffement
        ..groupe = '';
      await _ouvrir(tester, EchauffementScreen(contexte: b.contexte, session: b.session));
      return b;
    }

    testWidgets('le jeu : le spectacle, le lieu, le danger et ses paliers, les Destiny prévus ; ni questions, ni régie son',
        (tester) async {
      final b = await echauffement(tester);
      final s = b.session;
      expect(find.text(t.t('echauffement.titre')), findsWidgets);
      expect(find.byType(FilEtapes), findsOneWidget);
      // Plus de mise en place dans le fil, ni de flèche de retour.
      expect(find.text(t.t('troupe.fil.miseEnPlace')), findsNothing);
      expect(find.text(t.t('troupe.fil.echauffement')), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      // Le spectacle sous la main : le chrono, DESTINY et la régie.
      expect(find.byKey(const ValueKey('pilote_reste')), findsOneWidget);
      expect(find.byKey(const ValueKey('pilote_destiny')), findsOneWidget);
      expect(find.byKey(const ValueKey('ouvrir_regie')), findsOneWidget);
      // La section du danger : ses quatre paliers.
      expect(find.byType(FrisePaliers), findsOneWidget);
      for (final p in s.paliers) {
        expect(find.text(p), findsWidgets, reason: p);
      }
      expect(find.byType(LieuEtDanger), findsOneWidget);
      expect(find.text(s.lieuNom), findsWidgets);
      expect(find.text(s.dangerNom), findsWidgets);
      expect(find.byType(FriseDestiny), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('heure_destiny_2'))).data, '18:00');
      expect(find.text(t.t('echauffement.plan', {'duree': '30', 'liste': '10 · 18 · 27'})), findsOneWidget);
      // Retirés : la régie son, les trois questions, et les boutons du bas
      // (le fil des étapes suffit).
      expect(find.byType(BoutonRegieSon), findsNothing);
      expect(find.byType(TabletteSon), findsNothing);
      for (final q in g.personnage.echauffement.questions) {
        expect(find.text(q), findsNothing, reason: q);
      }
      expect(find.text(g.personnage.echauffement.limite), findsNothing);
      expect(find.byType(OutlinedButton), findsNWidgets(2), reason: 'le minuteur et « Terminer »');
      expect(find.text(_rg('terminer')), findsOneWidget);
    });

    testWidgets('on change un archétype à la main ; son animal repart à zéro', (tester) async {
      final b = await echauffement(tester);
      final s = b.session;
      final cynique = s.personnages.firstWhere((p) => p.archetypeId == 'cynique');
      expect(cynique.animalId, 'singe');
      final libre = g.archetypes.firstWhere((a) => s.personnages.every((p) => p.archetypeId != a.id));
      await tester.tap(find.byKey(const ValueKey('changer_cynique')));
      await tester.pumpAndSettle();
      final choix = find.descendant(of: find.byType(BottomSheet), matching: find.text(libre.nom));
      await tester.ensureVisible(choix);
      await tester.pumpAndSettle();
      await tester.tap(choix);
      await tester.pumpAndSettle();
      expect(cynique.archetypeId, libre.id);
      expect(cynique.animalId, isEmpty);
      expect(find.text(libre.nom), findsOneWidget);
    });

    testWidgets('si la distribution n\'est plus équilibrée, on le dit sans bloquer', (tester) async {
      final b = await echauffement(tester);
      final s = b.session;
      // Celui qui est seul de sa famille est remplacé par un archétype d'une
      // autre famille : sa famille manque.
      final seul = s.personnages.firstWhere((p) =>
          p.archetypeId != 'alarmiste' &&
          s.personnages.where((q) => q.archetypeId != 'alarmiste' && g.archetype(q.archetypeId)!.famille == g.archetype(p.archetypeId)!.famille).length == 1);
      final famille = g.archetype(seul.archetypeId)!.famille;
      final libre = g.archetypes.firstWhere((a) =>
          a.id != 'alarmiste' && a.famille != famille && s.personnages.every((p) => p.archetypeId != a.id));
      await tester.tap(find.byKey(ValueKey('changer_${seul.archetypeId}')));
      await tester.pumpAndSettle();
      final choix = find.descendant(of: find.byType(BottomSheet), matching: find.text(libre.nom));
      await tester.ensureVisible(choix);
      await tester.pumpAndSettle();
      await tester.tap(choix);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.personnages.any((p) => p.archetypeId == libre.id), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('sans alarmiste, le spectacle reste équilibré : le danger vient de la régie', (tester) async {
      final b = await echauffement(tester);
      final s = b.session;
      final libre = g.archetypes.firstWhere((a) =>
          a.id != 'alarmiste' && a.famille == FamilleId.interprete && s.personnages.every((p) => p.archetypeId != a.id));
      await tester.tap(find.byKey(const ValueKey('changer_alarmiste')));
      await tester.pumpAndSettle();
      final choix = find.descendant(of: find.byType(BottomSheet), matching: find.text(libre.nom));
      await tester.ensureVisible(choix);
      await tester.pumpAndSettle();
      await tester.tap(choix);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.personnages.any((p) => p.archetypeId == 'alarmiste'), isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('chaque archétype montre ses quatre réactions au danger, une par palier', (tester) async {
      final b = await echauffement(tester);
      expect(find.byType(ReactionsArchetype), findsNWidgets(4));
      for (final p in b.session.personnages) {
        final a = g.archetype(p.archetypeId)!;
        for (final pa in g.paliers) {
          expect(a.monteeA(pa.id), isNotEmpty, reason: '${a.id} ${pa.id}');
          expect(find.text(a.monteeA(pa.id)), findsWidgets, reason: '${a.id} ${pa.id}');
        }
      }
    });

    testWidgets('on fait glisser un Destiny sur la frise, sans dépasser le suivant', (tester) async {
      final b = await echauffement(tester);
      final s = b.session;
      await tester.drag(find.byKey(const ValueKey('repere_destiny_2')), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(s.destinyMinutes[1], inExclusiveRange(18, 27));
      expect(tester.widget<Text>(find.byKey(const ValueKey('heure_destiny_2'))).data, horloge(s.destinyMinutes[1] * 60));
      expect(tester.widget<Text>(find.byKey(const ValueKey('plan_destiny'))).data, contains('${s.destinyMinutes[1]}'));
      // Trop loin : il s'arrête juste avant le troisième.
      await tester.drag(find.byKey(const ValueKey('repere_destiny_2')), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(s.destinyMinutes, [10, 26, 27]);
      // Et vers la gauche, juste après le premier.
      await tester.drag(find.byKey(const ValueKey('repere_destiny_2')), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(s.destinyMinutes, [10, 11, 27]);
      // C'est enregistré.
      final relu = TroupeStore();
      await tester.runAsync(relu.charger);
      expect(relu.sessions.firstWhere((x) => x.id == s.id).destinyMinutes, [10, 11, 27]);
    });

    testWidgets('« Régie » ouvre directement la table de régie ; sa croix ramène au jeu, et le chrono continue',
        (tester) async {
      final b = await echauffement(tester);
      await tester.tap(find.text(t.t('troupe.fil.regie')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TabletteSon), findsOneWidget);
      expect(find.byType(RegieScreen), findsNothing);
      expect(find.byType(EchauffementScreen), findsOneWidget, reason: 'le jeu reste dessous');
      expect(b.session.etape, EtapeSession.regie);
      expect(b.session.groupe, isEmpty, reason: 'plus de groupe tiré d\'office');
      // Le chrono part depuis la table…
      final table = find.byType(TabletteSon);
      final pilote = find.ancestor(of: table, matching: find.byType(Material)).first;
      await tester.tap(find.descendant(of: pilote, matching: find.byKey(const ValueKey('pilote_basculer'))));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('29:57'), findsWidgets);
      // …et continue une fois la table fermée.
      await tester.tap(find.byKey(const ValueKey('fermer_regie_son')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TabletteSon), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<Text>(find.byKey(const ValueKey('pilote_reste'))).data, '29:55');
      await tester.tap(find.byKey(const ValueKey('pilote_basculer')));
      await tester.pump();
    });

    testWidgets('« Terminer », en bas du jeu : plus de débrief, retour à l\'accueil', (tester) async {
      final b = await echauffement(tester);
      final terminer = find.byKey(const ValueKey('terminer_spectacle'));
      await tester.ensureVisible(terminer);
      await tester.pumpAndSettle();
      expect(find.descendant(of: terminer, matching: find.text('Terminer')), findsOneWidget);
      await tester.tap(terminer);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.t('troupe.oui')));
      await tester.pumpAndSettle();
      expect(b.session.etape, EtapeSession.terminee);
      expect(find.byType(DebriefScreen), findsNothing);
    });
  });

  testWidgets('en quittant la préparation, le spectacle prend le chrono des réglages', (tester) async {
    final b = await _banc(tester);
    await tester.runAsync(() => b.contexte.reglages.choisirChrono(0));
    b.session.etape = EtapeSession.preparation;
    await _ouvrir(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => allerAEtape(context, b.contexte, b.session, EtapeSession.regie),
          child: const Text('aller'),
        ),
      ),
    );
    await tester.tap(find.text('aller'));
    await tester.pumpAndSettle();
    final chrono = b.contexte.reglages.chronos[0];
    expect(b.session.dureeMinutes, chrono.dureeMinutes);
    expect(b.session.destinyMinutes, chrono.destinyMinutes);
    // La régie, c'est le jeu avec la table de régie ouverte par-dessus.
    expect(find.byType(EchauffementScreen), findsOneWidget);
    expect(find.byType(TabletteSon), findsOneWidget);
  });

  testWidgets('à la mise en place, le chrono choisi va tout de suite dans la session', (tester) async {
    final b = await _banc(tester);
    b.session.etape = EtapeSession.miseEnPlace;
    await _ouvrir(tester, MiseEnPlaceScreen(contexte: b.contexte, session: b.session));
    final chronos = b.contexte.reglages.chronos;
    final dernier = chronos.last;
    final puce = find.widgetWithText(ChoiceChip, t.t('mise_en_place.minutes', {'n': '${dernier.dureeMinutes}'}));
    await tester.ensureVisible(puce);
    await tester.pumpAndSettle();
    await tester.tap(puce);
    await tester.pump();
    expect(b.session.dureeMinutes, dernier.dureeMinutes);
    expect(b.session.destinyMinutes, dernier.destinyMinutes);
  });

  testWidgets('plus d\'objets à l\'écran, même pour une ancienne session qui en avait', (tester) async {
    final b = await _banc(tester);
    final anciens = ['une clé rouillée', 'une lampe de poche', 'une photo déchirée'];
    b.session.objets = [...anciens];
    for (final page in [
      () => MiseEnPlaceScreen(contexte: b.contexte, session: b.session),
      () => RegieScreen(contexte: b.contexte, session: b.session),
    ]) {
      await _ouvrir(tester, page());
      for (final o in anciens) {
        expect(find.textContaining(o), findsNothing, reason: o);
      }
      expect(find.textContaining('Objet 1'), findsNothing);
      expect(find.textContaining('trois objets'), findsNothing);
      // Le mystère n'est plus au spectacle (2.2.0).
      expect(find.textContaining(RegExp('mystère', caseSensitive: false)), findsNothing);
    }
    // Les anciennes données restent dans la sauvegarde.
    expect(SessionTroupe.depuisJson(b.session.versJson()).objets, anciens);
  });

  testWidgets('le théâtre se joue en adulte : une ancienne session kids y repasse', (tester) async {
    final b = await _banc(tester);
    b.session.kids = true;
    await _ouvrir(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => ouvrirEtape(context, b.contexte, b.session),
          child: const Text('ouvrir'),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(EchauffementScreen), findsOneWidget);
    expect(b.session.kids, isFalse);
  });

  test('chaque texte des écrans Troupe existe', () {
    expect(textesManquants(['lib/presentation/troupe']), isEmpty);
  });

  test('chaque texte de la régie son existe', () {
    expect(textesManquants(['lib/presentation/regie_son']), isEmpty);
  });

  testWidgets('avec le pack : le minuteur du jeu lance la musique de l\'acte 1, une seule fois', (tester) async {
    final b = await _banc(tester);
    b.session.etape = EtapeSession.echauffement;
    final m = ManifesteAudio.depuisJson(
        jsonDecode(File('assets/data/destiny_audio.json').readAsStringSync()) as Map<String, dynamic>);
    final journal = <String>[];
    final pack = PackAudio.pourTests(m, IndexPack(fichiersDuManifeste(m)));
    final reglages = ReglagesRegieSon(ValeursRegieSon()..sansCourbes());
    final regieSon = RegieSon(
      pack: pack,
      reglages: reglages,
      conduite: ConduiteSon(
        pack: pack,
        reglages: reglages,
        muet: () => b.audio.muted,
        fabrique: (bus) => LecteurFactice(bus, journal),
        attendre: (d) => d >= const Duration(seconds: 60) ? Completer<void>().future : Future<void>.value(),
      ),
    );
    final c = b.contexte;
    final contexte = ContexteTroupe(
      store: c.store,
      reglages: c.reglages,
      catalogue: c.catalogue,
      audio: c.audio,
      musique: c.musique,
      visuels: c.visuels,
      regieSon: regieSon,
    );
    await _ouvrir(tester, EchauffementScreen(contexte: contexte, session: b.session));
    final acte1 = regieSon.conduite.musiqueDe(1).chemin!;
    // « Lancer le minuteur » : l'histoire commence, la musique de l'acte 1 part.
    await tester.tap(find.text(t.t('echauffement.demarrer')));
    await tester.pump();
    expect(journal, ['musique:jouer:$acte1']);
    // Le chrono du spectacle ne la relance pas.
    await tester.tap(find.byKey(const ValueKey('pilote_basculer')));
    await tester.pump(const Duration(seconds: 2));
    expect(journal.where((e) => e.startsWith('musique:jouer')), hasLength(1));
    // La pause du minuteur ne coupe pas la musique de l'histoire.
    await tester.tap(find.text(t.t('echauffement.pause')));
    await tester.pump();
    expect(journal, isNot(contains('musique:arreter')));
    await tester.tap(find.byKey(const ValueKey('pilote_basculer')));
    await tester.pump();
  });

  testWidgets('avec le pack : la conduite part au chrono, la table montre la conduite et les banques', (tester) async {
    final b = await _banc(tester);
    final m = ManifesteAudio.depuisJson(
        jsonDecode(File('assets/data/destiny_audio.json').readAsStringSync()) as Map<String, dynamic>);
    final journal = <String>[];
    final pack = PackAudio.pourTests(m, IndexPack(fichiersDuManifeste(m)));
    // Sans courbe de volume : les attentes du test sont immédiates.
    final reglages = ReglagesRegieSon(ValeursRegieSon()..sansCourbes());
    final regieSon = RegieSon(
      pack: pack,
      reglages: reglages,
      conduite: ConduiteSon(
        pack: pack,
        reglages: reglages,
        muet: () => b.audio.muted,
        fabrique: (bus) => LecteurFactice(bus, journal),
        attendre: (d) => d >= const Duration(seconds: 60) ? Completer<void>().future : Future<void>.value(),
      ),
    );
    final c = b.contexte;
    final contexte = ContexteTroupe(
      store: c.store,
      reglages: c.reglages,
      catalogue: c.catalogue,
      audio: c.audio,
      musique: c.musique,
      visuels: c.visuels,
      regieSon: regieSon,
    );
    await _ouvrir(tester, RegieScreen(contexte: contexte, session: b.session));
    expect(regieSon.conduite.active, isTrue);
    expect(find.byKey(const ValueKey('bouton_danger')), findsOneWidget);

    // Le chrono part : le son Destiny de l'ouverture, pas l'ancienne musique.
    await tester.tap(find.byTooltip(_rg('demarrer')));
    await tester.pump();
    expect(journal, [startsWith('musique:jouer:Musiques Destiny/')]);
    expect(b.musique.joues, isEmpty);

    // « Danger » : le bruitage du palier 1.
    await tester.tap(find.byKey(const ValueKey('bouton_danger')));
    await tester.pump();
    final codes = m.dangers[b.session.dangerId]!.codes(1);
    expect(journal, contains(startsWith('bruitageA:jouer:Bruitages/${codes.first}')));

    // La table : la conduite, les tranches, les banques par catégorie.
    await tester.tap(find.byKey(const ValueKey('bouton_regie_son')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TableRegie), findsOneWidget);
    expect(find.text(t.t('regie_son.danger')), findsWidgets);
    expect(find.text(t.t('regie_son.bus.musique').toUpperCase()), findsOneWidget);
    // Deux banques seulement : les sons du danger et les émotions.
    expect(find.byKey(const ValueKey('banque_danger')), findsOneWidget);
    expect(find.byKey(const ValueKey('banque_emotions')), findsOneWidget);
    for (final inutile in ['cat:alertes', 'cat:creatures', 'ambiances', 'lieux', 'univers', 'themes']) {
      expect(find.byKey(ValueKey('banque_$inutile')), findsNothing, reason: inutile);
    }
    journal.clear();
    final pad = find.text(m.sons[codes.first]!.nom).first;
    await tester.ensureVisible(pad);
    await tester.pump();
    await tester.tap(pad);
    await tester.pump();
    expect(journal, contains(startsWith('bruitageA:jouer:Bruitages/${codes.first}')));
    await tester.tap(find.byKey(const ValueKey('fermer_regie_son')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip(_rg('pause')));
    await tester.pump();
  });
}
