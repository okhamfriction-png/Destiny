import 'dart:math';

import 'package:flutter/material.dart';

/// Dé animé « style 3D » : tumble en perspective au lancer puis se stabilise
/// sur une face. Générique sur le nombre de faces et le rendu de chaque face.
class Dice3D extends StatefulWidget {
  const Dice3D({
    required this.sides,
    required this.faceBuilder,
    this.size = 120,
    this.gradient = const [Color(0xFFF5F3FF), Color(0xFFCFC6F5)],
    this.gradientForFace,
    this.onResult,
    this.onRollStart,
    super.key,
  });

  /// Nombre de faces (ex. 6, 3 ou 2).
  final int sides;

  /// Construit le contenu d'une face donnée (index dans [0, sides)).
  final Widget Function(int faceIndex) faceBuilder;

  final double size;
  final List<Color> gradient;

  /// Dégradé optionnel par face (sinon [gradient] est utilisé).
  final List<Color> Function(int faceIndex)? gradientForFace;

  final ValueChanged<int>? onResult;

  /// Appelé au tout début d'un lancer (tap ou bouton), pour jouer un son.
  final VoidCallback? onRollStart;

  @override
  State<Dice3D> createState() => Dice3DState();
}

class Dice3DState extends State<Dice3D> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _random = Random();

  int _displayedFace = 0;
  int _targetFace = 0;
  int get currentFace => _targetFace;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..addListener(_onAnim);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnim);
    _controller.dispose();
    super.dispose();
  }

  void _onAnim() {
    final t = _controller.value;
    setState(() {
      if (t < 0.82) {
        // Phase de tumble : on fait défiler les faces.
        _displayedFace = (t * widget.sides * 6).floor() % widget.sides;
      } else {
        _displayedFace = _targetFace;
      }
    });
  }

  /// Lance le dé et renvoie la face obtenue via [Dice3D.onResult].
  void roll() {
    if (_controller.isAnimating) return;
    widget.onRollStart?.call();
    _targetFace = _random.nextInt(widget.sides);
    _controller.forward(from: 0).whenComplete(() {
      widget.onResult?.call(_targetFace);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: roll,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // Atténuation de la rotation en fin de course (effet "se pose").
          final ease = Curves.easeOut.transform(t);
          final settle = (1 - ease);
          final rotX = sin(t * pi * 6) * settle * 0.9;
          final rotY = t * pi * 4 * settle + (t * pi * 4);
          final scale = 1 + sin(t * pi) * 0.06;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateX(rotX)
            ..rotateY(rotY * settle)
            ..scaleByDouble(scale, scale, scale, 1);

          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: child,
          );
        },
        child: _DieFace(
          size: widget.size,
          gradient: widget.gradientForFace?.call(_displayedFace) ??
              widget.gradient,
          child: widget.faceBuilder(_displayedFace),
        ),
      ),
    );
  }
}

/// Rendu statique d'une face avec biseau et ombrage pour l'effet de relief.
class _DieFace extends StatelessWidget {
  const _DieFace({
    required this.size,
    required this.gradient,
    required this.child,
  });

  final double size;
  final List<Color> gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Face d'un dé à six points (pips) classique pour la valeur [value] (1..6).
class PipFace extends StatelessWidget {
  const PipFace({required this.value, this.size = 120, super.key});

  final int value;
  final double size;

  static const Map<int, List<Alignment>> _layout = {
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    5: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.center,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    6: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _layout[value] ?? const [Alignment.center];
    final pipSize = size * 0.16;
    return Padding(
      padding: EdgeInsets.all(size * 0.16),
      child: Stack(
        children: [
          for (final alignment in pips)
            Align(
              alignment: alignment,
              child: Container(
                width: pipSize,
                height: pipSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2350),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 2,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dégradés de la pièce d'approche : Brave (orange) / Smart (violet).
class DestinyOmen {
  DestinyOmen._();

  static const List<Color> braveGradient = [
    Color(0xFFFFB347),
    Color(0xFFF57C00),
    Color(0xFF7A3A00),
  ];

  static const List<Color> smartGradient = [
    Color(0xFFB388FF),
    Color(0xFF7E3FF2),
    Color(0xFF2A1259),
  ];
}

/// Face de la pièce d'approche : BRAVE (éclair) ou SMART (masque).
class DestinyOmenFace extends StatelessWidget {
  const DestinyOmenFace({required this.brave, this.size = 130, super.key});

  final bool brave;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = brave ? Icons.bolt : Icons.theater_comedy;
    final label = brave ? 'BRAVE' : 'SMART';

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _OmenPainter()),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: size * 0.36,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: size * 0.08,
                  offset: Offset(0, size * 0.03),
                ),
              ],
            ),
            SizedBox(height: size * 0.06),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.14,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rayons lumineux partant du centre.
class _OmenPainter extends CustomPainter {
  _OmenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);

    const rays = 16;
    for (var i = 0; i < rays; i++) {
      final a = (i / rays) * 2 * pi;
      const spread = 0.09;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + cos(a - spread) * radius,
          center.dy + sin(a - spread) * radius,
        )
        ..lineTo(
          center.dx + cos(a + spread) * radius,
          center.dy + sin(a + spread) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OmenPainter oldDelegate) => false;
}
