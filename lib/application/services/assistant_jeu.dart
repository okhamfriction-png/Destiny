import 'dart:convert';

import '../../domain/entities/chat_message.dart';
import '../../domain/grammaire/modeles.dart';
import '../prompts/prompts.dart';
import '../state/ai_settings.dart';
import 'llm_service.dart';

/// Ce que l'IA propose pour la mise en place.
class MiseEnPlaceIA {
  const MiseEnPlaceIA({this.mystere = '', this.reponse = ''});
  final String mystere;
  final String reponse;
}

/// Des idées pour une question de l'échauffement.
class IdeesQuestion {
  const IdeesQuestion({required this.question, this.idees = const []});
  final String question;
  final List<String> idees;
}

/// Ce que le coach de débrief voit d'un personnage.
class LectureCoach {
  const LectureCoach({
    required this.nom,
    this.veut = '',
    this.besoin = '',
    this.seme = '',
    this.nomme = '',
    this.choix = '',
  });
  final String nom;
  final String veut;
  final String besoin;
  final String seme;
  final String nomme;
  final String choix;
}

/// Le débrief du coach.
class DebriefIA {
  const DebriefIA({this.personnages = const [], this.ceQuiAMarche = const []});
  final List<LectureCoach> personnages;
  final List<String> ceQuiAMarche;
}

/// Les rôles de l'IA au service du jeu entre humains (mise en place, coach
/// d'échauffement, coach de débrief, voix de l'alarmiste). Facultatif : sans
/// clé d'IA, l'appli fonctionne sans.
class AssistantJeu {
  AssistantJeu({required this.llm, required this.reglages, required this.grammaire});

  final LlmService llm;
  final AiSettings reglages;
  final Grammaire grammaire;

  bool get disponible => reglages.configured;

  static Map<String, dynamic> _objet(String reponse) {
    final debut = reponse.indexOf('{');
    final fin = reponse.lastIndexOf('}');
    if (debut < 0 || fin <= debut) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(reponse.substring(debut, fin + 1)) as Map);
    } catch (_) {
      return const {};
    }
  }

  static List<String> _ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'.trim()];
  static String _s(Object? v) => (v ?? '').toString().trim();

  Future<String> _demander(String systeme, String contenu) => llm.complete(
        settings: reglages,
        system: systeme,
        messages: [ChatMessage(role: 'user', content: contenu)],
      );

  /// Le mystère et sa réponse, pour un lieu, un groupe et un danger.
  Future<MiseEnPlaceIA> miseEnPlace(ScenePrompt connu, {bool kids = false}) async {
    final j = _objet(await _demander(promptMiseEnPlace(g: grammaire, connu: connu, kids: kids), 'Propose.'));
    return MiseEnPlaceIA(mystere: _s(j['mystere']), reponse: _s(j['reponse']));
  }

  /// Des idées pour les trois questions de l'échauffement.
  Future<List<IdeesQuestion>> echauffement({required String archetypeId, String animalId = '', bool kids = false}) async {
    final j = _objet(await _demander(
      promptCoachEchauffement(g: grammaire, archetypeId: archetypeId, animalId: animalId, kids: kids),
      'Des idées, s\'il te plaît.',
    ));
    return [
      for (final q in (j['questions'] as List? ?? const []))
        if (q is Map) IdeesQuestion(question: _s(q['question']), idees: _ls(q['idees'])),
    ];
  }

  /// Le coach de débrief, à partir des personnages et des notes.
  Future<DebriefIA> debrief({required List<PersonnagePrompt> personnages, required String notes, bool kids = false}) async {
    final contenu = StringBuffer('Les personnages :\n');
    for (final p in personnages) {
      contenu.writeln('- ${p.decrire(grammaire)}');
    }
    contenu
      ..writeln('\nLes notes de la partie :')
      ..write(notes.trim().isEmpty ? '(aucune note)' : notes.trim());
    final j = _objet(await _demander(promptCoachDebrief(g: grammaire, kids: kids), contenu.toString()));
    return DebriefIA(
      personnages: [
        for (final p in (j['personnages'] as List? ?? const []))
          if (p is Map)
            LectureCoach(
              nom: _s(p['nom']),
              veut: _s(p['veut']),
              besoin: _s(p['besoin']),
              seme: _s(p['seme']),
              nomme: _s(p['nomme']),
              choix: _s(p['choix']),
            ),
      ],
      ceQuiAMarche: _ls(j['ce_qui_a_marche']),
    );
  }

  /// Une ou deux répliques pour l'alarmiste, au palier qui arrive.
  Future<String> voixAlarmiste({
    required ScenePrompt scene,
    required PalierId palier,
    String animalId = '',
    bool kids = false,
  }) async =>
      (await _demander(
        promptVoixAlarmiste(g: grammaire, scene: scene, palier: palier, animalId: animalId, kids: kids),
        'La nouvelle, s\'il te plaît.',
      ))
          .trim();
}
