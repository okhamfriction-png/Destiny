import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';

/// Réglage de l'apparence : taille du texte de l'application.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({required this.visualSettings, super.key});

  final VisualSettings visualSettings;

  static const _presets = <({String label, double value})>[
    (label: 'Petit', value: 0.85),
    (label: 'Normal', value: 1.0),
    (label: 'Grand', value: 1.2),
    (label: 'Très grand', value: 1.45),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: ListenableBuilder(
          listenable: visualSettings,
          builder: (context, _) {
            final theme = Theme.of(context);
            final scale = visualSettings.textScale;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(Icons.format_size, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Taille du texte du Chat',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _presets)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: (scale - p.value).abs() < 0.02,
                        onSelected: (_) =>
                            visualSettings.setTextScale(p.value),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Réglage fin : ×${scale.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium),
                Slider(
                  value: scale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 16,
                  label: '×${scale.toStringAsFixed(2)}',
                  onChanged: (v) => visualSettings.setTextScale(v),
                ),
                const SizedBox(height: 16),
                // L'aperçu applique l'échelle choisie (comme dans le Chat).
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aperçu (taille du Chat)',
                              style: theme.textTheme.labelMedium),
                          const SizedBox(height: 8),
                          Text('Le Maître du jeu lance les dés…',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 6),
                          Text(
                            'DONC tu fonces. MAIS une ombre surgit. À toi de '
                            'choisir : brave ou malin ?',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.draw, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Écriture du Chat', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Standard')),
                    ButtonSegment(value: true, label: Text('Manuscrite')),
                  ],
                  selected: {visualSettings.handwritten},
                  onSelectionChanged: (s) =>
                      visualSettings.setHandwritten(s.first),
                ),
                const SizedBox(height: 10),
                Text(
                  'Aa Bb Cc — Le Maître du jeu écrit à la main.',
                  style: TextStyle(
                    fontFamily: visualSettings.handwritten
                        ? VisualSettings.handwrittenFamily
                        : null,
                    fontSize: 20 * scale,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La taille et l\'écriture s\'appliquent uniquement au Chat '
                  '(Maître du jeu) et sont conservées.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.image_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Visuels des cartes',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<VisualSource>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  segments: const [
                    ButtonSegment(
                        value: VisualSource.ai,
                        icon: Icon(Icons.image),
                        label: Text('Réaliste')),
                    ButtonSegment(
                        value: VisualSource.vector,
                        icon: Icon(Icons.auto_awesome),
                        label: Text('Vectoriel')),
                    ButtonSegment(
                        value: VisualSource.minimal,
                        icon: Icon(Icons.gradient),
                        label: Text('Minimal')),
                  ],
                  selected: {visualSettings.source},
                  onSelectionChanged: (s) => visualSettings.setSource(s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Style des images (lieux, dangers, archétypes) partout dans '
                  'l\'app. Minimal : dégradé sobre, sans icône.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 20),
                Text('Affichage du résultat (Générateur)',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<ResultLayout>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  segments: const [
                    ButtonSegment(
                        value: ResultLayout.cote,
                        icon: Icon(Icons.view_agenda_outlined),
                        label: Text('Côté')),
                    ButtonSegment(
                        value: ResultLayout.grand,
                        icon: Icon(Icons.fullscreen),
                        label: Text('Grand')),
                    ButtonSegment(
                        value: ResultLayout.full,
                        icon: Icon(Icons.dashboard_customize_outlined),
                        label: Text('Full')),
                  ],
                  selected: {visualSettings.resultLayout},
                  onSelectionChanged: (s) =>
                      visualSettings.setResultLayout(s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Côté : lieu et danger côte à côte (compact). Grand : images '
                  'en plein écran avec le nom dessous. Full : tout condensé sur '
                  'un seul écran (visuels réduits, sans défilement).',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.timer, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Durée du TOP (chrono de scène)',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30 s')),
                    ButtonSegment(value: 45, label: Text('45 s')),
                    ButtonSegment(value: 60, label: Text('60 s')),
                    ButtonSegment(value: 90, label: Text('90 s')),
                  ],
                  selected: {visualSettings.topSeconds},
                  onSelectionChanged: (s) =>
                      visualSettings.setTopSeconds(s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Durée du chrono lancé par le bouton TOP. Une alerte sonne à '
                  '10 s de la fin. 30 s par défaut.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.casino, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('DESTINY — le dé', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'À chaque DESTINY, le dé tire un type selon ces poids. Mets 0 '
                  'pour désactiver un type (ex. seulement « Destin »).',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final a = visualSettings.destinyWeightArchetype;
                  final d = visualSettings.destinyWeightDanger;
                  final x = visualSettings.destinyWeightDestin;
                  final total = a + d + x;
                  String pct(int w) =>
                      total <= 0 ? '—' : '${(w * 100 / total).round()} %';
                  return Text(
                    total <= 0
                        ? 'Aucun type actif — « Destin » tombera par défaut.'
                        : 'Chances : Archétype ${pct(a)} · Danger ${pct(d)} · '
                            'Destin ${pct(x)}.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  );
                }),
                const SizedBox(height: 4),
                _WeightRow(
                  label: 'Archétype',
                  value: visualSettings.destinyWeightArchetype,
                  onChanged: visualSettings.setDestinyWeightArchetype,
                ),
                _WeightRow(
                  label: 'Danger',
                  value: visualSettings.destinyWeightDanger,
                  onChanged: visualSettings.setDestinyWeightDanger,
                ),
                _WeightRow(
                  label: 'Destin',
                  value: visualSettings.destinyWeightDestin,
                  onChanged: visualSettings.setDestinyWeightDestin,
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: visualSettings.cubeAnimation,
                  onChanged: visualSettings.setCubeAnimation,
                  secondary:
                      Icon(Icons.view_in_ar, color: theme.colorScheme.primary),
                  title: const Text('Animation du cube'),
                  subtitle: Text(
                    'Cube doré animé au lancer des dés et au lancement du '
                    'chrono d\'histoire. Désactivée par défaut.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white38),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Curseur de poids (0–12) pour un type du dé DESTINY.
class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('$value',
              textAlign: TextAlign.end, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
