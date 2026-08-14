import '../../domain/repositories/chat_store.dart';
import '../datasources/in_memory_chat_store.dart';

ChatStore createChatStore() => InMemoryChatStore();
