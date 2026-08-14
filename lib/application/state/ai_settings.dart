import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider {
  openai,
  anthropic,
  google;

  String get label => switch (this) {
        AiProvider.openai => 'OpenAI',
        AiProvider.anthropic => 'Anthropic',
        AiProvider.google => 'Google',
      };

  String get defaultModel => models.first;

  /// Large choix de modèles (proche de la liste de GitHub Copilot).
  List<String> get models => switch (this) {
        AiProvider.openai => const [
            'gpt-4o',
            'gpt-4o-mini',
            'gpt-4.1',
            'gpt-4.1-mini',
            'gpt-4.1-nano',
            'gpt-4-turbo',
            'o3',
            'o3-mini',
            'o4-mini',
          ],
        AiProvider.anthropic => const [
            'claude-opus-4-1',
            'claude-opus-4-0',
            'claude-sonnet-4-0',
            'claude-3-7-sonnet-latest',
            'claude-3-5-sonnet-latest',
            'claude-3-5-haiku-latest',
          ],
        AiProvider.google => const [
            'gemini-2.5-pro',
            'gemini-2.5-flash',
            'gemini-2.0-flash',
            'gemini-1.5-pro',
            'gemini-1.5-flash',
          ],
      };
}

/// Style narratif du Maître du jeu.
enum NarrationStyle {
  normal,
  punchy,
  child,
  petit;

  String get label => switch (this) {
        NarrationStyle.normal => 'Normal',
        NarrationStyle.punchy => 'Ultra percutant',
        NarrationStyle.child => 'Enfant (CP-CE2)',
        NarrationStyle.petit => 'Petit (5-6 ans)',
      };
}

/// Réglages de l'IA (fournisseur, modèle, jeton API, style), persistés.
class AiSettings extends ChangeNotifier {
  AiSettings._();

  static const _kProvider = 'ai_provider';
  static const _kModel = 'ai_model';
  static const _kToken = 'ai_token';
  static const _kNarration = 'ai_narration';

  AiProvider _provider = AiProvider.openai;
  String _model = AiProvider.openai.defaultModel;
  String _token = '';
  NarrationStyle _narration = NarrationStyle.punchy;

  AiProvider get provider => _provider;
  String get model => _model;
  String get token => _token;
  NarrationStyle get narration => _narration;
  bool get configured => _token.trim().isNotEmpty;

  static Future<AiSettings> load() async {
    final s = AiSettings._();
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString(_kProvider);
      s._provider = AiProvider.values.firstWhere(
        (e) => e.name == p,
        orElse: () => AiProvider.openai,
      );
      s._model = prefs.getString(_kModel) ?? s._provider.defaultModel;
      s._token = prefs.getString(_kToken) ?? '';
      final n = prefs.getString(_kNarration);
      s._narration = NarrationStyle.values.firstWhere(
        (e) => e.name == n,
        orElse: () => NarrationStyle.punchy,
      );
    } catch (_) {
      // Prefs indisponibles : on garde les valeurs par défaut.
    }
    return s;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kProvider, _provider.name);
      await prefs.setString(_kModel, _model);
      await prefs.setString(_kToken, _token);
      await prefs.setString(_kNarration, _narration.name);
    } catch (_) {
      // Persistance indisponible (ex. web sans plugin) : ignorée.
    }
  }

  Future<void> update({
    AiProvider? provider,
    String? model,
    String? token,
    NarrationStyle? narration,
  }) async {
    if (provider != null && provider != _provider) {
      _provider = provider;
      // Aligne le modèle par défaut si l'utilisateur n'a pas personnalisé.
      _model = provider.defaultModel;
    }
    if (model != null) _model = model;
    if (token != null) _token = token;
    if (narration != null) _narration = narration;
    notifyListeners();
    await _save();
  }
}
