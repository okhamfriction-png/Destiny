import 'package:flutter/material.dart';

import '../../application/state/spectacle_controller.dart';
import '../../domain/entities/spectacle_turn.dart';
import '../visuals/entity_visuals.dart';
import 'spectacle_archives_screen.dart';

const Color _gold = Color(0xFFFFC24B);

/// Univers (mêmes listes que le mode Chat), « Contemporain » par défaut.
const List<String> _spectacleUniverses = [
  'Contemporain',
  'Policier',
  'High Fantasy',
  'Shonen',
  'Science-Fiction',
  'Dark Fantasy',
  'Cyberpunk',
  'Horreur',
  'Post-apocalyptique',
  'Steampunk',
  'Super-héros',
  'Historique',
];

/// Univers adaptés aux enfants (façon Disney / manga / contes).
const List<String> _spectacleKidUniverses = [
  'Conte de fées',
  'Dessin animé',
  'Manga rigolo',
  'Animaux qui parlent',
  'Super-héros (enfant)',
  'Pirates',
  'Espace rigolo',
  'Monde magique',
  'Sous la mer',
  'Chevaliers & dragons',
];

/// Tons / genres (mêmes que le mode Chat).
const List<String> _spectacleTones = [
  'Aventure',
  'Humour',
  'Drame',
  'Épique',
  'Voyage initiatique',
  'Romance',
  'Mystère',
  'Action',
];

/// Décennies proposées pour le mode Spin-off (film).
const List<String> _spinoffDecades = [
  'années 1970',
  'années 1980',
  'années 1990',
  'années 2000',
  'années 2010',
  'années 2020',
];

/// Genres de film pour le mode Spin-off.
const List<String> _spinoffGenres = [
  'Action',
  'Aventure',
  'Comédie',
  'Drame',
  'Horreur',
  'Science-Fiction',
  'Fantastique',
  'Thriller',
  'Policier',
  'Guerre',
  'Animation',
  'Romance',
];

/// Petit avatar emoji d'un archétype (par son nom), ou null si inconnu.
Widget? _archEmoji(String archetypeName, {double size = 18}) {
  final emoji = EntityVisuals.emojiForArchetypeName(archetypeName);
  if (emoji == null) return null;
  return Text(emoji, style: TextStyle(fontSize: size));
}

/// Onglet « Spectacle » : jeu d'impro long form solo piloté par l'IA.
class SpectacleScreen extends StatefulWidget {
  const SpectacleScreen({required this.controller, super.key});

  final SpectacleController controller;

  @override
  State<SpectacleScreen> createState() => _SpectacleScreenState();
}

class _SpectacleScreenState extends State<SpectacleScreen> {
  final _freeCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _freeCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    // Auto-scroll vers le bas quand le fil grandit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return c.started ? _buildGame(context, c) : _buildSetup(context, c);
  }

  // ------------------------------------------------------------------ SETUP
  Widget _buildSetup(BuildContext context, SpectacleController c) {
    final theme = Theme.of(context);
    final draw = c.draw;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Mode Scène',
                  style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              tooltip: 'Historique des parties',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      SpectacleArchivesScreen(controller: widget.controller))),
            ),
          ],
        ),
        Text(
          'Impro dramatique long form en solo. L\'IA joue trois personnages, '
          'le régisseur et le coach. Tu en incarnes un.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
        ),
        const SizedBox(height: 16),
        if (c.canResume) ...[
          Card(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            child: ListTile(
              leading: Icon(Icons.play_circle_fill,
                  color: theme.colorScheme.primary),
              title: const Text('Reprendre la partie en cours'),
              subtitle: const Text('Une partie non terminée a été trouvée.'),
              trailing: IconButton(
                tooltip: 'Oublier',
                icon: const Icon(Icons.close),
                onPressed: c.discardSaved,
              ),
              onTap: c.resume,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!c.configured)
          Card(
            color: Colors.orange.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Configure d\'abord l\'IA dans Paramètres → Configurer l\'IA '
                '(fournisseur, modèle, jeton). Le Mode Spectacle appelle l\'IA '
                'à chaque tour.',
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text('Type', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SpectacleKind>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: SpectacleKind.spectacle, label: Text('Spectacle')),
            ButtonSegment(
                value: SpectacleKind.spinoff, label: Text('Spin-off (film)')),
          ],
          selected: {c.kind},
          onSelectionChanged: (s) => c.setKind(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          c.isSpinoff
              ? 'Spin-off : on rejoue un vrai film (top 100 de sa décennie), en '
                  'partant du danger. L\'IA choisit le film et les archétypes.'
              : 'Spectacle : lieu, danger et archétypes tirés des catalogues.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
        ),
        const SizedBox(height: 16),
        Text('Sous-mode', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SpectacleMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: SpectacleMode.classique, label: Text('Classique')),
            ButtonSegment(value: SpectacleMode.libre, label: Text('Libre')),
          ],
          selected: {c.mode},
          onSelectionChanged: (s) => c.setMode(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          c.mode == SpectacleMode.classique
              ? 'Classique : 4 répliques proposées à chaque tour, une seule est '
                  'dans la langue de ton archétype.'
              : 'Libre : tu écris ta réplique, l\'IA la note sur 7 critères.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
        ),
        if (!c.isSpinoff) ...[
        const SizedBox(height: 16),
        // Univers et Ton côte à côte.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Univers', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: c.universe,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          enabled: false,
                          value: '__h_genres',
                          child: Text('— Genres —')),
                      for (final u in _spectacleUniverses)
                        DropdownMenuItem(value: u, child: Text(u)),
                      const DropdownMenuItem(
                          enabled: false,
                          value: '__h_kids',
                          child: Text('— Enfant —')),
                      for (final u in _spectacleKidUniverses)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) {
                      if (v == null || v.startsWith('__h')) return;
                      c.setUniverse(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ton', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: c.tone,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                    items: [
                      for (final t in _spectacleTones)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => c.setTone(v ?? _spectacleTones.first),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Longueur des scènes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SceneLength>(
          showSelectedIcon: false,
          style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: const [
            ButtonSegment(value: SceneLength.court, label: Text('Court 10')),
            ButtonSegment(value: SceneLength.normal, label: Text('Normal 20')),
            ButtonSegment(value: SceneLength.long, label: Text('Long 30')),
          ],
          selected: {c.sceneLength},
          onSelectionChanged: (s) => c.setSceneLength(s.first),
        ),
        const SizedBox(height: 8),
        Text(
          'Par défaut « Contemporain », ton « Drame ». Le lieu, le danger et '
          'les paliers ne changent pas — seuls l\'univers et le ton s\'adaptent. '
          'Chaque scène vise ${c.sceneTarget} répliques ; tu choisis ton '
          'personnage à chaque nouvelle scène.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => c.drawDecor(),
          icon: const Icon(Icons.casino),
          label: Text(draw == null ? 'Tirer le décor' : 'Retirer le décor'),
        ),
        if (c.error != null) ...[
          const SizedBox(height: 10),
          Text(c.error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        if (draw != null) ...[
          const SizedBox(height: 16),
          _DecorCard(draw: draw),
          const SizedBox(height: 16),
          Text('Personnage de départ', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < draw.archetypes.length; i++)
                ChoiceChip(
                  avatar: _archEmoji(draw.archetypes[i].name),
                  label: Text(draw.archetypes[i].name),
                  selected: c.playerIndex == i,
                  onSelected: (_) => c.setPlayerIndex(i),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (c.playerArchetype != null)
            Text(
              c.playerArchetype!.line,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: c.configured ? () => c.start() : null,
              icon: const Icon(Icons.theater_comedy),
              label: const Text('Lever le rideau'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
        ] else ...[
          // --- Spin-off (film) ---
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Décennie', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _spinoffDecades.contains(c.decade)
                          ? c.decade
                          : _spinoffDecades.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                      items: [
                        for (final d in _spinoffDecades)
                          DropdownMenuItem(value: d, child: Text(d)),
                      ],
                      onChanged: (v) =>
                          c.setDecade(v ?? _spinoffDecades.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Genre', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _spinoffGenres.contains(c.genre)
                          ? c.genre
                          : _spinoffGenres.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                      items: [
                        for (final g in _spinoffGenres)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (v) => c.setGenre(v ?? _spinoffGenres.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Longueur des scènes', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<SceneLength>(
            showSelectedIcon: false,
            style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            segments: const [
              ButtonSegment(value: SceneLength.court, label: Text('Court 10')),
              ButtonSegment(
                  value: SceneLength.normal, label: Text('Normal 20')),
              ButtonSegment(value: SceneLength.long, label: Text('Long 30')),
            ],
            selected: {c.sceneLength},
            onSelectionChanged: (s) => c.setSceneLength(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            'Un vrai film du top 100 le plus populaire de la décennie et du '
            'genre choisis. On récupère lieu, danger et 4 protagonistes ; on '
            'démarre sur le danger et l\'escalade se crée à la volée. Tu ne '
            'choisis pas ton archétype : l\'IA te l\'assigne.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
          if (c.error != null) ...[
            const SizedBox(height: 10),
            Text(c.error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: c.configured ? () => c.start() : null,
              icon: const Icon(Icons.movie_creation_outlined),
              label: const Text('Lever le rideau'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------- GAME
  Widget _buildGame(BuildContext context, SpectacleController c) {
    final theme = Theme.of(context);
    final turn = c.current;
    return Column(
      children: [
        _GameHeader(turn: turn, onQuit: () => _confirmQuit(context, c)),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: [
              if (c.filmContext != null)
                _FilmContextCard(context: c.filmContext!),
              if (turn?.isDestiny ?? false) const _DestinyBanner(),
              for (final item in c.log) _LogBubble(item: item),
              if (turn?.correction != null)
                _CorrectionCard(correction: turn!.correction!),
              if (turn?.crow != null) _CrowCard(crow: turn!.crow!),
              if (turn?.feedback != null)
                _FeedbackCard(child: _renderDynamic(theme, turn!.feedback)),
              if (turn?.isScore ?? false) _ScoreCard(turn: turn!),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(c.error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ),
        _ActionBar(
          controller: c,
          freeCtrl: _freeCtrl,
          onQuitToSetup: () => c.reset(),
        ),
      ],
    );
  }

  Future<void> _confirmQuit(BuildContext context, SpectacleController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitter le spectacle ?'),
        content: const Text('La partie en cours sera perdue.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuer')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitter')),
        ],
      ),
    );
    if (ok == true) c.reset();
  }
}

/// Rendu générique d'une valeur JSON (String / nombre / liste / objet).
Widget _renderDynamic(ThemeData theme, Object? value) {
  if (value == null) return const SizedBox.shrink();
  if (value is String) {
    return Text(value, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35));
  }
  if (value is num || value is bool) {
    return Text('$value', style: theme.textTheme.bodyMedium);
  }
  if (value is List) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in value)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: _renderDynamic(theme, e)),
              ],
            ),
          ),
      ],
    );
  }
  if (value is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in value.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pretty(entry.key.toString()),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 2),
                _renderDynamic(theme, entry.value),
              ],
            ),
          ),
      ],
    );
  }
  return Text('$value', style: theme.textTheme.bodyMedium);
}

String _pretty(String key) {
  const map = {
    'histoire': 'L\'histoire',
    'personnage': 'Ton personnage',
    'scoreGlobal': 'Score',
    'detail': 'Détail',
    'acte1': 'Acte 1',
    'acte2': 'Acte 2',
    'acte3': 'Acte 3',
    'crow': 'CROW (fin Acte 1)',
    'archetype': 'Ton archétype',
    'juste': 'Ce qui était juste',
    'travailler': 'À travailler',
  };
  return map[key] ?? (key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}');
}

// ------------------------------------------------------------------ WIDGETS

class _DecorCard extends StatelessWidget {
  const _DecorCard({required this.draw});

  final SpectacleDraw draw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(theme, 'LIEU', draw.lieu),
            const SizedBox(height: 6),
            _kv(theme, 'DANGER', draw.danger),
            if (draw.roles.isNotEmpty) ...[
              const SizedBox(height: 6),
              _kv(theme, 'RÔLES', draw.roles.join(', ')),
            ],
            if (draw.paliers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Paliers',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              for (var i = 0; i < draw.paliers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${i + 1}. ${draw.paliers[i]}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70, height: 1.3)),
                ),
            ],
            const SizedBox(height: 10),
            Text('Archétypes',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            for (final a in draw.archetypes)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(a.line,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70, height: 1.3)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) => Text.rich(TextSpan(children: [
        TextSpan(
            text: '$k : ',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        TextSpan(text: v, style: theme.textTheme.titleMedium),
      ]));
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.turn, required this.onQuit});

  final SpectacleTurn? turn;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (turn?.acte != null) 'Acte ${turn!.acte}',
      if (turn?.scene != null) 'Scène ${turn!.scene}',
      if (turn?.palier != null) 'Palier ${turn!.palier}',
    ];
    final cible = turn?.cible;
    final posees = turn?.posees;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parts.isEmpty ? 'Spectacle' : parts.join(' · '),
                    style: theme.textTheme.titleSmall),
                if (posees != null && cible != null)
                  Text('Répliques : $posees / $cible',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white54)),
              ],
            ),
          ),
          if (turn?.phase != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(turn!.phase,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          IconButton(
            tooltip: 'Quitter',
            icon: const Icon(Icons.close),
            onPressed: onQuit,
          ),
        ],
      ),
    );
  }
}

class _FilmContextCard extends StatelessWidget {
  const _FilmContextCard({required this.context});

  final FilmContext context;

  @override
  Widget build(BuildContext ctx) {
    final theme = Theme.of(ctx);
    final c = context;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie, color: _gold, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.annee.isEmpty ? c.film : '${c.film} (${c.annee})',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (c.lieu.isNotEmpty)
            Text('Lieu : ${c.lieu}', style: theme.textTheme.bodySmall),
          if (c.danger.isNotEmpty)
            Text('Danger : ${c.danger}', style: theme.textTheme.bodySmall),
          if (c.protagonistes.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final p in c.protagonistes)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Text(
                        EntityVisuals.emojiForArchetypeName(p.archetype) ??
                            '🎭',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${p.prenom}${p.role.isEmpty ? '' : ' — ${p.role}'}'
                        '  ·  ${p.archetype}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: p.antagoniste
                                ? const Color(0xFFFF5252)
                                : Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DestinyBanner extends StatelessWidget {
  const _DestinyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt, color: _gold, size: 18),
          SizedBox(width: 8),
          Text('DESTINY',
              style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _LogBubble extends StatelessWidget {
  const _LogBubble({required this.item});

  final SpectacleLogItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlayer = item.isPlayer;

    // Fond : vert = réussite, rouge = erreur, sinon couleur par défaut.
    Color bg;
    Color border;
    if (item.success == true) {
      bg = Colors.green.withValues(alpha: 0.18);
      border = Colors.green.withValues(alpha: 0.5);
    } else if (item.success == false) {
      bg = Colors.red.withValues(alpha: 0.16);
      border = Colors.red.withValues(alpha: 0.5);
    } else {
      bg = isPlayer
          ? theme.colorScheme.primary.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.05);
      border = Colors.white.withValues(alpha: 0.08);
    }

    final emoji = item.archetype.isEmpty ? null : _archEmoji(item.archetype);
    final nameLabel = [
      if (item.personnage.isNotEmpty) item.personnage,
    ].join();

    return Align(
      alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment:
              isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isPlayer && item.didascalie.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(item.didascalie,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontStyle: FontStyle.italic)),
              ),
            // Rappel de l'archétype : icône animal + prénom.
            if (emoji != null || nameLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji != null) ...[emoji, const SizedBox(width: 4)],
                    if (nameLabel.isNotEmpty)
                      Text(isPlayer ? 'Toi — $nameLabel' : nameLabel,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: theme.colorScheme.primary))
                    else if (isPlayer)
                      Text('Toi',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            Text(item.texte,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});

  final SpectacleCorrection correction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports, size: 16, color: Colors.orangeAccent),
              const SizedBox(width: 6),
              Text('Coach — ${correction.defaut}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Colors.orangeAccent)),
            ],
          ),
          if (correction.explication.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(correction.explication, style: theme.textTheme.bodySmall),
          ],
          if (correction.modele.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Modèle : ${correction.modele}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _CrowCard extends StatelessWidget {
  const _CrowCard({required this.crow});

  final SpectacleCrow crow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, bool ok) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: ok ? Colors.greenAccent : Colors.redAccent),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CROW — fin de scène',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              cell('Prénom', crow.prenom),
              cell('Fonction', crow.fonction),
              cell('Relation (${crow.liens})', crow.liens >= 2),
              cell('Objectif', crow.objectif),
              cell('Lieu', crow.where),
            ],
          ),
          if (crow.trou.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Trou : ${crow.trou}', style: theme.textTheme.bodySmall),
          ],
          if (crow.moyen.isNotEmpty)
            Text('À combler par : ${crow.moyen}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Retour',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.turn});

  final SpectacleTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0.12),
            theme.colorScheme.primary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text('DESTINY — FIN DU SPECTACLE',
                style: TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          _renderDynamic(theme, turn.score),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.freeCtrl,
    required this.onQuitToSetup,
  });

  final SpectacleController controller;
  final TextEditingController freeCtrl;
  final VoidCallback onQuitToSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final turn = c.current;

    Widget content;
    if (c.loading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (c.needsCharacterChoice && c.draw != null) {
      // Choix du personnage pour la scène courante.
      final draw = c.draw!;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scène ${c.sceneNumber} — quel personnage joues-tu ?',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < draw.archetypes.length; i++)
                ActionChip(
                  avatar: _archEmoji(draw.archetypes[i].name),
                  label: Text(draw.archetypes[i].name),
                  onPressed: () => c.chooseSceneCharacter(i),
                ),
            ],
          ),
        ],
      );
    } else if (turn?.isScore ?? false) {
      content = Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onQuitToSetup,
              icon: const Icon(Icons.replay),
              label: const Text('Nouveau spectacle'),
            ),
          ),
        ],
      );
    } else if (c.mode == SpectacleMode.classique &&
        (turn?.propositions.isNotEmpty ?? false)) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in turn!.propositions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                onPressed: () => c.choose(p),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                child: Text(p.texte, textAlign: TextAlign.left),
              ),
            ),
        ],
      );
    } else {
      // Mode libre (ou classique sans propositions) : saisie de la réplique.
      content = Row(
        children: [
          Expanded(
            child: TextField(
              controller: freeCtrl,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ta réplique…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _sendFree(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            onPressed: _sendFree,
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.mode == SpectacleMode.classique &&
              !c.loading &&
              !c.needsCharacterChoice &&
              !(turn?.isScore ?? false) &&
              (turn?.propositions.isNotEmpty ?? false))
            Builder(builder: (context) {
              final name = c.currentArchetypeName;
              final emoji = name.isEmpty ? null : _archEmoji(name, size: 16);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (emoji != null) ...[emoji, const SizedBox(width: 6)],
                    Expanded(
                      child: Text(
                        name.isEmpty
                            ? 'Choisis la réplique dans la langue de ton archétype :'
                            : 'Réponds en tant que $name — choisis sa langue :',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          content,
        ],
      ),
    );
  }

  void _sendFree() {
    final t = freeCtrl.text;
    if (t.trim().isEmpty) return;
    freeCtrl.clear();
    controller.submitFree(t);
  }
}
