import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Une piste musicale décrite dans assets/music/manifest.json.
class MusicTrack {
  const MusicTrack({
    required this.file,
    required this.title,
    required this.category,
    required this.loop,
  });

  /// Chemin relatif au préfixe 'assets/' (ex. 'music/atm_forest.m4a').
  final String file;
  final String title;
  final String category;
  final bool loop;

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    var title = json['title'] as String;
    // Masque tout préfixe technique éventuel (ATM_, EMO_).
    title = title.replaceFirst(RegExp(r'^(ATM_|EMO_)'), '').trim();
    return MusicTrack(
      file: json['file'] as String,
      title: title,
      category: json['category'] as String? ?? 'Autres',
      loop: json['loop'] as bool? ?? false,
    );
  }
}

/// État + lecteur du menu Musique (indépendant des effets sonores).
class MusicController extends ChangeNotifier {
  MusicController() {
    _wire();
    _load();
  }

  final AudioPlayer _player = AudioPlayer();

  List<MusicTrack> _tracks = const [];
  List<MusicTrack> get tracks => _tracks;

  bool _loading = true;
  bool get loading => _loading;

  MusicTrack? _current;
  MusicTrack? get current => _current;

  bool _playing = false;
  bool get playing => _playing;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  // Volume global (0..1) et lecture en boucle par défaut (régie).
  double _volume = 0.8;
  double get volume => _volume;
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
    notifyListeners();
  }

  bool _boucle = true;
  bool get boucle => _boucle;
  void setBoucle(bool b) {
    _boucle = b;
    notifyListeners();
  }

  /// Sens du tri alphabétique des pistes (A→Z si vrai, Z→A sinon).
  bool _ascending = true;
  bool get ascending => _ascending;
  void toggleSortOrder() {
    _ascending = !_ascending;
    notifyListeners();
  }

  void _wire() {
    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.onPlayerStateChanged.listen((s) {
      _playing = s == PlayerState.playing;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      _playing = false;
      _position = Duration.zero;
      notifyListeners();
    });
  }

  Future<void> _load() async {
    final tracks = <MusicTrack>[];
    try {
      final raw = await rootBundle.loadString('assets/music/manifest.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      tracks.addAll((data['tracks'] as List<dynamic>)
          .map((e) => MusicTrack.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
    // Ambiances de lieux (téléchargées, libres de droit) → catégorie « Lieux ».
    try {
      final raw =
          await rootBundle.loadString('assets/audio/ambiences/manifest.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      tracks.addAll((data['ambiences'] as List<dynamic>).map((e) {
        final m = e as Map<String, dynamic>;
        return MusicTrack(
          file: m['file'] as String,
          title: m['title'] as String,
          category: 'Lieux',
          loop: m['loop'] as bool? ?? true,
        );
      }));
    } catch (_) {}
    // Thèmes musicaux par univers d'histoire → catégorie « Univers ».
    try {
      final raw =
          await rootBundle.loadString('assets/audio/universes/manifest.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      tracks.addAll((data['universes'] as List<dynamic>).map((e) {
        final m = e as Map<String, dynamic>;
        return MusicTrack(
          file: m['file'] as String,
          title: m['title'] as String,
          category: 'Univers',
          loop: m['loop'] as bool? ?? true,
        );
      }));
    } catch (_) {}
    _tracks = tracks;
    _loading = false;
    notifyListeners();
  }

  /// Catégories dans l'ordre d'apparition.
  List<String> get categories {
    final seen = <String>[];
    for (final t in _tracks) {
      if (!seen.contains(t.category)) seen.add(t.category);
    }
    return seen;
  }

  List<MusicTrack> tracksOf(String category) {
    final list = _tracks.where((t) => t.category == category).toList();
    list.sort((a, b) {
      final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return _ascending ? c : -c;
    });
    return list;
  }

  /// Joue le thème de l'univers portant ce titre (catégorie « Univers »).
  /// Sans effet si aucun thème ne correspond.
  Future<void> playUniverse(String title) async {
    final t = title.trim().toLowerCase();
    for (final track in _tracks) {
      if (track.category == 'Univers' && track.title.toLowerCase() == t) {
        await playTrack(track);
        return;
      }
    }
  }

  /// Musique du Commencement, lancée au démarrage du chrono d'histoire.
  Future<void> playCommencement() =>
      _playScore('music/01_commencement.m4a', 'Commencement');

  /// Musique de Conclusion, lancée 15 s après le 3ᵉ DESTINY.
  Future<void> playConclusion() =>
      _playScore('music/02_conclusionainsique.m4a', 'Conclusion');

  /// Joue une musique scénaristique du chrono (one-shot, sans boucle).
  Future<void> _playScore(String file, String title) => playTrack(MusicTrack(
        file: file,
        title: title,
        category: 'Chrono',
        loop: false,
      ));

  /// Joue l'ambiance du lieu (catégorie « Lieux ») dont le titre correspond.
  /// Sans effet si aucune ambiance ne correspond.
  Future<void> playLocationAmbience(String locationName) async {
    final t = locationName.trim().toLowerCase();
    for (final track in _tracks) {
      if (track.category == 'Lieux' && track.title.trim().toLowerCase() == t) {
        await playTrack(track);
        return;
      }
    }
  }

  /// Joue une piste. [forceLoop] force la lecture en boucle (régie).
  Future<void> playTrack(MusicTrack track, {bool forceLoop = false}) async {
    _current = track;
    _position = Duration.zero;
    notifyListeners();
    await _player.setReleaseMode(
      (forceLoop || track.loop) ? ReleaseMode.loop : ReleaseMode.release,
    );
    await _player.stop();
    await _player.setVolume(_volume);
    await _player.play(AssetSource(track.file));
  }

  /// Lecture/pause d'une piste depuis la régie (boucle selon le réglage).
  Future<void> toggle(MusicTrack track) async {
    if (_current?.file == track.file) {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
    } else {
      await playTrack(track, forceLoop: _boucle);
    }
  }

  Future<void> togglePlayPause() async {
    if (_current == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration to) => _player.seek(to);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
