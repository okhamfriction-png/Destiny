class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.display,
    this.kind,
    this.result,
    this.actor,
    this.actorEmoji,
  });

  /// 'user' ou 'assistant'.
  final String role;

  /// Contenu envoyé au modèle (peut inclure des consignes internes).
  final String content;

  /// Texte propre à afficher (sinon [content]).
  final String? display;

  /// Pour une action du joueur : 'brave', 'smart' ou null (action perso).
  final String? kind;

  /// Résultat de la pièce : 'success', 'fail' ou null.
  final String? result;

  /// Nom du joueur qui a agi (mode duo / affichage archétype).
  final String? actor;

  /// Emoji de l'archétype du joueur qui a agi.
  final String? actorEmoji;

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        display: json['display'] as String?,
        kind: json['kind'] as String?,
        result: json['result'] as String?,
        actor: json['actor'] as String?,
        actorEmoji: json['actorEmoji'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (display != null) 'display': display,
        if (kind != null) 'kind': kind,
        if (result != null) 'result': result,
        if (actor != null) 'actor': actor,
        if (actorEmoji != null) 'actorEmoji': actorEmoji,
      };
}
