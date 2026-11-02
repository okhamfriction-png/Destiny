import 'package:flutter/material.dart';

import '../../application/state/chat_controller.dart';
import '../../domain/entities/chat_story.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';

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

  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('archives.histoires.$x', v);

  List<ChatStory> get _items {
    final list = [...widget.controller.archivedStories];
    switch (_sort) {
      case _Sort.dateDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.nameAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  Future<void> _showSummary(ChatStory s) async {
    final future = widget.controller.summarize(s);
    if (!mounted) return;
    final indisponible = k('resume_indisponible');
    final fermer = k('fermer');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.summarize, size: 20, color: context.destiny.titre),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
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
                child: Text(
                  snap.data ?? indisponible,
                  style: TextStyle(fontFamily: kPoliceTexte, height: 1.5, color: context.destiny.texte),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(fermer)),
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
        title: Text(k('supprimer_titre')),
        content: Text(n > 1 ? k('supprimer_n', {'n': '$n'}) : k('supprimer_un')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('supprimer'))),
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
    final c = context.destiny;
    final items = _items;
    final allSelected = items.isNotEmpty && _selected.length == items.length;
    final n = _selected.length;
    return Scaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: k('quitter_selection'),
                onPressed: _toggleSelectMode,
              )
            : null,
        title: Text(_selectMode ? (n > 1 ? k('selection', {'n': '$n'}) : k('selection_un', {'n': '$n'})) : k('titre')),
        actions: _selectMode
            ? [
                IconButton(
                  tooltip: allSelected ? k('tout_deselectionner') : k('tout_selectionner'),
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                  onPressed: items.isEmpty ? null : () => _toggleAll(items),
                ),
                IconButton(
                  tooltip: k('supprimer_selection'),
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
              ]
            : [
                if (items.isNotEmpty)
                  IconButton(
                    tooltip: k('selectionner'),
                    icon: const Icon(Icons.checklist),
                    onPressed: _toggleSelectMode,
                  ),
                PopupMenuButton<_Sort>(
                  tooltip: k('trier'),
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: _Sort.dateDesc, child: Text(k('par_date'))),
                    PopupMenuItem(value: _Sort.nameAsc, child: Text(k('par_nom'))),
                  ],
                ),
              ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  k('vide'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, color: c.texteSecondaire),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final s in items)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: _selectMode
                              ? Checkbox(
                                  value: _selected.contains(s.id),
                                  onChanged: (_) => _toggleOne(s.id),
                                )
                              : Icon(Icons.inventory_2_outlined, color: c.titre),
                          title: Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.texte),
                          ),
                          trailing: _selectMode
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: k('resume'),
                                      icon: const Icon(Icons.summarize),
                                      color: c.texteSecondaire,
                                      onPressed: () => _showSummary(s),
                                    ),
                                    IconButton(
                                      tooltip: k('desarchiver'),
                                      icon: const Icon(Icons.unarchive_outlined),
                                      color: c.texteSecondaire,
                                      onPressed: () => widget.controller.setArchived(s.id, false),
                                    ),
                                    IconButton(
                                      tooltip: k('supprimer'),
                                      icon: const Icon(Icons.delete_outline),
                                      color: c.texteSecondaire,
                                      onPressed: () => widget.controller.deleteStory(s.id),
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
                    ),
                  ),
              ],
            ),
    );
  }
}
