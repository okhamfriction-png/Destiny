import 'package:flutter/material.dart';

import '../../application/state/music_controller.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

/// Couleur d'accent par catégorie de son (repère visuel dans la régie).
Color _categoryColor(String cat) {
  switch (cat) {
    case 'Émotions':
      return const Color(0xFFFF8A80); // corail
    case 'Lieux':
      return const Color(0xFF5EE0C4); // teal
    case 'Ambiances':
      return const Color(0xFF64B5F6); // bleu
    case 'Thèmes':
      return const Color(0xFFFFC24B); // or
    case 'Univers':
      return const Color(0xFFB79CFF); // violet
    default:
      return _lav;
  }
}

/// Icône adaptée à la catégorie de son (à la place d'un bouton lecture).
IconData _categoryIcon(String cat) {
  switch (cat) {
    case 'Émotions':
      return Icons.favorite;
    case 'Lieux':
      return Icons.place;
    case 'Ambiances':
      return Icons.landscape;
    case 'Thèmes':
      return Icons.movie_creation;
    case 'Univers':
      return Icons.auto_awesome;
    default:
      return Icons.music_note;
  }
}

/// Ouvre le pupitre de régie son (mixeur) : accès à toutes les musiques
/// pendant le chrono d'histoire, pour lancer une ambiance en direct.
Future<void> showSoundMixer(BuildContext context, MusicController controller) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF120F1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => SoundMixerSheet(controller: controller),
  );
}

/// Panneau « Régie son » : la table de mixage du régisseur. Liste toutes les
/// pistes par catégorie ; un tap lance / met en pause. Le chrono tourne dessous.
class SoundMixerSheet extends StatefulWidget {
  const SoundMixerSheet({required this.controller, super.key});
  final MusicController controller;

  @override
  State<SoundMixerSheet> createState() => _SoundMixerSheetState();
}

class _SoundMixerSheetState extends State<SoundMixerSheet> {
  // Catégories repliées (masquées) par le régisseur.
  final Set<String> _collapsed = {};
  bool _initCollapse = false;

  // Ordre d'affichage voulu ; le reste est ajouté à la fin, alphabétiquement.
  static const List<String> _order = [
    'Émotions',
    'Lieux',
    'Ambiances',
    'Thèmes',
    'Univers',
  ];
  // Catégories dépliées par défaut à l'ouverture.
  static const Set<String> _openByDefault = {'Émotions', 'Lieux'};

  List<String> _ordered(List<String> cats) {
    int idx(String s) {
      final i = _order.indexOf(s);
      return i < 0 ? 999 : i;
    }

    final list = [...cats];
    list.sort((a, b) {
      final d = idx(a).compareTo(idx(b));
      return d != 0 ? d : a.compareTo(b);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final cats = _ordered(c.categories);
    // Première ouverture : on ne déplie qu'Émotions et Lieux, le reste masqué.
    if (!_initCollapse && !c.loading && cats.isNotEmpty) {
      _initCollapse = true;
      for (final cat in cats) {
        if (!_openByDefault.contains(cat)) _collapsed.add(cat);
      }
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scroll) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: _gold),
                  const SizedBox(width: 10),
                  const Text('Régie son',
                      style: TextStyle(
                          color: _gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (c.playing)
                    TextButton.icon(
                      onPressed: () => c.stop(),
                      icon: const Icon(Icons.stop_circle_outlined,
                          color: Colors.white70),
                      label: const Text('Couper',
                          style: TextStyle(color: Colors.white70)),
                    ),
                ],
              ),
            ),
            // Bandeau « en cours ».
            if (c.current != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(c.playing ? Icons.graphic_eq : Icons.pause,
                        color: _gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${c.playing ? "En cours" : "En pause"} : ${c.current!.title}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(c.playing ? Icons.pause : Icons.play_arrow,
                          color: _gold),
                      onPressed: () => c.togglePlayPause(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: c.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        for (final cat in cats) ...[
                          // En-tête repliable : tap pour masquer/afficher.
                          InkWell(
                            onTap: () => setState(() {
                              if (!_collapsed.remove(cat)) _collapsed.add(cat);
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: 14, bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                      _collapsed.contains(cat)
                                          ? Icons.chevron_right
                                          : Icons.expand_more,
                                      color: _categoryColor(cat),
                                      size: 18),
                                  const SizedBox(width: 4),
                                  Text(cat.toUpperCase(),
                                      style: TextStyle(
                                          color: _categoryColor(cat),
                                          letterSpacing: 2,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 8),
                                  Text('${c.tracksOf(cat).length}',
                                      style: TextStyle(
                                          color: _categoryColor(cat)
                                              .withValues(alpha: 0.6),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          if (!_collapsed.contains(cat))
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final t in c.tracksOf(cat))
                                  _TrackChip(
                                    title: t.title,
                                    color: _categoryColor(cat),
                                    icon: _categoryIcon(cat),
                                    active: c.current?.file == t.file,
                                    playing:
                                        c.current?.file == t.file && c.playing,
                                    onTap: () => c.toggle(t),
                                  ),
                              ],
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackChip extends StatelessWidget {
  const _TrackChip({
    required this.title,
    required this.color,
    required this.icon,
    required this.active,
    required this.playing,
    required this.onTap,
  });

  final String title;
  final Color color;
  final IconData icon;
  final bool active;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? color : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : Colors.white24,
              width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(playing ? Icons.graphic_eq : icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: fg,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
