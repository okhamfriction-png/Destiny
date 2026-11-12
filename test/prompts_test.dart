import 'dart:convert';

import 'package:destiny/application/prompts/assistant_serie.dart';
import 'package:destiny/application/prompts/prompts.dart';
import 'package:destiny/application/prompts/spectacle.dart';
import 'package:destiny/application/services/assistant_jeu.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
import 'package:destiny/application/state/spectacle_store.dart';
import 'package:destiny/domain/entities/chat_story.dart';
import 'package:destiny/domain/grammaire/distribution.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'serie_test.dart' show FauxLlm;
import 'troupe_test.dart' show CatalogueDeTest;

late GrammaireChargee chargee;
late Grammaire g;
late CatalogueDeTest catalogue;

const _scene = ScenePrompt(
  lieu: 'Aquarium',
  espaces: ['le hall', 'le grand bassin'],
  groupe: 'les soigneurs',
  danger: 'Un incendie',
  paliers: ['p1 fumée', 'p2 portes', 'p3 flammes', 'p4 sortie'],
);

/// Les traces de l'ancienne grammaire, qui ne doivent plus apparaître.
const _anciens = ['Résultat des dés', 'moteur', 'il pointe', 'il s\'installe', 'trois actes', '3 actes', 'Spin-off'];

void main() {
  setUpAll(() async {
    chargee = await chargerGrammaire();
    g = chargee.grammaire;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  void sansAncienneGrammaire(String prompt) {
    for (final a in _anciens) {
      expect(prompt.toLowerCase().contains(a.toLowerCase()), isFalse, reason: 'trace : $a');
    }
  }

  group('La grammaire courte', () {
    test('vient du fichier : paliers, actes, rituel, douze archétypes', () {
      final t = grammaireCourte(g);
      expect(t, contains(g.promesse));
      for (final p in g.paliers) {
        expect(t, contains(p.nom));
      }
      for (final a in g.archetypes) {
        expect(t, contains(a.nom));
      }
      for (final etape in g.rituel.sequence) {
        expect(t, contains(etape));
      }
      expect(t, contains(g.personnage.phraseCle));
      expect(t, isNot(contains('MODE ENFANT')));
      expect(grammaireCourte(g, kids: true), contains(g.modeKids.palier4));
      sansAncienneGrammaire(t);
    });

    test('les prompts sont versionnés', () {
      expect(kVersionPrompts, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });
  });

  group('Le Maître du destin', () {
    final heros = [
      const PersonnagePrompt(nom: 'Lila', archetypeId: 'leader', animalId: 'lion', blessure: 'Son père est parti.'),
    ];

    test('le lieu, le danger et ses paliers, les héros, les règles', () {
      final p = promptMaitreDuDestin(g: g, scene: _scene, heros: heros);
      for (final x in ['Aquarium', 'le grand bassin', 'Un incendie', 'p1 fumée', 'p4 sortie', 'Lila', 'Son père est parti.']) {
        expect(p, contains(x));
      }
      expect(p, contains('[DESTINY]'));
      expect(p, contains('pièce du destin'));
      expect(p, contains('Ne nomme jamais un archétype'));
      expect(p, contains('Pas de traître'));
      expect(p, contains('Chapitre 4'));
      // Le danger ne passe plus par l'alarmiste.
      expect(p, isNot(contains('L\'alarmiste du groupe')));
      expect(p, isNot(contains('dans la bouche de l\'alarmiste')));
      sansAncienneGrammaire(p);
    });

    test('adulte ou enfant', () {
      final adulte = promptMaitreDuDestin(g: g, scene: _scene, heros: heros);
      final enfant = promptMaitreDuDestin(g: g, scene: _scene, heros: heros, kids: true);
      expect(adulte, isNot(contains('frissons doux')));
      expect(enfant, contains('frissons doux, jamais d\'effroi'));
      expect(enfant, contains('Personne ne meurt'));
    });

    test('les styles et leur rappel', () {
      expect(styleNarration(StyleNarration.petit), contains('6 mots'));
      expect(styleNarration(StyleNarration.normal, duo: true), contains('DEUX HÉROS'));
      expect(rappelStyle(StyleNarration.normal), isEmpty);
    });
  });

  group('Les autres rôles', () {
    test('la mise en place complète ce qui manque, en JSON', () {
      final p = promptMiseEnPlace(g: g, connu: const ScenePrompt(lieu: 'Aquarium'));
      expect(p, contains('Aquarium'));
      expect(p, contains('"mystere"'));
      expect(p, isNot(contains('"objets"')));
      expect(p, isNot(contains('trois objets')));
      sansAncienneGrammaire(p);
    });

    test('le personnage : un besoin n\'est jamais un objet', () {
      final p = promptPersonnage(g: g, archetypeId: 'aidant', animalId: 'chien', scene: _scene, besoinPropose: 'de l\'argent');
      expect(p, contains(g.personnage.piege));
      expect(p, contains('refuse-le'));
      expect(p, contains('de l\'argent'));
      expect(p, contains('UNE phrase'));
    });

    test('la voix de l\'alarmiste monte avec le palier', () {
      expect(promptVoixAlarmiste(g: g, scene: _scene, palier: PalierId.signale), contains('inquiétude'));
      expect(promptVoixAlarmiste(g: g, scene: _scene, palier: PalierId.envahit), contains('panique'));
      expect(promptVoixAlarmiste(g: g, scene: _scene, palier: PalierId.envahit), contains('p3 flammes'));
    });

    test('le coach de débrief reste positif', () {
      final p = promptCoachDebrief(g: g);
      expect(p, contains(g.personnage.phraseCle));
      expect(p, contains('positif'));
      expect(p, contains('"ce_qui_a_marche"'));
    });

    test('le coach d\'échauffement reprend les trois questions', () {
      final p = promptCoachEchauffement(g: g, archetypeId: 'cynique', animalId: 'singe');
      for (final q in g.personnage.echauffement.questions) {
        expect(p, contains(q));
      }
    });

    test('l\'assistant de la Série : des frissons doux en kids', () {
      expect(consigneResume(kids: true), contains('frissons doux'));
      expect(consigneResume(kids: false, categoriesRegistre: ['objet']), contains('"registre"'));
      expect(consignePresages(kids: false), contains('quatre présages'));
    });
  });

  group('Le Spectacle avec l\'IA', () {
    final personnages = [
      for (final (id, animal) in [('alarmiste', 'rat'), ('leader', 'lion'), ('cynique', 'singe'), ('solitaire', 'chat')])
        PersonnagePrompt(nom: id, archetypeId: id, animalId: animal, joueur: false),
    ];

    test('quatre actes, Destiny lancé par le joueur, un débrief sans note', () {
      final p = promptSpectacle(g: g, scene: _scene, personnages: personnages, mode: ModeSpectacle.classique, cible: 20);
      expect(p, contains('[DESTINY]'));
      expect(p, contains('Acte 4'));
      expect(p, contains('"debrief"'));
      expect(p, contains('Pas de score'));
      expect(p, isNot(contains('scoreGlobal')));
      expect(p, contains('L\'alarmiste (J1) est un personnage comme les autres'));
      expect(p, contains('Le danger vient de la régie'));
      expect(p, isNot(contains('dans la bouche de l\'alarmiste')));
      // Les règles du sparring.
      for (final x in ['Tu ne coupes jamais un acte', '15 à 20 échanges', 'Accepte les perches',
          'Ne narre pas le danger', 'trois secondes figé', 'fautes d\'impro', 'Les actions passent par le dialogue']) {
        expect(p, contains(x), reason: x);
      }
      expect(p, contains('TENTÉS DE'));
      expect(p, contains('4 répliques'));
      expect(p, contains('Format Destiny © 2026 Marouane.'));
      sansAncienneGrammaire(p);
    });

    test('le mode libre et le mode enfant', () {
      final p = promptSpectacle(g: g, scene: _scene, personnages: personnages, mode: ModeSpectacle.libre, cible: 10, kids: true);
      expect(p, contains('✓ juste'));
      expect(p, contains('CROW'));
      expect(p, contains('frissons doux'));
    });
  });

  group('L\'histoire avec l\'IA', () {
    test('quatre chapitres égaux', () {
      expect([for (var a = 1; a <= 8; a++) ChatController.chapitreDe(a, 8)], [1, 1, 2, 2, 3, 3, 4, 4]);
      expect(ChatController.chapitreDe(30, 30), 4);
      expect(ChatController.chapitreDe(1, 0), 1);
    });

    test('une partie : le prompt est gardé, Destiny tombe entre les chapitres, la pièce tranche', () async {
      SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
      final ia = await AiSettings.load();
      final llm = FauxLlm('DONC tout va bien.\nCHOIX:\n- [BRAVE] Foncer\n- [SMART] Observer');
      final c = ChatController(
        chatStore: InMemoryChatStore(),
        llm: llm,
        aiSettings: ia,
        catalogue: catalogue,
        grammaire: chargee,
      );
      await c.newStory(
        players: const [ChatPlayer(name: 'Lila', archetypeId: 'leader', animalId: 'lion', archetype: 'Leader')],
        universe: 'Contemporain',
        tone: 'Drame',
        directAddress: true,
        maxResponses: 8,
        childMode: true,
        malus: true,
      );
      expect(c.error, isNull);
      final s = c.active!;
      expect(s.versionPrompts, kVersionPrompts);
      expect(s.systeme, contains('Lila'));
      expect(s.systeme, contains('frissons doux'));
      expect(s.paliers, hasLength(4));
      expect(c.choices, hasLength(2));

      await c.sendChoice(c.choices.first);
      await c.sendChoice(c.choices.first); // action 2 : encore le chapitre 1
      expect(c.dangerPulse, 0);
      await c.sendChoice(c.choices.first); // action 3 : chapitre 2, Destiny
      expect(c.dangerPulse, 1);
      final dernier = s.messages.where((m) => m.role == 'user').last.content;
      expect(dernier, contains('[DESTINY'));
      expect(dernier, contains('Chapitre 2'));
      expect(dernier, contains('La pièce du destin a tranché'));
      expect(c.malusPending, isTrue);
      for (final e in llm.envois) {
        expect(RegExp(r'(?<![\p{L}])dés(?![\p{L}])', unicode: true).hasMatch(e), isFalse);
      }
    });

    test('une histoire de l\'ancienne grammaire se relit, mais ne se reprend pas', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ChatController(
        chatStore: InMemoryChatStore(),
        llm: FauxLlm(''),
        aiSettings: await AiSettings.load(),
        catalogue: catalogue,
        grammaire: chargee,
      );
      c.openStory(ChatStory.fromJson(jsonDecode('{"id": "a", "title": "t", "createdAt": 0, "messages": '
          '[{"role": "user", "content": "x"}, {"role": "assistant", "content": "DONC.\\nCHOIX:\\n- [BRAVE] a\\n- [SMART] b"}]}')
          as Map<String, dynamic>));
      expect(c.lectureSeule, isTrue);
      expect(c.choices, isEmpty);
    });
  });

  group('Le spectacle avec l\'IA, le contrôleur', () {
    test('quatre personnages en distribution équilibrée, Destiny par le bouton, ancienne partie ignorée', () async {
      SharedPreferences.setMockInitialValues({
        'ai_token': 'jeton',
        'spectacle_session': jsonEncode({'mode': 'classique', 'messages': []}),
      });
      final ia = await AiSettings.load();
      final llm = FauxLlm(jsonEncode({
        'phase': 'jeu',
        'acte': 1,
        'scene': 1,
        'palier': 1,
        'compteur': {'posees': 1, 'cible': 10},
        'didascalie': '',
        'replique': {'personnage': 'Raoul', 'archetype': 'Rat', 'texte': 'Vous sentez ?'},
        'propositions': [],
      }));
      final c = SpectacleController(
        catalogue: catalogue,
        grammaire: chargee,
        llm: llm,
        aiSettings: ia,
        store: SpectacleStore(),
      );
      await c.loadSavedSession();
      expect(c.sessionIgnoree, isTrue);
      expect(c.canResume, isFalse);

      await c.drawDecor();
      final d = c.draw!;
      expect(d.archetypes, hasLength(4));
      expect(validerDistribution(g, [for (final p in d.archetypes) p.archetypeId]).valide, isTrue);
      expect(d.paliers, hasLength(4));

      await c.start();
      expect(c.peutLancerDestiny, isTrue);
      await c.lancerDestiny();
      expect(llm.envois.last, contains('[DESTINY]'));
      expect(llm.envois.first, contains(kVersionPrompts));
    });
  });

  group('L\'IA au service du jeu', () {
    Future<(AssistantJeu, FauxLlm)> assistant(String reponse) async {
      SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
      final llm = FauxLlm(reponse);
      return (AssistantJeu(llm: llm, reglages: await AiSettings.load(), grammaire: g), llm);
    }

    test('la mise en place : le mystère et sa réponse (d\'anciens objets sont ignorés)', () async {
      final (a, llm) = await assistant('Voici : {"objets": ["une clé", "une lampe", "une corde"], "mystere": "Qui ?", "reponse": "Lui."}');
      final r = await a.miseEnPlace(_scene);
      expect(r.mystere, 'Qui ?');
      expect(r.reponse, 'Lui.');
      expect(llm.envois.single, contains('Aquarium'));
    });

    test('l\'échauffement et le coach de débrief', () async {
      final (a, _) = await assistant('{"questions": [{"question": "Q1", "idees": ["a", "b"]}], '
          '"personnages": [{"nom": "Personnage 1", "veut": "sortir", "besoin": "faire confiance"}], '
          '"ce_qui_a_marche": ["le silence"]}');
      final idees = await a.echauffement(archetypeId: 'cynique', animalId: 'singe');
      expect(idees.single.idees, ['a', 'b']);
      final d = await a.debrief(
        personnages: const [PersonnagePrompt(nom: 'Personnage 1', archetypeId: 'leader')],
        notes: 'Un silence.',
      );
      expect(d.personnages.single.besoin, 'faire confiance');
      expect(d.ceQuiAMarche, ['le silence']);
    });

    test('la voix de l\'alarmiste', () async {
      final (a, llm) = await assistant('  « Vous sentez cette odeur ? »  ');
      expect(await a.voixAlarmiste(scene: _scene, palier: PalierId.enferme), '« Vous sentez cette odeur ? »');
      expect(llm.envois.single, contains('p2 portes'));
    });

    test('une réponse illisible ne casse rien', () async {
      final (a, _) = await assistant('pas de JSON');
      expect((await a.miseEnPlace(_scene)).mystere, isEmpty);
      expect(await a.echauffement(archetypeId: 'leader'), isEmpty);
    });
  });
}
