import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/music_controller.dart';
import '../../domain/entities/campagne.dart';
import 'campagne_preparation_screen.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

/// Liste des campagnes (histoires) + création.
class CampagneListeScreen extends StatefulWidget {
  const CampagneListeScreen({
    required this.store,
    required this.audioService,
    required this.musicController,
    super.key,
  });
  final CampagneStore store;
  final AudioService audioService;
  final MusicController musicController;

  @override
  State<CampagneListeScreen> createState() => _CampagneListeScreenState();
}

class _CampagneListeScreenState extends State<CampagneListeScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
    if (widget.store.loading) widget.store.load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final campagnes = widget.store.campagnes;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      appBar: AppBar(
        title: const Text('Campagnes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creer,
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
      ),
      body: widget.store.loading
          ? const Center(child: CircularProgressIndicator())
          : campagnes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aucune histoire pour le moment.\n\nUne histoire, c\'est un '
                      'monde, un méchant, et des épisodes qui se suivent.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: campagnes.length,
                  itemBuilder: (_, i) {
                    final c = campagnes[i];
                    final n = c.episodesJoues;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(c.nom,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${CampagneStore.univers[c.univers] ?? c.univers} · '
                          '${CampagneStore.tons[c.ton] ?? c.ton}\n'
                          '${n == 0 ? 'aucun épisode joué' : '$n épisode${n > 1 ? 's' : ''}'}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white38),
                        onTap: () => _ouvrir(c),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _creer() async {
    final campagne = await Navigator.of(context).push<Campagne>(
      MaterialPageRoute(
          builder: (_) => CreerCampagneScreen(store: widget.store)),
    );
    if (campagne == null || !mounted) return;
    // On enchaîne directement sur l'épisode 1.
    _jouer(campagne, 1);
  }

  void _ouvrir(Campagne c) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FicheCampagneScreen(
          store: widget.store,
          campagneId: c.id,
          audioService: widget.audioService,
          musicController: widget.musicController,
        ),
      ));

  void _jouer(Campagne c, int numero) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreparationScreen(
            store: widget.store,
            campagne: c,
            numero: numero,
            audioService: widget.audioService,
            musicController: widget.musicController,
          ),
        ),
      );
}

/// Création d'une histoire : univers, ton, contexte, nom.
class CreerCampagneScreen extends StatefulWidget {
  const CreerCampagneScreen({required this.store, super.key});
  final CampagneStore store;

  @override
  State<CreerCampagneScreen> createState() => _CreerCampagneScreenState();
}

class _CreerCampagneScreenState extends State<CreerCampagneScreen> {
  String _univers = CampagneStore.univers.keys.first;
  String _ton = CampagneStore.tons.keys.first;
  String _public = 'enfant';
  String _lore = ''; // '' = aucun
  final _contexte = TextEditingController();
  final _nom = TextEditingController();

  List<String> get _loresDispo => CampagneStore.lores[_univers] ?? const [];

  @override
  void initState() {
    super.initState();
    _nom.text = CampagneStore.univers[_univers] ?? '';
  }

  @override
  void dispose() {
    _contexte.dispose();
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      appBar: AppBar(
        title: const Text('Nouvelle histoire'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _Label('Public'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'enfant', label: Text('Enfant')),
              ButtonSegment(value: 'adulte', label: Text('Adulte')),
            ],
            selected: {_public},
            onSelectionChanged: (s) => setState(() => _public = s.first),
          ),
          const SizedBox(height: 16),
          const _Label('Univers'),
          DropdownButtonFormField<String>(
            initialValue: _univers,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final e in CampagneStore.univers.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() {
              _univers = v ?? _univers;
              _lore = ''; // les lores dépendent de l'univers
              if (_nom.text.isEmpty ||
                  CampagneStore.univers.containsValue(_nom.text)) {
                _nom.text = CampagneStore.univers[_univers] ?? '';
              }
            }),
          ),
          const SizedBox(height: 16),
          const _Label('Ton'),
          DropdownButtonFormField<String>(
            initialValue: _ton,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final e in CampagneStore.tons.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _ton = v ?? _ton),
          ),
          const SizedBox(height: 16),
          const _Label('Lore (couche de personnages)'),
          DropdownButtonFormField<String>(
            initialValue: _lore,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('Aucun')),
              for (final l in _loresDispo)
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => setState(() => _lore = v ?? ''),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ajoute l\'ambiance et des personnages inspirés de ce lore '
            '(surtout quand l\'IA écrit le résumé).',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const _Label('Contexte (facultatif)'),
          TextField(
            controller: _contexte,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Un détail à garder d\'un épisode à l\'autre…',
            ),
          ),
          const SizedBox(height: 16),
          const _Label('Nom de l\'histoire'),
          TextField(
            controller: _nom,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valider,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Créer et jouer l\'épisode 1'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _valider() async {
    final nom = _nom.text.trim().isEmpty
        ? (CampagneStore.univers[_univers] ?? 'Histoire')
        : _nom.text.trim();
    final c = await widget.store.creer(
      nom: nom,
      univers: _univers,
      ton: _ton,
      public: _public,
      lore: _lore,
      contexte: _contexte.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(c);
  }
}

/// Fiche d'une histoire : où on en est, jouer l'épisode N, ce qui s'est passé.
class FicheCampagneScreen extends StatefulWidget {
  const FicheCampagneScreen({
    required this.store,
    required this.campagneId,
    required this.audioService,
    required this.musicController,
    super.key,
  });
  final CampagneStore store;
  final int campagneId;
  final AudioService audioService;
  final MusicController musicController;

  @override
  State<FicheCampagneScreen> createState() => _FicheCampagneScreenState();
}

class _FicheCampagneScreenState extends State<FicheCampagneScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.store.byId(widget.campagneId);
    if (c == null) return const Scaffold(body: SizedBox.shrink());
    final seances = widget.store.seancesDe(c.id);
    final prochain = c.episodesJoues + 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      appBar: AppBar(
        title: Text(c.nom),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Retirer l\'histoire',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _retirer(c),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '${CampagneStore.univers[c.univers] ?? c.univers} · '
            '${CampagneStore.tons[c.ton] ?? c.ton} · '
            '${c.public == 'adulte' ? 'Adulte' : 'Enfant'}'
            '${c.lore.isEmpty ? '' : ' · ${c.lore}'}',
            style: const TextStyle(color: _lav, fontWeight: FontWeight.w600),
          ),
          if (c.contexte.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(c.contexte,
                style: const TextStyle(color: Colors.white54, height: 1.35)),
          ],
          if (c.resume.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _lav.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _lav.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OÙ ON EN EST',
                      style: TextStyle(
                          color: _lav,
                          letterSpacing: 2,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(c.resume,
                      style:
                          const TextStyle(color: Colors.white, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _jouer(c, prochain),
              icon: const Icon(Icons.play_arrow),
              label: Text('Jouer l\'épisode $prochain'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('CE QUI S\'EST PASSÉ',
              style: TextStyle(
                  color: _gold,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (seances.isEmpty)
            const Text('Aucun épisode joué pour l\'instant.',
                style: TextStyle(color: Colors.white38))
          else
            for (final s in seances.reversed)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _gold.withValues(alpha: 0.2),
                    child: Text('${s.numero}',
                        style: const TextStyle(color: _gold)),
                  ),
                  title: Text(s.intitule,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    s.phrase.isEmpty ? _date(s.dateMs) : '« ${s.phrase} »',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }

  void _jouer(Campagne c, int numero) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreparationScreen(
            store: widget.store,
            campagne: c,
            numero: numero,
            audioService: widget.audioService,
            musicController: widget.musicController,
          ),
        ),
      );

  Future<void> _retirer(Campagne c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer l\'histoire ?'),
        content: const Text(
            'Les épisodes déjà joués restent enregistrés : ils ont eu lieu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.supprimer(c.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: _lav,
                letterSpacing: 1.5,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );
}
