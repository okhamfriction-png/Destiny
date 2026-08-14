import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/catalog_store.dart';
import '../visuals/entity_visuals.dart';
import '../widgets/entity_image.dart';

const List<String> _dangerStyles = [
  'Catastrophe',
  'Fantastique',
  'Mystère',
  'Social / Dilemme',
  'Survie / Dilemme',
  'Thriller',
  'Libre',
];

const List<String> _defaultRoles = [
  'protagoniste',
  'témoin',
  'responsable',
  'intrus',
  'expert',
  'novice',
];

class CatalogEditorScreen extends StatefulWidget {
  const CatalogEditorScreen({required this.catalogStore, super.key});

  final CatalogStore catalogStore;

  @override
  State<CatalogEditorScreen> createState() => _CatalogEditorScreenState();
}

class _CatalogEditorScreenState extends State<CatalogEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  List<Location> _locations = const [];
  List<Danger> _dangers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final locations = await widget.catalogStore.getLocations();
    final dangers = await widget.catalogStore.getDangers();
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _dangers = dangers;
      _loading = false;
    });
  }

  // --- Helpers ---
  String _slug(String input) {
    var s = input.toLowerCase();
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    s = s
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'item' : s;
  }

  String _uniqueId(String base, Set<String> existing) {
    var id = base;
    var n = 1;
    while (existing.contains(id)) {
      id = '${base}_$n';
      n++;
    }
    return id;
  }

  Future<String?> _promptText(String title, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « $name » ?'),
        content: const Text('Cette suppression est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // --- Locations ---
  Future<void> _addLocation() async {
    final name = await _promptText('Nouveau lieu');
    if (name == null || name.isEmpty) return;
    final id = _uniqueId(_slug(name), _locations.map((l) => l.id).toSet());
    await widget.catalogStore.saveLocation(Location(
      id: id,
      name: name,
      roles: _defaultRoles,
      rue: false,
      actif: true,
    ));
    await _load();
  }

  Future<void> _renameLocation(Location l) async {
    final name = await _promptText('Renommer le lieu', initial: l.name);
    if (name == null || name.isEmpty) return;
    await widget.catalogStore.saveLocation(l.copyWith(name: name));
    await _load();
  }

  // --- Dangers ---
  Future<void> _addDanger() async {
    var style = _dangerStyles.first;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Nouveau danger'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nom'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: style,
                decoration: const InputDecoration(labelText: 'Style'),
                items: [
                  for (final s in _dangerStyles)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setLocal(() => style = v ?? style),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final id = _uniqueId(_slug(name), _dangers.map((d) => d.id).toSet());
    await widget.catalogStore.saveDanger(Danger(
      id: id,
      name: name,
      style: style,
      rue: false,
      actif: true,
    ));
    await _load();
  }

  Future<void> _renameDanger(Danger d) async {
    final name = await _promptText('Renommer le danger', initial: d.name);
    if (name == null || name.isEmpty) return;
    await widget.catalogStore.saveDanger(d.copyWith(name: name));
    await _load();
  }

  Future<void> _editPaliers(Danger d) async {
    const labels = [
      'Palier 1 — un signe, inquiétude légère',
      'Palier 2 — c\'est sérieux, il faut agir',
      'Palier 3 — danger immédiat, critique',
      'Palier 4 — climax, survie',
    ];
    final ctrls = List.generate(
      4,
      (i) => TextEditingController(
          text: i < d.paliers.length ? d.paliers[i] : ''),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Paliers — ${d.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextField(
                      controller: ctrls[i],
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: labels[i],
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final paliers =
        ctrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    await widget.catalogStore.saveDanger(d.copyWith(paliers: paliers));
    await _load();
  }

  Future<void> _restoreDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer les valeurs par défaut ?'),
        content: const Text(
          'Les lieux et dangers reviennent à la liste d\'origine de '
          'l\'application. Toutes tes modifications seront perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.catalogStore.resetToDefaults();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listes restaurées par défaut.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer lieux & dangers'),
        actions: [
          IconButton(
            tooltip: 'Restaurer les valeurs par défaut',
            icon: const Icon(Icons.restore),
            onPressed: _restoreDefaults,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Lieux'), Tab(text: 'Dangers')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tab.index == 0 ? _addLocation() : _addDanger(),
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0 ? 'Lieu' : 'Danger'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tab,
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: [
                      for (final l in _locations)
                        _EditTile(
                          visual: EntityVisuals.forLocation(l),
                          title: l.name,
                          subtitle: l.id,
                          actif: l.actif,
                          onActif: (v) async {
                            await widget.catalogStore
                                .saveLocation(l.copyWith(actif: v));
                            await _load();
                          },
                          onRename: () => _renameLocation(l),
                          onDelete: () async {
                            if (await _confirmDelete(l.name)) {
                              await widget.catalogStore.deleteLocation(l.id);
                              await _load();
                            }
                          },
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: [
                      for (final d in _dangers)
                        _EditTile(
                          visual: EntityVisuals.forDanger(d),
                          title: d.name,
                          subtitle: d.style,
                          actif: d.actif,
                          onActif: (v) async {
                            await widget.catalogStore
                                .saveDanger(d.copyWith(actif: v));
                            await _load();
                          },
                          onEditPaliers: () => _editPaliers(d),
                          onRename: () => _renameDanger(d),
                          onDelete: () async {
                            if (await _confirmDelete(d.name)) {
                              await widget.catalogStore.deleteDanger(d.id);
                              await _load();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.visual,
    required this.title,
    required this.subtitle,
    required this.actif,
    required this.onActif,
    required this.onRename,
    required this.onDelete,
    this.onEditPaliers,
  });

  final EntityVisual visual;
  final String title;
  final String subtitle;
  final bool actif;
  final ValueChanged<bool> onActif;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  /// Édition des 4 paliers (dangers uniquement).
  final VoidCallback? onEditPaliers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          children: [
            Opacity(
              opacity: actif ? 1 : 0.4,
              child: EntityImage(visual: visual, size: 48, radius: 12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white54)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Actif',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: Colors.white70)),
                      Switch(
                        value: actif,
                        onChanged: onActif,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') {
                  onRename();
                } else if (v == 'paliers') {
                  onEditPaliers?.call();
                } else {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Renommer')),
                if (onEditPaliers != null)
                  const PopupMenuItem(
                      value: 'paliers', child: Text('Modifier les paliers')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
