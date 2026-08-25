import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/music_controller.dart';
import '../../domain/entities/campagne.dart';
import '../visuals/campagne_visuals.dart';
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
  // Horaires des dangers 2, 3, 4 (le danger 1 démarre l'épisode), en minutes.
  List<int> _horairesMin = const [];
  Episode? _episode;
  // Archétypes des joueurs, modifiables (copie locale).
  List<ArchetypeHistoire> _archs = const [];

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
    _episode = widget.store.composer(widget.campagne, widget.numero, _joueurs);
    _archs = [for (final r in (_episode?.roles ?? const [])) r.archetype];
    _recalerHoraires();
  }

  void _recalerHoraires() {
    // Le danger 1 démarre l'épisode : on ne minute que les dangers 2, 3, 4…
    final timed = (_episode?.escalade.length ?? 0) - 1;
    if (timed <= 0) {
      _horairesMin = const [];
      return;
    }
    // Par défaut à 30 %, 60 %, 90 % de la durée (le chrono vire au rouge après
    // le dernier). Pour un autre nombre, répartition régulière équivalente.
    _horairesMin = [
      for (var i = 0; i < timed; i++)
        (((i + 1) / (timed + 1)) * _dureeMin).round().clamp(1, _dureeMin - 1),
    ];
    // Cas standard (3 dangers minutés) : 30 / 60 / 90 %.
    if (timed == 3) {
      _horairesMin = [
        (_dureeMin * 0.30).round().clamp(1, _dureeMin - 1),
        (_dureeMin * 0.60).round().clamp(1, _dureeMin - 1),
        (_dureeMin * 0.90).round().clamp(1, _dureeMin - 1),
      ];
    }
  }

  Future<void> _changerArchetype(int index) async {
    final chosen = await showModalBottomSheet<ArchetypeHistoire>(
      context: context,
      backgroundColor: const Color(0xFF120F1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ArchetypePicker(
        archetypes: widget.store.archetypes,
        currentId: _archs[index].id,
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _archs[index] = chosen);
    }
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i < ep.roles.length ? ep.roles[i].role : '',
                                  style: const TextStyle(
                                      color: _lav, fontSize: 13)),
                              if (i < _archs.length)
                                InkWell(
                                  onTap: () => _changerArchetype(i),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${emojiArchetype(_archs[i].id)} ',
                                          style: const TextStyle(fontSize: 15)),
                                      Flexible(
                                        child: Text(_archs[i].nom,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: couleurStatut(
                                                    _archs[i].statut),
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit,
                                          size: 14, color: _gold),
                                    ],
                                  ),
                                ),
                            ],
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
                const Text(
                  'Le danger 1 démarre l\'épisode. Les suivants tombent aux '
                  'moments réglés ; le chrono vire au rouge après le dernier.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _horairesMin.length; i++)
                  Row(
                    children: [
                      SizedBox(
                          width: 90,
                          child: Text('Danger ${i + 2}',
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
    // Reconstruit avec les archétypes choisis et les prénoms actuels.
    final rolesJoueurs = <RoleJoueur>[
      for (var i = 0; i < ep.roles.length; i++)
        RoleJoueur(
          joueur: i < _noms.length ? _noms[i].text.trim() : ep.roles[i].joueur,
          role: ep.roles[i].role,
          archetype: i < _archs.length ? _archs[i] : ep.roles[i].archetype,
        ),
    ];
    final epFinal = Episode(
      numero: ep.numero,
      lieu: ep.lieu,
      mechant: ep.mechant,
      roles: rolesJoueurs,
      figurants: ep.figurants,
      escalade: ep.escalade,
    );
    // Horaires des dangers 2, 3, 4 (le danger 1 démarre l'épisode), en ms.
    final horairesMs = [for (final m in _horairesMin) m * 60000]..sort();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => JeuScreen(
        store: widget.store,
        campagne: widget.campagne,
        episode: epFinal,
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

/// Sélecteur d'archétype (bottom sheet) groupé et coloré par statut.
class _ArchetypePicker extends StatelessWidget {
  const _ArchetypePicker({required this.archetypes, required this.currentId});
  final List<ArchetypeHistoire> archetypes;
  final String currentId;

  @override
  Widget build(BuildContext context) {
    List<ArchetypeHistoire> par(String s) =>
        archetypes.where((a) => a.statut == s).toList()
          ..sort((a, b) => a.nom.compareTo(b.nom));

    Widget groupe(String statut, String titre) {
      final list = par(statut);
      if (list.isEmpty) return const SizedBox.shrink();
      final c = couleurStatut(statut);
      final header = c == Colors.white ? _lav : c;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(titre.toUpperCase(),
                style: TextStyle(
                    color: header,
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in list)
                InkWell(
                  onTap: () => Navigator.of(context).pop(a),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: a.id == currentId
                          ? c.withValues(alpha: 0.18)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: a.id == currentId ? c : Colors.white24,
                          width: a.id == currentId ? 1.5 : 1),
                    ),
                    child: Text('${emojiArchetype(a.id)}  ${a.nom}',
                        style: TextStyle(
                            color: couleurStatut(a.statut),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Center(
            child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          const Text('Changer d\'archétype',
              style: TextStyle(
                  color: _gold, fontSize: 20, fontWeight: FontWeight.w800)),
          groupe('haut', 'Statut haut'),
          groupe('neutre', 'Statut neutre'),
          groupe('bas', 'Statut bas'),
        ],
      ),
    );
  }
}
