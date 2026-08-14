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
  // Mode sélection multiple (pour tout sélectionner / tout supprimer).
  bool _selectMode = false;
  final Set<String> _selected = {};

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

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selected.clear();
    });
  }

  void _toggleOne(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _toggleAll(List<ChatStory> items) {
    setState(() {
      if (_selected.length == items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(items.map((s) => s.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    if (n == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la sélection ?'),
        content: Text('Supprimer $n histoire${n > 1 ? 's' : ''} archivée'
            '${n > 1 ? 's' : ''} ? Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.deleteMany(_selected.toList());
      if (mounted) {
        setState(() {
          _selectMode = false;
          _selected.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    final allSelected = items.isNotEmpty && _selected.length == items.length;
    return Scaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Annuler',
                onPressed: _toggleSelectMode,
              )
            : null,
        title: Text(_selectMode
            ? '${_selected.length} sélectionné${_selected.length > 1 ? 's' : ''}'
            : 'Archives'),
        actions: _selectMode
            ? [
                IconButton(
                  tooltip: allSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                  onPressed: items.isEmpty ? null : () => _toggleAll(items),
                ),
                IconButton(
                  tooltip: 'Supprimer la sélection',
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
              ]
            : [
                if (items.isNotEmpty)
                  IconButton(
                    tooltip: 'Sélectionner',
                    icon: const Icon(Icons.checklist),
                    onPressed: _toggleSelectMode,
                  ),
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
                        leading: _selectMode
                            ? Checkbox(
                                value: _selected.contains(s.id),
                                onChanged: (_) => _toggleOne(s.id),
                              )
                            : Icon(Icons.inventory_2_outlined,
                                color: theme.colorScheme.primary),
                        title: Text(s.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: _selectMode
                            ? null
                            : Row(
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
                                    onPressed: () => widget.controller
                                        .setArchived(s.id, false),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        widget.controller.deleteStory(s.id),
                                  ),
                                ],
                              ),
                        onTap: _selectMode
                            ? () => _toggleOne(s.id)
                            : () {
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
