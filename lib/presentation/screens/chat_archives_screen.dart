import 'package:flutter/material.dart';

import '../../application/state/chat_controller.dart';
import '../../domain/entities/chat_story.dart';

enum _Sort { dateDesc, nameAsc }

/// Liste des histoires archivées, triable par date ou par nom.
class ChatArchivesScreen extends StatefulWidget {
  const ChatArchivesScreen({required this.controller, super.key});

  final ChatController controller;

  @override
  State<ChatArchivesScreen> createState() => _ChatArchivesScreenState();
}

class _ChatArchivesScreenState extends State<ChatArchivesScreen> {
  _Sort _sort = _Sort.dateDesc;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  List<ChatStory> get _items {
    final list = [...widget.controller.archivedStories];
    switch (_sort) {
      case _Sort.dateDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.nameAsc:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  Future<void> _showSummary(ChatStory s) async {
    final future = widget.controller.summarize(s);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.summarize, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(s.title,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<String>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: Text(snap.data ?? 'Résumé indisponible.',
                    style: const TextStyle(height: 1.5)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archives'),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: 'Trier',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _Sort.dateDesc, child: Text('Par date')),
              PopupMenuItem(value: _Sort.nameAsc, child: Text('Par nom')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: items.isEmpty
            ? const Center(
                child: Text('Aucune histoire archivée.',
                    style: TextStyle(color: Colors.white54)),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final s in items)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.inventory_2_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(s.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Résumé',
                              icon: const Icon(Icons.summarize),
                              onPressed: () => _showSummary(s),
                            ),
                            IconButton(
                              tooltip: 'Restaurer',
                              icon: const Icon(Icons.unarchive_outlined),
                              onPressed: () =>
                                  widget.controller.setArchived(s.id, false),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  widget.controller.deleteStory(s.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          widget.controller.openStory(s);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
