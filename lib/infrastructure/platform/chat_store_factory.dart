import '../../domain/repositories/chat_store.dart';
import 'chat_store_factory_io.dart'
    if (dart.library.html) 'chat_store_factory_web.dart' as impl;

/// Construit le [ChatStore] adapté à la plateforme (SQLite persistant sur
/// mobile/desktop, en mémoire sur le web).
ChatStore createChatStore() => impl.createChatStore();
