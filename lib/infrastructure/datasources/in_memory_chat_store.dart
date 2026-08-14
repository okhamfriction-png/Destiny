import '../../domain/entities/chat_story.dart';
import '../../domain/repositories/chat_store.dart';

/// Implémentation en mémoire de [ChatStore] (web / tests). Non persistée.
class InMemoryChatStore implements ChatStore {
  final List<ChatStory> _stories = [];

  @override
  Future<List<ChatStory>> list() async {
    final copy = [..._stories];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  @override
  Future<void> save(ChatStory story) async {
    final i = _stories.indexWhere((s) => s.id == story.id);
    if (i >= 0) {
      _stories[i] = story;
    } else {
      _stories.add(story);
    }
  }

  @override
  Future<void> delete(String id) async {
    _stories.removeWhere((s) => s.id == id);
  }
}
