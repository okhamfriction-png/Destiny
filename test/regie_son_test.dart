import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:destiny/application/son/conduite_son.dart';
import 'package:destiny/application/son/lecteur_son.dart';
import 'package:destiny/application/son/pack_audio.dart';
import 'package:destiny/application/son/reglages_regie_son.dart';
import 'package:destiny/domain/son/categories_son.dart';
import 'package:destiny/domain/son/manifeste_audio.dart';
import 'package:destiny/domain/son/nfc.dart';
import 'package:destiny/domain/son/resolution_son.dart';
import 'package:flutter_test/flutter_test.dart';

late ManifesteAudio m;

/// Les fichiers que décrit le manifeste : le pack tel qu'il est sur le NAS.
List<String> fichiersDuManifeste(ManifesteAudio m) => {
      for (final l in m.lieux.values) ...[for (final x in l.musiques.values) x.fichier],
      for (final s in m.sons.values) ...[for (final f in s.fichiers) f.chemin],
      for (final f in m.reveal) f.chemin,
    }.toList();

/// La forme NFD d'un texte (é → e + accent combinant), comme macOS l'écrit.
String nfd(String s) => s
    .replaceAll('É', 'É')
    .replaceAll('é', 'é')
    .replaceAll('è', 'è')
    .replaceAll('ê', 'ê')
    .replaceAll('ô', 'ô')
    .replaceAll('î', 'î');

/// Un lecteur qui note ce qu'on lui demande ; sa fin se déclenche à la main.
class LecteurFactice extends LecteurSon {
  LecteurFactice(this.bus, this.journal);

  final BusSon bus;
  final List<String> journal;
  SourceSon? _enCours;
  double _volume = 1;
  Completer<void> _fin = Completer<void>()..complete();
  Duration? dureeConnue;

  @override
  SourceSon? get enCours => _enCours;

  @override
  double get volume => _volume;

  @override
  Future<void> get fin => _fin.future;

  /// La dernière piste lancée tourne en boucle.
  bool enBoucle = false;

  @override
  Future<void> jouer(SourceSon source, {double volume = 1, bool boucle = false}) async {
    if (!_fin.isCompleted) _fin.complete();
    _fin = Completer<void>();
    _enCours = source;
    _volume = volume;
    enBoucle = boucle;
    journal.add('${bus.name}:jouer:${source.chemin}');
    notifyListeners();
  }

  /// Chaque volume réglé, dans l'ordre (fondus et atténuation).
  final List<double> volumes = [];

  @override
  Future<void> regler(double volume) async {
    _volume = volume;
    volumes.add(volume);
  }

  @override
  Future<void> arreter() async {
    if (_enCours != null) journal.add('${bus.name}:arreter');
    _enCours = null;
    if (!_fin.isCompleted) _fin.complete();
  }

  /// La piste arrive à sa fin naturelle.
  void finir() {
    _enCours = null;
    if (!_fin.isCompleted) _fin.complete();
  }

  @override
  Future<Duration?> duree() async => dureeConnue;
}

/// Laisse tourner les tâches en attente (les fondus des tests sont immédiats).
Future<void> laisserTourner() async {
  for (var i = 0; i < 400; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Le temps d'un testWidgets, en secondes : l'instant où chaque entrée du
/// journal est apparue.
class Chrono {
  Chrono(this.journal);

  final List<String> journal;
  double t = 0;
  final List<double> instants = [];

  DateTime maintenant() => DateTime(2026).add(Duration(milliseconds: (t * 1000).round()));

  void _noter() {
    while (instants.length < journal.length) {
      instants.add(t);
    }
  }

  /// Avance de [secondes], par pas de 100 ms.
  Future<void> avancer(WidgetTester tester, double secondes) async {
    await tester.pump();
    _noter();
    for (var i = 0; i < (secondes * 10).round(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
      t += 0.1;
      _noter();
    }
  }

  /// L'instant de la première entrée qui commence par [debut] (null : aucune).
  double? quand(String debut) {
    final i = journal.indexWhere((e) => e.startsWith(debut));
    return i < 0 ? null : instants[i];
  }
}

/// Une conduite branchée sur des lecteurs factices. Les attentes sont
/// immédiates, sauf le délai de sécurité : on attend vraiment la fin des sons.
({ConduiteSon conduite, Map<BusSon, LecteurFactice> lecteurs, List<String> journal}) conduiteDeTest({
  List<String>? fichiers,
  ValeursRegieSon? valeurs,
  bool Function()? muet,
  bool vraiTemps = false,
  String Function(int acte)? choixSansPack,
  bool fluide = false,
  DateTime Function()? maintenant,
}) {
  // Par défaut, l'enchaînement classique : ces tests gardent la séquence
  // d'avant le mode fluide, à l'identique.
  final v = (valeurs ?? (ValeursRegieSon()..sansCourbes()))..fluide = fluide;
  final journal = <String>[];
  final lecteurs = <BusSon, LecteurFactice>{};
  final conduite = ConduiteSon(
    pack: PackAudio.pourTests(m, IndexPack(fichiers ?? fichiersDuManifeste(m))),
    // L'atténuation progressive coupe la musique tout de suite quand les
    // attentes sont immédiates : elle a son propre test.
    reglages: ReglagesRegieSon(v),
    muet: muet,
    fabrique: (b) => lecteurs[b] = LecteurFactice(b, journal),
    // vraiTemps : les vrais délais (Future.delayed), menés par l'horloge d'un
    // testWidgets.
    attendre:
        vraiTemps ? null : (d) => d >= const Duration(seconds: 60) ? Completer<void>().future : Future<void>.value(),
    hasard: Random(1),
    choixSansPack: choixSansPack,
    maintenant: maintenant,
  );
  return (conduite: conduite, lecteurs: lecteurs, journal: journal);
}

void main() {
  setUpAll(() {
    m = ManifesteAudio.depuisJson(
        jsonDecode(File('assets/data/destiny_audio.json').readAsStringSync()) as Map<String, dynamic>);
  });

  group('manifeste', () {
    test('se lit en entier, et ses ids sont ceux de l\'appli', () {
      expect(m.lieux, hasLength(40));
      expect(m.dangers, hasLength(38));
      expect(m.sons, hasLength(79));
      final lieux = (jsonDecode(File('assets/data/locations.json').readAsStringSync())['locations'] as List)
          .map((x) => x['id'] as String)
          .toSet();
      final dangers = (jsonDecode(File('assets/data/dangers.json').readAsStringSync())['dangers'] as List)
          .map((x) => x['id'] as String)
          .toSet();
      expect(m.lieux.keys.toSet().difference(lieux), isEmpty);
      expect(m.dangers.keys.toSet().difference(dangers), isEmpty);
      // Chaque code joué par un danger existe dans la banque.
      for (final d in m.dangers.values) {
        for (final p in d.paliers.values) {
          for (final c in p) {
            expect(m.sons, contains(c), reason: '${d.id} : $c');
          }
        }
      }
    });

    test('chaque bruitage a son rayon sur la table de régie', () {
      for (final code in m.sons.keys) {
        expect(CategorieBruitage.de(code), isNot(CategorieBruitage.autres), reason: code);
      }
      expect(CategorieBruitage.de('NOUVEAU_SON'), CategorieBruitage.autres);
      expect(emotionDe('Colère 2'), 'Colère');
    });
  });

  group('NFC', () {
    test('recompose les noms venus de macOS', () {
      expect(nfc('Église'), 'Église');
      expect(nfc('Aéroport'), 'Aéroport');
      expect(nfc('Église'), 'Église');
      expect(nfc(''), '');
    });
  });

  group('résolution d\'une musique', () {
    test('musique propre : le nom attendu', () {
      final r = resoudreMusique(m, IndexPack(fichiersDuManifeste(m)), 'eglise', 2);
      expect(r.origine, OrigineMusique.nomAttendu);
      expect(r.chemin, endsWith('Destiny Acte 2 - 40 - Église.mp3'));
      expect(r.propre, isTrue);
    });

    test('nom en NFD sur le disque : retrouvé, et le chemin réel est rendu', () {
      final chemins = [for (final c in fichiersDuManifeste(m)) nfd(c)];
      final r = resoudreMusique(m, IndexPack(chemins), 'eglise', 1);
      expect(r.origine, OrigineMusique.nomAttendu);
      expect(r.chemin, nfd('Musiques Destiny/Mystère - Église/Destiny Intro 40 - Église.mp3'));
    });

    test('lieu sans musique propre : celle de sa famille', () {
      final r = resoudreMusique(m, IndexPack(fichiersDuManifeste(m)), 'aeroport', 3);
      expect(r.origine, OrigineMusique.famille);
      expect(r.chemin, contains('Avion en vol'));
      // Sans repli sur la famille : silence.
      expect(resoudreMusique(m, IndexPack(fichiersDuManifeste(m)), 'aeroport', 3, repliFamille: false).chemin, isNull);
    });

    test('une musique propre déposée plus tard est prise d\'office, où qu\'elle soit', () {
      final r = resoudreMusique(
        m,
        IndexPack([...fichiersDuManifeste(m), 'Musiques Destiny/Nouveautés/Destiny Acte 3 - 03 - Aéroport.mp3']),
        'aeroport',
        3,
      );
      expect(r.origine, OrigineMusique.nomAttendu);
      expect(r.chemin, 'Musiques Destiny/Nouveautés/Destiny Acte 3 - 03 - Aéroport.mp3');
    });

    test('le nom attendu en .m4a (téléchargé de Suno) vaut le .mp3, le .mp3 passe avant', () {
      const m4a = 'Musiques Destiny/Transports - Aéroport/Destiny Acte 3 - 03 - Aéroport.m4a';
      final r = resoudreMusique(m, IndexPack([...fichiersDuManifeste(m), m4a]), 'aeroport', 3);
      expect(r.origine, OrigineMusique.nomAttendu);
      expect(r.chemin, m4a);
      const mp3 = 'Musiques Destiny/Nouveautés/Destiny Acte 3 - 03 - Aéroport.mp3';
      expect(resoudreMusique(m, IndexPack([...fichiersDuManifeste(m), m4a, mp3]), 'aeroport', 3).chemin, mp3);
    });

    test('fichier absent : silence, sans plantage', () {
      expect(resoudreMusique(m, IndexPack.vide, 'eglise', 1).chemin, isNull);
      expect(resoudreMusique(m, IndexPack(fichiersDuManifeste(m)), 'lieu_inconnu', 1).chemin, isNull);
      expect(resoudreMusique(m, IndexPack(fichiersDuManifeste(m)), 'eglise', 9).chemin, isNull);
    });
  });

  group('résolution d\'un bruitage', () {
    test('le fichier 1 par défaut, le choix des réglages, « Autre » et le hasard', () {
      final idx = IndexPack(fichiersDuManifeste(m));
      final c = candidatsBruitage(m, idx, 'ALARME');
      expect(c.first, contains('/1 - '));
      expect(resoudreCode(m, idx, 'ALARME')!.chemin, c[0]);
      expect(resoudreCode(m, idx, 'ALARME', choix: {'ALARME': 2})!.chemin, c[2]);
      expect(resoudreCode(m, idx, 'ALARME', suivant: {'ALARME': 1})!.chemin, c[1]);
      // « Autre » fait le tour des candidats.
      expect(resoudreCode(m, idx, 'ALARME', suivant: {'ALARME': c.length})!.chemin, c[0]);
      final auHasard = resoudreCode(m, idx, 'ALARME', choix: {'ALARME': kCandidatAleatoire}, hasard: Random(3));
      expect(c, contains(auHasard!.chemin));
    });

    test('les candidats sont triés par leur numéro (2 avant 10)', () {
      final idx = IndexPack(['Bruitages/X - x/10 - b.ogg', 'Bruitages/X - x/2 - a.ogg', 'Bruitages/X - x/1 - c.ogg']);
      expect(idx.dossier('Bruitages/X - x').map((c) => c.split('/').last), ['1 - c.ogg', '2 - a.ogg', '10 - b.ogg']);
    });

    test('dossier vide : le remplacement du manifeste (MONITEUR → COEUR), ou rien (HELICO)', () {
      final idx = IndexPack(fichiersDuManifeste(m));
      final moniteur = resoudreCode(m, idx, 'MONITEUR');
      expect(moniteur!.codeJoue, 'COEUR');
      expect(moniteur.chemin, contains('COEUR'));
      expect(resoudreCode(m, idx, 'HELICO'), isNull);
    });

    test('un palier à deux codes donne deux bruitages, avec leur durée', () {
      final d = m.dangers.values.firstWhere((d) => d.codes(3).length == 2);
      final l = resoudreBruitage(m, IndexPack(fichiersDuManifeste(m)), d.id, 3);
      expect(l.map((b) => b.code), d.codes(3));
      expect(l.every((b) => b.dureeS != null), isTrue);
    });

    test('rien d\'importé : aucun bruitage', () {
      expect(resoudreBruitage(m, IndexPack.vide, 'siege_arme', 2), isEmpty);
    });
  });

  group('import et bilan', () {
    test('seuls les fichiers audio des deux dossiers entrent dans le pack', () {
      expect(cheminDansPack(m, 'Spectacle/Musiques Destiny/Mystère - Église/a.mp3'),
          'Musiques Destiny/Mystère - Église/a.mp3');
      expect(
          cheminDansPack(m, '/Volumes/X/Spectacle/Bruitages/ALARME - a/1 - x.ogg'), 'Bruitages/ALARME - a/1 - x.ogg');
      expect(cheminDansPack(m, 'Spectacle/Bruitages/Sonniss GDC 2026/pack.ogg'), isNull);
      expect(cheminDansPack(m, 'Spectacle/Bruitages/Bruitages_Destiny.md'), isNull);
      expect(cheminDansPack(m, 'Spectacle/8 Octobre 2026/rush.mp3'), isNull);
      expect(cheminDansPack(m, '__MACOSX/Bruitages/ALARME - a/._1 - x.ogg'), isNull);
      expect(cheminDansPack(m, 'Spectacle/Bruitages/../../etc/x.ogg'), isNull);
    });

    test('le bilan du pack du NAS : 20 lieux propres (21 groupes, le Stade sans son acte 1), 20 en repli', () {
      final b = BilanPack.calculer(m, IndexPack(fichiersDuManifeste(m)));
      expect(b.lieuxPropres, hasLength(20));
      expect(b.lieuxFamille, hasLength(20));
      expect(b.lieuxFamille, contains('stade'));
      expect(b.lieuxSansMusique, isEmpty);
      expect(b.sonsRemplaces, ['MONITEUR']);
      expect(b.sonsManquants, ['HELICO']);
      expect(b.stingers, 10);
    });
  });

  group('réglages de la régie son', () {
    test('aller-retour en JSON, valeurs par défaut de la spec', () {
      final v = ValeursRegieSon();
      // À chaque acte : la musique, puis le bruitage à sa fin, jamais en même
      // temps.
      expect(v.bruitageAuto, [false, false, false, false]);
      expect(v.bruitageFinMusique, [true, true, true, true]);
      expect(v.revealActe, [false, false, true, false]);
      expect(v.courbes.map((c) => [for (final p in c) (p.secondes, p.volume)]), everyElement([(30.0, 0.5)]));
      expect(v.finAZero, [true, true, true, true]);
      v.courbes[1] = [PointVolume(20, 0.6), PointVolume(90, 0.3)];
      v
        ..volumeActe = [0.5, 0.6, 0.7, 0.8]
        ..choixCandidat = {'ALARME': 2, 'TIRS': kCandidatAleatoire}
        ..volumeCode = {'TIRS': 0.4};
      final w = ValeursRegieSon.depuisJson(jsonDecode(jsonEncode(v.versJson())) as Map<String, dynamic>);
      expect(w.volumeActe, [0.5, 0.6, 0.7, 0.8]);
      expect(w.choixCandidat, {'ALARME': 2, 'TIRS': -1});
      expect(w.volumeDe('TIRS'), 0.4);
      expect(w.volumeDe('ALARME'), 1);
      expect([for (final p in w.courbes[1]) (p.secondes, p.volume)], [(20.0, 0.6), (90.0, 0.3)]);
    });
  });

  group('l\'enchaînement fluide', () {
    test('les réglages : fluide par défaut, gardés en JSON, bornés ; une ancienne sauvegarde passe en fluide', () {
      final defaut = ValeursRegieSon();
      expect(defaut.fluide, isTrue);
      expect((defaut.monteeDestiny, defaut.maintienDestiny, defaut.maintienOuverture, defaut.descenteFond),
          (10, 15, 30, 3));
      expect(defaut.niveauFond, [0.4, 0.4, 0.4, 0.4]);
      expect((defaut.decalageBruitage, defaut.attenuationFluide, defaut.sortieSousDestiny), (0, 0.6, 2));
      final v = ValeursRegieSon()
        ..fluide = false
        ..monteeDestiny = 12
        ..maintienDestiny = 20
        ..maintienOuverture = 45
        ..descenteFond = 4
        ..niveauFond = [0.3, 0.35, 0.4, 0.45]
        ..decalageBruitage = -2
        ..attenuationFluide = 0.5
        ..sortieSousDestiny = 1.5;
      final j = jsonDecode(jsonEncode(v.versJson())) as Map<String, dynamic>;
      expect(j['enchainement'], 'classique');
      final w = ValeursRegieSon.depuisJson(j);
      expect(w.fluide, isFalse);
      expect((w.monteeDestiny, w.maintienDestiny, w.maintienOuverture, w.descenteFond), (12, 20, 45, 4));
      expect(w.niveauFond, [0.3, 0.35, 0.4, 0.45]);
      expect((w.decalageBruitage, w.attenuationFluide, w.sortieSousDestiny), (-2, 0.5, 1.5));
      // Une sauvegarde d'avant (sans ces clés) : les valeurs par défaut, en fluide.
      expect(ValeursRegieSon.depuisJson({'pack_actif': true}).fluide, isTrue);
      // Hors plage : ramené dans la plage.
      final hors =
          ValeursRegieSon.depuisJson({'montee_destiny': 60, 'decalage_bruitage': -9, 'sortie_sous_destiny': 0});
      expect((hors.monteeDestiny, hors.decalageBruitage, hors.sortieSousDestiny), (20, -5, 0.5));
    });

    /// L'acte 2 joue (en fluide, au fond), puis DESTINY 2 ouvre l'acte 3 ; le
    /// son Destiny dure [destinyS] secondes.
    Future<({ConduiteSon conduite, Map<BusSon, LecteurFactice> lecteurs, List<String> journal, Chrono chrono})> acte3(
        WidgetTester tester,
        {double destinyS = 22,
        ValeursRegieSon? valeurs,
        int numero = 2}) async {
      late Chrono chrono;
      final t = conduiteDeTest(
          valeurs: valeurs ?? ValeursRegieSon(), fluide: true, vraiTemps: true, maintenant: () => chrono.maintenant());
      chrono = Chrono(t.journal);
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme', acte: numero);
      unawaited(t.conduite.musiqueActe(numero));
      await chrono.avancer(tester, 3);
      t.journal.clear();
      chrono.instants.clear();
      chrono.t = 0;
      t.lecteurs[BusSon.destiny]!.dureeConnue = Duration(milliseconds: (destinyS * 1000).round());
      unawaited(t.conduite.destiny(numero));
      return (conduite: t.conduite, lecteurs: t.lecteurs, journal: t.journal, chrono: chrono);
    }

    testWidgets(
        'DESTINY 2 (acte 3) : Destiny à 0, l\'ancienne musique sort en 2 s, la nouvelle monte de T − 10 s à T, '
        'bruitage et REVEAL à T, jeu muet 15 s, descente en 3 s, puis le fond en boucle', (tester) async {
      final t = await acte3(tester);
      final c = t.chrono;
      final musique = t.lecteurs[BusSon.musique]!;
      await c.avancer(tester, 1);
      expect(t.journal.first, 'destiny:jouer:audio/DestinyStorm.wav');
      expect(c.quand('destiny:jouer'), 0);
      expect(t.conduite.phase, PhaseFluide.destiny);
      expect(t.conduite.resteDePhase!.inMilliseconds / 1000, closeTo(21, 0.3));
      // L'ancienne musique sort en fondu sous le Destiny, en 2 s.
      expect(musique.volume, closeTo(0.35, 0.06));
      await c.avancer(tester, 2);
      expect(c.quand('musique:arreter'), closeTo(2, 0.2));
      // T − 10 s = 12 s : la musique de l'acte 3 part à 0 et monte.
      await c.avancer(tester, 14);
      expect(c.quand('musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 3'), closeTo(12, 0.2));
      expect(musique.enBoucle, isTrue);
      expect(musique.volume, closeTo(0.7 * 5 / 10, 0.05), reason: 'à mi-montée (17 s)');
      expect(t.journal.where((e) => e.startsWith('bruitage') || e.startsWith('stinger')), isEmpty);
      // T = 22 s : maximum, le bruitage et le REVEAL partent ensemble.
      await c.avancer(tester, 5.1);
      final codes = m.dangers['siege_arme']!.codes(3);
      expect(c.quand('bruitageA:jouer:Bruitages/${codes.first}'), closeTo(22, 0.2));
      expect(c.quand('stinger:jouer:Bruitages/REVEAL'), closeTo(22, 0.2));
      expect(t.conduite.phase, PhaseFluide.jeuMuet);
      expect(t.conduite.resteDePhase!.inMilliseconds / 1000, closeTo(15, 0.3));
      // Sous le bruitage : atténuée à 60 % (0,42), pas plus.
      await c.avancer(tester, 0.5);
      expect(musique.volume, closeTo(0.7 * 0.6, 0.02));
      // Le bruitage fini, elle remonte au maximum.
      await c.avancer(tester, 13);
      expect(musique.volume, closeTo(0.7, 0.02));
      expect(t.conduite.phase, PhaseFluide.jeuMuet);
      // T + 15 s = 37 s : la descente, en 3 s, vers le fond (0,4).
      await c.avancer(tester, 1.5);
      expect(t.conduite.phase, PhaseFluide.fond);
      expect(t.conduite.resteDePhase, isNull, reason: 'le fond dure jusqu\'au Destiny suivant');
      expect(musique.volume, closeTo(0.7 - 0.3 * 0.5 / 3, 0.05));
      await c.avancer(tester, 4);
      expect(musique.volume, closeTo(0.4, 1e-6));
      expect(musique.actif, isTrue);
      expect(musique.enBoucle, isTrue);
      expect(t.conduite.etape, EtapeConduite.repos);
      // Ni courbe, ni bruitage de fin de musique, ni ambiance du lieu.
      await c.avancer(tester, 30);
      expect(musique.volume, closeTo(0.4, 1e-6));
      expect(t.journal.where((e) => e.contains('ambiences')), isEmpty);
      expect(t.journal.where((e) => e.startsWith('bruitageA:jouer')), hasLength(1));
      await t.conduite.stopTout();
      await tester.pump(const Duration(seconds: 120));
    });

    testWidgets('DESTINY 1 (acte 2) : pas de REVEAL ; le bruitage décalé de +2 s', (tester) async {
      final t = await acte3(tester, numero: 1, valeurs: ValeursRegieSon()..decalageBruitage = 2);
      await t.chrono.avancer(tester, 26);
      expect(t.chrono.quand('bruitageA:jouer'), closeTo(24, 0.2));
      expect(t.journal.where((e) => e.startsWith('stinger')), isEmpty);
      expect(t.chrono.quand('musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 2'), closeTo(12, 0.2));
      await t.conduite.stopTout();
      await tester.pump(const Duration(seconds: 120));
    });

    testWidgets('un son Destiny plus court que la montée : la musique part avec lui, au maximum à sa fin',
        (tester) async {
      final t = await acte3(tester, destinyS: 4);
      final musique = t.lecteurs[BusSon.musique]!;
      await t.chrono.avancer(tester, 0.5);
      expect(t.chrono.quand('musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 3'), 0);
      expect(t.journal.indexWhere((e) => e.startsWith('musique:jouer')),
          greaterThan(t.journal.indexOf('destiny:jouer:audio/DestinyStorm.wav')),
          reason: 'le Destiny part d\'abord');
      await t.chrono.avancer(tester, 1.5);
      expect(musique.volume, closeTo(0.35, 0.05), reason: 'mi-montée à 2 s');
      await t.chrono.avancer(tester, 2.1);
      expect(t.chrono.quand('bruitageA:jouer'), closeTo(4, 0.2));
      expect(t.conduite.phase, PhaseFluide.jeuMuet);
      await t.conduite.stopTout();
      await tester.pump(const Duration(seconds: 120));
    });

    testWidgets('ouverture : la musique de l\'acte 1 tout de suite au maximum, 30 s, puis le fond en 3 s, en boucle',
        (tester) async {
      late Chrono c;
      final t =
          conduiteDeTest(valeurs: ValeursRegieSon(), fluide: true, vraiTemps: true, maintenant: () => c.maintenant());
      c = Chrono(t.journal);
      final musique = t.lecteurs[BusSon.musique]!;
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      unawaited(t.conduite.ouverture());
      await c.avancer(tester, 0.2);
      expect(t.journal, ['musique:jouer:Musiques Destiny/Mystère - Église/Destiny Intro 40 - Église.mp3']);
      expect(musique.volume, closeTo(0.7, 1e-9));
      expect(musique.enBoucle, isTrue);
      expect(t.conduite.phase, PhaseFluide.jeuMuet);
      expect(t.conduite.resteDePhase!.inMilliseconds / 1000, closeTo(29.8, 0.3));
      await c.avancer(tester, 29.6);
      expect(musique.volume, closeTo(0.7, 1e-9));
      await c.avancer(tester, 1.7);
      expect(t.conduite.phase, PhaseFluide.fond);
      expect(musique.volume, closeTo(0.7 - 0.3 * 1.5 / 3, 0.05));
      await c.avancer(tester, 3);
      expect(musique.volume, closeTo(0.4, 1e-6));
      // Pas de bruitage du palier 1 : il reste manuel.
      await c.avancer(tester, 60);
      expect(t.journal.where((e) => e.startsWith('bruitage') || e.contains('ambiences')), isEmpty);
      expect(musique.actif, isTrue);
      // « Danger » : le bruitage du palier 1, la musique atténuée à 60 % du fond.
      unawaited(t.conduite.danger());
      await c.avancer(tester, 0.5);
      expect(t.journal.last, startsWith('bruitageA:jouer:Bruitages/${m.dangers['siege_arme']!.codes(1).first}'));
      expect(musique.volume, closeTo(0.4 * 0.6, 0.02));
      await t.conduite.stopTout();
      await tester.pump(const Duration(seconds: 120));
    });

    for (final (nom, apres) in [
      ('pendant le Destiny, avant la musique', 5.0),
      ('pendant la montée', 15.0),
      ('pendant le jeu muet, sous le bruitage', 23.0),
      ('pendant la descente', 38.0),
    ]) {
      testWidgets('annuler $nom : plus rien ne part, la musique ne remonte pas', (tester) async {
        final t = await acte3(tester);
        final musique = t.lecteurs[BusSon.musique]!;
        await t.chrono.avancer(tester, apres);
        await t.conduite.annulerSequence();
        final entrees = t.journal.length;
        final volume = musique.volume;
        final reglages = musique.volumes.length;
        await t.chrono.avancer(tester, 60);
        expect(t.journal.sublist(entrees).where((e) => e.contains(':jouer')), isEmpty);
        expect(musique.volumes.sublist(reglages).where((x) => x > volume + 1e-9), isEmpty);
        expect(t.conduite.phase, PhaseFluide.aucune);
        expect(t.conduite.etape, EtapeConduite.repos);
        expect(t.lecteurs[BusSon.destiny]!.actif || t.lecteurs[BusSon.stinger]!.actif, isFalse);
        expect(t.lecteurs[BusSon.bruitageA]!.actif || t.lecteurs[BusSon.bruitageB]!.actif, isFalse);
        await t.conduite.stopTout();
        await tester.pump(const Duration(seconds: 120));
      });
    }

    testWidgets('un nouveau Destiny pendant une séquence la remplace, sans son orphelin', (tester) async {
      final t = await acte3(tester, numero: 1);
      await t.chrono.avancer(tester, 14);
      t.lecteurs[BusSon.destiny]!.dureeConnue = const Duration(seconds: 22);
      unawaited(t.conduite.destiny(2));
      await t.chrono.avancer(tester, 40);
      // Une seule musique de l'acte 2 (la première séquence), puis celle de l'acte 3 ; un seul bruitage, du palier 3.
      expect(t.journal.where((e) => e.startsWith('musique:jouer') && e.contains('Acte 3')), hasLength(1));
      final bruitages = t.journal.where((e) => e.startsWith('bruitageA:jouer')).toList();
      expect(bruitages, hasLength(1));
      expect(bruitages.single, startsWith('bruitageA:jouer:Bruitages/${m.dangers['siege_arme']!.codes(3).first}'));
      expect(t.conduite.acte, 3);
      expect(t.conduite.phase, PhaseFluide.fond);
      await t.conduite.stopTout();
      await tester.pump(const Duration(seconds: 120));
    });

    testWidgets('un réglage changé pendant la séquence vaut pour la suivante', (tester) async {
      final t = await acte3(tester);
      await t.chrono.avancer(tester, 1);
      t.conduite.reglages.v.monteeDestiny = 4;
      await t.chrono.avancer(tester, 12);
      expect(t.chrono.quand('musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 3'), closeTo(12, 0.2));
      await t.conduite.stopTout();
      await tester.pump(const Duration(seconds: 120));
    });
  });

  group('la conduite', () {
    test('ouverture : la musique de l\'acte 1, à sa fin le bruitage du palier 1, puis l\'ambiance du lieu à 15 %',
        () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      expect(t.conduite.active, isTrue);
      await t.conduite.ouverture();
      await laisserTourner();
      expect(t.journal, ['musique:jouer:Musiques Destiny/Mystère - Église/Destiny Intro 40 - Église.mp3']);
      expect(t.lecteurs[BusSon.musique]!.volume, closeTo(0.7, 1e-9));
      // Tant que la musique joue, pas de bruitage…
      expect(t.journal.where((e) => e.startsWith('bruitage')), isEmpty);
      // …et à sa fin, le bruitage du palier 1.
      t.lecteurs[BusSon.musique]!.finir();
      await laisserTourner();
      expect(t.journal, contains(startsWith('bruitageA:jouer:Bruitages/${m.dangers['siege_arme']!.codes(1).first}')));
      // Puis l'ambiance du lieu, en fond, à 15 %.
      final bruitage = t.journal.indexWhere((e) => e.startsWith('bruitageA:jouer'));
      final ambiance = t.journal.indexOf('musique:jouer:audio/ambiences/eglise.m4a');
      expect(ambiance, greaterThan(bruitage));
      expect(t.lecteurs[BusSon.musique]!.volume, closeTo(0.15, 1e-9));
      expect(t.lecteurs[BusSon.musique]!.actif, isTrue);
    });

    test('une musique coupée par la régie (Stop, Destiny) n\'appelle pas le bruitage', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      await t.conduite.ouverture();
      await laisserTourner();
      await t.conduite.stopTout();
      await laisserTourner();
      expect(t.journal.where((e) => e.startsWith('bruitage')), isEmpty);
    });

    test('un son d\'ouverture choisi passe avant la musique de l\'acte 1', () async {
      final t = conduiteDeTest(
          valeurs: ValeursRegieSon()
            ..sansCourbes()
            ..sonOuverture = 'storm');
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      final fini = t.conduite.ouverture();
      await laisserTourner();
      expect(t.journal, ['destiny:jouer:audio/DestinyStorm.wav']);
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      await fini;
      expect(t.journal.last, startsWith('musique:jouer:'));
    });

    test('DESTINY 2 (acte 3) : sortie, son Destiny, REVEAL, la musique, puis à sa fin les bruitages et l\'ambiance',
        () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme', acte: 2);
      // La musique de l'acte 2 joue déjà.
      await t.conduite.musiqueActe(2);
      await laisserTourner();
      t.journal.clear();

      final fini = t.conduite.destiny(2);
      await laisserTourner();
      expect(t.journal, ['musique:arreter', 'destiny:jouer:audio/DestinyStorm.wav']);
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      await fini;

      final codes = m.dangers['siege_arme']!.codes(3);
      int indice(String debut) => t.journal.indexWhere((e) => e.startsWith(debut));
      expect(indice('stinger:jouer:Bruitages/REVEAL'), greaterThan(0));
      expect(indice('musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 3'),
          greaterThan(indice('stinger:jouer')));
      // Pas de bruitage tant que la musique de l'acte joue.
      expect(indice('bruitage'), -1);
      expect(t.conduite.acte, 3);
      expect(t.conduite.acteEnCours, 3);
      expect(t.lecteurs[BusSon.musique]!.volume, closeTo(0.7, 1e-9));

      t.lecteurs[BusSon.musique]!.finir();
      await laisserTourner();
      expect(indice('bruitageA:jouer:Bruitages/${codes[0]}'), greaterThan(indice('musique:jouer:Musiques')));
      expect(indice('bruitageB:jouer:Bruitages/${codes[1]}'), greaterThan(indice('bruitageA:jouer')));
      expect(indice('musique:jouer:audio/ambiences/eglise.m4a'), greaterThan(indice('bruitageB:jouer')));
      expect(t.conduite.ambianceEnCours, isTrue);
      expect(t.conduite.acteEnCours, isNull);
    });

    test('DESTINY 1 (acte 2) : pas de REVEAL par défaut, la musique de l\'acte 2, puis le bruitage du palier 2',
        () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      final fini = t.conduite.destiny(1);
      await laisserTourner();
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      await fini;
      expect(t.journal.where((e) => e.startsWith('stinger')), isEmpty);
      expect(t.journal.last, 'musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 2 - 40 - Église.mp3');
      expect(t.journal.where((e) => e.startsWith('bruitage')), isEmpty);
      t.lecteurs[BusSon.musique]!.finir();
      await laisserTourner();
      expect(t.journal, contains(startsWith('bruitageA:jouer:Bruitages/${m.dangers['siege_arme']!.codes(2).first}')));
    });

    test(
        'le spectacle en entier, avec le pack : à chaque acte sa musique, puis le danger du palier, puis l\'ambiance ; '
        'jamais deux sons en même temps', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      final musique = t.lecteurs[BusSon.musique]!;
      final simultanes = <String>[];
      // À chaque son qui part, rien d'autre ne doit jouer (sauf l'ambiance
      // qu'un Destiny vient de faire sortir, déjà arrêtée).
      void surveiller() {
        final actifs = [
          for (final e in t.lecteurs.entries)
            // L'ambiance à 15 % peut croiser la fin d'un bruitage.
            if (e.value.actif && !(e.key == BusSon.musique && t.conduite.ambianceEnCours)) e.key.name,
        ];
        if (actifs.length > 1 &&
            !(actifs.length == 2 && actifs.contains('bruitageA') && actifs.contains('bruitageB'))) {
          simultanes.add('${t.journal.last} avec ${actifs.join('+')}');
        }
      }

      // Le stinger REVEAL est court : il finit avant la suite (avec les
      // attentes immédiates du test, on le termine dès qu'il part).
      final stinger = t.lecteurs[BusSon.stinger]!;
      stinger.addListener(() {
        if (stinger.actif) stinger.finir();
      });
      for (final l in t.lecteurs.values) {
        l.addListener(surveiller);
      }

      Future<void> acte(int n) async {
        final avant = t.journal.length;
        if (n == 1) {
          unawaited(t.conduite.ouverture());
        } else {
          unawaited(t.conduite.destiny(n - 1));
          await laisserTourner();
          t.lecteurs[BusSon.destiny]!.finir();
        }
        await laisserTourner();
        final attendu = m.lieux['eglise']!.musiques[n]!.fichier;
        expect(musique.enCours?.chemin, endsWith(attendu.split('/').last), reason: 'la musique de l\'acte $n');
        expect(t.conduite.acteEnCours, n);
        musique.finir();
        await laisserTourner();
        final codes = m.dangers['siege_arme']!.codes(n);
        final ici = t.journal.sublist(avant);
        expect(ici.where((e) => e.startsWith('bruitageA:jouer')).first,
            startsWith('bruitageA:jouer:Bruitages/${codes.first}'),
            reason: 'le danger du palier $n');
        expect(ici.indexOf('musique:jouer:audio/ambiences/eglise.m4a'),
            greaterThan(ici.indexWhere((e) => e.startsWith('bruitageA:jouer'))),
            reason: 'puis l\'ambiance du lieu');
        expect(t.conduite.ambianceEnCours, isTrue);
        expect(musique.volume, closeTo(0.15, 1e-9));
        // Les bruitages finissent.
        t.lecteurs[BusSon.bruitageA]!.finir();
        t.lecteurs[BusSon.bruitageB]!.finir();
      }

      for (var n = 1; n <= 4; n++) {
        await acte(n);
      }
      expect(simultanes, isEmpty);
      expect(t.conduite.acte, 4);
    });

    test('pour chacun des 40 lieux, les quatre actes ont chacun leur musique, et ce n\'est jamais l\'ambiance', () {
      final t = conduiteDeTest();
      for (final lieu in m.lieux.keys) {
        t.conduite.preparer(lieuId: lieu, dangerId: 'siege_arme');
        final chemins = [for (var a = 1; a <= 4; a++) t.conduite.sourceActe(a)?.chemin];
        expect(chemins, everyElement(isNotNull), reason: lieu);
        expect(chemins.toSet(), hasLength(4), reason: '$lieu : $chemins');
        expect(chemins[0], contains('Intro'), reason: lieu);
        for (var a = 2; a <= 4; a++) {
          expect(chemins[a - 1], contains('Acte $a'), reason: '$lieu, acte $a');
        }
        expect(chemins, everyElement(isNot(contains('ambiences'))), reason: lieu);
      }
    });

    test('sans pack : la même conduite avec les musiques des réglages et l\'ambiance du lieu, sans bruitage', () async {
      const choix = ['music/01_commencement.m4a', 'aucune', 'lieu', 'music/02_conclusionainsique.m4a'];
      final t = conduiteDeTest(fichiers: const [], choixSansPack: (a) => choix[a - 1]);
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      expect(t.conduite.active, isFalse);
      final musique = t.lecteurs[BusSon.musique]!;

      // Acte 1 : le Commencement, puis l'ambiance à 15 %.
      await t.conduite.ouverture();
      await laisserTourner();
      expect(t.journal, ['musique:jouer:music/01_commencement.m4a']);
      expect(t.conduite.acteEnCours, 1);
      expect(t.conduite.ambianceEnCours, isFalse);
      musique.finir();
      await laisserTourner();
      expect(t.journal.last, 'musique:jouer:audio/ambiences/eglise.m4a');
      expect(musique.volume, closeTo(0.15, 1e-9));
      expect(t.conduite.ambianceEnCours, isTrue);
      expect(t.conduite.acteEnCours, isNull, reason: 'un seul pad allumé : l\'ambiance');

      // Acte 2 (« aucune ») : l'ambiance sort, le son Destiny, l'ambiance revient.
      t.journal.clear();
      unawaited(t.conduite.destiny(1));
      await laisserTourner();
      expect(t.journal, ['musique:arreter', 'destiny:jouer:audio/DestinyStorm.wav']);
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      expect(t.journal.sublist(2), ['musique:jouer:audio/ambiences/eglise.m4a']);

      // Acte 3 (« lieu ») : l'ambiance du lieu comme musique, à 70 %, puis en fond.
      t.journal.clear();
      unawaited(t.conduite.destiny(2));
      await laisserTourner();
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      expect(t.journal.last, 'musique:jouer:audio/ambiences/eglise.m4a');
      expect(musique.volume, closeTo(0.7, 1e-9));
      expect(t.conduite.acteEnCours, 3);
      musique.finir();
      await laisserTourner();
      expect(musique.volume, closeTo(0.15, 1e-9));

      // Acte 4 : la Conclusion.
      t.journal.clear();
      unawaited(t.conduite.destiny(3));
      await laisserTourner();
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      expect(t.journal.last, 'musique:jouer:music/02_conclusionainsique.m4a');
      expect(t.conduite.acteEnCours, 4);
      expect(t.journal.where((e) => e.startsWith('bruitage') || e.startsWith('stinger')), isEmpty);
    });

    test('annuler pendant le son Destiny : plus rien ne part, rien ne reste', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      final fini = t.conduite.destiny(1);
      await laisserTourner();
      await t.conduite.annulerSequence();
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      await fini;
      expect(t.journal.where((e) => e.startsWith('bruitage') || e.startsWith('musique:jouer')), isEmpty);
      expect(t.journal.last, 'destiny:arreter');
      expect(t.lecteurs.values.every((l) => !l.actif), isTrue);
      expect(t.conduite.etape, EtapeConduite.repos);
    });

    test('« Danger » rejoue le palier en cours ; « Autre » passe au candidat suivant', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme', acte: 2);
      await t.conduite.danger();
      final premier = t.journal.firstWhere((e) => e.startsWith('bruitageA:jouer'));
      t.journal.clear();
      await t.conduite.autre();
      final second = t.journal.firstWhere((e) => e.startsWith('bruitageA:jouer'));
      expect(second, isNot(premier));
    });

    test('son coupé : la conduite ne joue rien ; pack désactivé : ni bruitage ni REVEAL', () async {
      final coupe = conduiteDeTest(muet: () => true);
      coupe.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      await coupe.conduite.ouverture();
      await coupe.conduite.danger();
      expect(coupe.journal, isEmpty);

      final inactif = conduiteDeTest(
          valeurs: ValeursRegieSon()
            ..sansCourbes()
            ..packActif = false);
      inactif.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      expect(inactif.conduite.active, isFalse);
      final fini = inactif.conduite.destiny(2);
      await laisserTourner();
      inactif.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      await fini;
      await inactif.conduite.danger();
      expect(
          inactif.journal.where((e) => e.startsWith('bruitage') || e.startsWith('stinger') || e.contains('Musiques')),
          isEmpty);

      final sansPack = conduiteDeTest(fichiers: const []);
      sansPack.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      expect(sansPack.conduite.active, isFalse);
    });

    testWidgets('courbe de volume : 70 % au départ, 50 % à 30 s, puis 0 % à la fin du morceau, où elle s\'arrête',
        (tester) async {
      expect(ValeursRegieSon().boucle, isFalse, reason: 'les musiques s\'arrêtent à la fin');
      final t = conduiteDeTest(valeurs: ValeursRegieSon(), vraiTemps: true);
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      final musique = t.lecteurs[BusSon.musique]!;
      // La musique de l'acte 1 de l'église dure 115,2 s (manifeste).
      unawaited(t.conduite.musiqueActe(1));
      Future<void> aller(double secondes) async {
        for (var i = 0; i < secondes * 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      // Fondu d'entrée fini (2 s) : sur la droite de 70 % (0 s) à 50 % (30 s).
      await aller(3);
      expect(musique.volume, closeTo(0.7 - 0.2 * 3 / 30, 0.01));
      await aller(27);
      expect(musique.volume, closeTo(0.5, 0.01));
      // À mi-chemin entre 30 s et la fin : 25 %.
      await aller((115.2 - 30) / 2);
      expect(musique.volume, closeTo(0.25, 0.02));
      await aller(50);
      expect(musique.actif, isFalse);
      expect(t.journal.last, 'musique:arreter');
      expect(musique.volumes.last, lessThan(0.01));
    });

    test('sans courbe, la musique reste à son volume', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      await t.conduite.musiqueActe(1);
      await laisserTourner();
      expect(t.lecteurs[BusSon.musique]!.actif, isTrue);
      expect(t.lecteurs[BusSon.musique]!.volume, closeTo(0.7, 1e-9));
    });

    test('« Fondu de fin » éteint tout puis arrête', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      await t.conduite.musiqueActe(1);
      await t.conduite.fonduFin();
      expect(t.lecteurs.values.every((l) => !l.actif), isTrue);
      expect(t.journal.last, 'musique:arreter');
    });
  });
}
