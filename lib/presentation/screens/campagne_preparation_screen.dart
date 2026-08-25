import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/music_controller.dart';
import '../../domain/entities/campagne.dart';
import '../../domain/usecases/constructeur_episode.dart';
import 'campagne_jeu_screen.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

/// Écran de préparation : tout se règle AVANT de lancer. Une fois l'épisode
/// commencé, plus personne n'y touche.
class PreparationScreen extends StatefulWidget {
  const PreparationScreen({
    required this.store,
    required this.campagne,
    required this.numero,
    required this.audioService,
    required this.musicController,
    super.key,
  });
  final CampagneStore store;
  final Campagne campagne;
  final int numero;
  final AudioService audioService;
  final MusicController musicController;

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  int _nbJoueurs = 3;
  late List<TextEditingController> _noms;
  int _dureeMin = 30;
  List<int> _horairesMin = const []; // horaires des dangers, en minutes
  Episode? _episode;

  final TranscriptionService _transcription = TranscriptionService();
  bool _micDispo = false;
  String _micRaison = '';
  bool _transcrire = false;

  @override
  void initState() {
    super.initState();
    _noms = [
      for (var i = 0; i < 5; i++) TextEditingController(text: 'Joueur ${i + 1}')
    ];
    _composer();
    _transcription.disponible().then((d) {
      if (mounted) {
        setState(() {
          _micDispo = d;
          if (!d) _micRaison = 'Aucun moteur de reconnaissance sur cet appareil.';
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _noms) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _joueurs =>
      [for (var i = 0; i < _nbJoueurs; i++) _noms[i].text.trim()];

  void _composer() {
    _episode = widget.store
        .composer(widget.campagne, widget.numero, _joueurs);
    _recalerHoraires();
  }

  void _recalerHoraires() {
    final n = _episode?.escalade.length ?? 0;
    if (n == 0) {
      _horairesMin = const [];
      return;
    }
    final ms = horairesDesPresages(_dureeMin * 60000, n);
    _horairesMin = [for (final h in ms) (h / 60000).round().clamp(1, _dureeMin - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final ep = _episode;
    final c = widget.campagne;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      appBar: AppBar(
        title: Text('Épisode ${widget.numero}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ep == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Rien à jouer. Aucun lieu ni méchant dans cet univers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (c.resume.isNotEmpty) ...[
                  _Bloc(
                    titre: 'DANS L\'ÉPISODE PRÉCÉDENT',
                    couleur: _lav,
                    texte: c.resume,
                  ),
                  const SizedBox(height: 10),
                ],
                if (c.accroche.isNotEmpty) ...[
                  _Bloc(
                    titre: 'OÙ ON REPREND',
                    couleur: _gold,
                    texte: c.accroche,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                const _Titre('Qui joue'),
                Row(
                  children: [
                    const Text('Joueurs',
                        style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    IconButton.outlined(
                      visualDensity: VisualDensity.compact,
                      onPressed: _nbJoueurs > 2
                          ? () => setState(() {
                                _nbJoueurs--;
                                _composer();
                              })
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                        width: 34,
                        child: Text('$_nbJoueurs',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18))),
                    IconButton.outlined(
                      visualDensity: VisualDensity.compact,
                      onPressed: _nbJoueurs < 5
                          ? () => setState(() {
                                _nbJoueurs++;
                                _composer();
                              })
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < _nbJoueurs; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _noms[i],
                            decoration: const InputDecoration(
                                isDense: true, border: OutlineInputBorder()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '— ${i < ep.roles.length ? ep.roles[i].role : ''}',
                            style: const TextStyle(color: _lav),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const _Titre('Le temps'),
                Text('Durée de l\'épisode : $_dureeMin min',
                    style: const TextStyle(color: Colors.white70)),
                Slider(
                  value: _dureeMin.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 27,
                  label: '$_dureeMin min',
                  onChanged: (v) => setState(() {
                    _dureeMin = v.round();
                    _recalerHoraires();
                  }),
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < _horairesMin.length; i++)
                  Row(
                    children: [
                      SizedBox(
                          width: 90,
                          child: Text('Danger ${i + 1}',
                              style: const TextStyle(color: _gold))),
                      Expanded(
                        child: Slider(
                          value: _horairesMin[i]
                              .toDouble()
                              .clamp(1, (_dureeMin - 1).toDouble()),
                          min: 1,
                          max: (_dureeMin - 1).toDouble(),
                          divisions: (_dureeMin - 1).clamp(1, 30),
                          label: '${_horairesMin[i]} min',
                          onChanged: (v) =>
                              setState(() => _horairesMin[i] = v.round()),
                        ),
                      ),
                      SizedBox(
                          width: 46,
                          child: Text('${_horairesMin[i]} min',
                              style: const TextStyle(color: Colors.white54))),
                    ],
                  ),
                const SizedBox(height: 4),
                const Text('Une fois l\'épisode lancé, plus personne n\'y touche.',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 16),
                const _Titre('Le micro'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _gold,
                  value: _transcrire && _micDispo,
                  onChanged: _micDispo
                      ? (v) => setState(() => _transcrire = v)
                      : null,
                  title: const Text('Transcrire l\'épisode',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _micDispo
                        ? 'Pour que l\'histoire se souvienne d\'elle-même.'
                        : _micRaison,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Le téléphone écoute et écrit le texte. Aucun son n\'est '
                    'conservé. Le texte reste sur l\'appareil : à la fin, vous '
                    'pourrez en demander un résumé — vous verrez exactement ce '
                    'qui part, et vous pourrez le corriger.',
                    style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.35),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _commencer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('On commence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _commencer() {
    final ep = _episode;
    if (ep == null) return;
    // Horaires ordonnés et distincts, en ms.
    final horairesMs = [
      for (final m in _horairesMin) m * 60000
    ]..sort();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => JeuScreen(
        store: widget.store,
        campagne: widget.campagne,
        episode: ep,
        dureeMs: _dureeMin * 60000,
        horairesMs: horairesMs,
        audioService: widget.audioService,
        musicController: widget.musicController,
        transcription: _transcrire && _micDispo ? _transcription : null,
      ),
    ));
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

class _Titre extends StatelessWidget {
  const _Titre(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      );
}
