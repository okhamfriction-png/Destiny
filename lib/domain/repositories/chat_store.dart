import '../entities/chat_story.dart';

/// Stockage persistant des histoires de chat.
abstract class ChatStore {
  /// Toutes les histoires, les plus récentes d'abord.
  Future<List<ChatStory>> list();

  /// Insère ou met à jour une histoire (par `id`).
  Future<void> save(ChatStory story);

  Future<void> delete(String id);
}
