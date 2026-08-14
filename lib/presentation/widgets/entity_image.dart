import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../visuals/entity_visuals.dart';

/// Vignette d'entité. Selon [source] :
///  - [VisualSource.ai] : image réaliste générée, embarquée en local, avec
///    repli vectoriel si absente ;
///  - [VisualSource.vector] : poster vectoriel stylisé (grande icône plein
///    cadre, dégradé, halo) — hors-ligne.
class EntityImage extends StatelessWidget {
  const EntityImage({
    required this.visual,
    this.source = VisualSource.ai,
    this.size = 72,
    this.radius = 18,
    super.key,
  });

  final EntityVisual visual;
  final VisualSource source;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // Visuel minimal : dégradé sobre, sans icône ni image.
    if (source == VisualSource.minimal) {
      return _MinimalPoster(visual: visual, size: size, radius: radius);
    }

    final vector = _VectorPoster(
      visual: visual,
      size: size,
      radius: radius,
    );

    // Image réaliste locale (asset embarqué), repli vectoriel si absente.
    if (source == VisualSource.ai && visual.assetPath != null) {
      return _framed(
        Image.asset(
          visual.assetPath!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => vector,
        ),
      );
    }

    return vector;
  }

  /// Encadre une image (voile dégradé + liseré) aux dimensions de la vignette.
  Widget _framed(Widget image) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Poster minimal : un simple dégradé sobre, sans icône ni image. Idéal pour
/// une génération d'histoire épurée.
class _MinimalPoster extends StatelessWidget {
  const _MinimalPoster({
    required this.visual,
    required this.size,
    required this.radius,
  });

  final EntityVisual visual;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c0 = visual.gradient.first;
    final c1 = visual.gradient.last;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c0.withValues(alpha: 0.85),
            c1.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
    );
  }
}

/// Poster vectoriel : grande silhouette débordante + emblème net, sur fond
/// dégradé profond avec halo, stries et vignettage.
class _VectorPoster extends StatelessWidget {
  const _VectorPoster({
    required this.visual,
    required this.size,
    required this.radius,
  });

  final EntityVisual visual;
  final double size;
  final double radius;

  Color _darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color _lighten(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final c0 = visual.gradient.first;
    final c1 = visual.gradient.last;
    final mid = Color.lerp(c0, c1, 0.5) ?? c1;
    final bottom = _darken(c1, 0.24);
    final accent = _lighten(c0, 0.18);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c0, mid, bottom],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.7, -0.85),
                  radius: 1.1,
                  colors: [
                    accent.withValues(alpha: 0.55),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            CustomPaint(painter: _PosterPainter(accent: accent)),
            // Léger vignettage pour la profondeur.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
            // Grande icône remplissant la vignette.
            Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: Center(child: _fullIcon()),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grande icône/emoji remplissant la vignette, avec ombre et reflet.
  Widget _fullIcon() {
    if (visual.emoji != null) {
      return FittedBox(
        fit: BoxFit.contain,
        child: Text(
          visual.emoji!,
          style: TextStyle(
            fontSize: size * 0.8,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: size * 0.08,
                offset: Offset(0, size * 0.03),
              ),
            ],
          ),
        ),
      );
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFE7E4F7)],
      ).createShader(bounds),
      child: Icon(
        visual.icon ?? Icons.help_outline,
        size: size * 0.82,
        color: Colors.white,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: size * 0.07,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
    );
  }
}

/// Stries lumineuses diagonales + arc d'accent translucide.
class _PosterPainter extends CustomPainter {
  _PosterPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(size.width * 0.2, 0);
    canvas.rotate(-math.pi / 9);
    final bandWidth = size.width * 0.16;
    for (var x = -size.width; x < size.width * 1.6; x += bandWidth * 2.4) {
      canvas.drawRect(
        Rect.fromLTWH(x, -size.height, bandWidth, size.height * 3),
        stripePaint,
      );
    }
    canvas.restore();

    final arcPaint = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.0), accent.withValues(alpha: 0.4)],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 1.1),
      size.width * 0.6,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PosterPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
