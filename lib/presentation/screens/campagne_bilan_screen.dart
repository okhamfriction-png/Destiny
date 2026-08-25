import 'package:flutter/material.dart';

import '../../application/assistant/campagne_assistant.dart';
import '../../application/services/audio_service.dart';
import '../../application/state/campagne_store.dart';
import '../../domain/entities/campagne.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

/// Bilan de fin d'épisode : le carnet, la transcription, puis on enregistre.
class BilanScreen extends StatefulWidget {
  const BilanScreen({
    required this.store,
    required this.campagne,
    required this.episode,
    required this.audioService,
    this.transcription = '',
    super.key,
  });
  final CampagneStore store;
  final Campagne campagne;
  final Episode episode;
  final AudioService audioService;
  final String transcription;

  @override
  State<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends State<BilanScreen> {
  final _ceQuiAMarche = TextEditingController();
  final _phrase = TextEditingController();
  bool _enregistre = false;

  @override
  void initState() {
    super.initState();
    widget.audioService.playShine(); // célébration
  }

  @override
  void dispose() {
    _ceQuiAMarche.dispose();
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _enregistrer({String? resume, String? accroche}) async {
    if (_enregistre) return;
    _enregistre = true;
    if (resume != null || accroche != null) {
      await widget.store.majResumeAccroche(widget.campagne.id,
          resume: resume, accroche: accroche);
    }
    await widget.store.enregistrerSeance(
      widget.campagne,
      widget.episode,
      phrase: _phrase.text.trim(),
      ceQuiAMarche: _ceQuiAMarche.text.trim(),
      transcription: widget.transcription,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _faireResumer() async {
    if (!widget.store.iaConfiguree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configure l\'IA dans les Paramètres pour le résumé.')));
      return;
    }
    final m = await Navigator.of(context).push<MemoireEpisode>(
      MaterialPageRoute(
        builder: (_) => DemandeResumeScreen(
          store: widget.store,
          campagne: widget.campagne,
          episode: widget.episode,
          transcription: widget.transcription,
        ),
      ),
    );
    if (m != null) {
      await _enregistrer(resume: m.resume, accroche: m.suite);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apercu = widget.transcription
        .split(RegExp(r'[\n.]'))
        .where((l) => l.trim().isNotEmpty)
        .take(6)
        .join('. ');
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      appBar: AppBar(
        title: const Text('Bravo !'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Épisode ${widget.episode.numero} — ${widget.episode.intitule}',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          const _MiniTitre('CE QUI A MARCHÉ'),
          const SizedBox(height: 8),
          TextField(
            controller: _ceQuiAMarche,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 18),
          const _MiniTitre('LA PHRASE QU\'ON GARDE'),
          const SizedBox(height: 8),
          TextField(
            controller: _phrase,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          if (widget.transcription.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const _MiniTitre('LA TRANSCRIPTION'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                apercu.isEmpty ? '(vide)' : '$apercu…',
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Elle est gardée avec l\'épisode, sur l\'appareil.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _faireResumer,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Faire résumer l\'épisode'),
                style: FilledButton.styleFrom(
                  backgroundColor: _lav,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _enregistrer(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Terminer sans résumé'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Écran de demande de résumé : la SEULE fois où des paroles quittent l'appareil.
/// Le parent voit le texte exact qui partira (prénoms déjà remplacés par les
/// rôles), peut le corriger, et voit le résultat avant de l'accepter.
class DemandeResumeScreen extends StatefulWidget {
  const DemandeResumeScreen({
    required this.store,
    required this.campagne,
    required this.episode,
    required this.transcription,
    super.key,
  });
  final CampagneStore store;
  final Campagne campagne;
  final Episode episode;
  final String transcription;

  @override
  State<DemandeResumeScreen> createState() => _DemandeResumeScreenState();
}

class _DemandeResumeScreenState extends State<DemandeResumeScreen> {
  late final TextEditingController _texte;
  bool _charge = false;
  String _erreur = '';
  MemoireEpisode? _resultat;

  @override
  void initState() {
    super.initState();
    // Prénoms → rôles avant toute chose : jamais un prénom d'enfant ne part.
    final roles = {
      for (final r in widget.episode.roles) r.joueur: r.role,
    };
    _texte =
        TextEditingController(text: sansPrenoms(widget.transcription, roles));
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _demander() async {
    setState(() {
      _charge = true;
      _erreur = '';
    });
    try {
      final m = await widget.store
          .resumer(campagne: widget.campagne, transcription: _texte.text);
      if (mounted) setState(() => _resultat = m);
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Échec : $e');
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultat;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      appBar: AppBar(
        title: const Text('Résumé'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Voici le texte exact qui partira. Les prénoms sont déjà remplacés '
            'par les rôles. Vous pouvez le corriger.',
            style: TextStyle(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _texte,
            maxLines: 8,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          if (_erreur.isNotEmpty) ...[
            Text(_erreur, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 10),
          ],
          if (r == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _charge ? null : _demander,
                icon: _charge
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_charge ? 'En cours…' : 'Demander le résumé'),
                style: FilledButton.styleFrom(
                  backgroundColor: _lav,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else ...[
            _Bloc(titre: 'RÉSUMÉ', couleur: _lav, texte: r.resume),
            if (r.suite.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Bloc(titre: 'OÙ ON REPREND', couleur: _gold, texte: r.suite),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _resultat = null),
                    child: const Text('Redemander'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(r),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({required this.titre, required this.couleur, required this.texte});
  final String titre;
  final Color couleur;
  final String texte;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre,
                style: TextStyle(
                    color: couleur,
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(texte,
                style: const TextStyle(color: Colors.white, height: 1.4)),
          ],
        ),
      );
}

class _MiniTitre extends StatelessWidget {
  const _MiniTitre(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _gold,
          letterSpacing: 2,
          fontSize: 12,
          fontWeight: FontWeight.w700));
}
