import 'package:flutter/material.dart';

class StoryControlsCard extends StatelessWidget {
  const StoryControlsCard({
    required this.playerCount,
    required this.isLoading,
    required this.onPlayerCountChanged,
    required this.onGenerate,
    super.key,
  });

  final int playerCount;
  final bool isLoading;
  final ValueChanged<double> onPlayerCountChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre de joueurs', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: playerCount.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    label: '$playerCount',
                    onChanged: isLoading ? null : onPlayerCountChanged,
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$playerCount',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: isLoading ? null : onGenerate,
              child: Text(isLoading ? 'Génération...' : 'Générer une histoire'),
            ),
          ],
        ),
      ),
    );
  }
}
