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
    this.source,
    this.suivante,
  });

  /// Chemin relatif au préfixe 'assets/' (ex. 'music/atm_forest.m4a') ; pour
  /// une piste du pack, un identifiant (la lecture passe par [source]).
  final String file;

  /// D'où lire la piste, si ce n'est pas l'asset [file] (le pack audio).
  final Source? source;
  final String title;
  final String category;
  final bool loop;

  /// La piste à enchaîner quand celle-ci se termine (les musiques du
  /// spectacle : acte suivant, puis lieu suivant). Null : on s'arrête.
  final MusicTrack? Function()? suivante;

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
    _chargerPreferences();
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

  static const String _kEnchainerAmbiances = 'musique_enchainer_ambiances';

  /// Dans « Spectacle », l'ambiance du lieu passe après l'acte 4 (sinon on
  /// la saute : acte 4, puis l'acte 1 du lieu suivant). Gardé sur l'appareil.
  bool _enchainerAmbiances = false;
  bool get enchainerAmbiances => _enchainerAmbiances;
  Future<void> setEnchainerAmbiances(bool b) async {
    _enchainerAmbiances = b;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnchainerAmbiances, b);
    } catch (_) {}
  }

  static const String _kDescente = 'musique_descente_v1';

  /// La descente automatique des musiques du spectacle : à partir de
  /// [descenteDebutS] secondes, le volume baisse jusqu'au silence en
  /// [descenteDureeS] secondes, puis la suivante part. Gardée sur l'appareil.
  bool _descenteActive = false;
  int _descenteDebutS = 30;
  int _descenteDureeS = 10;
  bool get descenteActive => _descenteActive;
  int get descenteDebutS => _descenteDebutS;
  int get descenteDureeS => _descenteDureeS;

  Future<void> setDescente({bool? active, int? debutS, int? dureeS}) async {
    _descenteActive = active ?? _descenteActive;
    _descenteDebutS = (debutS ?? _descenteDebutS).clamp(5, 600);
    _descenteDureeS = (dureeS ?? _descenteDureeS).clamp(1, 120);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kDescente, jsonEncode({'active': _descenteActive, 'debut': _descenteDebutS, 'duree': _descenteDureeS}));
    } catch (_) {}
  }

  /// Le niveau (0 à 1) d'une musique à la position [p] : 1 avant [debutS],
  /// puis une descente linéaire jusqu'à 0 en [dureeS] secondes.
  static double niveauDescente(Duration p, {required int debutS, required int dureeS}) {
    final s = p.inMilliseconds / 1000;
    if (s <= debutS) return 1;
    return (1 - (s - debutS) / dureeS).clamp(0.0, 1.0);
  }

  /// La descente s'applique-t-elle à la piste en cours ?
  bool get _descenteSurPiste => _descenteActive && _current?.category == 'Spectacle';
  bool _descenteFinie = false;
  double _niveauApplique = 1;

  void _suivreDescente(Duration p) {
    if (!_descenteSurPiste || _descenteFinie) return;
    final f = niveauDescente(p, debutS: _descenteDebutS, dureeS: _descenteDureeS);
    if ((f - _niveauApplique).abs() >= 0.01 || (f == 1 && _niveauApplique != 1)) {
      _niveauApplique = f;
      _player.setVolume(_volume * f).catchError((_) {});
    }
    if (f <= 0) {
      _descenteFinie = true;
      _finDePiste();
    }
  }

  /// La musique est finie (ou descendue jusqu'au silence) : la suivante.
  Future<void> _finDePiste() async {
    final suite = _current?.suivante?.call();
    if (suite != null) {
      await playTrack(suite, forceLoop: _boucle);
    } else {
      await _player.stop();
      _playing = false;
      _position = Duration.zero;
      notifyListeners();
    }
  }

  Future<void> _chargerPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enchainerAmbiances = prefs.getBool(_kEnchainerAmbiances) ?? false;
      final d = prefs.getString(_kDescente);
      if (d != null) {
        final j = jsonDecode(d) as Map<String, dynamic>;
        _descenteActive = j['active'] as bool? ?? false;
        _descenteDebutS = (j['debut'] as num?)?.toInt() ?? 30;
        _descenteDureeS = (j['duree'] as num?)?.toInt() ?? 10;
      }
      notifyListeners();
    } catch (_) {}
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
      _suivreDescente(p);
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
      if (_descenteFinie) return;
      final suite = _current?.suivante?.call();
      if (suite != null) playTrack(suite, forceLoop: _boucle);
    });
  }

  Future<void> _load() async {
    final tracks = <MusicTrack>[];
    try {
      final raw = await rootBundle.loadString('assets/music/manifest.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      tracks.addAll((data['tracks'] as List<dynamic>).map((e) => MusicTrack.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
    // Ambiances de lieux (téléchargées, libres de droit) → catégorie « Lieux ».
    try {
      final raw = await rootBundle.loadString('assets/audio/ambiences/manifest.json');
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
      final raw = await rootBundle.loadString('assets/audio/universes/manifest.json');
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
  Future<void> playCommencement() => _playScore('music/01_commencement.m4a', 'Commencement');

  /// Musique de Conclusion, lancée 15 s après le 3ᵉ DESTINY.
  Future<void> playConclusion() => _playScore('music/02_conclusionainsique.m4a', 'Conclusion');

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
      final data = _importees.map((m) => {'fichier': m.fichier, 'nom': m.nom}).toList();
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
      final tige = p.basenameWithoutExtension(f.name).replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ _-]'), '_').trim();
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

  /// Joue un choix de musique des réglages Destiny : `aucune`, `lieu`
  /// (l'ambiance du lieu [lieu]), ou le fichier d'une piste
  /// (`music/…`, `audio/…`).
  Future<void> jouerChoix(String choix, {String lieu = ''}) async {
    if (choix.isEmpty || choix == 'aucune') return;
    if (choix == 'lieu') {
      await playLocationAmbience(lieu);
      return;
    }
    for (final track in _tracks) {
      if (track.file == choix) {
        await playTrack(track);
        return;
      }
    }
    await _playScore(choix, choix.split('/').last);
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
    _descenteFinie = false;
    _niveauApplique = 1;
    notifyListeners();
    // Une piste qui enchaîne sur la suivante ne boucle jamais, sinon elle ne
    // se termine pas et l'enchaînement ne part pas.
    await _player.setReleaseMode(
      track.suivante == null && (forceLoop || track.loop) ? ReleaseMode.loop : ReleaseMode.release,
    );
    await _player.stop();
    await _player.setVolume(_volume);
    await _player.play(track.source ?? AssetSource(track.file));
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
