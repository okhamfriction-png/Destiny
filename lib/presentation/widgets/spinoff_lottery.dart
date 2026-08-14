import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Animation « loterie » affichée pendant la recherche d'un film (spin-off) :
/// des titres défilent vite, comme si on cherchait parmi d'autres films.
class SpinoffLottery extends StatefulWidget {
  const SpinoffLottery({required this.decade, required this.genre, super.key});

  final String decade;
  final String genre;

  @override
  State<SpinoffLottery> createState() => _SpinoffLotteryState();
}

class _SpinoffLotteryState extends State<SpinoffLottery> {
  static const List<String> _decoys = [
    'Jurassic Park', 'Terminator 2', 'Titanic', 'Matrix', 'Alien',
    'Le Roi Lion', 'Gladiator', 'Pulp Fiction', 'Rocky', 'Jaws',
    'Retour vers le futur', 'Indiana Jones', 'Die Hard', 'Blade Runner',
    'Le Silence des agneaux', 'Seven', 'Fight Club', 'Heat', 'Predator',
    'Speed', 'Twister', 'Armageddon', 'Independence Day', 'Men in Black',
    'Le Cinquième Élément', 'Mission Impossible', 'Braveheart', 'Forrest Gump',
    'Léon', 'Scream', 'The Ring', 'Shining', 'E.T.', 'Ghostbusters',
    'Top Gun', 'Rambo', 'RoboCop', 'Total Recall', 'Mad Max', 'The Thing',
  ];

  final Random _rng = Random();
  Timer? _timer;
  int _index = 0;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        _index = _rng.nextInt(_decoys.length);
        _tick++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _Spinner(),
                const SizedBox(width: 8),
                Text(
                  'Recherche d\'un film… ${widget.genre} · ${widget.decade}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // La « fenêtre » de la loterie : un titre qui défile.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A2350), Color(0xFF160F30)],
                  ),
                  border: Border.all(
                      color: const Color(0xFFFFC24B).withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 70),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.6), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    _decoys[_index],
                    key: ValueKey(_tick),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('La roue tourne…',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Icon(Icons.movie_filter,
          size: 18, color: Theme.of(context).colorScheme.primary),
    );
  }
}
