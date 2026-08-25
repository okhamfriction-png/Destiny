import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/state/location_details.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/entities/archetype.dart' show Archetype;
import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/story_repository.dart';
import '../visuals/entity_visuals.dart';
import '../widgets/entity_image.dart';
import '../widgets/location_detail_section.dart';

enum CatalogTab { lieux, dangers, archetypes }

/// Catalogue en lecture seule de toutes les données, avec filtres et tri.
class CatalogViewScreen extends StatefulWidget {
  const CatalogViewScreen({
    required this.repository,
    required this.visualSettings,
    this.locationDetails,
    this.initialTab = CatalogTab.lieux,
    super.key,
  });

  final StoryRepository repository;
  final VisualSettings visualSettings;

  /// Sous-espaces + vocabulaire par lieu (affichés dans l'onglet Lieux).
  final LocationDetailsStore? locationDetails;

  /// Onglet ouvert au démarrage (raccourci depuis le menu principal).
  final CatalogTab initialTab;

  @override
  State<CatalogViewScreen> createState() => _CatalogViewScreenState();
}

class _CatalogViewScreenState extends State<CatalogViewScreen> {
  List<Location> _locations = const [];
  List<Danger> _dangers = const [];
  List<Archetype> _archetypes = const [];
  bool _loading = true;
  late CatalogTab _filter = widget.initialTab;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await widget.repository.getLocations();
    final d = await widget.repository.getDangers();
    final a = await widget.repository.getArchetypes();
    if (!mounted) return;
    setState(() {
      _locations = l;
      _dangers = d;
      _archetypes = a;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue de données')),
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
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<CatalogTab>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                  value: CatalogTab.lieux, label: Text('Lieux')),
                              ButtonSegment(
                                  value: CatalogTab.dangers,
                                  label: Text('Dangers')),
                              ButtonSegment(
                                  value: CatalogTab.archetypes,
                                  label: Text('Archét.')),
                            ],
                            selected: {_filter},
                            onSelectionChanged: (s) =>
                                setState(() => _filter = s.first),
                          ),
                        ),
                        IconButton(
                          tooltip: _ascending ? 'A → Z' : 'Z → A',
                          onPressed: () =>
                              setState(() => _ascending = !_ascending),
                          icon: Icon(_ascending
                              ? Icons.sort_by_alpha
                              : Icons.sort_by_alpha_outlined),
                        ),
                        IconButton(
                          tooltip: 'Copier ce tableau (JSON)',
                          onPressed: _copyCurrentJson,
                          icon: const Icon(Icons.copy_all),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: _items(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Affiche le tableau courant en JSON brut (sélectionnable + bouton Copier).
  Future<void> _copyCurrentJson() async {
    final List<Map<String, dynamic>> data;
    final String label;
    switch (_filter) {
      case CatalogTab.lieux:
        label = 'lieux';
        data = ([..._locations]..sort((a, b) => a.name.compareTo(b.name)))
            .map((l) => l.toJson())
            .toList();
      case CatalogTab.dangers:
        label = 'dangers';
        data = ([..._dangers]..sort((a, b) => a.name.compareTo(b.name)))
            .map((d) => d.toJson())
            .toList();
      case CatalogTab.archetypes:
        label = 'archetypes';
        data = ([..._archetypes]..sort((a, b) => a.name.compareTo(b.name)))
            .map((a) => a.toJson())
            .toList();
    }
    final json = const JsonEncoder.withIndent('  ').convert({label: data});
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data.length} $label — JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.35),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copier'),
            onPressed: () async {
              var ok = true;
              try {
                await Clipboard.setData(ClipboardData(text: json));
              } catch (_) {
                ok = false;
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? '${data.length} $label copiés dans le presse-papier'
                      : 'Copie auto indisponible — sélectionne le texte manuellement'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _items() {
    final source = widget.visualSettings.source;
    int cmp(String a, String b) =>
        _ascending ? a.compareTo(b) : b.compareTo(a);
    switch (_filter) {
      case CatalogTab.lieux:
        final items = [..._locations]..sort((a, b) => cmp(a.name, b.name));
        return items.map((l) {
          final d = widget.locationDetails?.byId(l.id);
          return _CatalogTile(
            visual: EntityVisuals.forLocation(l),
            source: source,
            title: l.name,
            subtitle: '${l.roles.length} rôles${l.actif ? "" : " · inactif"}',
            sousEspaces: d?.sousEspaces ?? const [],
            fonctions: d?.fonctions ?? const [],
            vocabulaire: d?.vocabulaire ?? const [],
          );
        }).toList();
      case CatalogTab.dangers:
        final items = [..._dangers]..sort((a, b) => cmp(a.name, b.name));
        return items
            .map((d) => _CatalogTile(
                  visual: EntityVisuals.forDanger(d),
                  source: source,
                  title: d.name,
                  subtitle: '${d.style}'
                      '${d.actif ? "" : " · inactif"}',
                  paliers: d.paliers,
                ))
            .toList();
      case CatalogTab.archetypes:
        final items = [..._archetypes]..sort((a, b) => cmp(a.name, b.name));
        return items
            .map((a) => _CatalogTile(
                  visual: EntityVisuals.forArchetype(a),
                  source: source,
                  title: a.name,
                  titleColor: EntityVisuals.colorForStatut(a.statut),
                  subtitle: a.traits,
                  subtitleRich: _ArchetypeSubtitle(archetype: a),
                ))
            .toList();
    }
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.visual,
    required this.source,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.subtitleRich,
    this.paliers = const [],
    this.sousEspaces = const [],
    this.fonctions = const [],
    this.vocabulaire = const [],
  });

  final EntityVisual visual;
  final VisualSource source;
  final String title;
  final String subtitle;
  final Color? titleColor;

  /// Sous-titre riche (stylé) qui remplace [subtitle] si fourni.
  final Widget? subtitleRich;
  final List<String> paliers;

  /// Détails de lieu (onglet Lieux) : sous-espaces + fonctions + vocabulaire.
  final List<String> sousEspaces;
  final List<String> fonctions;
  final List<String> vocabulaire;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EntityImage(
                    visual: visual, source: source, size: 56, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: titleColor)),
                      const SizedBox(height: 2),
                      subtitleRich ??
                          Text(subtitle,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.white60)),
                    ],
                  ),
                ),
              ],
            ),
            if (paliers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timelapse,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Étapes du danger',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < paliers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.18),
                        ),
                        child: Text('${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(paliers[i],
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
            ],
            if (sousEspaces.isNotEmpty || fonctions.isNotEmpty ||
                vocabulaire.isNotEmpty)
              const SizedBox(height: 10),
            LocationDetailSection(
                kind: LocationDetailKind.sousEspaces,
                items: sousEspaces,
                dense: true),
            LocationDetailSection(
                kind: LocationDetailKind.fonctions,
                items: fonctions,
                dense: true),
            LocationDetailSection(
                kind: LocationDetailKind.vocabulaire,
                items: vocabulaire,
                dense: true),
          ],
        ),
      ),
    );
  }

}

/// Sous-titre stylé d'un archétype : tempérament · *port* (italique) ·
/// **moteur** (gras).
class _ArchetypeSubtitle extends StatelessWidget {
  const _ArchetypeSubtitle({required this.archetype});

  final Archetype archetype;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall ?? const TextStyle();
    return Text.rich(
      TextSpan(
        children: [
          if (archetype.temperament.isNotEmpty)
            TextSpan(
                text: archetype.temperament,
                style: base.copyWith(color: Colors.white70)),
          if (archetype.port.isNotEmpty)
            TextSpan(
                text: '  ·  ${archetype.port}',
                style: base.copyWith(
                    color: Colors.white54, fontStyle: FontStyle.italic)),
          if (archetype.moteur.isNotEmpty)
            TextSpan(
                text: '\n${archetype.moteur}',
                style: base.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
