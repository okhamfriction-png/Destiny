import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/entities/story.dart';
import '../visuals/entity_visuals.dart';
import 'entity_image.dart';

/// Carte du mode « Rue » : Lieu et Danger EN GRAND, puis les étapes 3 & 4 du
/// danger en petit (montée résumée). Pas de joueurs.
class RueResultCard extends StatelessWidget {
  const RueResultCard({
    required this.story,
    this.source = VisualSource.ai,
    this.big = true,
    this.full = false,
    super.key,
  });

  final Story story;
  final VisualSource source;

  /// Images EN GRAND empilées (true) ou côte à côte compact (false).
  final bool big;

  /// Mode « full » : tout condensé pour tenir sur un seul écran.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paliers = story.danger.paliers;
    // Étapes 3 et 4 (indices 2 et 3) — la montée du danger, en résumé.
    final steps = <String>[
      if (paliers.length >= 3) paliers[2],
      if (paliers.length >= 4) paliers[3],
    ];

    final lieuVisual = EntityVisuals.forLocation(story.location);
    final dangerVisual = EntityVisuals.forDanger(story.danger);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (big && !full) ...[
              _BigEntity(
                label: 'DANGER',
                name: story.danger.name,
                visual: dangerVisual,
                source: source,
              ),
              const SizedBox(height: 18),
              _BigEntity(
                label: 'LIEU',
                name: story.location.name,
                visual: lieuVisual,
                source: source,
              ),
            ] else
              // Danger à GAUCHE, Lieu à DROITE, même ligne (pas de scroll).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompactEntity(
                      label: 'DANGER',
                      name: story.danger.name,
                      visual: dangerVisual,
                      source: source,
                      imageCap: full ? 92 : 200,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactEntity(
                      label: 'LIEU',
                      name: story.location.name,
                      visual: lieuVisual,
                      source: source,
                      imageCap: full ? 92 : 200,
                    ),
                  ),
                ],
              ),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.trending_up,
                      size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Ça monte (fin)',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${i == 0 ? '3' : '4'}. ${steps[i]}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54, height: 1.3),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cellule compacte Lieu / Danger (demi-colonne) : image + libellé + nom.
class _CompactEntity extends StatelessWidget {
  const _CompactEntity({
    required this.label,
    required this.name,
    required this.visual,
    required this.source,
    this.imageCap = 200,
  });

  final String label;
  final String name;
  final EntityVisual visual;
  final VisualSource source;
  final double imageCap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary, letterSpacing: 1)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) => EntityImage(
              visual: visual,
              source: source,
              size: c.maxWidth.clamp(0.0, imageCap),
              radius: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: theme.textTheme.titleMedium, maxLines: 2),
        ],
      ),
    );
  }
}

class _BigEntity extends StatelessWidget {
  const _BigEntity({
    required this.label,
    required this.name,
    required this.visual,
    required this.source,
  });

  final String label;
  final String name;
  final EntityVisual visual;
  final VisualSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Image EN GRAND, pleine largeur (plafonnée pour les grands écrans),
    // puis le nom EN DESSOUS.
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.maxWidth.clamp(0.0, 480.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EntityImage(
                visual: visual, source: source, size: size, radius: 26),
            const SizedBox(height: 10),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary, letterSpacing: 2)),
            const SizedBox(height: 2),
            Text(name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        );
      },
    );
  }
}
