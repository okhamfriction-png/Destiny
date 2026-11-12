import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'on fait jouer : un son embarqué dans l'appli, ou un fichier du pack.
sealed class SourceSon {
  const SourceSon(this.chemin, {this.titre});

  final String chemin;

  /// Le nom affiché sur la table de régie.
  final String? titre;

  /// Identifiant stable (pour allumer le pad qui joue).
  String get cle;
}

/// Un son embarqué, chemin relatif au dossier `assets/` (« music/x.m4a »).
class SourceAsset extends SourceSon {
  const SourceAsset(super.chemin, {super.titre});

  @override
  String get cle => 'asset:$chemin';
}

/// Un fichier du pack importé, chemin relatif à sa racine.
class SourcePack extends SourceSon {
  const SourcePack(super.chemin, {super.titre});

  @override
  String get cle => 'pack:$chemin';
}

/// Un lecteur : une piste à la fois, un volume, une fin qu'on peut attendre.
/// Aucun lecteur n'en coupe un autre.
abstract class LecteurSon extends ChangeNotifier {
  /// La source en cours (null : rien ne joue).
  SourceSon? get enCours;
  bool get actif => enCours != null;
  double get volume;

  /// Joue [source] (ce qui jouait s'arrête), au [volume] donné.
  Future<void> jouer(SourceSon source, {double volume = 1, bool boucle = false});
  Future<void> regler(double volume);
  Future<void> arreter();

  /// Se termine quand la piste en cours finit (ou est arrêtée). Une boucle ne
  /// finit qu'à l'arrêt.
  Future<void> get fin;

  /// Durée de la piste en cours, si le lecteur la connaît.
  Future<Duration?> duree();

  void liberer() => dispose();
}

/// Le lecteur réel (audioplayers). [vers] traduit une source en fichier,
/// asset ou adresse web.
class LecteurAudioplayers extends LecteurSon {
  LecteurAudioplayers(this._vers) {
    _abonnement = _p.onPlayerComplete.listen((_) {
      _enCours = null;
      _terminer();
      notifyListeners();
    });
  }

  final Source Function(SourceSon) _vers;
  final AudioPlayer _p = AudioPlayer();
  late final StreamSubscription<void> _abonnement;
  SourceSon? _enCours;
  double _volume = 1;
  Completer<void> _fin = Completer<void>()..complete();

  @override
  SourceSon? get enCours => _enCours;

  @override
  double get volume => _volume;

  @override
  Future<void> get fin => _fin.future;

  void _terminer() {
    if (!_fin.isCompleted) _fin.complete();
  }

  @override
  Future<void> jouer(SourceSon source, {double volume = 1, bool boucle = false}) async {
    _terminer();
    _fin = Completer<void>();
    _enCours = source;
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _p.stop();
      await _p.setReleaseMode(boucle ? ReleaseMode.loop : ReleaseMode.stop);
      await _p.setVolume(_volume);
      await _p.play(_vers(source));
    } catch (e) {
      debugPrint('Régie son : impossible de jouer ${source.chemin} ($e)');
      _enCours = null;
      _terminer();
      notifyListeners();
    }
  }

  @override
  Future<void> regler(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _p.setVolume(_volume);
    } catch (_) {}
  }

  @override
  Future<void> arreter() async {
    final jouait = _enCours != null;
    _enCours = null;
    _terminer();
    try {
      await _p.stop();
    } catch (_) {}
    if (jouait) notifyListeners();
  }

  @override
  Future<Duration?> duree() async {
    try {
      return await _p.getDuration();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _abonnement.cancel();
    _p.dispose();
    super.dispose();
  }
}
