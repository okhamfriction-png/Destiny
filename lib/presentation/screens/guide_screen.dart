import 'package:flutter/material.dart';

import '../../application/state/guide_content.dart';
import '../../application/state/visual_settings.dart';

const Color _gold = Color(0xFFFFC24B);

/// Le Guide Destiny : manuel de référence navigable (sections dépliables).
/// Lecture seule pour tous ; éditable uniquement en mode admin.
class GuideScreen extends StatefulWidget {
  const GuideScreen({
    required this.guide,
    required this.visualSettings,
    super.key,
  });

  final GuideContent guide;
  final VisualSettings visualSettings;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  @override
  void initState() {
    super.initState();
    widget.guide.addListener(_onChange);
    widget.visualSettings.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.guide.removeListener(_onChange);
    widget.visualSettings.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _edit(GuideSection s) async {
    final result = await Navigator.of(context).push<({String title, String body})>(
      MaterialPageRoute(builder: (_) => _GuideEditPage(section: s)),
    );
    if (result != null) {
      await widget.guide.updateSection(s.id,
          title: result.title, body: result.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = widget.visualSettings.adminMode;
    final sections = widget.guide.sections;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide Destiny'),
        actions: [
          if (admin)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  label: Text('Admin'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
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
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
              child: Text(
                'La référence complète pour jouer Destiny. '
                '${admin ? 'Mode admin : touche ✎ pour éditer une section.' : 'Lecture seule.'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ),
            for (final s in sections)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  leading: const Icon(Icons.menu_book, color: _gold),
                  title: Text(s.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  trailing: admin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Éditer',
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _edit(s),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        )
                      : null,
                  children: [
                    SelectableText(
                      s.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Éditeur plein écran d'une section du Guide (admin uniquement).
class _GuideEditPage extends StatefulWidget {
  const _GuideEditPage({required this.section});
  final GuideSection section;

  @override
  State<_GuideEditPage> createState() => _GuideEditPageState();
}

class _GuideEditPageState extends State<_GuideEditPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.section.title);
  late final TextEditingController _body =
      TextEditingController(text: widget.section.body);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer la section'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
                context, (title: _title.text.trim(), body: _body.text)),
            child: const Text('Enregistrer'),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _body,
              maxLines: null,
              minLines: 12,
              decoration: const InputDecoration(
                labelText: 'Contenu',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
