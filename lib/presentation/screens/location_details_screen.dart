import 'package:flutter/material.dart';

import '../../application/state/location_details.dart';
import '../widgets/location_detail_section.dart';

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

/// Popup (dialogue) avec TOUTES les infos d'un lieu : sous-espaces, fonctions,
/// vocabulaire. Consultation rapide (récap, chrono…).
Future<void> showLocationDetailsPopup(
  BuildContext context,
  LocationDetailsStore store,
  String locationName,
) {
  final details = store.byName(locationName);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final maxH = MediaQuery.of(context).size.height * 0.82;
      return Dialog(
        backgroundColor: const Color(0xFF141029),
        insetPadding: const EdgeInsets.all(20),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: _gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(locationName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Flexible(
                child: (details == null || details.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('Aucun détail pour ce lieu.',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        children: [
                          LocationDetailSection(
                              kind: LocationDetailKind.sousEspaces,
                              items: details.sousEspaces),
                          LocationDetailSection(
                              kind: LocationDetailKind.fonctions,
                              items: details.fonctions),
                          LocationDetailSection(
                              kind: LocationDetailKind.vocabulaire,
                              items: details.vocabulaire),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

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
                  LocationDetailSection(
                    kind: LocationDetailKind.sousEspaces,
                    items: details.sousEspaces,
                  ),
                  LocationDetailSection(
                    kind: LocationDetailKind.fonctions,
                    items: details.fonctions,
                  ),
                  LocationDetailSection(
                    kind: LocationDetailKind.vocabulaire,
                    items: details.vocabulaire,
                  ),
                ],
              ),
      ),
    );
  }

}

/// Éditeur des détails d'un lieu (sous-espaces + fonctions + vocabulaire).
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
  late List<TextEditingController> _fonc;
  late List<TextEditingController> _voc;

  @override
  void initState() {
    super.initState();
    final d = widget.store.byId(widget.locationId);
    _sous = [for (final s in d?.sousEspaces ?? const []) TextEditingController(text: s)];
    _fonc = [for (final s in d?.fonctions ?? const []) TextEditingController(text: s)];
    _voc = [for (final s in d?.vocabulaire ?? const []) TextEditingController(text: s)];
    if (_sous.isEmpty) _sous.add(TextEditingController());
    if (_fonc.isEmpty) _fonc.add(TextEditingController());
    if (_voc.isEmpty) _voc.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in [..._sous, ..._fonc, ..._voc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    List<String> vals(List<TextEditingController> cs) =>
        [for (final c in cs) if (c.text.trim().isNotEmpty) c.text.trim()];
    final details = LocationDetails(
      sousEspaces: vals(_sous),
      fonctions: vals(_fonc),
      vocabulaire: vals(_voc),
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
              title: 'Fonctions',
              controllers: _fonc,
              onAdd: () => setState(() => _fonc.add(TextEditingController())),
              onRemove: (i) => setState(() => _fonc.removeAt(i).dispose()),
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
