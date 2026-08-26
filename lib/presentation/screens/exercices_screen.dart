import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemChrome, SystemUiMode;

import '../../application/services/audio_service.dart';
import '../../domain/entities/exercice.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

/// Ordre des thèmes (le premier est l'onglet par défaut).
const List<String> _themes = [
  'Échauffement',
  'Statut',
  'Spontanéité',
  'Écoute',
  'Dialogue',
  'Imagination',
];

/// Couleur d'accent par thème d'exercice.
Color _categorieColor(String cat) {
  switch (cat) {
    case 'Échauffement':
      return const Color(0xFFFF8A80);
    case 'Statut':
      return const Color(0xFFFFC24B);
    case 'Spontanéité':
      return const Color(0xFF5EE0C4);
    case 'Écoute':
      return const Color(0xFF64B5F6);
    case 'Imagination':
      return const Color(0xFFB79CFF);
    case 'Dialogue':
      return const Color(0xFF4DD0E1); // cyan dialogue
    case 'Solo':
      return const Color(0xFFF48FB1); // rose diction
    default:
      return _lav;
  }
}

IconData _categorieIcon(String cat) {
  switch (cat) {
    case 'Échauffement':
      return Icons.local_fire_department;
    case 'Statut':
      return Icons.swap_vert;
    case 'Spontanéité':
      return Icons.bolt;
    case 'Écoute':
      return Icons.hearing;
    case 'Imagination':
      return Icons.auto_awesome;
    case 'Dialogue':
      return Icons.forum;
    case 'Solo':
      return Icons.record_voice_over;
    default:
      return Icons.sports_kabaddi;
  }
}

/// Module Exercices : échauffements et jeux de théâtre courts (adultes),
/// chronométrés, sans score. But : commencer la séance dans le rire.
class ExercicesScreen extends StatefulWidget {
  const ExercicesScreen({required this.audioService, super.key});
  final AudioService audioService;

  @override
  State<ExercicesScreen> createState() => _ExercicesScreenState();
}

class _ExercicesScreenState extends State<ExercicesScreen> {
  List<Exercice> _exercices = const [];
  List<String> _principes = const [];
  List<String> _virelangues = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/exercices.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _exercices = (data['exercices'] as List)
          .map((e) => Exercice.fromJson(e as Map<String, dynamic>))
          .toList();
      _principes =
          (data['principes'] as List).map((e) => e as String).toList();
      _virelangues = [
        for (final v in (data['virelangues'] as List? ?? const [])) v as String
      ];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  /// Un principe par séance : stable sur la journée, tourne chaque jour.
  String get _principeDuJour {
    if (_principes.isEmpty) return '';
    final jour = DateTime.now().difference(DateTime(2020)).inDays;
    return _principes[jour % _principes.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0818),
        appBar: AppBar(
            title: const Text('Exercices'),
            backgroundColor: Colors.transparent,
            elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Thèmes présents, dans l'ordre voulu (Échauffement d'abord) ; inconnus à la fin.
    final themes = [
      for (final t in _themes)
        if (_exercices.any((e) => e.categorie == t)) t,
    ];
    for (final e in _exercices) {
      if (!themes.contains(e.categorie)) themes.add(e.categorie);
    }
    // Onglet Solo (diction / virelangues), à part du reste.
    if (_virelangues.isNotEmpty) themes.add('Solo');
    return DefaultTabController(
      length: themes.length,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0818),
        appBar: AppBar(
          title: const Text('Exercices'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              for (final t in themes)
                Tab(
                    icon: Icon(_categorieIcon(t), color: _categorieColor(t)),
                    text: t),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: _principeBanner(),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final t in themes)
                    if (t == 'Solo')
                      _DictionTab(virelangues: _virelangues)
                    else
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [
                          for (final ex
                              in _exercices.where((e) => e.categorie == t))
                            _ExerciceTile(
                              exercice: ex,
                              onTap: () =>
                                  Navigator.of(context).push(MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => ExerciceRunScreen(
                                    exercice: ex,
                                    audioService: widget.audioService),
                              )),
                            ),
                        ],
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _principeBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PRINCIPE DU JOUR',
                style: TextStyle(
                    color: _gold,
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_principeDuJour,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ExerciceTile extends StatelessWidget {
  const _ExerciceTile({required this.exercice, required this.onTap});
  final Exercice exercice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categorieColor(exercice.categorie);
    final min = (exercice.duree / 60).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_categorieIcon(exercice.categorie),
                    color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(exercice.nom,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Text('$min min',
                            style: TextStyle(color: color, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(exercice.consigne,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglet Solo — Diction : les 50 virelangues les plus populaires, avec un
/// tirage « au hasard » et un affichage en grand pour s'entraîner à voix haute.
class _DictionTab extends StatefulWidget {
  const _DictionTab({required this.virelangues});
  final List<String> virelangues;

  @override
  State<_DictionTab> createState() => _DictionTabState();
}

class _DictionTabState extends State<_DictionTab> {
  static const Color _rose = Color(0xFFF48FB1);
  final Random _rng = Random();
  final ScrollController _scroll = ScrollController();
  int? _sel;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _hasard() {
    if (widget.virelangues.isEmpty) return;
    setState(() => _sel = _rng.nextInt(widget.virelangues.length));
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.virelangues.length;
    final courant = _sel == null ? null : widget.virelangues[_sel!];
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const Row(children: [
          Icon(Icons.record_voice_over, color: _rose, size: 18),
          SizedBox(width: 8),
          Text('DICTION — VIRELANGUES',
              style: TextStyle(
                  color: _rose,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text('Les $total plus populaires. Articule, accélère, recommence.',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 12),
        // Carte du virelangue en cours (grande, lisible à voix haute).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _rose.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _rose.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (courant != null)
                Text('N° ${_sel! + 1} / $total',
                    style: const TextStyle(
                        color: _rose,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                courant ?? 'Touche « Au hasard », ou choisis un virelangue dans la liste.',
                style: TextStyle(
                    color: courant == null ? Colors.white54 : Colors.white,
                    fontSize: courant == null ? 16 : 24,
                    height: 1.35,
                    fontWeight:
                        courant == null ? FontWeight.w500 : FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _hasard,
            icon: const Icon(Icons.casino),
            label: const Text('Au hasard'),
            style: FilledButton.styleFrom(
              backgroundColor: _rose,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('TOUS LES VIRELANGUES',
            style: TextStyle(
                color: Colors.white38,
                letterSpacing: 2,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < total; i++)
          InkWell(
            onTap: () => setState(() => _sel = i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _sel == i
                    ? _rose.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _sel == i ? _rose : Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: _rose.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(widget.virelangues[i],
                        style: const TextStyle(
                            color: Colors.white, height: 1.3)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Écran de jeu d'un exercice : consigne + chrono + célébration finale.
class ExerciceRunScreen extends StatefulWidget {
  const ExerciceRunScreen(
      {required this.exercice, required this.audioService, super.key});
  final Exercice exercice;
  final AudioService audioService;

  @override
  State<ExerciceRunScreen> createState() => _ExerciceRunScreenState();
}

class _ExerciceRunScreenState extends State<ExerciceRunScreen> {
  late int _remaining = widget.exercice.duree;
  Timer? _timer;
  bool _running = false;
  bool _done = false;

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggle() {
    if (_done) return;
    setState(() => _running = !_running);
    _timer?.cancel();
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remaining--;
          if (_remaining <= 0) {
            _remaining = 0;
            _running = false;
            _done = true;
            t.cancel();
            widget.audioService.playShine(); // son joyeux de célébration
          }
        });
      });
    }
  }

  void _restart() {
    setState(() {
      _remaining = widget.exercice.duree;
      _done = false;
      _running = false;
    });
    _timer?.cancel();
  }

  String get _fmt {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _categorieColor(widget.exercice.categorie);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  Icon(_categorieIcon(widget.exercice.categorie),
                      color: color, size: 40),
                  const SizedBox(height: 12),
                  Text(widget.exercice.nom,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Text(widget.exercice.consigne,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 17, height: 1.4)),
                  const SizedBox(height: 36),
                  Text(_done ? 'Bravo !' : _fmt,
                      style: TextStyle(
                          color: _done ? _gold : color,
                          fontSize: _done ? 64 : 88,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  if (_done)
                    const Text('Exercice terminé. On applaudit !',
                        style: TextStyle(color: Colors.white54, fontSize: 16))
                  else
                    Text(_running ? 'C\'est parti !' : 'Prêts ?',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 16)),
                  const Spacer(),
                  if (!_done)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _toggle,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pause' : 'Démarrer'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('Rejouer'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Terminer'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (_done) const Positioned.fill(child: IgnorePointer(child: _Confetti())),
        ],
      ),
    );
  }
}

/// Pluie de confettis colorés (célébration), une passe animée.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..forward();
  late final List<_Particle> _parts = _makeParticles();

  static const _colors = [
    Color(0xFFFFC24B),
    Color(0xFFFF8A80),
    Color(0xFF5EE0C4),
    Color(0xFFB79CFF),
    Colors.white,
  ];

  List<_Particle> _makeParticles() {
    final rng = Random();
    return List.generate(90, (i) {
      return _Particle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.35,
        speed: 0.7 + rng.nextDouble() * 0.6,
        drift: (rng.nextDouble() - 0.5) * 0.3,
        size: 6 + rng.nextDouble() * 8,
        color: _colors[rng.nextInt(_colors.length)],
        rot: rng.nextDouble() * 6.28,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) =>
          CustomPaint(painter: _ConfettiPainter(_parts, _c.value)),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.color,
    required this.rot,
  });
  final double x, delay, speed, drift, size, rot;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts, this.t);
  final List<_Particle> parts;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = (local * p.speed) * (size.height + 40) - 20;
      final x = (p.x + p.drift * local) * size.width;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - local).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + local * 6);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
