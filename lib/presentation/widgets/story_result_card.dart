import 'package:flutter/material.dart';

import '../../application/state/location_details.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/entities/player_assignment.dart';
import '../../domain/entities/story.dart';
import '../screens/location_details_screen.dart';
import '../visuals/entity_visuals.dart';
import 'entity_image.dart';

class StoryResultCard extends StatelessWidget {
  const StoryResultCard({
    required this.story,
    this.source = VisualSource.ai,
    this.big = false,
    this.full = false,
    this.locationDetails,
    super.key,
  });

  final Story story;
  final VisualSource source;

  /// Détails du lieu (sous-espaces, fonctions, vocabulaire). Si fourni, le lieu
  /// devient cliquable (popup) et ses fonctions s'affichent près de l'image.
  final LocationDetailsStore? locationDetails;

  /// Images EN GRAND (plein largeur, nom dessous) plutôt qu'à côté (compact).
  final bool big;

  /// Mode « full » : tout condensé pour tenir sur un seul écran.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // En mode full, on force la disposition côté (compacte) et on réduit tout.
    final bigImages = big && !full;
    final cap = full ? 92.0 : 200.0;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(full ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CycleBanner(story: story),
            SizedBox(height: full ? 8 : 12),
            if (bigImages) ...[
              // Images EN GRAND, nom dessous (Danger d'abord, puis Lieu).
              _BigCell(
                label: 'DANGER',
                name: story.danger.name,
                visual: EntityVisuals.forDanger(story.danger),
                source: source,
              ),
              const SizedBox(height: 16),
              _BigCell(
                label: 'LIEU',
                name: story.location.name,
                visual: EntityVisuals.forLocation(story.location),
                source: source,
              ),
            ] else
              // Danger à GAUCHE, Lieu à DROITE, sur la même ligne (compact).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _EntityCell(
                      label: 'Danger',
                      title: story.danger.name,
                      visual: EntityVisuals.forDanger(story.danger),
                      source: source,
                      imageCap: cap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EntityCell(
                      label: 'Lieu',
                      title: story.location.name,
                      visual: EntityVisuals.forLocation(story.location),
                      source: source,
                      imageCap: cap,
                    ),
                  ),
                ],
              ),
            if (locationDetails != null)
              _LieuFonctionsPanel(
                  story: story, source: source, store: locationDetails!),
            // Héros AVANT les étapes du danger.
            SizedBox(height: full ? 8 : 14),
            Row(
              children: [
                Icon(Icons.groups, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Héros', style: theme.textTheme.titleMedium),
              ],
            ),
            SizedBox(height: full ? 6 : 8),
            ...story.players
                .map((p) => _PlayerRow(player: p, source: source, full: full)),
            if (story.danger.paliers.isNotEmpty) ...[
              SizedBox(height: full ? 8 : 12),
              _DangerSteps(paliers: story.danger.paliers, full: full),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cellule Lieu / Danger EN GRAND : image pleine largeur + nom dessous.
class _BigCell extends StatelessWidget {
  const _BigCell({
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
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.maxWidth.clamp(0.0, 480.0);
        return Column(
          children: [
            EntityImage(
                visual: visual, source: source, size: size, radius: 24),
            const SizedBox(height: 8),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary, letterSpacing: 2)),
            const SizedBox(height: 2),
            Text(name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        );
      },
    );
  }
}

/// Cellule compacte Lieu / Danger : image + libellé + nom.
class _EntityCell extends StatelessWidget {
  const _EntityCell({
    required this.label,
    required this.title,
    required this.visual,
    required this.source,
    this.imageCap = 200,
  });

  final String label;
  final String title;
  final EntityVisual visual;
  final VisualSource source;

  /// Taille maximale de l'image (réduite en mode full).
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
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          // Image qui remplit la demi-colonne (bien visible, mais côte à côte).
          LayoutBuilder(
            builder: (context, c) => EntityImage(
              visual: visual,
              source: source,
              size: c.maxWidth.clamp(0.0, imageCap),
              radius: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleMedium, maxLines: 2),
        ],
      ),
    );
  }
}

/// Liste numérotée compacte des 4 étapes (paliers) du danger.
class _DangerSteps extends StatelessWidget {
  const _DangerSteps({required this.paliers, this.full = false});

  final List<String> paliers;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(full ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timelapse,
                  size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Étapes du danger',
                  style: theme.textTheme.labelMedium?.copyWith(
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
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
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
                            ?.copyWith(color: Colors.white70, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne joueur compacte (sans rôle) : image + nom + archétype + traits.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow(
      {required this.player, required this.source, this.full = false});

  final PlayerAssignment player;
  final VisualSource source;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: full ? 5 : 8),
      padding: EdgeInsets.all(full ? 7 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EntityImage(
            visual: EntityVisuals.forArchetype(player.archetype),
            source: source,
            size: full ? 38 : 48,
            radius: 12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('J${player.playerIndex}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(width: 6),
                    Text(player.archetype.name,
                        style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 2),
                // Tempérament · port (italique) · moteur (gras).
                Text.rich(
                  TextSpan(children: [
                    if (player.archetype.temperament.isNotEmpty)
                      TextSpan(
                          text: player.archetype.temperament,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white60)),
                    if (player.archetype.port.isNotEmpty)
                      TextSpan(
                          text: '  ·  ${player.archetype.port}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic)),
                    if (player.archetype.moteur.isNotEmpty)
                      TextSpan(
                          text: '\n${player.archetype.moteur}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _CycleBanner extends StatelessWidget {
  const _CycleBanner({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cycle ${story.cycle} · danger ${story.usedCount}/${story.totalCombos}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panneau du lieu : image à gauche, FONCTIONS à droite ; tout le panneau est
/// cliquable et ouvre la popup avec sous-espaces, fonctions et vocabulaire.
class _LieuFonctionsPanel extends StatelessWidget {
  const _LieuFonctionsPanel({
    required this.story,
    required this.source,
    required this.store,
  });

  final Story story;
  final VisualSource source;
  final LocationDetailsStore store;

  static const Color _violet = Color(0xFFB79CFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fonctions = store.byName(story.location.name)?.fonctions ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              showLocationDetailsPopup(context, store, story.location.name),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _violet.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityImage(
                  visual: EntityVisuals.forLocation(story.location),
                  source: source,
                  size: 88,
                  radius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined,
                              size: 16, color: _violet),
                          const SizedBox(width: 6),
                          const Text('Fonctions du lieu',
                              style: TextStyle(
                                  color: _violet,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const Spacer(),
                          const Icon(Icons.open_in_full,
                              size: 14, color: Colors.white38),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (fonctions.isEmpty)
                        Text('Toucher pour voir les détails du lieu.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54))
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final f in fonctions)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _violet.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _violet.withValues(alpha: 0.34)),
                                ),
                                child: Text(f,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12.5)),
                              ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Text('Toucher pour les sous-espaces & le vocabulaire',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
