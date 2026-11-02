import 'package:destiny/application/services/audio_service.dart';
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
    ..objets = ['une clé', 'une lampe', 'une photo']
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

  testWidgets('la frise montre les trois Destiny et le compte à rebours du prochain', (tester) async {
    await _regie(tester);
    for (final n in [1, 2, 3]) {
      expect(find.byKey(ValueKey('repere_destiny_$n')), findsOneWidget);
    }
    expect(find.text(_rg('dans', {'n': '1', 't': '10:00'})), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget, reason: 'le temps qui reste, en grand');
    expect(find.text(_rg('destiny_n', {'n': '1'}).toUpperCase()), findsOneWidget);
  });

  testWidgets('« +1 min » déplace le prochain Destiny, et le garde', (tester) async {
    final b = await _regie(tester);
    await tester.tap(find.text(_rg('plus_une')));
    await tester.pump();
    expect(b.session.destinyMinutes, [11, 18, 27]);
    expect(find.text(_rg('dans', {'n': '1', 't': '11:00'})), findsOneWidget);
    await tester.tap(find.text(_rg('moins_une')));
    await tester.tap(find.text(_rg('moins_une')));
    await tester.pump();
    expect(b.session.destinyMinutes, [9, 18, 27]);
    final relu = TroupeStore();
    await tester.runAsync(relu.charger);
    expect(relu.sessions.single.destinyMinutes, [9, 18, 27]);
  });

  testWidgets('« +1 min » est refusé quand il dépasserait le Destiny suivant', (tester) async {
    final b = await _regie(tester, destiny: [17, 18, 27]);
    await tester.tap(find.text(_rg('plus_une')));
    await tester.pump();
    expect(b.session.destinyMinutes, [17, 18, 27]);
    expect(find.text(_rg('refus_suivant', {'n': '1', 'm': '2'})), findsOneWidget);
  });

  testWidgets('« −1 min » est refusé quand le chrono a déjà passé la minute', (tester) async {
    final b = await _regie(tester, destiny: [1, 18, 27]);
    await tester.tap(find.text(_rg('moins_une')));
    await tester.pump();
    expect(b.session.destinyMinutes.first, 1);
    expect(find.text(_rg('refus_chrono', {'t': '00:00'})), findsOneWidget);
  });

  testWidgets('« Régler les Destiny » : chaque Destiny restant, avec les mêmes règles', (tester) async {
    final b = await _regie(tester, destiny: [10, 11, 28]);
    await tester.tap(find.byTooltip(_rg('regler')));
    await tester.pumpAndSettle();
    for (final n in [1, 2, 3]) {
      expect(find.byKey(ValueKey('reglage_destiny_$n')), findsOneWidget);
    }
    Finder dansLaFeuille(String aide) => find.descendant(of: find.byType(BottomSheet), matching: find.byTooltip(aide));
    await tester.tap(dansLaFeuille(_rg('plus_tard', {'n': '3'})));
    await tester.pump();
    expect(b.session.destinyMinutes, [10, 11, 29]);
    await tester.tap(dansLaFeuille(_rg('plus_tard', {'n': '3'})));
    await tester.pump();
    expect(b.session.destinyMinutes, [10, 11, 29], reason: 'la fin est à 30 min');
    expect(find.text(_rg('refus_fin', {'n': '3'})), findsOneWidget);
    await tester.tap(dansLaFeuille(_rg('plus_tot', {'n': '2'})));
    await tester.pump();
    expect(b.session.destinyMinutes, [10, 11, 29]);
    expect(find.text(_rg('refus_precedent', {'n': '2', 'm': '1'})), findsOneWidget);
    await tester.tap(dansLaFeuille(_rg('plus_tot', {'n': '1'})));
    await tester.pump();
    expect(b.session.destinyMinutes, [9, 11, 29]);
    expect(find.text(_rg('refus_precedent', {'n': '2', 'm': '1'})), findsNothing);
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
    expect(find.text(_rg('dans', {'n': '2', 't': '18:00'})), findsOneWidget);
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

  testWidgets('la régie son : chaque tuile fait jouer la régie', (tester) async {
    final b = await _regie(tester);
    final r = b.contexte.reglages;
    Future<void> tuile(String cle) async {
      await tester.tap(find.text(_rg(cle)));
      await tester.pump();
    }

    await tuile('son_debut');
    await tuile('son_lieu');
    await tuile('son_acte2');
    await tuile('son_fin');
    expect(b.musique.joues, [r.musiqueDebut, ChoixMusique.lieu, r.ambianceActe2, r.musiqueFin]);
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
    expect(find.text(_rg('son_coupe')), findsOneWidget);
    await tester.tap(find.text(_rg('son_debut')), warnIfMissed: false);
    await tester.tap(find.text(_rg('son_destiny')), warnIfMissed: false);
    await tester.pump();
    expect(b.musique.joues, isEmpty);
    expect(b.audio.effets, isEmpty);
    await tester.tap(find.text(_rg('son_remettre')));
    await tester.pump();
    expect(b.audio.muted, isFalse);
    await tester.tap(find.text(_rg('son_debut')));
    await tester.pump();
    expect(b.musique.joues, [b.contexte.reglages.musiqueDebut]);
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
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': g.animal('rat')!.nom})));
    await tester.pumpAndSettle();
    expect(find.byType(FicheAnimal), findsOneWidget);
    expect(b.session.personnages, hasLength(4));
  });

  testWidgets('le lieu et le danger ont leur bulle d\'info (régie, mise en place, débrief)', (tester) async {
    final b = await _banc(tester);
    final s = b.session;
    Future<void> bulles() async {
      await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': s.lieuNom})).first);
      await tester.pumpAndSettle();
      expect(find.byType(FicheLieu), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.t('troupe.info_de', {'nom': s.dangerNom})).first);
      await tester.pumpAndSettle();
      expect(find.byType(FicheDanger), findsOneWidget);
      await tester.pageBack();
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
        'avant scène': () => AvantSceneScreen(contexte: b.contexte, session: b.session),
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

    testWidgets('le lieu, le danger, la régie son et les Destiny prévus sont là', (tester) async {
      final b = await echauffement(tester);
      final s = b.session;
      expect(find.byType(FilEtapes), findsOneWidget);
      expect(find.byType(LieuEtDanger), findsOneWidget);
      expect(find.text(s.lieuNom), findsWidgets);
      expect(find.text(s.dangerNom), findsWidgets);
      expect(find.byType(TabletteSon), findsOneWidget);
      expect(find.byType(FriseDestiny), findsOneWidget);
      expect(find.text(t.t('echauffement.plan', {'duree': '30', 'liste': '10 · 18 · 27'})), findsOneWidget);
      // On s'échauffe en musique.
      await tester.tap(find.text(_rg('son_debut')));
      await tester.pump();
      expect(b.musique.joues, [b.contexte.reglages.musiqueDebut]);
    });

    testWidgets('le fil des étapes mène à la régie en un appui, avec un groupe tiré d\'office', (tester) async {
      final b = await echauffement(tester);
      await tester.tap(find.text(t.t('troupe.fil.regie')));
      await tester.pumpAndSettle();
      expect(find.byType(RegieScreen), findsOneWidget);
      expect(b.session.etape, EtapeSession.regie);
      expect(b.session.groupe, isNotEmpty);
      expect(find.byKey(const ValueKey('bouton_destiny')), findsOneWidget);
      expect(find.byType(TabletteSon), findsOneWidget);
    });

    testWidgets('« Aller directement à la régie » aussi', (tester) async {
      final b = await echauffement(tester);
      await tester.scrollUntilVisible(find.text(t.t('echauffement.vers_regie')), 300);
      await tester.tap(find.text(t.t('echauffement.vers_regie')));
      await tester.pumpAndSettle();
      expect(find.byType(RegieScreen), findsOneWidget);
      expect(b.session.etape, EtapeSession.regie);
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
    expect(find.byType(RegieScreen), findsOneWidget);
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

  test('chaque texte des écrans Troupe existe', () {
    expect(textesManquants(['lib/presentation/troupe']), isEmpty);
  });
}
