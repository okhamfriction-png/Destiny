import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:destiny/application/exercices/seance_exercice_destiny.dart';
import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/son/conduite_son.dart';
import 'package:destiny/application/son/lecteur_son.dart';
import 'package:destiny/application/son/pack_audio.dart';
import 'package:destiny/application/son/reglages_regie_son.dart';
import 'package:destiny/domain/entities/danger.dart';
import 'package:destiny/domain/exercices/exercices_destiny.dart';
import 'package:destiny/domain/son/categories_son.dart';
import 'package:destiny/domain/son/manifeste_audio.dart';
import 'package:destiny/domain/son/resolution_son.dart';
import 'package:flutter_test/flutter_test.dart';

import 'regie_son_test.dart' show LecteurFactice, fichiersDuManifeste;

late ManifesteAudio m;
late List<Danger> dangers;

/// Un lecteur qui note, pour chaque volume réglé, l'instant (horloge
/// virtuelle du test).
class LecteurHorodate extends LecteurFactice {
  LecteurHorodate(super.bus, super.journal, this.horloge);

  final double Function() horloge;
  final List<(double, double)> courbe = [];

  @override
  Future<void> jouer(SourceSon source, {double volume = 1, bool boucle = false}) async {
    courbe.add((horloge(), volume));
    await super.jouer(source, volume: volume, boucle: boucle);
  }

  @override
  Future<void> regler(double volume) async {
    courbe.add((horloge(), volume));
    await super.regler(volume);
  }
}

/// Un exercice avec une horloge virtuelle : chaque attente fait avancer le
/// temps d'autant, tout de suite. Une attente d'une minute ou plus (les
/// délais de sécurité) ne se termine jamais.
({SeanceExerciceDestiny seance, Map<BusSon, LecteurHorodate> lecteurs, List<String> journal, double Function() t})
    exercice(
  ExerciceDestiny e, {
  int dureeS = 120,
  int acte = 1,
  int protagonistes = 4,
  List<String>? fichiers,
  ReglagesExercicesDestiny? reglages,
  int graine = 1,
}) {
  var t = 0.0;
  final journal = <String>[];
  final lecteurs = <BusSon, LecteurHorodate>{};
  final seance = SeanceExerciceDestiny(
    exercice: e,
    pack: PackAudio.pourTests(m, IndexPack(fichiers ?? fichiersDuManifeste(m))),
    regie: ValeursRegieSon(),
    reglages: reglages ?? ReglagesExercicesDestiny(),
    lieux: [for (final l in m.lieux.values) (id: l.id, nom: l.nom)],
    lieuId: 'casino',
    dureeS: dureeS,
    acte: acte,
    protagonistes: protagonistes,
    dangers: dangers,
    muet: () => false,
    // Le son Destiny dure 12 s (le lecteur le dit, comme un vrai).
    fabrique: (b) => lecteurs[b] = LecteurHorodate(b, journal, () => t)
      ..dureeConnue = b == BusSon.destiny ? const Duration(seconds: 12) : null,
    attendre: (d) {
      if (d >= const Duration(seconds: 60)) return Future<void>.delayed(const Duration(days: 1));
      t += d.inMilliseconds / 1000;
      return Future<void>.value();
    },
    hasard: Random(graine),
    minuteur: false,
  );
  return (seance: seance, lecteurs: lecteurs, journal: journal, t: () => t);
}

/// Le volume de la courbe à l'instant [instant] (le dernier réglé avant).
double volumeA(List<(double, double)> courbe, double instant) {
  var v = 0.0;
  for (final (t, x) in courbe) {
    if (t <= instant + 1e-9) v = x;
  }
  return v;
}

Future<void> laisserTourner() async {
  for (var i = 0; i < 2000; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() {
    m = ManifesteAudio.depuisJson(
        jsonDecode(File('assets/data/destiny_audio.json').readAsStringSync()) as Map<String, dynamic>);
    dangers = [
      for (final d in (jsonDecode(File('assets/data/dangers.json').readAsStringSync())['dangers'] as List))
        Danger.fromJson(d as Map<String, dynamic>),
    ];
  });

  group('les sons des exercices', () {
    test('le manifeste a les trois DESTINY n°2 et la cloche, et le pack de l\'appli passe devant celui du NAS', () {
      expect(m.version, greaterThanOrEqualTo(2));
      for (final code in ['DESTINY2_CATASTROPHE', 'DESTINY2_THRILLER', 'DESTINY2_SURVIE', 'FIN_EXERCICE']) {
        expect(m.sons[code]?.fichiers, isNotEmpty, reason: code);
        expect(CategorieBruitage.de(code), CategorieBruitage.destiny);
      }
      expect(m.sons['DESTINY2_THRILLER']!.fichiers, hasLength(8));
      expect(m.sons['DESTINY2_SURVIE']!.fichiers, hasLength(8));
      expect(m.sons['DESTINY2_CATASTROPHE']!.fichiers, hasLength(4));
      // L'import du pack prend ces dossiers.
      for (final f in m.sons['FIN_EXERCICE']!.fichiers) {
        expect(cheminDansPack(m, '/Volumes/ShikaZero/Spectacle/${f.chemin}'), f.chemin);
      }
    });

    test('le son du DESTINY n°2 suit le style du danger tiré au DESTINY n°1', () {
      expect(codeDestiny2('Catastrophe'), 'DESTINY2_CATASTROPHE');
      expect(codeDestiny2('Thriller'), 'DESTINY2_THRILLER');
      expect(codeDestiny2('Survie / Dilemme'), 'DESTINY2_SURVIE');
      expect(codeDestiny2('Fantastique'), isNull);
      // Chaque danger actif a un type sur le dé.
      for (final d in dangers.where((d) => d.actif)) {
        expect(TypeDanger.deStyle(d.style), isNotNull, reason: d.id);
      }
    });

    test('les prises du DESTINY n°2 sont au hasard par défaut, et la régie peut en fixer une', () {
      final v = ValeursRegieSon();
      expect(v.choixCandidat['DESTINY2_THRILLER'], kCandidatAleatoire);
      final relu = ValeursRegieSon.depuisJson({
        'choix_candidat': {'DESTINY2_THRILLER': 2},
      });
      expect(relu.choixCandidat['DESTINY2_THRILLER'], 2);
      expect(relu.choixCandidat['DESTINY2_SURVIE'], kCandidatAleatoire);
    });
  });

  group('le spectacle', () {
    test('le DESTINY n°2 joue le son du type du danger ; les deux autres, le son Destiny habituel', () async {
      final styles = {
        for (final d in dangers) d.id: d.style,
      };
      final journal = <String>[];
      final conduite = ConduiteSon(
        pack: PackAudio.pourTests(m, IndexPack(fichiersDuManifeste(m))),
        reglages: ReglagesRegieSon(ValeursRegieSon()),
        muet: () => false,
        fabrique: (b) => LecteurFactice(b, journal)..dureeConnue = const Duration(seconds: 12),
        attendre: (d) => d >= const Duration(seconds: 60) ? Future<void>.delayed(const Duration(days: 1)) : Future<void>.value(),
        styleDanger: (id) => styles[id],
      );
      final incendie = dangers.firstWhere((d) => d.id == 'incendie');
      conduite.preparer(lieuId: 'eglise', dangerId: incendie.id, acte: 2);
      unawaited(conduite.destiny(2));
      await laisserTourner();
      final code = codeDestiny2(incendie.style)!;
      expect(journal.firstWhere((j) => j.startsWith('destiny:jouer:')), contains(code));
      journal.clear();
      unawaited(conduite.destiny(3));
      await laisserTourner();
      expect(journal.firstWhere((j) => j.startsWith('destiny:jouer:')), 'destiny:jouer:${AudioService.stormAsset}');
      // Ni bruitage du palier ni REVEAL par défaut.
      expect(journal.where((j) => j.startsWith('bruitage') || j.startsWith('stinger')), isEmpty);
    });
  });

  group('la pause', () {
    test('pendant les 20 s à 100 %, la pause fige la musique ; à la reprise, elle repart et descend à 5 %', () async {
      final journal = <String>[];
      final lecteurs = <BusSon, LecteurFactice>{};
      var t = 0.0;
      var bloque = true;
      final conduite = ConduiteSon(
        pack: PackAudio.pourTests(m, IndexPack(fichiersDuManifeste(m))),
        reglages: ReglagesRegieSon(ValeursRegieSon()),
        muet: () => false,
        fabrique: (b) => lecteurs[b] = LecteurFactice(b, journal),
        // Le maintien de 20 s ne se termine pas tant que [bloque] : on met en
        // pause pendant.
        attendre: (d) async {
          if (d >= const Duration(seconds: 15) && bloque) return Completer<void>().future;
          t += d.inMilliseconds / 1000;
        },
      );
      conduite.preparer(lieuId: 'eglise', dangerId: 'incendie');
      unawaited(conduite.ouverture());
      await laisserTourner();
      final musique = lecteurs[BusSon.musique]!;
      expect(musique.volume, closeTo(1, 1e-9), reason: '100 % pendant le maintien');
      expect(conduite.phase, PhaseFluide.jeuMuet);
      await conduite.pause();
      expect(journal, contains('musique:pause'));
      expect(conduite.enPause, isTrue);
      expect(musique.actif, isTrue, reason: 'en pause, pas arrêtée');
      bloque = false;
      await conduite.reprendre();
      await laisserTourner();
      expect(journal, contains('musique:reprendre'));
      expect(musique.volume, closeTo(0.05, 1e-9), reason: 'elle a fini de descendre au fond');
      expect(t, greaterThanOrEqualTo(10), reason: 'la descente prend 10 s');
      expect(conduite.niveauMusique, closeTo(0.05, 1e-9));
      // Le fader de la table suit le volume réel.
      expect(conduite.volumeVisible(BusSon.musique).value, closeTo(0.05, 1e-9));
      // Bougé à la main, il donne son volume à la musique, tout de suite.
      await conduite.reglerVolumeManuel(BusSon.musique, 0.6);
      expect(musique.volume, closeTo(0.6, 1e-9));
      expect(conduite.volumeVisible(BusSon.musique).value, closeTo(0.6, 1e-9));
    });

    test('Stop arrête la musique, même pendant qu\'elle se lance', () async {
      final journal = <String>[];
      final lecteurs = <BusSon, LecteurFactice>{};
      final conduite = ConduiteSon(
        pack: PackAudio.pourTests(m, IndexPack(fichiersDuManifeste(m))),
        reglages: ReglagesRegieSon(ValeursRegieSon()),
        muet: () => false,
        fabrique: (b) => lecteurs[b] = LecteurFactice(b, journal),
        attendre: (d) => d >= const Duration(seconds: 15) ? Completer<void>().future : Future<void>.value(),
      );
      conduite.preparer(lieuId: 'eglise', dangerId: 'incendie');
      unawaited(conduite.ouverture());
      await conduite.stopTout();
      await laisserTourner();
      expect(lecteurs[BusSon.musique]!.actif, isFalse);
      expect(conduite.niveauMusique, 0);
    });
  });

  group('les règles', () {
    test('les moments des trois DESTINY se recalculent au prorata de la durée', () {
      const base = [10.0, 22.0, 40.0];
      expect(momentsAuProrata(base, 2700, 2700), [600, 1320, 2400]);
      // Un long form raccourci à 6 min : 1 min 20, 2 min 56, 5 min 20.
      expect(momentsAuProrata(base, 2700, 360), [80, 176, 320]);
      expect(momentsAuProrata(base, 2700, 5400), [1200, 2640, 4800]);
      // Toujours dans l'ordre et dans la durée, même très court.
      final court = momentsAuProrata(base, 2700, 3);
      expect(court, [1, 2, 2]);
    });

    test('les faces du dé des survivants, de 2 à 8 protagonistes', () {
      expect(facesSurvivants(4),
          [const FaceNombre(0), const FaceNombre(1), const FaceNombre(2), const FaceNombre(3), const FaceTous(), const FacePublic()]);
      for (var n = 2; n <= 8; n++) {
        final f = facesSurvivants(n);
        expect(f, hasLength(n + 2));
        expect(f.first, const FaceNombre(0));
        expect(f, contains(FaceNombre(n - 1)));
        expect(f, isNot(contains(FaceNombre(n))));
        expect(f.sublist(n), [const FaceTous(), const FacePublic()]);
      }
    });

    test('les réglages se relisent, et une valeur absente garde son défaut', () {
      final r = ReglagesExercicesDestiny()
        ..maintienS = 15
        ..dureesS[ExerciceDestiny.trio] = 600
        ..momentsDestinyMin = [8, 20, 35];
      final relu = ReglagesExercicesDestiny.depuisJson(jsonDecode(jsonEncode(r.versJson())) as Map<String, dynamic>);
      expect(relu.maintienS, 15);
      expect(relu.descenteS, 10);
      expect(relu.dureeDe(ExerciceDestiny.trio), 600);
      expect(relu.dureeDe(ExerciceDestiny.duo), 120);
      expect(relu.momentsDestinyMin, [8, 20, 35]);
      final vide = ReglagesExercicesDestiny.depuisJson({});
      expect(vide.fondMinute, 0);
      expect(vide.fondLongForm, 0.05);
      expect(vide.dureeDe(ExerciceDestiny.longForm), 2700);
    });

    test('les exercices ne touchent pas à la régie : pas de bruitage, pas de REVEAL, pas d\'ambiance', () {
      final regie = ValeursRegieSon()..maintienDestiny = 15;
      final v = valeursPourExercice(regie, ReglagesExercicesDestiny(), longForm: true);
      expect(v.fluide, isTrue);
      expect(v.maintienOuverture, 20);
      expect(v.maintienDestiny, 20);
      expect(v.descenteFond, 10);
      expect(v.niveauFond, [0.05, 0.05, 0.05, 0.05]);
      expect(v.bruitageAuto, everyElement(isFalse));
      expect(v.bruitageFinMusique, everyElement(isFalse));
      expect(v.revealActe, everyElement(isFalse));
      expect(v.ambianceApresMusique, isFalse);
      expect(regie.maintienDestiny, 15, reason: 'la régie du spectacle est intacte');
      expect(valeursPourExercice(regie, ReglagesExercicesDestiny(), longForm: false).niveauFond, [0, 0, 0, 0]);
    });
  });

  group('l\'exercice minuté', () {
    test('la musique de l\'acte tient 20 s, descend en 10 s jusqu\'à 0 %, puis s\'arrête', () async {
      final x = exercice(ExerciceDestiny.duo, acte: 2);
      await x.seance.lancer();
      await laisserTourner();
      final musique = x.lecteurs[BusSon.musique]!;
      final chemin = resoudreMusique(m, x.seance.pack.index, 'casino', 2).chemin!;
      expect(x.journal.first, 'musique:jouer:$chemin', reason: 'la musique de l\'acte choisi');
      final c = musique.courbe;
      expect(volumeA(c, 0), closeTo(1, 1e-9), reason: 'tout de suite à 100 %');
      expect(volumeA(c, 19.9), closeTo(1, 1e-9));
      expect(volumeA(c, 25), closeTo(0.5, 0.02));
      expect(volumeA(c, 30.01), 0);
      expect(x.journal.last, 'musique:arreter');
    });

    test('à zéro, la cloche sonne une fois', () async {
      final x = exercice(ExerciceDestiny.duo, dureeS: 3);
      await x.seance.lancer();
      await laisserTourner();
      for (var i = 0; i < 3; i++) {
        x.seance.tic();
      }
      await laisserTourner();
      expect(x.seance.fini, isTrue);
      final cloches = x.journal.where((j) => j.startsWith('stinger:jouer:') && j.contains('FIN_EXERCICE')).toList();
      expect(cloches, hasLength(1));
      x.seance.tic();
      await laisserTourner();
      expect(x.journal.where((j) => j.contains('FIN_EXERCICE')), hasLength(1));
    });

    test('pack pas réimporté : la cloche devient le son du REVEAL embarqué, avec un message', () async {
      final sansNouveaux =
          fichiersDuManifeste(m).where((f) => !f.contains('FIN_EXERCICE') && !f.contains('DESTINY2')).toList();
      final x = exercice(ExerciceDestiny.duo, dureeS: 1, fichiers: sansNouveaux);
      await x.seance.lancer();
      x.seance.tic();
      await laisserTourner();
      expect(x.journal, contains('stinger:jouer:${AudioService.revealAsset}'));
      expect(x.seance.packIncomplet, isTrue);
    });

    test('Nouveau lieu : un autre lieu, et ça repart', () async {
      final x = exercice(ExerciceDestiny.trio);
      await x.seance.lancer();
      await x.seance.nouveauLieu();
      await laisserTourner();
      expect(x.seance.lieuId, isNot('casino'));
      expect(x.seance.reste, 120);
    });
  });

  group('le long form', () {
    test('les trois DESTINY : le dé du danger, le DESTINY n°2 du type tiré, le dé des survivants', () async {
      final x = exercice(ExerciceDestiny.longForm, dureeS: 360, protagonistes: 5);
      expect(x.seance.moments, [80, 176, 320]);
      await x.seance.lancer();
      await laisserTourner();
      // Acte 1 : 20 s, puis 10 s jusqu'à 5 %, et elle continue.
      final musique = x.lecteurs[BusSon.musique]!;
      expect(volumeA(musique.courbe, 31), closeTo(0.05, 1e-9));
      expect(x.journal, isNot(contains('musique:arreter')));

      for (var s = 0; s < 80; s++) {
        x.seance.tic();
      }
      await laisserTourner();
      expect(x.seance.destinyFaits, 1);
      expect(x.seance.ecran, EcranDestiny.deDanger);
      final type = x.seance.typeDanger!;
      expect(TypeDanger.deStyle(x.seance.danger!.style), type);
      expect(x.journal, contains('destiny:jouer:${AudioService.stormAsset}'));
      final avant = x.seance.danger!.id;
      x.seance.retirerDanger();
      expect(x.seance.danger!.id, isNot(avant));
      expect(TypeDanger.deStyle(x.seance.danger!.style), type, reason: 'retiré dans le même type');

      x.journal.clear();
      await x.seance.destinyMaintenant();
      await laisserTourner();
      expect(x.seance.ecran, EcranDestiny.eclair);
      final destiny2 = x.journal.firstWhere((j) => j.startsWith('destiny:jouer:'));
      expect(destiny2, contains(type.codeDestiny2), reason: 'pas le tonnerre : le DESTINY n°2 du type');
      final acte3 = resoudreMusique(m, x.seance.pack.index, 'casino', 3).chemin!;
      expect(x.journal, contains('musique:jouer:$acte3'));

      await x.seance.destinyMaintenant();
      await laisserTourner();
      expect(x.seance.ecran, EcranDestiny.deSurvivants);
      expect(facesSurvivants(5), contains(x.seance.survivants));
      expect(x.seance.destinyFaits, 3);
      expect(x.seance.prochainDestiny, isNull);
      // Pas de bruitage de palier ni de REVEAL.
      expect(x.journal.where((j) => j.startsWith('bruitage') || j.startsWith('stinger')), isEmpty);
    });

    test('pack pas réimporté : le DESTINY n°2 joue le son Destiny habituel', () async {
      final sansNouveaux = fichiersDuManifeste(m).where((f) => !f.contains('DESTINY2')).toList();
      final x = exercice(ExerciceDestiny.longForm, dureeS: 360, fichiers: sansNouveaux);
      await x.seance.lancer();
      await x.seance.destinyMaintenant();
      await laisserTourner();
      x.journal.clear();
      await x.seance.destinyMaintenant();
      await laisserTourner();
      expect(x.journal.firstWhere((j) => j.startsWith('destiny:jouer:')), 'destiny:jouer:${AudioService.stormAsset}');
      expect(x.seance.packIncomplet, isTrue);
    });

    test('à la fin : le fondu de fin, pas de cloche', () async {
      final x = exercice(ExerciceDestiny.longForm, dureeS: 360);
      await x.seance.lancer();
      for (var s = 0; s < 360; s++) {
        x.seance.tic();
        if (s % 40 == 0) await laisserTourner();
      }
      await laisserTourner();
      expect(x.seance.fini, isTrue);
      expect(x.seance.destinyFaits, 3);
      expect(x.journal.where((j) => j.contains('FIN_EXERCICE')), isEmpty);
    });
  });
}
