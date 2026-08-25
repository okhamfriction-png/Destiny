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
const Color _lieuC = Color(0xFF5EE0C4); // teal (peuple)

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
  // Copies locales modifiables, une entrée par joueur.
  List<ArchetypeHistoire> _archs = const []; // archétype (animal)
  List<String> _peuples = const []; // peuple (origine/espèce)
  List<String> _fonctions = const []; // fonction dans le lieu

  final TranscriptionService _transcription = TranscriptionService();
  bool _micDispo = false;
  String _micRaison = '';
  bool _transcrire = false;

  @override
  void initState() {
    super.initState();
    // Le champ prénom est vide par défaut (le meneur le remplit s'il veut).
    _noms = [for (var i = 0; i < 5; i++) TextEditingController()];
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
    final roles = _episode?.roles ?? const <RoleJoueur>[];
    _archs = [for (final r in roles) r.archetype];
    // Fonction par défaut = celle du lieu déjà renseignée dans l'appli.
    _fonctions = [for (final r in roles) r.role];
    // Peuple par défaut = le plus évident pour l'univers + le lore choisis.
    final dispo = CampagneStore.peuplesPour(
        widget.campagne.univers, widget.campagne.lore);
    final defaut = dispo.isNotEmpty ? dispo.first : '';
    _peuples = [for (final _ in roles) defaut];
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

  /// Choix du peuple : options cohérentes avec l'univers ET le lore.
  Future<void> _changerPeuple(int index) async {
    final options = CampagneStore.peuplesPour(
        widget.campagne.univers, widget.campagne.lore);
    final chosen = await _choisirOption(
      titre: 'Peuple',
      couleur: _lieuC,
      options: options,
      courant: index < _peuples.length ? _peuples[index] : '',
    );
    if (chosen != null && mounted) {
      setState(() => _peuples[index] = chosen);
    }
  }

  /// Choix de la fonction : les fonctions du lieu, ou une saisie libre.
  Future<void> _changerFonction(int index) async {
    final lieuRoles = _episode?.lieu.roles ?? const <String>[];
    final chosen = await _choisirOption(
      titre: 'Fonction dans le lieu',
      couleur: _lav,
      options: lieuRoles,
      courant: index < _fonctions.length ? _fonctions[index] : '',
      libre: true, // « Autre… » : saisie personnalisée
    );
    if (chosen != null && mounted) {
      setState(() => _fonctions[index] = chosen);
    }
  }

  /// Feuille de sélection générique (peuple / fonction). Si [libre], propose une
  /// saisie personnalisée « Autre… ».
  Future<String?> _choisirOption({
    required String titre,
    required Color couleur,
    required List<String> options,
    required String courant,
    bool libre = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF120F1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _OptionPicker(
        titre: titre,
        couleur: couleur,
        options: options,
        courant: courant,
        libre: libre,
      ),
    );
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
                ..._recapPrecedent(),
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
                const SizedBox(height: 4),
                for (var i = 0; i < _nbJoueurs; i++) _carteJoueur(i, ep),
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

  /// Tableau récap de l'épisode précédent (affiché dès l'épisode 2) : intitulé,
  /// morts et blessés — pour que le meneur reprenne le fil.
  List<Widget> _recapPrecedent() {
    if (widget.numero < 2) return const [];
    final seances = widget.store.seancesDe(widget.campagne.id);
    if (seances.isEmpty) return const [];
    final prec = seances.reduce((a, b) => b.numero >= a.numero ? b : a);
    return [
      _RecapTable(seance: prec),
      const SizedBox(height: 10),
    ];
  }

  /// Carte d'un joueur : prénom (vide), puis Peuple · Archétype · Fonction.
  Widget _carteJoueur(int i, Episode ep) {
    final arch = i < _archs.length ? _archs[i] : null;
    final peuple = i < _peuples.length ? _peuples[i] : '';
    final fonction = i < _fonctions.length ? _fonctions[i] : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prénom (réduit) + Peuple · Archétype · Fonction : tout sur une ligne.
          Row(
            children: [
              SizedBox(
                width: 92,
                child: TextField(
                  controller: _noms[i],
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    border: const OutlineInputBorder(),
                    hintText: 'Joueur ${i + 1}',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              // Puces : sur une ligne quand ça tient, sinon elles passent à la
              // ligne (Wrap) — aucune puce n'est masquée par un scroll caché.
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _champChip(
                      lead: const Icon(Icons.public, size: 15, color: _lieuC),
                      label: peuple.isEmpty ? 'Peuple' : peuple,
                      color: _lieuC,
                      onTap: () => _changerPeuple(i),
                    ),
                    if (arch != null)
                      _champChip(
                        lead: Text(emojiArchetype(arch.id),
                            style: const TextStyle(fontSize: 15)),
                        label: arch.nom,
                        color: couleurStatut(arch.statut),
                        onTap: () => _changerArchetype(i),
                      ),
                    _champChip(
                      lead: const Icon(Icons.badge_outlined,
                          size: 15, color: _lav),
                      label: fonction.isEmpty ? 'Fonction' : fonction,
                      color: _lav,
                      onTap: () => _changerFonction(i),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Détail de l'archétype : tempérament · port · moteur.
          if (arch != null && _detailArchetype(arch).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                _detailArchetype(arch),
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.25),
              ),
            ),
        ],
      ),
    );
  }

  /// « tempérament · port · moteur » de l'archétype (parties vides ignorées).
  String _detailArchetype(ArchetypeHistoire a) => [
        a.temperament,
        a.port,
        a.moteur,
      ].where((s) => s.trim().isNotEmpty).join(' · ');

  /// Puce éditable (peuple / archétype / fonction) avec icône de crayon.
  Widget _champChip({
    required Widget lead,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            lead,
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 13, color: color.withValues(alpha: 0.8)),
          ],
        ),
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
          role: i < _fonctions.length ? _fonctions[i] : ep.roles[i].role,
          archetype: i < _archs.length ? _archs[i] : ep.roles[i].archetype,
          peuple: i < _peuples.length ? _peuples[i] : '',
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

/// Tableau récap de l'épisode précédent (morts / blessés) pour le meneur.
class _RecapTable extends StatelessWidget {
  const _RecapTable({required this.seance});
  final SeanceJouee seance;

  static const Color _corail = Color(0xFFFF8A80);

  @override
  Widget build(BuildContext context) {
    Widget ligne(IconData ic, Color col, String label, List<String> vals) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ic, color: col, size: 18),
              const SizedBox(width: 10),
              SizedBox(
                width: 78,
                child: Text(label,
                    style: TextStyle(
                        color: col, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Expanded(
                child: Text(vals.isEmpty ? '—' : vals.join(', '),
                    style: TextStyle(
                        color: vals.isEmpty ? Colors.white38 : Colors.white,
                        height: 1.3)),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _corail.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _corail.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CE QUI S\'EST PASSÉ — ÉPISODE ${seance.numero}',
              style: const TextStyle(
                  color: _corail,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(seance.intitule,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ligne(Icons.heart_broken, Colors.redAccent, 'Morts', seance.morts),
          ligne(Icons.healing, Colors.orangeAccent, 'Blessés', seance.blesses),
          if (seance.phrase.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('« ${seance.phrase.trim()} »',
                  style: const TextStyle(
                      color: Colors.white54, fontStyle: FontStyle.italic)),
            ),
          if (seance.morts.isEmpty && seance.blesses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Les morts d\'un épisode ne réapparaissent plus.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ],
      ),
    );
  }
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

/// Sélecteur générique (peuple / fonction) : une liste de puces + option de
/// saisie libre « Autre… » quand [libre] est vrai.
class _OptionPicker extends StatelessWidget {
  const _OptionPicker({
    required this.titre,
    required this.couleur,
    required this.options,
    required this.courant,
    required this.libre,
  });
  final String titre;
  final Color couleur;
  final List<String> options;
  final String courant;
  final bool libre;

  Future<void> _saisirLibre(BuildContext context) async {
    final ctrl = TextEditingController(text: courant);
    final saisi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1530),
        title: Text(titre, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Saisie personnalisée',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    if (saisi != null && saisi.isNotEmpty && context.mounted) {
      Navigator.of(context).pop(saisi);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
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
          Text(titre,
              style: TextStyle(
                  color: couleur, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                InkWell(
                  onTap: () => Navigator.of(context).pop(o),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: o == courant
                          ? couleur.withValues(alpha: 0.18)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: o == courant ? couleur : Colors.white24,
                          width: o == courant ? 1.5 : 1),
                    ),
                    child: Text(o,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (libre)
                InkWell(
                  onTap: () => _saisirLibre(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: couleur.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 15, color: couleur),
                        const SizedBox(width: 6),
                        Text('Autre…',
                            style: TextStyle(
                                color: couleur, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
