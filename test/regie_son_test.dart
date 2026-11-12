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

  @override
  Future<void> jouer(SourceSon source, {double volume = 1, bool boucle = false}) async {
    if (!_fin.isCompleted) _fin.complete();
    _fin = Completer<void>();
    _enCours = source;
    _volume = volume;
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

/// Une conduite branchée sur des lecteurs factices. Les attentes sont
/// immédiates, sauf le délai de sécurité : on attend vraiment la fin des sons.
({ConduiteSon conduite, Map<BusSon, LecteurFactice> lecteurs, List<String> journal}) conduiteDeTest({
  List<String>? fichiers,
  ValeursRegieSon? valeurs,
  bool Function()? muet,
  bool vraiTemps = false,
}) {
  final journal = <String>[];
  final lecteurs = <BusSon, LecteurFactice>{};
  final conduite = ConduiteSon(
    pack: PackAudio.pourTests(m, IndexPack(fichiers ?? fichiersDuManifeste(m))),
    // L'atténuation progressive coupe la musique tout de suite quand les
    // attentes sont immédiates : elle a son propre test.
    reglages: ReglagesRegieSon(valeurs ?? (ValeursRegieSon()..sansCourbes())),
    muet: muet,
    fabrique: (b) => lecteurs[b] = LecteurFactice(b, journal),
    // vraiTemps : les vrais délais (Future.delayed), menés par l'horloge d'un
    // testWidgets.
    attendre: vraiTemps
        ? null
        : (d) => d >= const Duration(seconds: 60) ? Completer<void>().future : Future<void>.value(),
    hasard: Random(1),
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
      expect(cheminDansPack(m, '/Volumes/X/Spectacle/Bruitages/ALARME - a/1 - x.ogg'), 'Bruitages/ALARME - a/1 - x.ogg');
      expect(cheminDansPack(m, 'Spectacle/Bruitages/Sonniss GDC 2026/pack.ogg'), isNull);
      expect(cheminDansPack(m, 'Spectacle/Bruitages/Bruitages_Destiny.md'), isNull);
      expect(cheminDansPack(m, 'Spectacle/8 Octobre 2026/rush.mp3'), isNull);
      expect(cheminDansPack(m, '__MACOSX/Bruitages/ALARME - a/._1 - x.ogg'), isNull);
      expect(cheminDansPack(m, 'Spectacle/Bruitages/../../etc/x.ogg'), isNull);
    });

    test('le bilan du pack du NAS : 6 lieux propres, 34 en repli famille', () {
      final b = BilanPack.calculer(m, IndexPack(fichiersDuManifeste(m)));
      expect(b.lieuxPropres, hasLength(6));
      expect(b.lieuxFamille, hasLength(34));
      expect(b.lieuxSansMusique, isEmpty);
      expect(b.sonsRemplaces, ['MONITEUR']);
      expect(b.sonsManquants, ['HELICO']);
      expect(b.stingers, 10);
    });
  });

  group('réglages de la régie son', () {
    test('aller-retour en JSON, valeurs par défaut de la spec', () {
      final v = ValeursRegieSon();
      expect(v.bruitageAuto, [false, true, true, true]);
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

  group('la conduite', () {
    test('ouverture : la musique de l\'acte 1, à sa fin le bruitage du palier 1, puis l\'ambiance du lieu à 15 %', () async {
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
      final t = conduiteDeTest(valeurs: ValeursRegieSon()
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

    test('DESTINY 2 (acte 3) : sortie, son Destiny, REVEAL, bruitages décalés, puis musique', () async {
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
      expect(indice('bruitageA:jouer:Bruitages/${codes[0]}'), greaterThan(indice('stinger:jouer')));
      expect(indice('bruitageB:jouer:Bruitages/${codes[1]}'), greaterThan(indice('bruitageA:jouer')));
      // La musique entre pendant le bruitage (atténuée), après le 1er code.
      expect(indice('musique:jouer:Musiques Destiny/Mystère - Église/Destiny Acte 3'), greaterThan(indice('bruitageA:jouer')));
      expect(t.conduite.acte, 3);
      // Le bruitage fini, la musique est remontée.
      expect(t.conduite.attenue, isFalse);
      expect(t.lecteurs[BusSon.musique]!.volume, closeTo(0.7, 1e-9));
    });

    test('DESTINY 1 (acte 2) : pas de REVEAL par défaut, le bruitage du palier 2', () async {
      final t = conduiteDeTest();
      t.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      final fini = t.conduite.destiny(1);
      await laisserTourner();
      t.lecteurs[BusSon.destiny]!.finir();
      await laisserTourner();
      await fini;
      expect(t.journal.where((e) => e.startsWith('stinger')), isEmpty);
      expect(t.journal, contains(startsWith('bruitageA:jouer:Bruitages/${m.dangers['siege_arme']!.codes(2).first}')));
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

    test('son coupé ou pack désactivé : la conduite ne joue rien', () async {
      final coupe = conduiteDeTest(muet: () => true);
      coupe.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      await coupe.conduite.ouverture();
      await coupe.conduite.danger();
      expect(coupe.journal, isEmpty);

      final inactif = conduiteDeTest(valeurs: ValeursRegieSon()..packActif = false);
      inactif.conduite.preparer(lieuId: 'eglise', dangerId: 'siege_arme');
      expect(inactif.conduite.active, isFalse);
      await inactif.conduite.destiny(1);
      expect(inactif.journal, isEmpty);

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
