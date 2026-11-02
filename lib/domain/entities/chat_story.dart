import 'chat_message.dart';

/// Un héros d'une histoire avec l'IA : son nom, son archétype et son animal,
/// et les couches connues de son personnage.
class ChatPlayer {
  const ChatPlayer({
    required this.name,
    this.archetypeId = '',
    this.animalId = '',
    this.blessure = '',
    this.vouloir = '',
    this.besoin = '',
    this.archetype = '',
    this.traits = '',
    this.emoji,
  });

  final String name;
  final String archetypeId;
  final String animalId;
  final String blessure;
  final String vouloir;
  final String besoin;

  /// Le nom affiché de l'archétype (et, pour les anciennes histoires, celui
  /// de l'ancien « archétype animal »).
  final String archetype;

  /// Traits de l'ancien archétype animal (anciennes histoires seulement).
  final String traits;

  /// L'icône de son animal.
  final String? emoji;

  factory ChatPlayer.fromJson(Map<String, dynamic> json) => ChatPlayer(
        name: json['name'] as String,
        archetypeId: json['archetype_id'] as String? ?? '',
        animalId: json['animal_id'] as String? ?? '',
        blessure: json['blessure'] as String? ?? '',
        vouloir: json['vouloir'] as String? ?? '',
        besoin: json['besoin'] as String? ?? '',
        archetype: json['archetype'] as String? ?? '',
        traits: json['traits'] as String? ?? '',
        emoji: json['emoji'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (archetypeId.isNotEmpty) 'archetype_id': archetypeId,
        if (animalId.isNotEmpty) 'animal_id': animalId,
        if (blessure.isNotEmpty) 'blessure': blessure,
        if (vouloir.isNotEmpty) 'vouloir': vouloir,
        if (besoin.isNotEmpty) 'besoin': besoin,
        'archetype': archetype,
        'traits': traits,
        if (emoji != null) 'emoji': emoji,
      };
}

/// Une histoire avec l'IA (partie de jeu de rôle menée par le Maître du
/// destin), persistée.
class ChatStory {
  ChatStory({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.context,
    required this.messages,
    this.players = const [],
    this.tone = '',
    this.maxResponses = 0,
    this.childMode = false,
    this.archived = false,
    this.systeme = '',
    this.versionPrompts = '',
    this.paliers = const [],
    this.malus = false,
  });

  final String id;
  final String title;
  final int createdAt; // epoch ms
  /// Résumé lisible (lieu · danger · personnages).
  final String context;
  final List<ChatMessage> messages;

  /// Les héros de la partie (1 = solo, 2 = duo).
  final List<ChatPlayer> players;

  /// Ton de l'histoire (Humour, Drame, Voyage initiatique…).
  final String tone;

  /// Nombre de réponses visé avant clôture, réparti en quatre chapitres.
  final int maxResponses;

  /// Mode enfant (vocabulaire et contenu adaptés).
  final bool childMode;

  /// Vrai si l'histoire est archivée (masquée de la liste principale).
  final bool archived;

  /// Le prompt système de la partie, gardé tel quel pour la reprendre.
  final String systeme;

  /// La version des prompts qui l'a créée. Vide : une histoire de l'ancienne
  /// grammaire, qui se relit mais ne se reprend pas.
  final String versionPrompts;

  /// Les quatre phrases du danger, une par palier.
  final List<String> paliers;

  /// Après chaque Destiny, la pièce est plus dure (2 réussites sur 2).
  final bool malus;

  bool get ancienneGrammaire => versionPrompts.isEmpty;

  ChatStory copyWith({bool? archived}) => ChatStory(
        id: id,
        title: title,
        createdAt: createdAt,
        context: context,
        messages: messages,
        players: players,
        tone: tone,
        maxResponses: maxResponses,
        childMode: childMode,
        archived: archived ?? this.archived,
        systeme: systeme,
        versionPrompts: versionPrompts,
        paliers: paliers,
        malus: malus,
      );

  factory ChatStory.fromJson(Map<String, dynamic> json) => ChatStory(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: json['createdAt'] as int,
        context: json['context'] as String? ?? '',
        players: (json['players'] as List<dynamic>? ?? [])
            .map((e) => ChatPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        tone: json['tone'] as String? ?? '',
        maxResponses: json['maxResponses'] as int? ?? 0,
        childMode: json['childMode'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        systeme: json['systeme'] as String? ?? '',
        versionPrompts: json['version_prompts'] as String? ?? '',
        paliers: [for (final p in (json['paliers'] as List<dynamic>? ?? const [])) '$p'],
        malus: json['malus'] as bool? ?? false,
        messages: (json['messages'] as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'context': context,
        'players': players.map((p) => p.toJson()).toList(),
        'tone': tone,
        'maxResponses': maxResponses,
        'childMode': childMode,
        'archived': archived,
        'systeme': systeme,
        'version_prompts': versionPrompts,
        'paliers': paliers,
        'malus': malus,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}
