import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/archetype.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_story.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/chat_store.dart';
import '../../domain/usecases/generate_story_usecase.dart';
import '../../infrastructure/datasources/local_json_datasource.dart';
import '../services/gm_prompt.dart';
import '../services/llm_service.dart';
import 'ai_settings.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.chatStore,
    required this.llm,
    required this.aiSettings,
    required this.generateStoryUseCase,
    required this.dataSource,
  });

  final ChatStore chatStore;
  final LlmService llm;
  final AiSettings aiSettings;
  final GenerateStoryUseCase generateStoryUseCase;
  final LocalJsonDataSource dataSource;

  final Random _random = Random();

  List<ChatStory> stories = [];
  List<Archetype> archetypes = [];
  ChatStory? active;
  List<String> choices = [];
  bool busy = false;
  String? error;
  String? lastCoin; // 'RÉUSSITE' ou 'ÉCHEC'

  /// Incrémenté à chaque résolution d'action (déclenche l'animation).
  int resultPulse = 0;
  bool lastSuccess = false;

  /// Incrémenté à chaque montée du danger (déclenche l'éclair + tonnerre).
  int dangerPulse = 0;

  /// Malus en attente : après une montée du danger, la prochaine action
  /// exige 2 réussites sur 2 dés.
  bool _malusPending = false;
  bool get malusPending => _malusPending;

  /// Détails du dernier lancer (pour l'affichage).
  List<bool> lastRolls = const [];
  int lastRequired = 1;

  /// Lance les dés de l'action courante. Sous malus (le danger vient de monter),
  /// il faut 2 réussites sur 2 dés ; sinon 1 réussite sur 1 dé.
  bool _rollAction() {
    final required = _malusPending ? 2 : 1;
    _malusPending = false;
    lastRequired = required;

    final rolls = <bool>[];
    var heads = 0;
    for (var i = 0; i < required; i++) {
      final h = _random.nextBool();
      rolls.add(h);
      if (h) heads++;
    }
    final success = heads >= required;
    lastRolls = rolls;
    lastSuccess = success;
    lastCoin = success ? 'RÉUSSITE' : 'ÉCHEC';
    resultPulse++;
    return success;
  }

  String _rollNote(bool success) {
    final b = StringBuffer();
    if (lastRequired >= 2) {
      b.write(' (le danger venait de monter : 2 réussites étaient exigées)');
    }
    return b.toString();
  }

  /// Rappel de contrainte de style, injecté à CHAQUE tour (les modèles oublient
  /// une consigne système répétée trop tôt).
  String get _styleBrief => switch (aiSettings.narration) {
        NarrationStyle.petit =>
          'CONTRAINTE ABSOLUE — réponds en UNE SEULE phrase de 6 MOTS MAXIMUM '
              '(« DONC »/« MAIS » compris), uniquement des mots très simples '
              'qu\'un enfant de 5 ans lit. Puis 2 actions de 3 mots max.',
        NarrationStyle.child =>
          'CONTRAINTE ABSOLUE — réponds en UNE SEULE phrase de 8 mots maximum, '
              'mots simples. Puis 2 actions de 4 mots max.',
        NarrationStyle.punchy =>
          'CONTRAINTE — réponds en UNE phrase très courte, sujet-verbe-complément.',
        NarrationStyle.normal => '',
      };

  bool get aiConfigured => aiSettings.configured;

  /// Messages affichables (on masque le 1er message = contexte technique).
  List<ChatMessage> get visibleMessages =>
      active == null || active!.messages.isEmpty
          ? const []
          : active!.messages.skip(1).toList();

  /// Les héros de la partie active.
  List<ChatPlayer> get activePlayers => active?.players ?? const [];

  bool get isDuo => activePlayers.length >= 2;

  /// Nombre d'actions déjà jouées (hors message de contexte).
  int get _completedActions => active == null
      ? 0
      : (active!.messages.where((m) => m.role == 'user').length - 1);

  /// Le héros qui doit jouer la prochaine action.
  ChatPlayer? get currentActor {
    final p = activePlayers;
    if (p.isEmpty) return null;
    return p[_completedActions % p.length];
  }

  String _actorContext(ChatPlayer? a) => a == null
      ? ''
      : 'Joueur qui agit : ${a.name} — archétype « ${a.archetype} » (${a.traits}). ';

  Future<void> loadList() async {
    stories = await chatStore.list();
    if (archetypes.isEmpty) {
      try {
        archetypes = await dataSource.loadArchetypes();
      } catch (_) {}
    }
    notifyListeners();
  }

  void closeStory() {
    active = null;
    choices = [];
    error = null;
    lastCoin = null;
    notifyListeners();
  }

  void openStory(ChatStory story) {
    active = story;
    error = null;
    lastCoin = null;
    _malusPending = false;
    lastRolls = const [];
    lastRequired = 1;
    choices = _parseChoices(_lastAssistant(story));
    notifyListeners();
  }

  /// Résume une histoire (IA si configurée, sinon récap brut de la narration).
  Future<String> summarize(ChatStory story) async {
    final sb = StringBuffer();
    for (final m in story.messages) {
      if (m.role == 'assistant') {
        sb.writeln(displayContent(m.content));
      } else if (m.display != null) {
        sb.writeln('> ${m.display}');
      }
    }
    final transcript = sb.toString().trim();
    if (transcript.isEmpty) return 'Cette histoire est vide.';
    final isChild = story.childMode;
    if (!aiSettings.configured) {
      return isChild ? 'Il était une fois… $transcript' : transcript;
    }
    try {
      return await llm.complete(
        settings: aiSettings,
        system: isChild
            ? 'Tu racontes le résumé d\'une histoire comme un CONTE pour enfant. '
                'COMMENCE OBLIGATOIREMENT par « Il était une fois ». 3 à 4 phrases '
                'TRÈS simples, douces, joyeuses et rassurantes, à la 3e personne. '
                'Pas de liste, juste un petit paragraphe magique.'
            : 'Tu résumes une partie de jeu de rôle DESTINY en 3 à 4 phrases '
                'simples et fluides, à la 3e personne. Donne l\'essentiel : qui, où, '
                'le danger, et comment ça a tourné. Pas de liste, juste un paragraphe.',
        messages: [
          ChatMessage(
              role: 'user',
              content: 'Voici la partie :\n\n$transcript\n\nRésume-la.'),
        ],
      );
    } catch (_) {
      return isChild ? 'Il était une fois… $transcript' : transcript;
    }
  }

  /// Histoires actives (non archivées) et archivées.
  List<ChatStory> get activeStories =>
      stories.where((s) => !s.archived).toList();
  List<ChatStory> get archivedStories =>
      stories.where((s) => s.archived).toList();

  Future<void> deleteStory(String id) async {
    await chatStore.delete(id);
    if (active?.id == id) closeStory();
    await loadList();
  }

  Future<void> deleteMany(Iterable<String> ids) async {
    for (final id in ids) {
      await chatStore.delete(id);
      if (active?.id == id) closeStory();
    }
    await loadList();
  }

  Future<void> setArchived(String id, bool archived) async {
    final story = stories.firstWhere(
      (s) => s.id == id,
      orElse: () => active != null && active!.id == id
          ? active!
          : throw StateError('Histoire introuvable'),
    );
    await chatStore.save(story.copyWith(archived: archived));
    await loadList();
  }

  Future<void> archiveMany(Iterable<String> ids, bool archived) async {
    final byId = {for (final s in stories) s.id: s};
    for (final id in ids) {
      final s = byId[id];
      if (s != null) await chatStore.save(s.copyWith(archived: archived));
    }
    await loadList();
  }

  Future<void> newStory({
    required List<ChatPlayer> players,
    required String universe,
    required String tone,
    required bool directAddress,
    required int maxResponses,
    required bool childMode,
  }) async {
    error = null;
    busy = true;
    _malusPending = false;
    lastRolls = const [];
    lastRequired = 1;
    notifyListeners();
    try {
      final count = players.isEmpty ? 1 : players.length;
      final story = await generateStoryUseCase.execute(playerCount: count);
      final paliers = story.danger.paliers;
      final now = DateTime.now().millisecondsSinceEpoch;
      final seed = _buildSeed(
          story, paliers, players, universe, tone, directAddress, childMode);
      final title = players.length >= 2
          ? '${players[0].name} & ${players[1].name} — $universe'
          : '${players.first.name} — $universe';
      final chat = ChatStory(
        id: 'story_${now}_${_random.nextInt(99999)}',
        title: title,
        createdAt: now,
        context: '$universe · ${story.location.name} · ${story.danger.name}',
        players: players,
        tone: tone,
        maxResponses: maxResponses,
        childMode: childMode,
        messages: [ChatMessage(role: 'user', content: seed)],
      );
      active = chat;
      notifyListeners();
      await _callAndAppend();
      await chatStore.save(active!);
      await loadList();
    } on LlmException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Impossible de démarrer : $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sendChoice(String choice) async {
    if (active == null || busy) return;
    final up = choice.toUpperCase();
    final kind = up.contains('[BRAVE]')
        ? 'brave'
        : (up.contains('[SMART]') ? 'smart' : null);
    final label =
        choice.replaceAll(RegExp(r'\[(BRAVE|SMART)\]', caseSensitive: false), '').trim();
    final actor = currentActor;
    final success = _rollAction();
    await _dispatch(ChatMessage(
      role: 'user',
      content:
          '${_actorContext(actor)}Action choisie : $choice\nRésultat des dés : ${success ? 'RÉUSSITE' : 'ÉCHEC'}.${_rollNote(success)}',
      display: label,
      kind: kind,
      result: success ? 'success' : 'fail',
      actor: actor?.name,
      actorEmoji: actor?.emoji,
    ));
  }

  /// Action libre écrite par le joueur : l'IA déduit si c'est BRAVE ou SMART.
  Future<void> sendCustomAction(String text) async {
    if (active == null || busy || text.trim().isEmpty) return;
    final actor = currentActor;
    final success = _rollAction();
    await _dispatch(ChatMessage(
      role: 'user',
      content: '${_actorContext(actor)}Action personnalisée du joueur : '
          '« ${text.trim()} ». '
          'Déduis si c\'est une action BRAVE (courage, force, affrontement) ou '
          'SMART (intelligence, ruse, observation) et indique-le brièvement. '
          'Résultat des dés : ${success ? 'RÉUSSITE' : 'ÉCHEC'}.${_rollNote(success)}',
      display: text.trim(),
      kind: null,
      result: success ? 'success' : 'fail',
      actor: actor?.name,
      actorEmoji: actor?.emoji,
    ));
  }

  Future<void> _dispatch(ChatMessage userMsg) async {
    error = null;
    // Le danger monte d'un cran toutes les 4 actions du joueur.
    final priorActions =
        active!.messages.where((m) => m.role == 'user').length - 1;
    final thisAction = priorActions + 1;
    var content = userMsg.content;
    final maxR = active!.maxResponses;
    final ending = maxR > 0 && thisAction >= maxR;
    if (!ending && thisAction % 4 == 0) {
      content +=
          '\n[MONTE LE DANGER d\'un cran maintenant : commence par « ⚡ » '
          'suivi de la sensation du palier suivant (sans écrire le mot DANGER). '
          'Si les 4 paliers sont passés, improvise une aggravation pire.]';
      // Déclenche l'éclair + le tonnerre, et arme le malus pour l'action suivante.
      dangerPulse++;
      _malusPending = true;
    }
    if (ending) {
      content +=
          '\n[C\'est la DERNIÈRE réponse de l\'histoire : amène le climax et '
          'CONCLUS par « Et c\'est ainsi que… ». N\'écris PAS de ligne CHOIX:.]';
    } else {
      // Indique pour QUI sont les 2 prochaines actions (et adapte à l'archétype).
      final players = activePlayers;
      if (players.isNotEmpty) {
        final next = players[thisAction % players.length];
        content +=
            '\n[Les 2 prochaines actions (CHOIX) sont pour ${next.name}, '
            'archétype « ${next.archetype} » (${next.traits}) : adapte la BRAVE '
            'et la SMART à ses traits.'
            '${players.length >= 2 ? ' C\'est SON tour : adresse-lui les choix.' : ''}]';
      }
      if (maxR > 0 && thisAction >= maxR - 2) {
        content +=
            '\n[On approche de la fin (réponse $thisAction sur $maxR) : commence '
            'à converger vers le climax.]';
      }
    }
    // Rappel du style en DERNIER (le modèle suit mieux la dernière consigne).
    if (_styleBrief.isNotEmpty) content += '\n[$_styleBrief]';
    active!.messages.add(ChatMessage(
      role: 'user',
      content: content,
      display: userMsg.display,
      kind: userMsg.kind,
      result: userMsg.result,
      actor: userMsg.actor,
      actorEmoji: userMsg.actorEmoji,
    ));
    choices = [];
    busy = true;
    notifyListeners();
    try {
      await _callAndAppend();
      await chatStore.save(active!);
      await loadList();
    } on LlmException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erreur lors de l\'envoi : $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _callAndAppend() async {
    var system = kGmSystemPrompt;
    if (activePlayers.length >= 2) {
      system += kGmDuoAddendum;
    }
    switch (aiSettings.narration) {
      case NarrationStyle.punchy:
        system += kGmPunchyAddendum;
      case NarrationStyle.child:
        system += kGmChildStyleAddendum;
      case NarrationStyle.petit:
        system += kGmPetitStyleAddendum;
      case NarrationStyle.normal:
        break;
    }
    if (active!.childMode) {
      system += kGmChildAddendum;
    }
    final reply = await llm.complete(
      settings: aiSettings,
      system: system,
      messages: active!.messages,
    );
    active!.messages.add(ChatMessage(role: 'assistant', content: reply));
    choices = _parseChoices(reply);
    notifyListeners();
  }

  String _buildSeed(Story story, List<String> paliers, List<ChatPlayer> players,
      String universe, String tone, bool directAddress, bool childMode) {
    final duo = players.length >= 2;
    final b = StringBuffer();
    if (childMode) {
      b.writeln('MODE ENFANT (8 ans) : tout doit être simple, gentil et '
          'rassurant. Réinterprète le lieu et le danger en version douce, '
          'rigolote et NON effrayante, adaptée à un enfant.');
    }
    if (duo) {
      b.writeln('Partie à DEUX héros (DUO). Ils jouent CHACUN leur tour, en '
          'alternance. À chaque tour, un seul héros agit et reçoit les 2 choix.');
      b.writeln(directAddress
          ? 'Narration : adresse-toi DIRECTEMENT (« tu ») au héros dont c\'est '
              'le tour, et nomme l\'autre héros présent.'
          : 'Narration : à la 3e personne, nomme chaque héros.');
    } else {
      b.writeln(directAddress
          ? 'Narration : adresse-toi DIRECTEMENT au joueur (« tu »). Parle-lui comme s\'il était le héros.'
          : 'Narration : à la 3e personne, raconte le héros par son nom.');
    }
    b.writeln('Univers : $universe. TOUTE l\'histoire se déroule dans cet '
        'univers (décor, ton, technologie, vocabulaire).');
    if (universe.toLowerCase().contains('shonen')) {
      b.writeln('Style SHONEN NEKKETSU (à la Naruto, My Hero Academia, '
          'Dragon Ball) : héros qui ne renonce JAMAIS, dépassement de soi, '
          'force de l\'amitié et des liens, techniques et pouvoirs NOMMÉS criés '
          'à voix haute, power-ups et rebondissements spectaculaires, rivaux '
          'charismatiques, émotions et énergie à fond. Adopte ce ton.');
    }
    if (tone.trim().isNotEmpty) {
      b.writeln('Ton de l\'histoire : $tone. Imprègne TOUTE la narration de ce '
          'ton, du début à la fin.');
    }
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final role =
          i < story.players.length ? story.players[i].role : 'protagoniste';
      final label = duo ? 'Héros ${i + 1}' : 'Héros';
      b.writeln('$label : ${p.name}, archétype « ${p.archetype} » '
          '(${p.traits}) — rôle : $role. Appelle-le par son nom : ${p.name}.');
    }
    b.writeln('IMPORTANT : l\'archétype décrit la PERSONNALITÉ du héros (ses '
        'traits), PAS un animal. Le héros est un personnage normal — aucune '
        'capacité animale (ni griffes, crocs, ailes, ni cris d\'animal). Adapte '
        'TOUJOURS les 2 actions (BRAVE et SMART) UNIQUEMENT à ses '
        'CARACTÉRISTIQUES de personnalité.');
    b.writeln('Lieu : ${story.location.name} (à réinterpréter dans l\'univers).');
    b.writeln('Danger : ${story.danger.name}.');
    if (paliers.isNotEmpty) {
      b.writeln('Paliers du danger (dans l\'ordre) :');
      for (var i = 0; i < paliers.length; i++) {
        b.writeln('${i + 1}. ${paliers[i]}');
      }
    }
    final first = players.first;
    final opening = switch (aiSettings.narration) {
      NarrationStyle.petit =>
        'Pose l\'ouverture en UNE phrase de 6 MOTS MAXIMUM (mots très simples '
            'pour un enfant de 5 ans qui apprend à lire)',
      NarrationStyle.child =>
        'Pose l\'ouverture en UNE phrase de 8 mots maximum (mots simples)',
      NarrationStyle.punchy =>
        'Pose l\'ouverture en UNE phrase très courte et directe',
      NarrationStyle.normal =>
        'Pose la scène d\'ouverture (palier 1, 2-3 phrases)',
    };
    b.write('$opening et propose 2 actions (une BRAVE, une SMART) adaptées à '
        '${first.name} (archétype « ${first.archetype} »).');
    return b.toString();
  }

  ChatMessage? _lastAssistantMessage(ChatStory s) {
    for (final m in s.messages.reversed) {
      if (m.role == 'assistant') return m;
    }
    return null;
  }

  String _lastAssistant(ChatStory s) => _lastAssistantMessage(s)?.content ?? '';

  // Tolère « CHOIX: », « CHOIX : », « Choix : », etc.
  static final RegExp _choixMarker =
      RegExp(r'CHOIX\s*:', caseSensitive: false);

  /// Texte affichable d'un message assistant (sans le bloc CHOIX).
  static String displayContent(String content) {
    final m = _choixMarker.firstMatch(content);
    return (m != null ? content.substring(0, m.start) : content).trim();
  }

  List<String> _parseChoices(String content) {
    final m = _choixMarker.firstMatch(content);
    if (m == null) return [];
    final block = content.substring(m.end);
    return block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('-') || l.startsWith('['))
        .map((l) => l.replaceFirst(RegExp(r'^-\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
