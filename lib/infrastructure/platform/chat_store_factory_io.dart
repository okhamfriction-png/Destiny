import '../../domain/repositories/chat_store.dart';
import '../datasources/sqlite_chat_store.dart';

ChatStore createChatStore() => SqliteChatStore();
