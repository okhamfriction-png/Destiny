import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une musique importée par le meneur, copiée dans le dossier de l'app.
///
/// [chemin] est un chemin de fichier local (lecture via [DeviceFileSource]).
/// [nom] est le titre affiché, sans extension.
class MusiqueImportee {
  const MusiqueImportee({required this.nom, required this.chemin});

  final String nom;
  final String chemin;

  /// Nom du fichier sur le disque (identifiant stable dans les réglages).
  String get fichier => p.basename(chemin);
}

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
    _chargerImportees();
  }

  final AudioPlayer _player = AudioPlayer();

  /// Lecteur dédié aux musiques de DESTINY : il se superpose au lit sonore
  /// (ambiance / commencement) sans le couper.
  final AudioPlayer _destinyPlayer = AudioPlayer();

  /// Sous-dossier du répertoire de l'app où sont copiées les musiques importées.
  static const String _dossierMusiques = 'musiques_destiny';
  static const String _kMusiquesImportees = 'destiny_musiques_importees';

  List<MusiqueImportee> _importees = const [];

  /// Musiques importées par le meneur, jouables à chaque DESTINY.
  List<MusiqueImportee> get importees => _importees;

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

  // ---------------------------------------------------------------------------
  // Musiques de DESTINY importées par le meneur.
  // ---------------------------------------------------------------------------

  Future<Directory> _dossierImportees() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _dossierMusiques));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Recharge la liste des musiques importées depuis le disque.
  ///
  /// La source de vérité est le dossier lui-même : on liste les fichiers
  /// présents et on récupère leur titre affichable dans les préférences. Ainsi
  /// une musique supprimée à la main disparaît, et rien ne casse si le chemin
  /// du dossier change d'une installation à l'autre.
  Future<void> _chargerImportees() async {
    try {
      final dir = await _dossierImportees();
      final titres = <String, String>{};
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kMusiquesImportees);
        if (raw != null) {
          for (final e in jsonDecode(raw) as List<dynamic>) {
            final m = e as Map<String, dynamic>;
            titres[m['fichier'] as String] = m['nom'] as String;
          }
        }
      } catch (_) {}
      final liste = <MusiqueImportee>[];
      for (final f in dir.listSync().whereType<File>()) {
        final base = p.basename(f.path);
        liste.add(MusiqueImportee(
          nom: titres[base] ?? p.basenameWithoutExtension(f.path),
          chemin: f.path,
        ));
      }
      liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      _importees = liste;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persisterImportees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _importees
          .map((m) => {'fichier': m.fichier, 'nom': m.nom})
          .toList();
      await prefs.setString(_kMusiquesImportees, jsonEncode(data));
    } catch (_) {}
  }

  /// Ouvre le sélecteur de fichiers et copie les musiques choisies dans l'app.
  /// Renvoie le nombre de musiques réellement ajoutées.
  Future<int> importerMusiques() async {
    final choisies = await FilePicker.pickFiles(type: FileType.audio);
    if (choisies.isEmpty) return 0;
    final dir = await _dossierImportees();
    var ajoutees = 0;
    for (final f in choisies) {
      final src = f.path;
      if (src == null) continue;
      // Nom de fichier unique et lisible (garde l'extension d'origine).
      final ext = p.extension(f.name);
      final tige = p
          .basenameWithoutExtension(f.name)
          .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ _-]'), '_')
          .trim();
      var cible = p.join(dir.path, '$tige$ext');
      var n = 2;
      while (await File(cible).exists()) {
        cible = p.join(dir.path, '$tige ($n)$ext');
        n++;
      }
      try {
        await File(src).copy(cible);
        ajoutees++;
      } catch (_) {}
    }
    if (ajoutees > 0) {
      await _chargerImportees();
      await _persisterImportees();
    }
    return ajoutees;
  }

  /// Supprime une musique importée (fichier + entrée).
  Future<void> retirerImportee(MusiqueImportee m) async {
    try {
      final f = File(m.chemin);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _chargerImportees();
    await _persisterImportees();
  }

  /// Résout un choix de réglage ('aucune' / 'aleatoire' / nom de fichier) vers
  /// une musique importée. Renvoie null si rien ne doit jouer.
  MusiqueImportee? _resoudreDestiny(String selection) {
    if (_importees.isEmpty || selection == 'aucune' || selection.isEmpty) {
      return null;
    }
    if (selection == 'aleatoire') {
      return _importees[Random().nextInt(_importees.length)];
    }
    for (final m in _importees) {
      if (m.fichier == selection) return m;
    }
    return null;
  }

  /// Joue la musique de DESTINY correspondant au réglage, en superposition du
  /// lit sonore. 'aucune' ou une musique introuvable ne joue rien.
  Future<void> jouerDestiny(String selection) async {
    final m = _resoudreDestiny(selection);
    if (m == null) return;
    await _jouerFichier(m.chemin);
  }

  /// Écoute une musique importée (aperçu depuis les réglages).
  Future<void> apercuImportee(MusiqueImportee m) => _jouerFichier(m.chemin);

  Future<void> _jouerFichier(String chemin) async {
    try {
      await _destinyPlayer.setReleaseMode(ReleaseMode.release);
      await _destinyPlayer.stop();
      await _destinyPlayer.setVolume(_volume);
      await _destinyPlayer.play(DeviceFileSource(chemin));
    } catch (_) {}
  }

  /// Coupe la musique de DESTINY en cours (le lit sonore continue).
  Future<void> stopDestiny() async {
    try {
      await _destinyPlayer.stop();
    } catch (_) {}
  }

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
    await _destinyPlayer.stop();
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration to) => _player.seek(to);

  @override
  void dispose() {
    _player.dispose();
    _destinyPlayer.dispose();
    super.dispose();
  }
}
