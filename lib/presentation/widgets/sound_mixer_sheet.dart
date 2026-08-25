import 'package:flutter/material.dart';

import '../../application/state/music_controller.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
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
                        for (final cat in c.categories) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 8),
                            child: Text(cat.toUpperCase(),
                                style: const TextStyle(
                                    color: _lav,
                                    letterSpacing: 2,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in c.tracksOf(cat))
                                _TrackChip(
                                  title: t.title,
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
    required this.active,
    required this.playing,
    required this.onTap,
  });

  final String title;
  final bool active;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _gold : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _gold.withValues(alpha: 0.16) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? _gold : Colors.white24,
              width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                playing
                    ? Icons.pause
                    : (active ? Icons.play_arrow : Icons.play_circle_outline),
                size: 18,
                color: color),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
