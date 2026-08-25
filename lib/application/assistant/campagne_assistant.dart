import 'dart:convert';

import '../../domain/entities/chat_message.dart';
import '../services/llm_service.dart';
import '../state/ai_settings.dart';

// Ce module est la SEULE porte par laquelle des paroles quittent l'appareil.
// Il ne connaît que : l'univers, le ton, le contexte écrit par le parent, et la
// transcription qu'il a vue et validée. Jamais un prénom d'enfant, jamais une
// notion de suivi de l'application. Un test scanne ce dossier pour le vérifier.

/// Remplace chaque prénom par son rôle : mot entier uniquement, insensible à la
/// casse, en Unicode. « Naël » dans « Naelle » ne désigne pas l'enfant et n'est
/// pas touché.
String sansPrenoms(String transcription, Map<String, String> rolesParPrenom) {
  var texte = transcription;
  for (final entry in rolesParPrenom.entries) {
    final prenom = entry.key.trim();
    if (prenom.isEmpty) continue;
    final motif = RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(prenom)}(?![\\p{L}\\p{N}])',
      unicode: true,
      caseSensitive: false,
    );
    texte = texte.replaceAll(motif, entry.value);
  }
  return texte;
}

/// Le résumé et l'accroche tirés de la réponse du modèle.
class MemoireEpisode {
  const MemoireEpisode({this.resume = '', this.suite = ''});
  final String resume;
  final String suite;

  /// Lecture tolérante : on cherche le premier `{` et le dernier `}`. Un modèle
  /// qui répond en texte brut ne doit pas faire perdre le résumé — on garde
  /// alors tout comme résumé, l'accroche reste vide.
  factory MemoireEpisode.depuis(String reponse) {
    final debut = reponse.indexOf('{');
    final fin = reponse.lastIndexOf('}');
    if (debut >= 0 && fin > debut) {
      try {
        final map =
            jsonDecode(reponse.substring(debut, fin + 1)) as Map<String, dynamic>;
        return MemoireEpisode(
          resume: (map['resume'] ?? '').toString().trim(),
          suite: (map['suite'] ?? '').toString().trim(),
        );
      } catch (_) {}
    }
    return MemoireEpisode(resume: reponse.trim());
  }
}

const String _consigneEnfant =
    'Tu suis une histoire de théâtre improvisée entre un parent et ses enfants, '
    'en français. Aucune violence, aucune peur, aucune mort, aucun personnage '
    'humilié. Tu ne commentes ni le jeu, ni les enfants, ni leur comportement : '
    'tu ne parles que des personnages. Aucun jugement, aucune note, aucun '
    'conseil. Tu réponds uniquement par un objet JSON, sans texte autour, de la '
    'forme {"resume": "...", "suite": "..."}. '
    '"resume" : au plus six phrases courtes, au passé, à la troisième personne, '
    'sur ce qui est arrivé aux personnages. '
    '"suite" : deux phrases au présent qui disent où l\'on reprend et ce que le '
    'méchant a fait depuis — de quoi commencer à jouer sans relire.';

const String _consigneAdulte =
    'Tu suis une histoire de théâtre improvisée entre adultes, en français. '
    'Reste respectueux, sans complaisance gratuite. Tu ne commentes ni le jeu '
    'ni les joueurs : tu ne parles que des personnages. Aucun jugement, aucune '
    'note, aucun conseil. Tu réponds uniquement par un objet JSON, sans texte '
    'autour, de la forme {"resume": "...", "suite": "..."}. '
    '"resume" : au plus six phrases courtes, au passé, à la troisième personne, '
    'sur ce qui est arrivé aux personnages. '
    '"suite" : deux phrases au présent qui disent où l\'on reprend et ce que le '
    'méchant a fait depuis — de quoi commencer à jouer sans relire.';

/// Demande à l'IA un résumé et une accroche à partir du seul contexte validé.
class CampagneAssistant {
  const CampagneAssistant(this._llm);
  final LlmService _llm;

  Future<MemoireEpisode> resumer({
    required AiSettings settings,
    required String univers,
    required String ton,
    required String contexte,
    required String transcription,
    String public = 'enfant',
    String lore = '',
  }) async {
    final contenu = StringBuffer()
      ..writeln('Univers : $univers')
      ..writeln('Ton : $ton');
    if (lore.trim().isNotEmpty) {
      contenu.writeln(
          'Lore/ambiance à évoquer (personnages et décor peuvent s\'en inspirer) : ${lore.trim()}');
    }
    if (contexte.trim().isNotEmpty) {
      contenu.writeln('Contexte : ${contexte.trim()}');
    }
    contenu
      ..writeln('Transcription :')
      ..write(transcription.trim());
    final reponse = await _llm.complete(
      settings: settings,
      system: public == 'adulte' ? _consigneAdulte : _consigneEnfant,
      messages: [ChatMessage(role: 'user', content: contenu.toString())],
    );
    return MemoireEpisode.depuis(reponse);
  }
}
