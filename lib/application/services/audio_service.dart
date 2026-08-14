import 'package:audioplayers/audioplayers.dart';

/// Lecture des effets sonores de l'app. Un lecteur dédié par canal pour que
/// les sons courts (pièce, dé) puissent se chevaucher sans se couper.
class AudioService {
  AudioService() {
    for (final p in [
      _storm,
      _story,
      _coin,
      _dice,
      _crack,
      _shine,
      _thunder,
      _beast,
    ]) {
      p.setReleaseMode(ReleaseMode.stop);
    }
    // Mode basse latence pour les effets courts déclenchés au tap.
    _coin.setPlayerMode(PlayerMode.lowLatency);
    _dice.setPlayerMode(PlayerMode.lowLatency);
    _crack.setPlayerMode(PlayerMode.lowLatency);
    _shine.setPlayerMode(PlayerMode.lowLatency);
  }

  // Chemins relatifs au préfixe 'assets/' utilisé par audioplayers.
  static const String stormAsset = 'audio/DestinyStorm.wav';
  static const String storyAsset = 'audio/story_epic.wav';
  static const String coinAsset = 'audio/coin.wav';
  static const String diceAsset = 'audio/dice.wav';
  static const String crackAsset = 'audio/crack.wav';
  static const String shineAsset = 'audio/shine.wav';
  static const String thunderAsset = 'audio/thunder.wav';
  static const String revealAsset = 'audio/reveal.wav';

  final AudioPlayer _storm = AudioPlayer();
  final AudioPlayer _story = AudioPlayer();
  final AudioPlayer _coin = AudioPlayer();
  final AudioPlayer _dice = AudioPlayer();
  final AudioPlayer _crack = AudioPlayer();
  final AudioPlayer _shine = AudioPlayer();
  final AudioPlayer _thunder = AudioPlayer();
  final AudioPlayer _beast = AudioPlayer();

  bool _muted = false; // son activé par défaut
  bool get muted => _muted;

  /// Active/désactive le son. En coupant, on stoppe ce qui joue.
  void setMuted(bool value) {
    _muted = value;
    if (value) {
      for (final p in [
        _storm,
        _story,
        _coin,
        _dice,
        _crack,
        _shine,
        _thunder,
        _beast,
      ]) {
        p.stop();
      }
    }
  }

  Future<void> _restart(AudioPlayer player, String asset) async {
    if (_muted) return;
    await player.stop();
    await player.play(AssetSource(asset));
  }

  /// Son de tempête (minuteur).
  Future<void> playStorm() => _restart(_storm, stormAsset);

  /// Son épique à la création d'une histoire.
  Future<void> playStory() => _restart(_story, storyAsset);

  /// Tintement de pièce.
  Future<void> playCoin() => _restart(_coin, coinAsset);

  /// Cliquetis de dé.
  Future<void> playDice() => _restart(_dice, diceAsset);

  /// Bris de verre (échec).
  Future<void> playCrack() => _restart(_crack, crackAsset);

  /// Éclat lumineux (réussite).
  Future<void> playShine() => _restart(_shine, shineAsset);

  /// Coup de foudre (montée du danger).
  Future<void> playThunder() => _restart(_thunder, thunderAsset);

  /// Révélation d'archétype : tambour + coup de foudre.
  Future<void> playReveal() => _restart(_beast, revealAsset);

  Future<void> stopStorm() => _storm.stop();

  void dispose() {
    for (final p in [
      _storm,
      _story,
      _coin,
      _dice,
      _crack,
      _shine,
      _thunder,
      _beast,
    ]) {
      p.dispose();
    }
  }
}
