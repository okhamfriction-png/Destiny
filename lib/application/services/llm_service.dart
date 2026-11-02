import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/chat_message.dart';
import '../state/ai_settings.dart';

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client minimal pour OpenAI (chat completions) et Anthropic (messages).
class LlmService {
  Future<String> complete({
    required AiSettings settings,
    required String system,
    required List<ChatMessage> messages,
  }) async {
    if (!settings.configured) {
      throw LlmException('Aucun jeton API configuré (Paramètres → IA).');
    }
    switch (settings.provider) {
      case AiProvider.openai:
        return _openai(settings, system, messages);
      case AiProvider.anthropic:
        return _anthropic(settings, system, messages);
      case AiProvider.google:
        return _google(settings, system, messages);
    }
  }

  Future<String> _openai(
      AiSettings s, String system, List<ChatMessage> messages) async {
    // Pas de température imposée : les modèles de raisonnement la refusent.
    final body = jsonEncode({
      'model': s.model,
      'messages': [
        {'role': 'system', 'content': system},
        ...messages.map((m) => {'role': m.role, 'content': m.content}),
      ],
    });
    final r = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${s.token}',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 90));
    if (r.statusCode != 200) throw LlmException(_err(r.body, r.statusCode));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final texte = (d['choices']?[0]?['message']?['content'] as String?)?.trim() ?? '';
    if (texte.isEmpty) throw LlmException('Réponse vide de l\'IA.');
    return texte;
  }

  /// Les modèles Claude de la génération 5 et les Opus/Sonnet 4.6 à 4.8
  /// acceptent le réglage d'effort ; le jeu demande des réponses vives.
  static bool _accepteEffort(String modele) =>
      RegExp(r'^claude-(opus|sonnet|haiku|fable)-5').hasMatch(modele) ||
      RegExp(r'^claude-(opus-4-[678]|sonnet-4-6)').hasMatch(modele);

  /// Les modèles qui ont un repli côté serveur quand ils déclinent une
  /// demande (Claude Haiku 5.5 n'en a pas).
  static bool _avecRepli(String modele) =>
      RegExp(r'^claude-(fable-5-1|opus-5-5|opus-5|sonnet-5-5)$').hasMatch(modele);

  Future<String> _anthropic(
      AiSettings s, String system, List<ChatMessage> messages) async {
    final repli = _avecRepli(s.model);
    final body = jsonEncode({
      'model': s.model,
      'max_tokens': 16000,
      'system': system,
      if (_accepteEffort(s.model)) 'output_config': {'effort': 'low'},
      if (repli) 'fallbacks': 'default',
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
    });
    final r = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': s.token,
            'anthropic-version': '2023-06-01',
            if (repli) 'anthropic-beta': 'server-side-fallback-2026-07-01',
            'anthropic-dangerous-direct-browser-access': 'true',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) throw LlmException(_err(r.body, r.statusCode));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    // Un refus arrive en HTTP 200 : on le regarde avant de lire le contenu.
    if (d['stop_reason'] == 'refusal') {
      throw LlmException(
          'L\'IA a décliné cette demande. Reformule-la, ou choisis un autre modèle dans les Réglages.');
    }
    final content = d['content'] as List<dynamic>? ?? const [];
    final text = content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n')
        .trim();
    if (text.isEmpty) throw LlmException('Réponse vide de l\'IA.');
    return text;
  }

  Future<String> _google(
      AiSettings s, String system, List<ChatMessage> messages) async {
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': messages
          .map((m) => {
                'role': m.role == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': m.content}
                ],
              })
          .toList(),
    });
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${s.model}:generateContent');
    final r = await http
        .post(
          uri,
          headers: {
            'x-goog-api-key': s.token,
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 90));
    if (r.statusCode != 200) throw LlmException(_err(r.body, r.statusCode));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final candidates = d['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw LlmException('Réponse vide de l\'IA.');
    }
    final parts = (candidates.first['content']?['parts'] as List<dynamic>?) ??
        const [];
    return parts
        .map((p) => p['text'] as String? ?? '')
        .join('\n')
        .trim();
  }

  String _err(String body, int code) {
    try {
      final d = jsonDecode(body) as Map<String, dynamic>;
      final m = (d['error'] as Map<String, dynamic>?)?['message'];
      if (m != null) return 'Erreur IA ($code) : $m';
    } catch (_) {}
    return 'Erreur IA ($code).';
  }
}
