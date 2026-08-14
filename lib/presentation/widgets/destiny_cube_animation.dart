import 'dart:math';

import 'package:flutter/material.dart';

const Color _gold = Color(0xFFFFC24B);

/// Chemin de l'illustration du cube DESTINY (les 3 faces : Lieu / Archétype /
/// Danger). Si l'asset est absent, un cube dessiné sert de repli.
const String kDestinyCubeAsset = 'assets/images/destiny_cube.png';

/// Animation « lancement du dé » : le cube doré surgit (zoom), effectue un
/// tumble 3D sur lui-même puis se stabilise, avec une lueur dorée pulsée.
///
/// Se joue **une fois** à l'affichage. Utilisable en superposition (overlay)
/// au-dessus d'un écran : le parent le monte avec une [Key] unique par lancer
/// et le retire dans [onCompleted].
class DestinyCubeAnimation extends StatefulWidget {
  const DestinyCubeAnimation({
    this.size = 200,
    this.label,
    this.onCompleted,
    this.holdAtEnd = false,
    this.fullscreenScrim = false,
    super.key,
  });

  /// Côté du cube (en pixels).
  final double size;

  /// Texte affiché sous le cube (ex. « DESTINY 2 »). Masqué si null.
  final String? label;

  /// Appelé à la fin de l'animation (pour retirer l'overlay).
  final VoidCallback? onCompleted;

  /// Si vrai, le cube reste affiché à la fin au lieu de disparaître en fondu.
  final bool holdAtEnd;

  /// Ajoute un voile sombre plein écran derrière le cube (mode overlay).
  final bool fullscreenScrim;

  @override
  State<DestinyCubeAnimation> createState() => _DestinyCubeAnimationState();
}

class _DestinyCubeAnimationState extends State<DestinyCubeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted?.call();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // --- Enveloppe d'opacité (fondu entrée / maintien / sortie) ---
        double opacity;
        if (t < 0.12) {
          opacity = t / 0.12; // fondu d'entrée
        } else if (widget.holdAtEnd || t < 0.82) {
          opacity = 1;
        } else {
          opacity =
              (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0).toDouble(); // sortie
        }

        // --- Zoom : surgit petit, léger dépassement, se stabilise ---
        final zoom = Curves.easeOutBack.transform(t);
        final scale = 0.35 + zoom * 0.65; // 0.35 -> ~1.05 -> 1.0

        // --- Tumble 3D : ~3 tours en Y qui s'amortissent vers la face avant ---
        final settleT = Curves.easeOutCubic.transform(t);
        final rotY = settleT * 2 * pi * 3;
        // Léger basculement en X qui s'estompe.
        final rotX = sin(t * pi * 5) * (1 - settleT) * 0.5;

        // --- Lueur dorée pulsée ---
        final glow = 0.45 + 0.55 * sin(t * pi * 4).abs() * (1 - t * 0.4);

        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(rotX)
          ..rotateY(rotY)
          ..scaleByDouble(scale, scale, scale, 1);

        final cube = Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size * 1.45,
                height: widget.size * 1.45,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo doré : dégradé radial (shader GPU, pas de flou gaussien
                    // coûteux → évite le gel de rendu sur le web/mobile).
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _gold.withValues(alpha: 0.5 * glow),
                            _gold.withValues(alpha: 0.14 * glow),
                            const Color(0x00000000),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    Transform(
                      alignment: Alignment.center,
                      transform: transform,
                      child: _CubeArt(size: widget.size * 0.9),
                    ),
                  ],
                ),
              ),
              if (widget.label != null) ...[
                SizedBox(height: widget.size * 0.08),
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: _gold,
                    fontSize: widget.size * 0.16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

        if (!widget.fullscreenScrim) return Center(child: cube);

        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35 * opacity),
              alignment: Alignment.center,
              child: cube,
            ),
          ),
        );
      },
    );
  }
}

/// Illustration du cube : l'image fournie, avec repli dessiné si absente.
class _CubeArt extends StatelessWidget {
  const _CubeArt({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kDestinyCubeAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => _CubeFallback(size: size),
    );
  }
}

/// Repli : cube stylisé (utilisé tant que [kDestinyCubeAsset] n'est pas fourni).
class _CubeFallback extends StatelessWidget {
  const _CubeFallback({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          colors: [Color(0xFF1A1530), Color(0xFF07060F)],
        ),
        borderRadius: BorderRadius.circular(size * 0.16),
        border: Border.all(color: _gold, width: size * 0.02),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.4),
            blurRadius: size * 0.12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place, color: _gold, size: size * 0.22),
          SizedBox(height: size * 0.04),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.theater_comedy, color: _gold, size: size * 0.22),
              SizedBox(width: size * 0.08),
              Icon(Icons.bolt, color: _gold, size: size * 0.22),
            ],
          ),
        ],
      ),
    );
  }
}
