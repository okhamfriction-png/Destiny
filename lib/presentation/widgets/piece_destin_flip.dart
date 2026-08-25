import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dice_3d.dart' show DestinyOmen;

/// La « Pièce du destin » : BRAVE (éclair) ou SMART (masque).
/// Overlay lancé par le MJ ; tourne sur elle-même puis retombe sur [brave].
///
/// L'animation enchaîne plusieurs demi-tours sur l'axe Y (effet 3D), la face
/// visible bascule selon le sens de la rotation, puis se fige sur le résultat.
/// [onFini] est appelé quand l'animation + le temps de lecture sont terminés.
class PieceDestinFlip extends StatefulWidget {
  const PieceDestinFlip({
    required this.brave,
    required this.onFini,
    this.size = 240,
    super.key,
  });

  /// Résultat sur lequel la pièce retombe (true = BRAVE, false = SMART).
  final bool brave;
  final double size;
  final VoidCallback onFini;

  @override
  State<PieceDestinFlip> createState() => _PieceDestinFlipState();
}

class _PieceDestinFlipState extends State<PieceDestinFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  // Nombre de demi-tours avant l'arrêt (impair/pair ajusté pour finir sur la
  // bonne face). On vise ~5 tours complets pour un beau spin.
  static const int _demiToursBase = 10;
  late final int _demiTours;

  @override
  void initState() {
    super.initState();
    // On veut terminer face « brave » visible. Face avant = BRAVE quand le
    // nombre de demi-tours affichés est pair. On ajuste la parité au résultat.
    final pairPourBrave = _demiToursBase.isEven;
    _demiTours = (pairPourBrave == widget.brave)
        ? _demiToursBase
        : _demiToursBase + 1;
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    // Lecture du résultat, puis on sort.
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future<void>.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) widget.onFini();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Décélération marquée en fin de course (la pièce ralentit et se pose).
  double get _t => Curves.easeOutCubic.transform(_c.value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onFini, // le MJ peut fermer d'un tap
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PIÈCE DU DESTIN',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final angle = _t * _demiTours * math.pi;
                // Face avant visible tant que cos(angle) >= 0.
                final faceBrave = math.cos(angle) >= 0;
                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012) // perspective
                  ..rotateY(angle);
                // La face arrière est vue « par derrière » → son contenu serait
                // en miroir (texte à l'envers). On le pré-miroite pour corriger.
                if (!faceBrave) {
                  matrix.multiply(Matrix4.diagonal3Values(-1.0, 1.0, 1.0));
                }
                // Léger rebond vertical pendant le vol.
                final saut = math.sin(_t * math.pi) * widget.size * 0.18;
                return Transform.translate(
                  offset: Offset(0, -saut),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: matrix,
                    child: _Piece(brave: faceBrave, size: widget.size),
                  ),
                );
              },
            ),
            const SizedBox(height: 26),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Opacity(
                opacity: _c.isCompleted ? 1 : 0,
                child: Text(
                  widget.brave ? 'BRAVE — le courage' : 'SMART — la ruse',
                  style: TextStyle(
                      color: widget.brave
                          ? const Color(0xFFF57C00)
                          : const Color(0xFFB388FF),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rendu d'une face de la pièce : disque doré + dégradé + icône + label.
class _Piece extends StatelessWidget {
  const _Piece({required this.brave, required this.size});
  final bool brave;
  final double size;

  @override
  Widget build(BuildContext context) {
    final grad = brave ? DestinyOmen.braveGradient : DestinyOmen.smartGradient;
    final icon = brave ? Icons.bolt : Icons.theater_comedy;
    final label = brave ? 'BRAVE' : 'SMART';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: grad, radius: 0.95),
        border: Border.all(color: const Color(0xFFFFC24B), width: size * 0.03),
        boxShadow: [
          BoxShadow(
            color: grad[1].withValues(alpha: 0.55),
            blurRadius: size * 0.18,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: size * 0.38,
              color: Colors.white,
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: size * 0.06,
                    offset: Offset(0, size * 0.02)),
              ]),
          SizedBox(height: size * 0.04),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.15,
                  letterSpacing: 3,
                  shadows: const [
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ])),
        ],
      ),
    );
  }
}
