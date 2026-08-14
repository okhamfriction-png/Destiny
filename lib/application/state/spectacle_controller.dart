import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/spectacle_turn.dart';
import '../../domain/repositories/story_repository.dart';
import '../services/llm_service.dart';
import '../services/spectacle_prompt.dart';
import 'ai_settings.dart';
import 'spectacle_store.dart';

/// Sous-mode de jeu.
enum SpectacleMode {
  classique,
  libre;

  String get label =>
      this == SpectacleMode.classique ? 'Classique' : 'Libre';
  String get wire => this == SpectacleMode.classique ? 'classique' : 'libre';
}

/// Source du contexte : catalogue (Spectacle) ou film (Spin-off).
enum SpectacleKind {
  spectacle,
  spinoff;

  bool get isSpinoff => this == SpectacleKind.spinoff;
  String get wire => name;

  static SpectacleKind fromName(String? n) =>
      n == 'spinoff' ? SpectacleKind.spinoff : SpectacleKind.spectacle;
}

/// Longueur d'une scène (nombre de répliques cible).
enum SceneLength {
  court,
  normal,
  long;

  int get count => switch (this) {
        SceneLength.court => 10,
        SceneLength.normal => 20,
        SceneLength.long => 30,
      };

  String get label => switch (this) {
        SceneLength.court => 'Court (10)',
        SceneLength.normal => 'Normal (20)',
        SceneLength.long => 'Long (30)',
      };

  String get wire => name;

  static SceneLength fromName(String? n) {
    for (final l in SceneLength.values) {
      if (l.name == n) return l;
    }
    return SceneLength.normal;
  }
}

/// Le décor tiré au hasard (lieu + danger + 4 archétypes).
class SpectacleDraw {
  const SpectacleDraw({
    required this.lieu,
    required this.roles,
    required this.danger,
    required this.paliers,
    required this.archetypes,
  });

  final String lieu;
  final List<String> roles;
  final String danger;
  final List<String> paliers;
  final List<SpectacleArchetype> archetypes;
}

/// Une bulle du fil de jeu.
class SpectacleLogItem {
  SpectacleLogItem({
    required this.isPlayer,
    this.didascalie = '',
    this.personnage = '',
    this.archetype = '',
    required this.texte,
    this.success,
  });

  final bool isPlayer;
  final String didascalie;
  final String personnage;

  /// Archétype (animal) du personnage — pour l'icône dans la bulle.
  final String archetype;
  final String texte;

  /// Vrai = réplique juste (fond vert), faux = ratée (fond rouge), null = neutre.
  bool? success;
}

/// Orchestration du Mode Spectacle : tirage du décor, appel LLM tour par tour,
/// parsing du protocole JSON.
class SpectacleController extends ChangeNotifier {
  SpectacleController({
    required StoryRepository repository,
    required LlmService llm,
    required AiSettings aiSettings,
    this.store,
  })  : _repository = repository,
        _llm = llm,
        _ai = aiSettings;

  final StoryRepository _repository;
  final LlmService _llm;
  final AiSettings _ai;
  final SpectacleStore? store;
  final Random _rng = Random();

  // --- Configuration ---
  SpectacleMode _mode = SpectacleMode.classique;
  SpectacleKind _kind = SpectacleKind.spectacle;
  int _playerIndex = 0;
  String _universe = 'Contemporain';
  String _tone = 'Drame';
  SceneLength _sceneLength = SceneLength.normal;
  String _decade = 'années 1990';
  String _genre = 'Action';

  SpectacleMode get mode => _mode;
  SpectacleKind get kind => _kind;
  bool get isSpinoff => _kind.isSpinoff;
  int get playerIndex => _playerIndex;
  String get universe => _universe;
  String get tone => _tone;
  SceneLength get sceneLength => _sceneLength;
  int get sceneTarget => _sceneLength.count;
  String get decade => _decade;
  String get genre => _genre;

  /// Contexte du film (mode Spin-off), une fois la partie lancée.
  FilmContext? _filmContext;
  FilmContext? get filmContext => _filmContext;

  /// Archétype que le joueur incarne actuellement (assigné par l'IA en Spin-off,
  /// choisi au setup/par scène en Spectacle).
  String get currentArchetypeName {
    if (_kind.isSpinoff) return _current?.joueurArchetype ?? '';
    return playerArchetype?.name ?? '';
  }

  void setMode(SpectacleMode m) {
    if (m == _mode || _started) return;
    _mode = m;
    notifyListeners();
  }

  void setKind(SpectacleKind k) {
    if (k == _kind || _started) return;
    _kind = k;
    notifyListeners();
  }

  void setDecade(String d) {
    if (d == _decade || _started) return;
    _decade = d;
    notifyListeners();
  }

  void setGenre(String g) {
    if (g == _genre || _started) return;
    _genre = g;
    notifyListeners();
  }

  void setPlayerIndex(int i) {
    if (i == _playerIndex || _started) return;
    _playerIndex = i;
    notifyListeners();
  }

  void setUniverse(String u) {
    if (u == _universe || _started) return;
    _universe = u;
    notifyListeners();
  }

  void setTone(String t) {
    if (t == _tone || _started) return;
    _tone = t;
    notifyListeners();
  }

  void setSceneLength(SceneLength l) {
    if (l == _sceneLength || _started) return;
    _sceneLength = l;
    notifyListeners();
  }

  // --- État ---
  SpectacleDraw? _draw;
  bool _started = false;
  bool _loading = false;
  String? _error;
  SpectacleTurn? _current;
  bool _awaitingCharacter = false; // il faut choisir le perso de la scène
  int _sceneNumber = 1;
  final List<SpectacleLogItem> _log = [];
  final List<ChatMessage> _messages = [];
  String _system = '';

  SpectacleDraw? get draw => _draw;
  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  SpectacleTurn? get current => _current;
  List<SpectacleLogItem> get log => List.unmodifiable(_log);
  bool get configured => _ai.configured;

  /// Vrai quand il faut choisir le personnage pour la scène qui s'ouvre.
  /// (Jamais en Spin-off : l'IA assigne le personnage.)
  bool get needsCharacterChoice =>
      _started && !_loading && _awaitingCharacter && !_kind.isSpinoff;

  /// Numéro de la scène qui va s'ouvrir (pour l'invite de choix).
  int get sceneNumber => _sceneNumber;

  // --- Reprise d'une partie en cours ---
  Map<String, dynamic>? _savedSession;

  /// Vrai si une partie en cours a été trouvée (à charger avec [resume]).
  bool get canResume => _savedSession != null && !_started;

  /// Charge (au démarrage) la partie sauvegardée, s'il y en a une.
  Future<void> loadSavedSession() async {
    _savedSession = await store?.loadSession();
    notifyListeners();
  }

  /// Reprend la partie sauvegardée.
  void resume() {
    final s = _savedSession;
    if (s == null) return;
    try {
      _mode = (s['mode'] == 'libre') ? SpectacleMode.libre : SpectacleMode.classique;
      _kind = SpectacleKind.fromName(s['kind'] as String?);
      _decade = s['decade'] as String? ?? 'années 1990';
      _genre = s['genre'] as String? ?? 'Action';
      _filmContext = FilmContext.fromJson(s['filmContext']);
      _playerIndex = (s['playerIndex'] as num?)?.toInt() ?? 0;
      _universe = s['universe'] as String? ?? 'Contemporain';
      _tone = s['tone'] as String? ?? 'Drame';
      _sceneLength = SceneLength.fromName(s['sceneLength'] as String?);
      _sceneNumber = (s['sceneNumber'] as num?)?.toInt() ?? 1;
      _awaitingCharacter = s['awaitingCharacter'] as bool? ?? false;
      _system = s['system'] as String? ?? '';
      _draw = _drawFromJson(s['draw']);
      _messages
        ..clear()
        ..addAll([
          for (final m in (s['messages'] as List<dynamic>? ?? const []))
            ChatMessage.fromJson((m as Map).cast<String, dynamic>()),
        ]);
      _log
        ..clear()
        ..addAll([
          for (final l in (s['log'] as List<dynamic>? ?? const []))
            _logItemFromJson((l as Map).cast<String, dynamic>()),
        ]);
      // Restaure le tour courant depuis le dernier message de l'IA.
      SpectacleTurn? last;
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == 'assistant') {
          last = SpectacleTurn.tryParse(_messages[i].content);
          break;
        }
      }
      _current = last;
      _error = null;
      _loading = false;
      _started = true;
      notifyListeners();
    } catch (_) {
      _error = 'Impossible de reprendre la partie sauvegardée.';
      notifyListeners();
    }
  }

  /// Oublie la partie sauvegardée (sans y toucher en base tant que non écrasée).
  void discardSaved() {
    _savedSession = null;
    store?.clearSession();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> loadHistory() async =>
      (await store?.history()) ?? const [];

  Future<void> clearHistory() async => store?.clearHistory();

  SpectacleArchetype? get playerArchetype {
    final d = _draw;
    if (d == null || _playerIndex >= d.archetypes.length) return null;
    return d.archetypes[_playerIndex];
  }

  /// Tire un nouveau décor (lieu + danger + 4 archétypes).
  Future<void> drawDecor() async {
    _error = null;
    try {
      final locations =
          (await _repository.getLocations()).where((l) => l.actif).toList();
      final dangers = (await _repository.getDangers())
          .where((d) => d.actif && d.paliers.isNotEmpty)
          .toList();
      final archetypes = await _repository.getArchetypes();
      if (locations.isEmpty || dangers.isEmpty || archetypes.length < 4) {
        _error = 'Catalogue insuffisant pour le Mode Spectacle.';
        notifyListeners();
        return;
      }
      final loc = locations[_rng.nextInt(locations.length)];
      final dan = dangers[_rng.nextInt(dangers.length)];
      final pool = [...archetypes]..shuffle(_rng);
      final four = pool.take(4).toList();
      _draw = SpectacleDraw(
        lieu: loc.name,
        roles: loc.roles,
        danger: dan.name,
        paliers: dan.paliers,
        archetypes: [
          for (final a in four)
            SpectacleArchetype(
              name: a.name,
              temperament: a.temperament,
              port: a.port,
              moteur: a.moteur,
            ),
        ],
      );
      _started = false;
      _current = null;
      _awaitingCharacter = false;
      _sceneNumber = 1;
      _log.clear();
      _messages.clear();
      if (_playerIndex > 3) _playerIndex = 0;
      notifyListeners();
    } catch (_) {
      _error = 'Impossible de tirer le décor (données locales).';
      notifyListeners();
    }
  }

  /// Lève le rideau : construit le prompt et lance l'ouverture.
  Future<void> start() async {
    if (_loading) return;
    if (!_kind.isSpinoff && _draw == null) return;
    if (!_ai.configured) {
      _error = 'Configure l\'IA (Paramètres → IA) pour jouer.';
      notifyListeners();
      return;
    }
    final cible = _sceneLength.count;
    _messages.clear();
    _log.clear();
    _current = null;
    _filmContext = null;
    _awaitingCharacter = false;
    _sceneNumber = 1;
    _savedSession = null;
    _started = true;

    if (_kind.isSpinoff) {
      _system = buildSpinoffSystem(
        decade: _decade,
        genre: _genre,
        mode: _mode.wire,
        cible: cible,
      );
      final suite = _mode == SpectacleMode.classique
          ? 'puis mes 4 propositions dans la langue de mon personnage'
          : 'puis attends ma réplique';
      await _send(
        'Lève le rideau. Choisis un film réel du TOP 100 le plus populaire de '
        'la décennie « $_decade », genre « $genre ». Renseigne le champ '
        '"contexte" (film, année, lieu, danger, 4 protagonistes + archétypes). '
        'Assigne-moi un protagoniste (champ joueur_archetype), DÉMARRE '
        'directement sur le danger, ouvre la scène 1 avec UNE réplique d\'entrée '
        'du partenaire, $suite. Réponds uniquement avec le premier objet JSON.',
      );
      return;
    }

    final d = _draw!;
    _system = buildSpectacleSystem(
      lieu: d.lieu,
      roles: d.roles,
      danger: d.danger,
      paliers: d.paliers,
      archetypes: d.archetypes,
      playerIndex: _playerIndex,
      mode: _mode.wire,
      universe: _universe,
      tone: _tone,
      cible: cible,
    );
    final name = playerArchetype?.name ?? 'mon personnage';
    final suite = _mode == SpectacleMode.classique
        ? 'puis mes 4 propositions dans la langue de $name'
        : 'puis attends ma réplique';
    await _send(
      'Lève le rideau : Acte 1, scène 1, in media res. Je joue $name. '
      'Ouvre la scène avec UNE seule réplique d\'entrée du partenaire, $suite. '
      'Termine la scène par un tour phase="transition" une fois la cible de '
      '$cible répliques atteinte. Réponds uniquement avec le premier objet JSON.',
    );
  }

  /// Choisit le personnage pour la scène qui s'ouvre (après une transition).
  Future<void> chooseSceneCharacter(int index) async {
    final d = _draw;
    if (d == null || index < 0 || index >= d.archetypes.length) return;
    _playerIndex = index;
    _awaitingCharacter = false;
    final name = d.archetypes[index].name;
    notifyListeners();
    final suite = _mode == SpectacleMode.classique
        ? 'puis mes 4 propositions dans la langue de $name'
        : 'puis attends ma réplique';
    await _send(
      'Scène $_sceneNumber : je joue $name. Ouvre la scène avec UNE seule '
      'réplique d\'entrée du partenaire, $suite. Termine la scène par un tour '
      'phase="transition" à ${_sceneLength.count} répliques. Réponds en JSON.',
    );
  }

  /// Mode classique : le joueur choisit une proposition.
  Future<void> choose(SpectacleProposition p) async {
    final me =
        currentArchetypeName.isNotEmpty ? currentArchetypeName : 'mon personnage';
    _log.add(SpectacleLogItem(
      isPlayer: true,
      texte: p.texte,
      archetype: me,
      success: p.correcte,
    ));
    notifyListeners();
    await _send(
      'Je joue $me. Je choisis la proposition ${p.id} : « ${p.texte} ». '
      'Donne le feedback puis enchaîne le tour suivant en JSON.',
    );
  }

  /// Mode libre : le joueur écrit sa réplique.
  Future<void> submitFree(String text) async {
    final line = text.trim();
    if (line.isEmpty) return;
    final me =
        currentArchetypeName.isNotEmpty ? currentArchetypeName : 'mon personnage';
    _log.add(SpectacleLogItem(isPlayer: true, texte: line, archetype: me));
    notifyListeners();
    await _send(
      'Je joue $me. Ma réplique : « $line ». Note-la puis enchaîne le tour '
      'suivant en JSON.',
    );
  }

  /// Revient à l'écran de configuration (garde le décor tiré).
  void reset() {
    _started = false;
    _loading = false;
    _current = null;
    _filmContext = null;
    _awaitingCharacter = false;
    _sceneNumber = 1;
    _error = null;
    _log.clear();
    _messages.clear();
    _savedSession = null;
    store?.clearSession();
    notifyListeners();
  }

  Future<void> _send(String userContent) async {
    _loading = true;
    _error = null;
    notifyListeners();

    _messages.add(ChatMessage(role: 'user', content: userContent));
    try {
      final reply = await _llm.complete(
        settings: _ai,
        system: _system,
        messages: _messages,
      );
      _messages.add(ChatMessage(role: 'assistant', content: reply));
      final turn = SpectacleTurn.tryParse(reply);
      if (turn == null) {
        _error = 'Réponse illisible de l\'IA (JSON attendu).';
      } else {
        _current = turn;
        if (turn.contexte != null) _filmContext = turn.contexte;
        // Note la dernière réplique libre du joueur d'après le verdict.
        _gradeLastFreeLine(turn.feedback);
        if (turn.texte.isNotEmpty || turn.didascalie.isNotEmpty) {
          _log.add(SpectacleLogItem(
            isPlayer: false,
            didascalie: turn.didascalie,
            personnage: turn.personnage,
            archetype: turn.archetype,
            texte: turn.texte,
          ));
        }
        // Fin de scène : on demande le personnage de la scène suivante.
        // (En Spin-off, l'IA enchaîne seule : pas d'attente de choix.)
        if (turn.phase == 'transition' && !turn.isScore && !_kind.isSpinoff) {
          _sceneNumber += 1;
          _awaitingCharacter = true;
        }
      }
    } on LlmException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Erreur pendant l\'appel à l\'IA.';
    }
    _loading = false;
    _persist();
    notifyListeners();
  }

  /// Sauvegarde la partie (reprise) ou l'archive si elle est terminée.
  void _persist() {
    if (!_started) return;
    final t = _current;
    if (t != null && t.isScore) {
      store?.addToHistory(_archiveRecord(t));
      store?.clearSession();
      _savedSession = null;
    } else {
      store?.saveSession(_snapshot());
    }
  }

  Map<String, dynamic> _snapshot() => {
        'mode': _mode.wire,
        'kind': _kind.wire,
        'decade': _decade,
        'genre': _genre,
        'filmContext': _filmContext?.toJson(),
        'playerIndex': _playerIndex,
        'universe': _universe,
        'tone': _tone,
        'sceneLength': _sceneLength.wire,
        'sceneNumber': _sceneNumber,
        'awaitingCharacter': _awaitingCharacter,
        'system': _system,
        'draw': _draw == null ? null : _drawToJson(_draw!),
        'messages': [for (final m in _messages) m.toJson()],
        'log': [for (final i in _log) _logItemToJson(i)],
      };

  Map<String, dynamic> _archiveRecord(SpectacleTurn score) => {
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'mode': _kind.isSpinoff ? 'spin-off' : _mode.wire,
        'lieu': _kind.isSpinoff
            ? (_filmContext?.film ?? 'Film')
            : (_draw?.lieu ?? ''),
        'danger': _kind.isSpinoff
            ? (_filmContext?.danger ?? '')
            : (_draw?.danger ?? ''),
        'archetype': currentArchetypeName,
        'score': score.score,
        'log': [for (final i in _log) _logItemToJson(i)],
      };

  Map<String, dynamic> _drawToJson(SpectacleDraw d) => {
        'lieu': d.lieu,
        'roles': d.roles,
        'danger': d.danger,
        'paliers': d.paliers,
        'archetypes': [
          for (final a in d.archetypes)
            {
              'name': a.name,
              'temperament': a.temperament,
              'port': a.port,
              'moteur': a.moteur,
            },
        ],
      };

  SpectacleDraw? _drawFromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    return SpectacleDraw(
      lieu: j['lieu'] as String? ?? '',
      roles: [for (final r in (j['roles'] as List<dynamic>? ?? const [])) r as String],
      danger: j['danger'] as String? ?? '',
      paliers: [
        for (final p in (j['paliers'] as List<dynamic>? ?? const [])) p as String
      ],
      archetypes: [
        for (final a in (j['archetypes'] as List<dynamic>? ?? const []))
          SpectacleArchetype(
            name: (a as Map)['name'] as String? ?? '',
            temperament: a['temperament'] as String? ?? '',
            port: a['port'] as String? ?? '',
            moteur: a['moteur'] as String? ?? '',
          ),
      ],
    );
  }

  Map<String, dynamic> _logItemToJson(SpectacleLogItem i) => {
        'isPlayer': i.isPlayer,
        'didascalie': i.didascalie,
        'personnage': i.personnage,
        'archetype': i.archetype,
        'texte': i.texte,
        'success': i.success,
      };

  SpectacleLogItem _logItemFromJson(Map<String, dynamic> j) => SpectacleLogItem(
        isPlayer: j['isPlayer'] as bool? ?? false,
        didascalie: j['didascalie'] as String? ?? '',
        personnage: j['personnage'] as String? ?? '',
        archetype: j['archetype'] as String? ?? '',
        texte: j['texte'] as String? ?? '',
        success: j['success'] as bool?,
      );

  /// En mode libre, colore la dernière bulle joueur d'après le verdict (✓/✗)
  /// contenu dans le feedback du modèle.
  void _gradeLastFreeLine(Object? feedback) {
    if (feedback is! String) return;
    for (var k = _log.length - 1; k >= 0; k--) {
      final item = _log[k];
      if (!item.isPlayer) continue;
      if (item.success == null) {
        if (feedback.contains('✓')) {
          item.success = true;
        } else if (feedback.contains('✗')) {
          item.success = false;
        }
      }
      break;
    }
  }
}
