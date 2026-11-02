import 'package:flutter/material.dart';

import '../../application/state/music_controller.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';

/// La bibliothèque musicale : les pistes par catégorie, triées de A à Z (ou
/// de Z à A), et la barre de lecture en bas.
class MusicScreen extends StatefulWidget {
  const MusicScreen({required this.controller, super.key});

  final MusicController controller;

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  String? _selected;

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

  static const Map<String, IconData> _categoryIcons = {
    'Ambiances': Icons.terrain,
    'Émotions': Icons.favorite,
    'Thèmes': Icons.movie,
    'Lieux': Icons.place,
    'Univers': Icons.videogame_asset,
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final t = context.textes;
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('musique.$x', v);

    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            k('vide'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, color: d.texteSecondaire),
          ),
        ),
      );
    }

    final categories = c.categories;
    final selected = (_selected != null && categories.contains(_selected)) ? _selected! : categories.first;
    final tracks = c.tracksOf(selected);

    Widget centre(Widget enfant) =>
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: enfant));

    return Column(
      children: [
        // Filtres par catégorie.
        centre(Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                ChoiceChip(
                  avatar: Icon(_categoryIcons[category] ?? Icons.library_music, size: 18, color: d.titre),
                  label: Text(k('categorie', {'nom': category, 'n': '${c.tracksOf(category).length}'})),
                  selected: selected == category,
                  selectedColor: d.or.withValues(alpha: 0.3),
                  side: BorderSide(color: selected == category ? d.titre : d.filet),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selected = category),
                ),
            ],
          ),
        )),
        // Tri alphabétique (A→Z / Z→A).
        centre(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                tracks.length == 1 ? k('piste') : k('pistes', {'n': '${tracks.length}'}),
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: d.texteSecondaire),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: c.toggleSortOrder,
                icon: Icon(c.ascending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                label: Text(c.ascending ? k('tri_az') : k('tri_za')),
              ),
            ],
          ),
        )),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              for (final piste in tracks)
                centre(_TrackTile(
                  track: piste,
                  isCurrent: c.current?.file == piste.file,
                  isPlaying: c.current?.file == piste.file && c.playing,
                  onTap: () => c.toggle(piste),
                )),
            ],
          ),
        ),
        if (c.current != null) _NowPlayingBar(controller: c),
      ],
    );
  }
}

/// Icône thématique par piste (clé = titre sans le numéro de variante).
const Map<String, IconData> _trackIcons = {
  // Ambiances
  'Plage': Icons.beach_access,
  'Blizzard': Icons.ac_unit,
  'Grotte': Icons.dark_mode,
  'Ville': Icons.location_city,
  'Forêt': Icons.forest,
  'Pluie': Icons.umbrella,
  'Égouts': Icons.water,
  'Navire': Icons.sailing,
  'Marais': Icons.grass,
  'Orage': Icons.thunderstorm,
  'Volcan': Icons.local_fire_department,
  'Taverne': Icons.sports_bar,
  // Émotions
  'Climax': Icons.whatshot,
  'Colère': Icons.sentiment_very_dissatisfied,
  'Émerveillement': Icons.auto_awesome,
  'Joie': Icons.sentiment_very_satisfied,
  'Mystère': Icons.help_outline,
  'Nostalgie': Icons.hourglass_bottom,
  'Peur': Icons.sentiment_dissatisfied,
  'Recueillement': Icons.self_improvement,
  'Surprise': Icons.celebration,
  'Tension': Icons.bolt,
  'Trahison': Icons.heart_broken,
  'Traque': Icons.directions_run,
  'Tristesse': Icons.water_drop,
  // Thèmes
  'Commencement': Icons.flag,
  'Conclusion': Icons.emoji_events,
  'Ashen Oath': Icons.shield,
  'Destiny Storm': Icons.thunderstorm,
};

/// Couleur/dégradé propre à chaque piste, pour distinguer l'ambiance ou
/// l'émotion au premier coup d'œil (clé = titre sans numéro de variante).
const Map<String, List<Color>> _trackColors = {
  // Ambiances
  'Plage': [Color(0xFF36D1DC), Color(0xFFFFD194)],
  'Blizzard': [Color(0xFFE0EAFC), Color(0xFF74A9D8)],
  'Grotte': [Color(0xFF3E3B45), Color(0xFF14101A)],
  'Ville': [Color(0xFF485563), Color(0xFF29323C)],
  'Forêt': [Color(0xFF11998E), Color(0xFF38EF7D)],
  'Pluie': [Color(0xFF3A6073), Color(0xFF16222A)],
  'Égouts': [Color(0xFF4E5C3F), Color(0xFF1B2719)],
  'Navire': [Color(0xFF2193B0), Color(0xFF6DD5ED)],
  'Marais': [Color(0xFF5A6E3A), Color(0xFF2C3B1E)],
  'Orage': [Color(0xFF3A1C71), Color(0xFF0B8793)],
  'Volcan': [Color(0xFFF12711), Color(0xFFF5AF19)],
  'Taverne': [Color(0xFFC98E3E), Color(0xFF6E3B1E)],
  // Émotions
  'Climax': [Color(0xFFFF0844), Color(0xFFFFB199)],
  'Colère': [Color(0xFFCB2D3E), Color(0xFF7A0E0E)],
  'Émerveillement': [Color(0xFF7F00FF), Color(0xFFE100FF)],
  'Joie': [Color(0xFFFFE000), Color(0xFFFF8A00)],
  'Mystère': [Color(0xFF4568DC), Color(0xFF20123A)],
  'Nostalgie': [Color(0xFFD1913C), Color(0xFF8E6E53)],
  'Peur': [Color(0xFF0F0C29), Color(0xFF302B63)],
  'Recueillement': [Color(0xFF8E9EAB), Color(0xFF45617A)],
  'Surprise': [Color(0xFFF953C6), Color(0xFF00C9FF)],
  'Tension': [Color(0xFFFFB75E), Color(0xFFED5E03)],
  'Trahison': [Color(0xFF870000), Color(0xFF190A05)],
  'Traque': [Color(0xFFFF512F), Color(0xFFDD2476)],
  'Tristesse': [Color(0xFF2980B9), Color(0xFF2C3E50)],
  // Thèmes
  'Commencement': [Color(0xFF1F4037), Color(0xFF99F2C8)],
  'Conclusion': [Color(0xFFFFD700), Color(0xFFB8860B)],
  'Ashen Oath': [Color(0xFF8E0E00), Color(0xFF1F1C18)],
  'Destiny Storm': [Color(0xFF360033), Color(0xFF0B8793)],
};

const Map<String, List<Color>> _categoryFallback = {
  'Ambiances': [Color(0xFF11998E), Color(0xFF38EF7D)],
  'Émotions': [Color(0xFFDD2476), Color(0xFFFF512F)],
  'Thèmes': [Color(0xFFF7971E), Color(0xFFFFD200)],
};

String _baseKey(MusicTrack t) =>
    t.title.replaceFirst(RegExp(r'\s*\d+$'), '').trim();

IconData _iconFor(MusicTrack t) {
  return _trackIcons[_baseKey(t)] ??
      switch (t.category) {
        'Ambiances' => Icons.terrain,
        'Émotions' => Icons.favorite,
        'Thèmes' => Icons.movie,
        _ => Icons.music_note,
      };
}

List<Color> _gradientFor(MusicTrack t) {
  return _trackColors[_baseKey(t)] ??
      _categoryFallback[t.category] ??
      const [Color(0xFF614385), Color(0xFF516395)];
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final MusicTrack track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    final gradient = _gradientFor(track);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCurrent ? Color.alphaBlend(d.or.withValues(alpha: d.sombre ? 0.16 : 0.12), d.carte) : d.carte,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isCurrent ? d.titre : d.filet, width: isCurrent ? 1.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // La vignette de la piste : son dégradé et son icône.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_iconFor(track), color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    track.title,
                    style: TextStyle(
                      fontFamily: kPoliceTexte,
                      fontSize: 15,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                      color: d.texte,
                    ),
                  ),
                ),
                if (track.loop)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.loop, size: 16, color: d.texteSecondaire),
                  ),
                Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: d.titre,
                  size: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({required this.controller});

  final MusicController controller;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    final t = context.textes;
    final current = controller.current!;
    final dur = controller.duration.inMilliseconds.toDouble();
    final pos = controller.position.inMilliseconds.toDouble().clamp(0, dur <= 0 ? 1 : dur);
    final temps = TextStyle(fontFamily: kPoliceTexte, fontSize: 12, color: d.texteSecondaire);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: d.carte,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: d.filet)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: d.sombre ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.music_note, color: d.titre),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    current.title,
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, fontWeight: FontWeight.w600, color: d.texte),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: t.t(controller.playing ? 'accessibilite.pause' : 'accessibilite.lecture'),
                  icon: Icon(controller.playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                  iconSize: 40,
                  color: d.titre,
                  onPressed: controller.togglePlayPause,
                ),
                IconButton(
                  tooltip: t.t('accessibilite.arreter'),
                  icon: const Icon(Icons.stop_circle),
                  iconSize: 32,
                  color: d.texteSecondaire,
                  onPressed: controller.stop,
                ),
              ],
            ),
            Row(
              children: [
                Text(_fmt(controller.position), style: temps),
                Expanded(
                  child: Slider(
                    value: pos.toDouble(),
                    max: dur <= 0 ? 1 : dur,
                    onChanged: (v) => controller.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Text(_fmt(controller.duration), style: temps),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
