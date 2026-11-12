import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/spectacle_turn.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../infrastructure/datasources/grammaire_source.dart';
import '../prompts/prompts.dart';
import '../prompts/spectacle.dart';
import '../services/llm_service.dart';
import 'ai_settings.dart';
import 'spectacle_store.dart';

/// Sous-mode de jeu.
enum SpectacleMode {
  classique,
  libre;

  String get label => this == SpectacleMode.classique ? 'Classique' : 'Libre';
  String get wire => this == SpectacleMode.classique ? 'classique' : 'libre';
  ModeSpectacle get prompt => this == SpectacleMode.classique ? ModeSpectacle.classique : ModeSpectacle.libre;
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

/// Un des quatre personnages du spectacle : un archétype et son animal.
class PersonnageSpectacle {
  const PersonnageSpectacle({required this.archetypeId, required this.animalId, required this.name, this.line = ''});

  final String archetypeId;
  final String animalId;

  /// « Leader · Lion ».
  final String name;

  /// Ce qu'il fait face au danger.
  final String line;

  Map<String, dynamic> versJson() => {'archetype': archetypeId, 'animal': animalId, 'name': name, 'line': line};

  factory PersonnageSpectacle.depuisJson(Map<String, dynamic> j) => PersonnageSpectacle(
        archetypeId: j['archetype'] as String? ?? '',
        animalId: j['animal'] as String? ?? '',
        name: j['name'] as String? ?? '',
        line: j['line'] as String? ?? '',
      );
}

/// Le décor tiré au hasard : lieu, groupe, danger et quatre personnages.
class SpectacleDraw {
  const SpectacleDraw({
    required this.lieu,
    this.espaces = const [],
    this.groupe = '',
    required this.danger,
    required this.paliers,
    required this.archetypes,
  });

  final String lieu;
  final List<String> espaces;
  final String groupe;
  final String danger;
  final List<String> paliers;

  /// Les quatre personnages (J1 à J4).
  final List<PersonnageSpectacle> archetypes;

  Map<String, dynamic> versJson() => {
        'lieu': lieu,
        'espaces': espaces,
        'groupe': groupe,
        'danger': danger,
        'paliers': paliers,
        'personnages': [for (final p in archetypes) p.versJson()],
      };

  static SpectacleDraw? depuisJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    List<String> ls(Object? x) => [for (final e in (x as List? ?? const [])) '$e'];
    return SpectacleDraw(
      lieu: j['lieu'] as String? ?? '',
      espaces: ls(j['espaces']),
      groupe: j['groupe'] as String? ?? '',
      danger: j['danger'] as String? ?? '',
      paliers: ls(j['paliers']),
      archetypes: [
        for (final p in (j['personnages'] as List? ?? const []))
          if (p is Map) PersonnageSpectacle.depuisJson(p.cast<String, dynamic>()),
      ],
    );
  }
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

  /// L'animal du personnage, pour l'icône dans la bulle.
  final String archetype;
  final String texte;

  /// Vrai = réplique juste (fond vert), faux = ratée (fond rouge), null = neutre.
  bool? success;
}

/// Le Spectacle avec l'IA : le joueur joue un personnage par scène, l'IA joue
/// les partenaires, la régie et le coach. Quatre actes ; Destiny se lance de
/// l'extérieur (le bouton du joueur) ; à la fin, un débrief positif.
class SpectacleController extends ChangeNotifier {
  SpectacleController({
    required CatalogStore catalogue,
    required GrammaireChargee grammaire,
    required LlmService llm,
    required AiSettings aiSettings,
    this.store,
    Random? hasard,
  })  : _catalogue = catalogue,
        _grammaire = grammaire,
        _llm = llm,
        _ai = aiSettings,
        _rng = hasard ?? Random();

  final CatalogStore _catalogue;
  final GrammaireChargee _grammaire;
  final LlmService _llm;
  final AiSettings _ai;
  final SpectacleStore? store;
  final Random _rng;

  Grammaire get _g => _grammaire.grammaire;

  // --- Configuration ---
  SpectacleMode _mode = SpectacleMode.classique;
  int _playerIndex = 0;
  String _universe = 'Contemporain';
  String _tone = 'Drame';
  SceneLength _sceneLength = SceneLength.normal;
  bool _kids = false;

  SpectacleMode get mode => _mode;
  int get playerIndex => _playerIndex;
  String get universe => _universe;
  String get tone => _tone;
  SceneLength get sceneLength => _sceneLength;
  int get sceneTarget => _sceneLength.count;
  bool get kids => _kids;

  String get currentArchetypeName => playerArchetype?.name ?? '';

  void setMode(SpectacleMode m) {
    _mode = m;
    notifyListeners();
  }

  void setPlayerIndex(int i) {
    _playerIndex = i;
    notifyListeners();
  }

  void setUniverse(String u) {
    _universe = u;
    notifyListeners();
  }

  void setTone(String t) {
    _tone = t;
    notifyListeners();
  }

  void setSceneLength(SceneLength l) {
    _sceneLength = l;
    notifyListeners();
  }

  void setKids(bool v) {
    _kids = v;
    _draw = null;
    notifyListeners();
  }

  // --- État ---
  SpectacleDraw? _draw;
  bool _started = false;
  bool _loading = false;
  String? _error;
  SpectacleTurn? _current;
  final List<SpectacleLogItem> _log = [];
  final List<ChatMessage> _messages = [];
  String _system = '';
  bool _awaitingCharacter = false;
  int _sceneNumber = 1;

  SpectacleDraw? get draw => _draw;
  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  SpectacleTurn? get current => _current;
  List<SpectacleLogItem> get log => List.unmodifiable(_log);
  bool get configured => _ai.configured;

  /// Vrai quand l'application doit demander au joueur quel personnage il
  /// incarne pour la scène qui s'ouvre (après une transition ou un Destiny).
  bool get needsCharacterChoice => _started && !_loading && _awaitingCharacter;

  /// Numéro de la scène qui va s'ouvrir (pour l'invite de choix).
  int get sceneNumber => _sceneNumber;

  /// Le palier atteint (d'après le dernier tour de l'IA).
  int get palier => (_current?.palier ?? 1).clamp(1, 4);

  /// Destiny se lance de l'extérieur : seulement en cours de partie, avant le
  /// palier 4, et pas pendant qu'on attend l'IA.
  bool get peutLancerDestiny =>
      _started && !_loading && !(_current?.isFin ?? false) && _current != null && palier < 4;

  // --- Reprise d'une partie en cours ---
  Map<String, dynamic>? _savedSession;
  bool _sessionIgnoree = false;

  /// Vrai si une partie en cours a été trouvée (à charger avec [resume]).
  bool get canResume => _savedSession != null && !_started;

  /// Vrai si une partie de l'ancienne grammaire a été trouvée et laissée de
  /// côté (elle ne se reprend pas avec les nouveaux prompts).
  bool get sessionIgnoree => _sessionIgnoree;

  /// Charge (au démarrage) la partie sauvegardée, s'il y en a une. Une
  /// partie commencée avec d'autres prompts n'est pas reprise.
  Future<void> loadSavedSession() async {
    final s = await store?.loadSession();
    if (s != null && s['version_prompts'] != kVersionPrompts) {
      _sessionIgnoree = true;
      await store?.clearSession();
      _savedSession = null;
    } else {
      _savedSession = s;
    }
    notifyListeners();
  }

  /// Reprend la partie sauvegardée.
  void resume() {
    final s = _savedSession;
    if (s == null) return;
    try {
      _mode = (s['mode'] == 'libre') ? SpectacleMode.libre : SpectacleMode.classique;
      _playerIndex = (s['playerIndex'] as num?)?.toInt() ?? 0;
      _universe = s['universe'] as String? ?? 'Contemporain';
      _tone = s['tone'] as String? ?? 'Drame';
      _kids = s['kids'] as bool? ?? false;
      _sceneLength = SceneLength.fromName(s['sceneLength'] as String?);
      _sceneNumber = (s['sceneNumber'] as num?)?.toInt() ?? 1;
      _awaitingCharacter = s['awaitingCharacter'] as bool? ?? false;
      _system = s['system'] as String? ?? '';
      _draw = SpectacleDraw.depuisJson(s['draw']);
      _messages
        ..clear()
        ..addAll([
          for (final m in (s['messages'] as List<dynamic>? ?? const []))
            ChatMessage.fromJson((m as Map).cast<String, dynamic>()),
        ]);
      _log
        ..clear()
        ..addAll([
          for (final l in (s['log'] as List<dynamic>? ?? const [])) _logItemFromJson((l as Map).cast<String, dynamic>()),
        ]);
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

  /// Oublie la partie sauvegardée.
  void discardSaved() {
    _savedSession = null;
    store?.clearSession();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> loadHistory() async => (await store?.history()) ?? const [];

  Future<void> clearHistory() async => store?.clearHistory();

  PersonnageSpectacle? get playerArchetype {
    final d = _draw;
    if (d == null || _playerIndex >= d.archetypes.length) return null;
    return d.archetypes[_playerIndex];
  }

  /// Tire un nouveau décor : un lieu, un danger (filtrés en mode enfant), un
  /// groupe, et quatre personnages en distribution équilibrée.
  Future<void> drawDecor() async {
    _error = null;
    try {
      final lieux = [for (final l in await _catalogue.getLocations()) if (l.actif && (!_kids || l.kids)) l];
      final dangers = [
        for (final d in await _catalogue.getDangers())
          if (d.actif && d.paliers.length == 4 && (!_kids || d.kids)) d,
      ];
      if (lieux.isEmpty || dangers.isEmpty) {
        _error = 'Catalogue insuffisant pour le spectacle.';
        notifyListeners();
        return;
      }
      final lieu = lieux[_rng.nextInt(lieux.length)];
      final danger = dangers[_rng.nextInt(dangers.length)];
      final groupes = _grammaire.textes.liste('mise_en_place.groupes');
      final ids = tirerDistribution(_g, 4, hasard: _rng);
      _draw = SpectacleDraw(
        lieu: lieu.name,
        espaces: lieu.espaces,
        groupe: groupes.isEmpty ? '' : groupes[_rng.nextInt(groupes.length)],
        danger: danger.name,
        paliers: danger.paliersPour(kids: _kids),
        archetypes: [
          for (final id in ids)
            () {
              final animal = tirerAnimal(_g, id, hasard: _rng);
              return PersonnageSpectacle(
                archetypeId: id,
                animalId: animal,
                name: '${_g.archetype(id)?.nom ?? id} · ${_g.animal(animal)?.nom ?? animal}',
                line: _g.archetype(id)?.ceQuIlFait ?? '',
              );
            }(),
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

  String _j(int i) => 'J${i + 1}';

  /// Lève le rideau : construit le prompt et lance l'ouverture.
  Future<void> start() async {
    if (_loading || _draw == null) return;
    if (!_ai.configured) {
      _error = 'Configure l\'IA (Réglages → IA) pour jouer.';
      notifyListeners();
      return;
    }
    final d = _draw!;
    final cible = _sceneLength.count;
    _messages.clear();
    _log.clear();
    _current = null;
    _awaitingCharacter = false;
    _sceneNumber = 1;
    _savedSession = null;
    _sessionIgnoree = false;
    _started = true;
    _system = promptSpectacle(
      g: _g,
      scene: ScenePrompt(
        lieu: d.lieu,
        espaces: d.espaces,
        groupe: d.groupe,
        danger: d.danger,
        paliers: d.paliers,
        univers: _universe,
        ton: _tone,
      ),
      personnages: [
        for (final p in d.archetypes)
          PersonnagePrompt(nom: p.name, archetypeId: p.archetypeId, animalId: p.animalId, joueur: false),
      ],
      mode: _mode.prompt,
      cible: cible,
      kids: _kids,
    );
    await _send(
      'Lève le rideau : acte 1, scène 1, au palier 1. Je joue ${_j(_playerIndex)} (${playerArchetype?.name ?? ''}). '
      'Ouvre la scène avec UNE seule réplique d\'entrée du partenaire, '
      '${_mode == SpectacleMode.classique ? 'puis mes 4 propositions' : 'puis attends ma réplique'}. '
      'Réponds uniquement avec le premier objet JSON.',
    );
  }

  /// Choisit le personnage pour la scène qui s'ouvre.
  Future<void> chooseSceneCharacter(int index) async {
    final d = _draw;
    if (d == null || index < 0 || index >= d.archetypes.length) return;
    _playerIndex = index;
    _awaitingCharacter = false;
    notifyListeners();
    await _send(
      'Scène $_sceneNumber : je joue ${_j(index)} (${d.archetypes[index].name}). Ouvre la scène avec UNE seule '
      'réplique d\'entrée du partenaire, '
      '${_mode == SpectacleMode.classique ? 'puis mes 4 propositions' : 'puis attends ma réplique'}. '
      'Réponds en JSON.',
    );
  }

  /// La régie lance Destiny : le danger monte d'un palier.
  Future<void> lancerDestiny() async {
    if (!peutLancerDestiny) return;
    _awaitingCharacter = false;
    await _send('[DESTINY] La régie lance Destiny. Écris le rituel, le son du nouveau palier et la première réaction '
        'd\'un partenaire, en JSON.');
  }

  /// Mode classique : le joueur choisit une proposition.
  Future<void> choose(SpectacleProposition p) async {
    final me = currentArchetypeName.isNotEmpty ? currentArchetypeName : 'mon personnage';
    _log.add(SpectacleLogItem(isPlayer: true, texte: p.texte, archetype: playerArchetype?.animalId ?? '', success: p.correcte));
    notifyListeners();
    await _send('Je joue $me. Je choisis la proposition ${p.id} : « ${p.texte} ». '
        'Donne le feedback puis enchaîne le tour suivant en JSON.');
  }

  /// Mode libre : le joueur écrit sa réplique.
  Future<void> submitFree(String text) async {
    final line = text.trim();
    if (line.isEmpty) return;
    final me = currentArchetypeName.isNotEmpty ? currentArchetypeName : 'mon personnage';
    _log.add(SpectacleLogItem(isPlayer: true, texte: line, archetype: playerArchetype?.animalId ?? ''));
    notifyListeners();
    await _send('Je joue $me. Ma réplique : « $line ». Donne ton verdict puis enchaîne le tour suivant en JSON.');
  }

  /// Revient à l'écran de configuration (garde le décor tiré).
  void reset() {
    _started = false;
    _loading = false;
    _current = null;
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
      final reply = await _llm.complete(settings: _ai, system: _system, messages: _messages);
      _messages.add(ChatMessage(role: 'assistant', content: reply));
      final turn = SpectacleTurn.tryParse(reply);
      if (turn == null) {
        _error = 'Réponse illisible de l\'IA (JSON attendu).';
      } else {
        _current = turn;
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
        // Fin de scène ou Destiny : on demande le personnage de la suivante.
        if ((turn.phase == 'transition' || turn.isDestiny) && !turn.isFin) {
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
    if (t != null && t.isFin) {
      store?.addToHistory(_archiveRecord(t));
      store?.clearSession();
      _savedSession = null;
    } else {
      store?.saveSession(_snapshot());
    }
  }

  Map<String, dynamic> _snapshot() => {
        'version_prompts': kVersionPrompts,
        'mode': _mode.wire,
        'playerIndex': _playerIndex,
        'universe': _universe,
        'tone': _tone,
        'kids': _kids,
        'sceneLength': _sceneLength.wire,
        'sceneNumber': _sceneNumber,
        'awaitingCharacter': _awaitingCharacter,
        'system': _system,
        'draw': _draw?.versJson(),
        'messages': [for (final m in _messages) m.toJson()],
        'log': [for (final i in _log) _logItemToJson(i)],
      };

  Map<String, dynamic> _archiveRecord(SpectacleTurn fin) => {
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'mode': _mode.wire,
        'lieu': _draw?.lieu ?? '',
        'danger': _draw?.danger ?? '',
        'archetype': currentArchetypeName,
        'debrief': fin.debrief,
        'log': [for (final i in _log) _logItemToJson(i)],
      };

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

  /// En mode libre, colore la dernière bulle joueur d'après le verdict (✓/✗).
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
