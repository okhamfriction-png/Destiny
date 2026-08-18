import 'package:flutter/material.dart';

import '../../application/state/location_details.dart';

/// Liste des lieux (paramètres) : choisir un lieu pour éditer ses détails.
class LocationDetailsListScreen extends StatefulWidget {
  const LocationDetailsListScreen({required this.store, super.key});
  final LocationDetailsStore store;

  @override
  State<LocationDetailsListScreen> createState() =>
      _LocationDetailsListScreenState();
}

class _LocationDetailsListScreenState extends State<LocationDetailsListScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations = widget.store.locations;
    return Scaffold(
      appBar: AppBar(title: const Text('Détails des lieux')),
      body: Container(
        decoration: _bg,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Text(
                'Sous-espaces et vocabulaire par lieu. Touche un lieu pour '
                'éditer.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ),
            for (final l in locations)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  leading:
                      const Icon(Icons.place_outlined, color: Color(0xFFFFC24B)),
                  title: Text(l.name),
                  subtitle: Builder(builder: (context) {
                    final d = widget.store.byId(l.id);
                    final n = (d?.sousEspaces.length ?? 0);
                    final v = (d?.vocabulaire.length ?? 0);
                    return Text('$n sous-espaces · $v mots'
                        '${widget.store.hasOverride(l.id) ? ' · modifié' : ''}');
                  }),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LocationDetailsEditScreen(
                      store: widget.store,
                      locationId: l.id,
                      locationName: l.name,
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const Color _gold = Color(0xFFFFC24B);

const BoxDecoration _bg = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141029), Color(0xFF0A0818)],
  ),
);

/// Consultation des détails d'un lieu : sous-espaces jouables + vocabulaire.
/// Lecture seule (l'édition se fait dans les paramètres).
class LocationDetailsScreen extends StatelessWidget {
  const LocationDetailsScreen({
    required this.store,
    required this.locationName,
    super.key,
  });

  final LocationDetailsStore store;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = store.byName(locationName);
    return Scaffold(
      appBar: AppBar(title: Text('Lieu : $locationName')),
      body: Container(
        decoration: _bg,
        child: (details == null || details.isEmpty)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun détail pour ce lieu.\n'
                    'Ajoute des sous-espaces et du vocabulaire dans '
                    'Paramètres → Détails des lieux.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(
                    context,
                    icon: Icons.place_outlined,
                    title: 'Sous-espaces',
                    subtitle: 'Des endroits jouables à l\'intérieur du lieu.',
                    items: details.sousEspaces,
                  ),
                  const SizedBox(height: 20),
                  _section(
                    context,
                    icon: Icons.record_voice_over_outlined,
                    title: 'Vocabulaire',
                    subtitle: 'Mots, objets et fonctions propres au lieu.',
                    items: details.vocabulaire,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> items,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _gold, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: _gold, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final it in items)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Text(it,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Éditeur des détails d'un lieu (sous-espaces + vocabulaire). Admin.
class LocationDetailsEditScreen extends StatefulWidget {
  const LocationDetailsEditScreen({
    required this.store,
    required this.locationId,
    required this.locationName,
    super.key,
  });

  final LocationDetailsStore store;
  final String locationId;
  final String locationName;

  @override
  State<LocationDetailsEditScreen> createState() =>
      _LocationDetailsEditScreenState();
}

class _LocationDetailsEditScreenState extends State<LocationDetailsEditScreen> {
  late List<TextEditingController> _sous;
  late List<TextEditingController> _voc;

  @override
  void initState() {
    super.initState();
    final d = widget.store.byId(widget.locationId);
    _sous = [for (final s in d?.sousEspaces ?? const []) TextEditingController(text: s)];
    _voc = [for (final s in d?.vocabulaire ?? const []) TextEditingController(text: s)];
    if (_sous.isEmpty) _sous.add(TextEditingController());
    if (_voc.isEmpty) _voc.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _sous) {
      c.dispose();
    }
    for (final c in _voc) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final details = LocationDetails(
      sousEspaces: [
        for (final c in _sous)
          if (c.text.trim().isNotEmpty) c.text.trim()
      ],
      vocabulaire: [
        for (final c in _voc)
          if (c.text.trim().isNotEmpty) c.text.trim()
      ],
    );
    await widget.store.setDetails(widget.locationId, details);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Éditer : ${widget.locationName}'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Enregistrer')),
        ],
      ),
      body: Container(
        decoration: _bg,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _editList(
              title: 'Sous-espaces',
              controllers: _sous,
              onAdd: () => setState(() => _sous.add(TextEditingController())),
              onRemove: (i) => setState(() => _sous.removeAt(i).dispose()),
            ),
            const SizedBox(height: 20),
            _editList(
              title: 'Vocabulaire',
              controllers: _voc,
              onAdd: () => setState(() => _voc.add(TextEditingController())),
              onRemove: (i) => setState(() => _voc.removeAt(i).dispose()),
            ),
            const SizedBox(height: 24),
            if (widget.store.hasOverride(widget.locationId))
              TextButton.icon(
                onPressed: () async {
                  await widget.store.resetToDefault(widget.locationId);
                  if (mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.restore),
                label: const Text('Restaurer les valeurs d\'origine'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editList({
    required String title,
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: _gold, fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        for (var i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
