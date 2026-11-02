import 'package:flutter/material.dart';

import '../../application/state/location_details.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import '../widgets/location_detail_section.dart';

/// Liste des lieux (réglages) : choisir un lieu pour éditer ses détails.
class LocationDetailsListScreen extends StatefulWidget {
  const LocationDetailsListScreen({required this.store, super.key});
  final LocationDetailsStore store;

  @override
  State<LocationDetailsListScreen> createState() => _LocationDetailsListScreenState();
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
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('details_lieux.$x', v);
    final locations = widget.store.locations;
    return PageDestiny(
      titre: k('titre'),
      enfants: [
        Paragraphe(k('intro'), italique: true),
        for (final l in locations)
          Builder(builder: (context) {
            final d = widget.store.byId(l.id);
            final resume = k('resume', {
              'n': '${d?.sousEspaces.length ?? 0}',
              'v': '${d?.vocabulaire.length ?? 0}',
            });
            return ElementListe(
              titre: l.name,
              sousTitre: widget.store.hasOverride(l.id) ? '$resume · ${k('modifie')}' : resume,
              devant: Icon(Icons.place_outlined, color: c.titre),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => LocationDetailsEditScreen(
                  store: widget.store,
                  locationId: l.id,
                  locationName: l.name,
                ),
              )),
            );
          }),
      ],
    );
  }
}

/// Consultation des détails d'un lieu : sous-espaces jouables + vocabulaire.
/// Lecture seule (l'édition se fait dans les réglages).
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
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('details_lieux.$x', v);
    final details = store.byName(locationName);
    if (details == null || details.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(k('lieu', {'nom': locationName}))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              k('vide'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texteSecondaire),
            ),
          ),
        ),
      );
    }
    return PageDestiny(
      titre: k('lieu', {'nom': locationName}),
      enfants: [
        LocationDetailSection(kind: LocationDetailKind.sousEspaces, items: details.sousEspaces),
        LocationDetailSection(kind: LocationDetailKind.fonctions, items: details.fonctions),
        LocationDetailSection(kind: LocationDetailKind.vocabulaire, items: details.vocabulaire),
      ],
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
  State<LocationDetailsEditScreen> createState() => _LocationDetailsEditScreenState();
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

  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('details_lieux.$x', v);

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

  Future<void> _restaurer() async {
    await widget.store.resetToDefault(widget.locationId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PageDestiny(
      titre: k('modifier', {'nom': widget.locationName}),
      actions: [
        TextButton(onPressed: _save, child: Text(k('enregistrer'))),
      ],
      enfants: [
        _editList(
          title: k('sous_espaces'),
          aide: k('sous_espaces_aide'),
          controllers: _sous,
          onAdd: () => setState(() => _sous.add(TextEditingController())),
          onRemove: (i) => setState(() => _sous.removeAt(i).dispose()),
        ),
        _editList(
          title: k('fonctions'),
          aide: k('fonctions_aide'),
          controllers: _fonc,
          onAdd: () => setState(() => _fonc.add(TextEditingController())),
          onRemove: (i) => setState(() => _fonc.removeAt(i).dispose()),
        ),
        _editList(
          title: k('vocabulaire'),
          aide: k('vocabulaire_aide'),
          controllers: _voc,
          onAdd: () => setState(() => _voc.add(TextEditingController())),
          onRemove: (i) => setState(() => _voc.removeAt(i).dispose()),
        ),
        if (widget.store.hasOverride(widget.locationId))
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _restaurer,
                icon: const Icon(Icons.restore_rounded),
                label: Text(k('restaurer')),
              ),
            ),
          ),
      ],
    );
  }

  Widget _editList({
    required String title,
    required String aide,
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    final c = context.destiny;
    return SectionDestiny(
      titre: title,
      enfants: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(aide,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.3, color: c.texteSecondaire)),
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
                  tooltip: context.textes.t('accessibilite.retirer'),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  color: c.texteSecondaire,
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(k('ajouter')),
          ),
        ),
      ],
    );
  }
}
