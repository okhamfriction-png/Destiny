import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/visual_settings.dart';
import '../widgets/destiny_cube_animation.dart';
import '../widgets/dice_3d.dart';

class DiceScreen extends StatefulWidget {
  const DiceScreen({
    required this.audioService,
    required this.visualSettings,
    super.key,
  });

  final AudioService audioService;
  final VisualSettings visualSettings;

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _CategoryFace {
  const _CategoryFace(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class _DiceScreenState extends State<DiceScreen> {
  static const List<_CategoryFace> _categories = [
    _CategoryFace('Danger', Icons.crisis_alert, Color(0xFFDD2476)),
    _CategoryFace('Lieu', Icons.place, Color(0xFF4286f4)),
    _CategoryFace('Archétype', Icons.theater_comedy, Color(0xFF38EF7D)),
  ];

  final GlobalKey<Dice3DState> _coinKey = GlobalKey<Dice3DState>();
  final GlobalKey<Dice3DState> _d3Key = GlobalKey<Dice3DState>();

  bool? _coinBrave;
  _CategoryFace? _d3Result;

  // Overlay d'animation du cube DESTINY au lancer.
  bool _showCube = false;
  int _cubeToken = 0;

  /// Déclenche l'animation du cube (au tout début d'un lancer). Ignoré si une
  /// animation est déjà en cours, pour éviter un double-jeu quand on lance les
  /// deux dés à la fois.
  void _launchCube() {
    if (!widget.visualSettings.cubeAnimation) return; // animation désactivée
    if (_showCube) return;
    setState(() {
      _showCube = true;
      _cubeToken++;
    });
  }

  void _rollAll() {
    _coinKey.currentState?.roll();
    _d3Key.currentState?.roll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        _buildContent(theme),
        if (_showCube)
          DestinyCubeAnimation(
            key: ValueKey(_cubeToken),
            size: 220,
            fullscreenScrim: true,
            onCompleted: () {
              if (mounted) setState(() => _showCube = false);
            },
          ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Dés',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Touche un dé pour le lancer, ou lance les deux.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runSpacing: 28,
          spacing: 28,
          children: [
            _DieColumn(
              title: 'Pièce d\'approche',
              result: _coinBrave == null
                  ? '—'
                  : (_coinBrave! ? 'Brave' : 'Smart'),
              die: Dice3D(
                key: _coinKey,
                sides: 2,
                size: 176,
                onRollStart: () {
                  widget.audioService.playCoin();
                  _launchCube();
                },
                gradientForFace: (face) => face == 0
                    ? DestinyOmen.braveGradient
                    : DestinyOmen.smartGradient,
                faceBuilder: (face) =>
                    DestinyOmenFace(brave: face == 0, size: 176),
                onResult: (face) =>
                    setState(() => _coinBrave = face == 0),
              ),
            ),
            _DieColumn(
              title: 'Dé catégorie',
              result: _d3Result?.label ?? '—',
              die: Dice3D(
                key: _d3Key,
                sides: 3,
                size: 176,
                onRollStart: () {
                  widget.audioService.playDice();
                  _launchCube();
                },
                gradient: const [Color(0xFF2B2350), Color(0xFF13102A)],
                faceBuilder: (face) => _categoryFaceWidget(_categories[face]),
                onResult: (face) =>
                    setState(() => _d3Result = _categories[face]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        ElevatedButton.icon(
          onPressed: _rollAll,
          icon: const Icon(Icons.casino),
          label: const Text('Lancer les dés'),
        ),
      ],
    );
  }

  Widget _categoryFaceWidget(_CategoryFace face) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(face.icon, color: face.color, size: 64),
        const SizedBox(height: 8),
        Text(
          face.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _DieColumn extends StatelessWidget {
  const _DieColumn({
    required this.title,
    required this.result,
    required this.die,
  });

  final String title;
  final String result;
  final Widget die;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 196,
      child: Column(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          die,
          const SizedBox(height: 16),
          Text(
            result,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
