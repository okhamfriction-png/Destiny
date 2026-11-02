import 'package:flutter/material.dart';

import '../../application/state/spectacle_controller.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Historique des parties de Mode Spectacle terminées.
class SpectacleArchivesScreen extends StatefulWidget {
  const SpectacleArchivesScreen({required this.controller, super.key});

  final SpectacleController controller;

  @override
  State<SpectacleArchivesScreen> createState() => _SpectacleArchivesScreenState();
}

class _SpectacleArchivesScreenState extends State<SpectacleArchivesScreen> {
  List<Map<String, dynamic>> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('archives.spectacles.$x', v);

  Future<void> _load() async {
    final r = await widget.controller.loadHistory();
    if (!mounted) return;
    setState(() {
      _records = r;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(k('vider_titre')),
        content: Text(k('vider_texte')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('vider_ok'))),
        ],
      ),
    );
    if (ok != true) return;
    await widget.controller.clearHistory();
    await _load();
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Scaffold(
      appBar: AppBar(
        title: Text(k('titre')),
        actions: [
          if (_records.isNotEmpty)
            IconButton(tooltip: k('vider'), icon: const Icon(Icons.delete_sweep), onPressed: _clearAll),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      k('vide'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, color: c.texteSecondaire),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _records.length,
                  itemBuilder: (context, i) {
                    final r = _records[i];
                    final arch = r['archetype'] as String? ?? '';
                    final emoji = arch.isEmpty ? null : emojiAnimal(arch);
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ElementListe(
                          titre: '${r['lieu'] ?? ''} · ${r['danger'] ?? ''}',
                          sousTitre: '${arch.isEmpty ? '' : '$arch · '}'
                              '${(r['mode'] as String? ?? '')} · '
                              '${_date((r['createdAt'] as num?)?.toInt() ?? 0)}',
                          devant: Text(emoji ?? '🎭', style: const TextStyle(fontSize: 24)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => _ArchiveDetailScreen(record: r)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ArchiveDetailScreen extends StatelessWidget {
  const _ArchiveDetailScreen({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('archives.spectacles.$x', v);
    final log = (record['log'] as List<dynamic>? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    final bilan = record['debrief'] ?? record['score'];
    return PageDestiny(
      titre: record['lieu'] as String? ?? k('partie'),
      enfants: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${record['lieu'] ?? ''} · ${record['danger'] ?? ''}',
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, fontWeight: FontWeight.w700, color: c.titre),
          ),
        ),
        // Transcript.
        for (final item in log) _ArchiveBubble(item: item),
        // Le débrief (les anciennes parties avaient un score).
        if (bilan != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CadreLisere(
              couleur: c.or,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['debrief'] != null ? k('debrief') : k('score'),
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, fontWeight: FontWeight.w700, color: c.titre),
                  ),
                  const SizedBox(height: 8),
                  _renderDynamic(c, bilan),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ArchiveBubble extends StatelessWidget {
  const _ArchiveBubble({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final isPlayer = item['isPlayer'] as bool? ?? false;
    final arch = item['archetype'] as String? ?? '';
    final emoji = arch.isEmpty ? null : emojiAnimal(arch);
    final personnage = item['personnage'] as String? ?? '';
    final texte = item['texte'] as String? ?? '';
    final didascalie = item['didascalie'] as String? ?? '';
    final success = item['success'] as bool?;

    final Color teinte;
    if (success == true) {
      teinte = Colors.green.withValues(alpha: c.sombre ? 0.16 : 0.12);
    } else if (success == false) {
      teinte = Colors.red.withValues(alpha: c.sombre ? 0.14 : 0.08);
    } else {
      teinte = isPlayer ? c.or.withValues(alpha: c.sombre ? 0.16 : 0.10) : Colors.transparent;
    }

    return Align(
      alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: Color.alphaBlend(teinte, c.carte),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.filet),
        ),
        child: Column(
          crossAxisAlignment: isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isPlayer && didascalie.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  didascalie,
                  style: TextStyle(
                      fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire, fontStyle: FontStyle.italic),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    isPlayer
                        ? (personnage.isEmpty
                            ? t.t('archives.spectacles.toi')
                            : t.t('archives.spectacles.toi_personnage', {'personnage': personnage}))
                        : personnage,
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, fontWeight: FontWeight.w700, color: c.titre),
                  ),
                ),
              ],
            ),
            Text(texte, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: c.texte)),
          ],
        ),
      ),
    );
  }
}

/// Rendu générique d'une valeur JSON (dupliqué léger pour l'écran d'archive).
Widget _renderDynamic(DestinyCouleurs c, Object? value) {
  final texte = TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: c.texte);
  if (value == null) return const SizedBox.shrink();
  if (value is String) {
    return Text(value, style: texte);
  }
  if (value is num || value is bool) {
    return Text('$value', style: texte);
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
                Text('•  ', style: texte),
                Expanded(child: _renderDynamic(c, e)),
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
                Text(
                  entry.key.toString(),
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, fontWeight: FontWeight.w700, color: c.titre),
                ),
                const SizedBox(height: 2),
                _renderDynamic(c, entry.value),
              ],
            ),
          ),
      ],
    );
  }
  return Text('$value', style: texte);
}
