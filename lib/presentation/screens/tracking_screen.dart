import 'package:flutter/material.dart';

import '../../application/state/story_controller.dart';
import '../../application/state/tracking_store.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _green = Color(0xFF3FE08A); // état validé (croix)

/// Les trois tableaux de suivi (Acte 1 POSER / Acte 2 RÉAGIR / Acte 3
/// CONVERGER). Remplissage ultra-rapide : un tap par cellule (vide → ○ → ✕).
/// Joueurs et relations sont partagés par les trois actes.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    required this.store,
    required this.storyController,
    super.key,
  });

  final TrackingStore store;
  final StoryController storyController;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  TrackingStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onChange);
  }

  @override
  void dispose() {
    store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _importFromStory() async {
    final s = widget.storyController.state.story;
    final messenger = ScaffoldMessenger.of(context);
    if (s == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Aucune histoire générée à importer.')));
      return;
    }
    await store.importFromStory(
      s.players.length,
      [for (final p in s.players) p.archetype.name],
    );
    messenger.showSnackBar(
        const SnackBar(content: Text('Joueurs importés depuis l\'histoire.')));
  }

  Future<void> _addRelation() async {
    var a = 1;
    var b = store.playerCount >= 2 ? 2 : 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          List<DropdownMenuItem<int>> items() => [
                for (var i = 1; i <= store.playerCount; i++)
                  DropdownMenuItem(value: i, child: Text(store.playerLabel(i))),
              ];
          return AlertDialog(
            title: const Text('Nouvelle relation'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: a,
                  items: items(),
                  onChanged: (v) => setLocal(() => a = v ?? a),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('–'),
                ),
                DropdownButton<int>(
                  value: b,
                  items: items(),
                  onChanged: (v) => setLocal(() => b = v ?? b),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ajouter')),
            ],
          );
        },
      ),
    );
    if (ok == true && a != b) await store.addRelation(a, b);
  }

  Future<void> _setPlayers() async {
    var n = store.playerCount;
    final res = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Nombre de joueurs'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: n > 2 ? () => setLocal(() => n--) : null,
              ),
              Text('$n', style: const TextStyle(fontSize: 28)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: n < 10 ? () => setLocal(() => n++) : null,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(context, n),
                child: const Text('Valider')),
          ],
        ),
      ),
    );
    if (res != null) await store.setPlayerCount(res);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suivi de répétition'),
          actions: [
            IconButton(
              tooltip: 'Importer l\'histoire tirée',
              icon: const Icon(Icons.download),
              onPressed: _importFromStory,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'players') _setPlayers();
                if (v == 'clear') _confirmClear();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'players', child: Text('Nombre de joueurs')),
                PopupMenuItem(value: 'clear', child: Text('Effacer les coches')),
              ],
            ),
          ],
          bottom: const TabBar(
            labelColor: _gold,
            indicatorColor: _gold,
            tabs: [
              Tab(text: 'Acte 1'),
              Tab(text: 'Acte 2'),
              Tab(text: 'Acte 3'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF141029), Color(0xFF0A0818)],
            ),
          ),
          child: TabBarView(
            children: [
              _buildActe1(),
              _buildActe2(),
              _buildActe3(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer les coches ?'),
        content: const Text(
            'Remet toutes les cellules à vide (garde joueurs et relations).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Effacer')),
        ],
      ),
    );
    if (ok == true) await store.clearChecks();
  }

  // ============================================================= ACTE 1
  Widget _buildActe1() {
    final theme = Theme.of(context);
    final cols = store.act1Cols;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ActeHeader(
          title: 'ACTE 1 — POSER',
          subtitle: 'C · O · W · A par joueur, puis les relations. '
              'A = respect de l\'archétype.',
        ),
        const SizedBox(height: 8),
        // En-tête des colonnes.
        Row(
          children: [
            const SizedBox(width: 96),
            for (final c in cols)
              Expanded(
                child: Center(
                  child: Text(c,
                      style: const TextStyle(
                          color: _gold, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var p = 1; p <= store.playerCount; p++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(store.playerLabel(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                for (var c = 0; c < cols.length; c++)
                  Expanded(
                    child: Center(
                      child: _TriCell(
                        state: store.act1Cell(p, c),
                        onTap: () => store.cycleAct1Cell(p, c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Relations',
                style: TextStyle(
                    color: _gold, fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addRelation,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        Text(
          'Une relation lie deux joueurs. Coche quand elle est posée.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
        if (store.validatedRelationsAct1 < 2)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 15, color: Color(0xFFFFB74D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Au moins 2 relations validées attendues '
                    '(${store.validatedRelationsAct1}/2).',
                    style: const TextStyle(
                        color: Color(0xFFFFB74D), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        if (store.relations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune relation. Touche « Ajouter ».',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white38)),
          ),
        for (final r in store.relations)
          _RelationRow(
            label: store.relationLabel(r),
            state: store.act1RelState(r.id),
            onTap: () => store.cycleAct1Rel(r.id),
            onDelete: () => store.removeRelation(r.id),
          ),
      ],
    );
  }

  // ======================================================= ACTES 2 & 3
  Widget _buildActe2() => _buildReportedActe(
        title: 'ACTE 2 — RÉAGIR',
        subtitle: 'O, A et relations, reportés de l\'Acte 1.',
        oState: store.act2OState,
        aState: store.act2AState,
        onO: store.cycleAct2O,
        onA: store.cycleAct2A,
        relState: store.act2RelState,
        onRel: store.cycleAct2Rel,
      );

  Widget _buildActe3() => _buildReportedActe(
        title: 'ACTE 3 — CONVERGER',
        subtitle: 'O, A et relations, reportés de l\'Acte 2.',
        oState: store.act3OState,
        aState: store.act3AState,
        onO: store.cycleAct3O,
        onA: store.cycleAct3A,
        relState: store.act3RelState,
        onRel: store.cycleAct3Rel,
      );

  /// Tableau O + A par joueur (comme l'Acte 1), dont les valeurs sont
  /// reportées de l'acte précédent ; on peut les ajuster pour cet acte.
  Widget _buildReportedActe({
    required String title,
    required String subtitle,
    required int Function(int) oState,
    required int Function(int) aState,
    required void Function(int) onO,
    required void Function(int) onA,
    required int Function(String) relState,
    required void Function(String) onRel,
  }) {
    final theme = Theme.of(context);
    final cols = store.act1Cols;
    final labelO = cols.length > 1 ? cols[1] : 'O';
    final labelA = cols.length > 3 ? cols[3] : 'A';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ActeHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 96),
            Expanded(
              child: Center(
                child: Text(labelO,
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(labelA,
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var p = 1; p <= store.playerCount; p++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(store.playerLabel(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Center(
                    child: _TriCell(state: oState(p), onTap: () => onO(p)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _TriCell(state: aState(p), onTap: () => onA(p)),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.south, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Valeurs reportées de l\'acte précédent — tape une cellule '
                'pour l\'ajuster à cet acte.',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
              ),
            ),
          ],
        ),
        if (store.relations.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Relations',
              style: TextStyle(
                  color: _gold, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          for (final r in store.relations)
            _RelationRow(
              label: store.relationLabel(r),
              state: relState(r.id),
              onTap: () => onRel(r.id),
            ),
        ],
      ],
    );
  }
}

/// Cellule à 3 états : vide → ○ (à moitié) → ✓ (validé, vert).
class _TriCell extends StatelessWidget {
  const _TriCell({required this.state, required this.onTap, this.size = 40});
  final int state;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (state) {
      case 1:
        child = Icon(Icons.circle_outlined, color: _gold, size: size * 0.5);
      case 2:
        // Validé / complété → coche verte (V).
        child = Icon(Icons.check, color: _green, size: size * 0.66);
      default:
        child = const SizedBox.shrink();
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color:
              state == 2 ? _green.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: switch (state) {
              2 => _green.withValues(alpha: 0.8),
              1 => _gold.withValues(alpha: 0.6),
              _ => Colors.white24,
            },
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ActeHeader extends StatelessWidget {
  const _ActeHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.label,
    required this.state,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final int state;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            _TriCell(state: state, onTap: onTap),
            if (onDelete != null)
              IconButton(
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
