import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/entities/story.dart';
import '../visuals/entity_visuals.dart';
import 'entity_image.dart';

/// Carte du mode « Dilemme » : contexte (lieu + danger) puis le dilemme moral,
/// avec la bascule « tout ou rien » du destin mise en avant.
class DilemmaResultCard extends StatelessWidget {
  const DilemmaResultCard({
    required this.story,
    this.source = VisualSource.ai,
    this.full = false,
    super.key,
  });

  final Story story;
  final VisualSource source;

  /// Mode « full » : tout condensé pour tenir sur un seul écran.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = story.dilemma;
    if (d == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(full ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contexte : lieu + danger, compact.
            Row(
              children: [
                _MiniEntity(
                    visual: EntityVisuals.forDanger(story.danger),
                    source: source,
                    name: story.danger.name,
                    size: full ? 38 : 48),
                const SizedBox(width: 12),
                _MiniEntity(
                    visual: EntityVisuals.forLocation(story.location),
                    source: source,
                    name: story.location.name,
                    size: full ? 38 : 48),
              ],
            ),
            SizedBox(height: full ? 10 : 16),
            Text(d.nom,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: full ? 8 : 12),
            // Genre (moteur).
            _label(theme, 'Genre :', d.moteur),
            SizedBox(height: full ? 6 : 10),
            // Le dilemme (situation).
            _label(theme, 'Le dilemme :', d.situation),
            SizedBox(height: full ? 8 : 12),
            // Les deux choix.
            _choice(theme, d.choixA),
            const SizedBox(height: 6),
            _choice(theme, d.choixB),
            if (d.sourceReelle.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(d.sourceReelle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white38, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String label, String value) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800)),
          TextSpan(
              text: value,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.4)),
        ]),
      );

  Widget _choice(ThemeData theme, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.circle,
                size: 8, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
          ),
        ],
      );
}

class _MiniEntity extends StatelessWidget {
  const _MiniEntity(
      {required this.visual,
      required this.source,
      required this.name,
      this.size = 48});

  final EntityVisual visual;
  final VisualSource source;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        children: [
          EntityImage(visual: visual, source: source, size: size, radius: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

