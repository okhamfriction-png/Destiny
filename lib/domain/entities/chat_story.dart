import 'chat_message.dart';

/// Un joueur (héros) d'une partie de chat : nom + archétype choisi.
class ChatPlayer {
  const ChatPlayer({
    required this.name,
    required this.archetype,
    required this.traits,
    this.emoji,
  });

  final String name;

  /// Nom de l'archétype (ex. « Le Rebelle »).
  final String archetype;

  /// Traits de l'archétype.
  final String traits;

  /// Emoji de l'archétype (pour l'affichage).
  final String? emoji;

  factory ChatPlayer.fromJson(Map<String, dynamic> json) => ChatPlayer(
        name: json['name'] as String,
        archetype: json['archetype'] as String? ?? '',
        traits: json['traits'] as String? ?? '',
        emoji: json['emoji'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'archetype': archetype,
        'traits': traits,
        if (emoji != null) 'emoji': emoji,
      };
}

/// Une histoire de chat (partie de jeu de rôle menée par l'IA), persistée.
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

  /// Nombre de réponses visé avant clôture (0 = illimité).
  final int maxResponses;

  /// Mode enfant (vocabulaire et contenu adaptés ~8 ans).
  final bool childMode;

  /// Vrai si l'histoire est archivée (masquée de la liste principale).
  final bool archived;

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
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}
