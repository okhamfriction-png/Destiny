import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// La voix de l'appli quand le pack audio n'a pas le fichier d'une annonce :
/// la synthèse vocale de l'appareil (le navigateur sur le web, Android sur
/// la tablette), en français. Une erreur ne bloque jamais le spectacle.
class SyntheseVocale {
  FlutterTts? _tts;
  bool _pret = false;

  /// Les phrases dites, dans l'ordre (pour les tests).
  @visibleForTesting
  final List<String> dites = [];

  /// Remplace la vraie voix (tests).
  @visibleForTesting
  Future<void> Function(String texte)? remplacer;

  Future<void> dire(String texte) async {
    final t = texte.trim();
    if (t.isEmpty) return;
    dites.add(t);
    final r = remplacer;
    if (r != null) return r(t);
    try {
      final tts = _tts ??= FlutterTts();
      if (!_pret) {
        await tts.setLanguage('fr-FR');
        await tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
        _pret = true;
      }
      await tts.stop();
      await tts.speak(t);
    } catch (e) {
      debugPrint('Synthèse vocale indisponible : $e');
    }
  }
}
