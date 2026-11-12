import '../services/audio_service.dart';
import '../state/music_controller.dart';
import '../state/reglages_destiny.dart';
import 'conduite_son.dart';
import 'pack_audio.dart';
import 'reglages_regie_son.dart';

/// La régie son du spectacle d'un seul tenant : le pack importé, ses
/// réglages et la conduite qui les joue. Créée une fois au démarrage.
class RegieSon {
  RegieSon({required this.pack, required this.reglages, required this.conduite});

  final PackAudio pack;
  final ReglagesRegieSon reglages;
  final ConduiteSon conduite;

  /// Charge le pack et les réglages, puis branche la conduite sur le son de
  /// l'appli : le bouton qui coupe le son la coupe aussi, et une musique de la
  /// conduite arrête celle du lecteur de la bibliothèque.
  static Future<RegieSon> creer(
      {required AudioService audio, required MusicController musique, ReglagesDestiny? reglagesDestiny}) async {
    final pack = PackAudio();
    final reglages = ReglagesRegieSon();
    await Future.wait([pack.charger(), reglages.charger()]);
    final conduite = ConduiteSon(
      pack: pack,
      reglages: reglages,
      muet: () => audio.muted,
      muetNotifier: audio.muetNotifier,
      avantMusique: () {
        if (musique.playing) musique.stop();
      },
      // Sans pack : la musique de chaque acte choisie dans les réglages.
      choixSansPack: reglagesDestiny == null ? null : (acte) => reglagesDestiny.musiqueActe(acte),
    );
    return RegieSon(pack: pack, reglages: reglages, conduite: conduite);
  }
}

/// Ce dont la table de régie et le chrono ont besoin pour faire du son, au
/// théâtre comme au jeu de rôle.
abstract interface class SourcesSon {
  ReglagesDestiny get reglages;
  AudioService get audio;
  MusicController get musique;

  /// La régie son du spectacle (facultative).
  RegieSon? get regieSon;
}
