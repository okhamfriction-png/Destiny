import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_story.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/repositories/chat_store.dart';
import '../../infrastructure/datasources/grammaire_source.dart';
import '../prompts/prompts.dart';
import '../services/llm_service.dart';
import 'ai_settings.dart';

/// Le jeu avec l'IA : le Maître du destin raconte, le joueur décide. Quatre
/// chapitres, un par palier ; Destiny entre deux chapitres ; la pièce du
/// destin tranche chaque action.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.chatStore,
    required this.llm,
    required this.aiSettings,
    required this.catalogue,
    required this.grammaire,
    Random? hasard,
  }) : _random = hasard ?? Random();

  final ChatStore chatStore;
  final LlmService llm;
  final AiSettings aiSettings;

  /// Le catalogue de l'appli (lieux et dangers de Destiny).
  final CatalogStore catalogue;
  final GrammaireChargee grammaire;

  final Random _random;

  Grammaire get _g => grammaire.grammaire;

  List<ChatStory> stories = [];
  ChatStory? active;
  List<String> choices = [];
  bool busy = false;
  String? error;
  String? lastCoin; // 'RÉUSSITE' ou 'ÉCHEC'

  /// Incrémenté à chaque résolution d'action (déclenche l'animation).
  int resultPulse = 0;
  bool lastSuccess = false;

  /// Incrémenté à chaque Destiny (déclenche l'éclair et le tonnerre).
  int dangerPulse = 0;

  /// Option : après un Destiny, la prochaine action exige 2 réussites sur 2
  /// lancers de la pièce.
  bool _malusPending = false;
  bool get malusPending => _malusPending;

  /// Les lancers de la pièce pour la dernière action (pour l'affichage).
  List<bool> lastRolls = const [];
  int lastRequired = 1;

  bool get aiConfigured => aiSettings.configured;

  /// Une histoire de l'ancienne grammaire se relit, mais ne se reprend pas.
  bool get lectureSeule => active?.ancienneGrammaire ?? false;

  /// Messages affichables (on masque le 1er message = contexte technique).
  List<ChatMessage> get visibleMessages =>
      active == null || active!.messages.isEmpty ? const [] : active!.messages.skip(1).toList();

  /// Les héros de la partie active.
  List<ChatPlayer> get activePlayers => active?.players ?? const [];

  bool get isDuo => activePlayers.length >= 2;

  /// Nombre d'actions déjà jouées (hors message de contexte).
  int get _completedActions =>
      active == null ? 0 : (active!.messages.where((m) => m.role == 'user').length - 1);

  /// Le chapitre (1 à 4) de l'action numéro [action] (à partir de 1), sur
  /// [total] réponses : quatre chapitres égaux.
  static int chapitreDe(int action, int total) {
    if (total <= 0) return 1;
    return (((action - 1).clamp(0, total) * 4) ~/ total + 1).clamp(1, 4);
  }

  /// Le chapitre en cours de la partie active.
  int get chapitre => chapitreDe(_completedActions + 1, active?.maxResponses ?? 0);

  /// Le palier en cours (un par chapitre).
  PalierId get palier => PalierId.deNumero(chapitre);

  /// Le héros qui doit jouer la prochaine action.
  ChatPlayer? get currentActor {
    final p = activePlayers;
    if (p.isEmpty) return null;
    return p[_completedActions % p.length];
  }

  /// La pièce du destin : 1 lancer, ou 2 sous l'option « plus dure ».
  bool _lancerLaPiece() {
    final requis = _malusPending ? 2 : 1;
    _malusPending = false;
    lastRequired = requis;
    final lancers = [for (var i = 0; i < requis; i++) _random.nextBool()];
    final reussite = lancers.where((x) => x).length >= requis;
    lastRolls = lancers;
    lastSuccess = reussite;
    lastCoin = reussite ? 'RÉUSSITE' : 'ÉCHEC';
    resultPulse++;
    return reussite;
  }

  StyleNarration get _style => switch (aiSettings.narration) {
        NarrationStyle.petit => StyleNarration.petit,
        NarrationStyle.child => StyleNarration.enfant,
        NarrationStyle.punchy => StyleNarration.percutant,
        NarrationStyle.normal => StyleNarration.normal,
      };

  String _acteur(ChatPlayer? a) {
    if (a == null) return '';
    final arch = _g.archetype(a.archetypeId)?.nom ?? a.archetype;
    return 'Héros qui agit : ${a.name}${arch.isEmpty ? '' : ' (archétype : $arch)'}. ';
  }

  Future<void> loadList() async {
    stories = await chatStore.list();
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
    choices = story.ancienneGrammaire ? const [] : _parseChoices(_lastAssistant(story));
    notifyListeners();
  }

  /// Résume une histoire, à la façon du coach de débrief (IA si configurée,
  /// sinon le récit brut).
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
    if (!aiSettings.configured) return story.childMode ? 'Il était une fois… $transcript' : transcript;
    final heros = story.players.map((p) => p.name).join(', ');
    try {
      return await llm.complete(
        settings: aiSettings,
        system: promptResumeHistoire(g: _g, kids: story.childMode),
        messages: [
          ChatMessage(role: 'user', content: 'Les héros : $heros.\n\nLa partie :\n\n$transcript\n\nRésume-la.'),
        ],
      );
    } catch (_) {
      return story.childMode ? 'Il était une fois… $transcript' : transcript;
    }
  }

  /// Histoires actives (non archivées) et archivées.
  List<ChatStory> get activeStories => stories.where((s) => !s.archived).toList();
  List<ChatStory> get archivedStories => stories.where((s) => s.archived).toList();

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
      orElse: () => active != null && active!.id == id ? active! : throw StateError('Histoire introuvable'),
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

  /// Une nouvelle histoire : le lieu et le danger sont tirés dans le
  /// catalogue de Destiny (filtrés en mode enfant), le groupe dans les idées
  /// de groupes ; les autres personnages du groupe complètent une
  /// distribution équilibrée, joués par l'IA.
  Future<void> newStory({
    required List<ChatPlayer> players,
    required String universe,
    required String tone,
    required bool directAddress,
    required int maxResponses,
    required bool childMode,
    bool malus = false,
  }) async {
    error = null;
    busy = true;
    _malusPending = false;
    lastRolls = const [];
    lastRequired = 1;
    notifyListeners();
    try {
      final lieux = [for (final l in await catalogue.getLocations()) if (l.actif && (!childMode || l.kids)) l];
      final dangers = [
        for (final d in await catalogue.getDangers())
          if (d.actif && d.paliers.length == 4 && (!childMode || d.kids)) d,
      ];
      if (lieux.isEmpty || dangers.isEmpty) {
        error = 'Le catalogue de lieux et de dangers est vide.';
        return;
      }
      final lieu = lieux[_random.nextInt(lieux.length)];
      final danger = dangers[_random.nextInt(dangers.length)];
      final paliers = danger.paliersPour(kids: childMode);
      final groupes = grammaire.textes.liste('mise_en_place.groupes');
      final groupe = groupes.isEmpty ? '' : groupes[_random.nextInt(groupes.length)];

      // Les autres membres du groupe, joués par l'IA.
      final imposes = [for (final p in players) if (p.archetypeId.isNotEmpty) p.archetypeId];
      final distribution = tirerDistribution(_g, 4, hasard: _random, imposes: imposes);
      final autres = <PersonnagePrompt>[];
      for (final id in distribution) {
        if (imposes.contains(id)) continue;
        autres.add(PersonnagePrompt(
          nom: _g.archetype(id)?.nom ?? id,
          archetypeId: id,
          animalId: tirerAnimal(_g, id, hasard: _random),
          joueur: false,
        ));
      }
      final scene = ScenePrompt(
        lieu: lieu.name,
        espaces: lieu.espaces,
        groupe: groupe,
        danger: danger.name,
        paliers: paliers,
        univers: universe,
        ton: tone,
      );
      final heros = [
        for (final p in players)
          PersonnagePrompt(
            nom: p.name,
            archetypeId: p.archetypeId,
            animalId: p.animalId,
            blessure: p.blessure,
            vouloir: p.vouloir,
            besoin: p.besoin,
          ),
      ];
      final systeme = promptMaitreDuDestin(g: _g, scene: scene, heros: heros, autres: autres, kids: childMode) +
          styleNarration(_style, duo: players.length >= 2);

      final duo = players.length >= 2;
      final seed = StringBuffer()
        ..writeln(duo
            ? (directAddress
                ? 'Narration : adresse-toi directement (« tu ») au héros dont c\'est le tour, et nomme l\'autre.'
                : 'Narration : à la troisième personne, nomme chaque héros.')
            : (directAddress
                ? 'Narration : adresse-toi directement au joueur (« tu »), comme s\'il était le héros.'
                : 'Narration : à la troisième personne, par le nom du héros.'))
        ..writeln('[Chapitre 1 — palier 1 : ${_g.palier(PalierId.signale).nom}.]')
        ..write('Ouvre la partie au palier 1, puis propose 2 actions (une BRAVE, une SMART) pour ${players.first.name}.');
      if (rappelStyle(_style).isNotEmpty) seed.write('\n[${rappelStyle(_style)}]');

      final now = DateTime.now().millisecondsSinceEpoch;
      final title = duo ? '${players[0].name} & ${players[1].name} — $universe' : '${players.first.name} — $universe';
      active = ChatStory(
        id: 'story_${now}_${_random.nextInt(99999)}',
        title: title,
        createdAt: now,
        context: '$universe · ${lieu.name} · ${danger.name}',
        players: players,
        tone: tone,
        maxResponses: maxResponses,
        childMode: childMode,
        systeme: systeme,
        versionPrompts: kVersionPrompts,
        paliers: paliers,
        malus: malus,
        messages: [ChatMessage(role: 'user', content: seed.toString())],
      );
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
    if (active == null || busy || lectureSeule) return;
    final up = choice.toUpperCase();
    final kind = up.contains('[BRAVE]') ? 'brave' : (up.contains('[SMART]') ? 'smart' : null);
    final label = choice.replaceAll(RegExp(r'\[(BRAVE|SMART)\]', caseSensitive: false), '').trim();
    final actor = currentActor;
    final success = _lancerLaPiece();
    await _dispatch(ChatMessage(
      role: 'user',
      content: '${_acteur(actor)}Action choisie : $choice\n${_resultat(success)}',
      display: label,
      kind: kind,
      result: success ? 'success' : 'fail',
      actor: actor?.name,
      actorEmoji: actor?.emoji,
    ));
  }

  /// Action libre écrite par le joueur : l'IA déduit si c'est BRAVE ou SMART.
  Future<void> sendCustomAction(String text) async {
    if (active == null || busy || lectureSeule || text.trim().isEmpty) return;
    final actor = currentActor;
    final success = _lancerLaPiece();
    await _dispatch(ChatMessage(
      role: 'user',
      content: '${_acteur(actor)}Action écrite par le joueur : « ${text.trim()} ». '
          'Déduis si c\'est une action BRAVE ou SMART et note-le.\n${_resultat(success)}',
      display: text.trim(),
      kind: null,
      result: success ? 'success' : 'fail',
      actor: actor?.name,
      actorEmoji: actor?.emoji,
    ));
  }

  String _resultat(bool success) =>
      'La pièce du destin a tranché : ${success ? 'RÉUSSITE' : 'ÉCHEC'}.'
      '${lastRequired >= 2 ? ' (Après Destiny, il fallait deux réussites.)' : ''}';

  Future<void> _dispatch(ChatMessage userMsg) async {
    error = null;
    final s = active!;
    final thisAction = _completedActions + 1;
    final total = s.maxResponses;
    final fin = total > 0 && thisAction >= total;
    final ch = chapitreDe(thisAction, total);
    final chAvant = chapitreDe(thisAction - 1, total);
    final palier = _g.palier(PalierId.deNumero(ch));
    final b = StringBuffer(userMsg.content)..write('\n[Chapitre $ch — palier ${palier.id.numero} : ${palier.nom}.]');
    if (thisAction > 1 && ch > chAvant) {
      // Le passage d'un chapitre à l'autre : Destiny, lancé de l'extérieur.
      final nouvelle = ch - 1 < s.paliers.length ? s.paliers[ch - 1] : '';
      b.write('\n[DESTINY : écris le rituel, l\'ellipse, puis la nouvelle du palier (ce qu\'on entend du danger, et la '
          'réaction d\'un personnage) : $nouvelle]');
      if (ch == 2) b.write('\n[Premier figé : chacun sait en silence ce qu\'il veut, et ce dont il a besoin.]');
      dangerPulse++;
      if (s.malus) _malusPending = true;
    }
    if (fin) {
      b.write('\n[C\'est la DERNIÈRE réponse : le choix est fait, le prix est payé. Conclus par « Et c\'est ainsi '
          'que… », une image par héros. Pas de ligne CHOIX:.]');
    } else {
      final players = activePlayers;
      if (players.isNotEmpty) {
        final next = players[thisAction % players.length];
        final arch = _g.archetype(next.archetypeId)?.nom ?? next.archetype;
        b.write('\n[Les 2 prochaines actions sont pour ${next.name}${arch.isEmpty ? '' : ' (archétype : $arch)'}.'
            '${players.length >= 2 ? ' C\'est son tour : adresse-lui les choix.' : ''}]');
      }
      if (ch == 4) {
        b.write('\n[Chapitre 4 : ne remonte plus la tension. Les 2 actions sont le choix final : l\'une sert son '
            'vouloir, l\'autre son besoin.]');
      }
    }
    if (rappelStyle(_style).isNotEmpty) b.write('\n[${rappelStyle(_style)}]');
    s.messages.add(ChatMessage(
      role: 'user',
      content: b.toString(),
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
      await chatStore.save(s);
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
    final reply = await llm.complete(settings: aiSettings, system: active!.systeme, messages: active!.messages);
    active!.messages.add(ChatMessage(role: 'assistant', content: reply));
    choices = _parseChoices(reply);
    notifyListeners();
  }

  ChatMessage? _lastAssistantMessage(ChatStory s) {
    for (final m in s.messages.reversed) {
      if (m.role == 'assistant') return m;
    }
    return null;
  }

  String _lastAssistant(ChatStory s) => _lastAssistantMessage(s)?.content ?? '';

  // Tolère « CHOIX: », « CHOIX : », « Choix : », etc.
  static final RegExp _choixMarker = RegExp(r'CHOIX\s*:', caseSensitive: false);

  /// Texte affichable d'un message assistant (sans le bloc CHOIX).
  static String displayContent(String content) {
    final m = _choixMarker.firstMatch(content);
    return (m != null ? content.substring(0, m.start) : content).trim();
  }

  static List<String> _parseChoices(String content) {
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
