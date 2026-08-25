import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Résultat d'une tentative de démarrage du micro : ok, ou une raison courte.
class Echec {
  const Echec(this.message);
  const Echec.aucun() : message = '';
  final String message;
  bool get ok => message.isEmpty;
}

String _court(Object e) {
  final s = e.toString();
  return s.length > 120 ? '${s.substring(0, 117)}…' : s;
}

/// La garde qui coûte le plus cher à oublier : démarrer le micro ne doit
/// JAMAIS empêcher un épisode de commencer. On borne l'essai par un délai, on
/// attrape ses exceptions, et l'épisode part dans tous les cas.
Future<Echec> demarrerLeMicro(
  Future<bool> Function() essai, {
  Duration patience = const Duration(seconds: 8),
}) async {
  try {
    // `then` refait un vrai Future<bool> : un essai qui ne fait que lever rend
    // un Future<Never>, et `timeout` refuse alors sa porte de sortie.
    final lancement = essai().then<bool>((ok) => ok);
    final ok = await lancement.timeout(patience, onTimeout: () => false);
    return ok ? const Echec.aucun() : const Echec('micro refusé ou absent');
  } catch (e) {
    return Echec(_court(e));
  }
}

/// Transcription de la séance : le moteur du système rend du texte, aucun son
/// n'est conservé. Le texte reste sur l'appareil.
class TranscriptionService {
  final SpeechToText _speech = SpeechToText();
  bool _initialise = false;
  bool _ecoute = false;
  bool get ecoute => _ecoute;

  final StringBuffer _texte = StringBuffer();
  String get texte => _texte.toString();

  DateTime _deadline = DateTime.now();
  void Function(String)? _onPhrase;
  void Function()? _onChangement;

  /// Vrai si la plateforme a un moteur de reconnaissance disponible.
  Future<bool> disponible() async {
    try {
      _initialise = await _speech.initialize(
          onError: (_) {}, onStatus: (_) {}, debugLogging: false);
      return _initialise && _speech.isAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Démarre l'écoute (locale fr, résultats finaux, l'erreur ne coupe pas).
  /// Rend un [Echec] ; NE LÈVE JAMAIS. Le micro s'arrête tout seul au bout de
  /// [dureeMax] : un micro qu'on oublie d'éteindre écoute la soirée entière.
  Future<Echec> demarrer({
    required void Function(String) onPhrase,
    void Function()? onChangement,
    Duration dureeMax = const Duration(minutes: 12),
  }) async {
    _onPhrase = onPhrase;
    _onChangement = onChangement;
    _deadline = DateTime.now().add(dureeMax);
    final echec = await demarrerLeMicro(_initEtEcoute);
    _ecoute = echec.ok;
    _onChangement?.call();
    return echec;
  }

  Future<bool> _initEtEcoute() async {
    if (!_initialise) {
      _initialise = await _speech.initialize(
          onError: (_) {}, onStatus: _onStatus, debugLogging: false);
    }
    if (!_initialise) return false;
    await _ecouter();
    return true;
  }

  Future<void> _ecouter() async {
    final reste = _deadline.difference(DateTime.now());
    if (reste <= Duration.zero) {
      await arreter();
      return;
    }
    try {
      await _speech.listen(
        localeId: 'fr_FR',
        onResult: _onResult,
        listenFor: reste,
        listenOptions: SpeechListenOptions(
          partialResults: false, // résultats finaux seulement
          listenMode: ListenMode.dictation,
          cancelOnError: false, // l'erreur ne coupe pas l'écoute
        ),
      );
    } catch (_) {
      // Une erreur d'écoute ne doit pas casser la séance.
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!r.finalResult) return;
    final p = r.recognizedWords.trim();
    if (p.isEmpty) return;
    if (_texte.isNotEmpty) _texte.write(' ');
    _texte.write(p);
    _onPhrase?.call(p);
  }

  // Le moteur s'arrête tout seul après un silence : on relance tant qu'on est
  // dans la fenêtre d'écoute, pour couvrir tout l'épisode.
  void _onStatus(String status) {
    if (_ecoute &&
        (status == 'done' || status == 'notListening') &&
        DateTime.now().isBefore(_deadline)) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (_ecoute) _ecouter();
      });
    }
  }

  /// Arrête l'écoute. Attrape ses exceptions : appelé depuis dispose, une
  /// exception ici emporterait la fermeture de l'écran.
  Future<void> arreter() async {
    _ecoute = false;
    _onChangement?.call();
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
