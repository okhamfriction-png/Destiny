import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/campagne.dart';
import '../../domain/usecases/constructeur_episode.dart';
import '../assistant/campagne_assistant.dart';
import '../services/llm_service.dart';
import 'ai_settings.dart';

/// Un épisode joué et gardé (pour « Ce qui s'est passé »).
class SeanceJouee {
  const SeanceJouee({
    required this.numero,
    required this.dateMs,
    required this.intitule,
    required this.amorceId,
    this.phrase = '',
    this.ceQuiAMarche = '',
    this.transcription = '',
  });
  final int numero;
  final int dateMs;
  final String intitule;
  final String amorceId;
  final String phrase;
  final String ceQuiAMarche;
  final String transcription;

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'dateMs': dateMs,
        'intitule': intitule,
        'amorceId': amorceId,
        'phrase': phrase,
        'ceQuiAMarche': ceQuiAMarche,
        'transcription': transcription,
      };

  factory SeanceJouee.fromJson(Map<String, dynamic> j) => SeanceJouee(
        numero: (j['numero'] as num).toInt(),
        dateMs: (j['dateMs'] as num).toInt(),
        intitule: j['intitule'] as String? ?? '',
        amorceId: j['amorceId'] as String? ?? '',
        phrase: j['phrase'] as String? ?? '',
        ceQuiAMarche: j['ceQuiAMarche'] as String? ?? '',
        transcription: j['transcription'] as String? ?? '',
      );
}

/// Catalogue livré + campagnes de l'utilisateur, persistées localement.
class CampagneStore extends ChangeNotifier {
  CampagneStore({LlmService? llm, AiSettings? aiSettings})
      : _aiSettings = aiSettings,
        _assistant = llm == null ? null : CampagneAssistant(llm);

  static const _kCampagnes = 'campagnes_v1';
  static const _kSeances = 'campagne_seances_v1';
  static const _kProchainId = 'campagne_prochain_id_v1';

  final ConstructeurEpisode _constructeur = const ConstructeurEpisode();
  final AiSettings? _aiSettings;
  final CampagneAssistant? _assistant;

  /// L'IA est-elle configurée (clé) et disponible pour résumer ?
  bool get iaConfiguree => _assistant != null && (_aiSettings?.configured ?? false);

  /// Demande à l'IA un résumé + une accroche (le texte est déjà validé/nettoyé).
  Future<MemoireEpisode> resumer({
    required Campagne campagne,
    required String transcription,
  }) async {
    if (_assistant == null || _aiSettings == null) {
      return const MemoireEpisode();
    }
    return _assistant.resumer(
      settings: _aiSettings,
      univers: CampagneStore.univers[campagne.univers] ?? campagne.univers,
      ton: CampagneStore.tons[campagne.ton] ?? campagne.ton,
      contexte: campagne.contexte,
      transcription: transcription,
      public: campagne.public,
      lore: campagne.lore,
    );
  }

  List<LieuHistoire> _lieux = const [];
  List<MechantHistoire> _mechants = const [];
  List<ArchetypeHistoire> _archetypes = const [];
  List<String> _objectifs = const [];

  List<Campagne> _campagnes = [];
  List<Campagne> get campagnes => List.unmodifiable(_campagnes);

  // Épisodes joués, par identifiant de campagne.
  final Map<int, List<SeanceJouee>> _seances = {};

  bool _loading = true;
  bool get loading => _loading;

  int _prochainId = 1;

  /// Les douze univers livrés (id → libellé lisible).
  static const Map<String, String> univers = {
    'dragon_ball': 'Dragon Ball',
    'arts_martiaux': 'Arts martiaux',
    'animaux': 'Animaux',
    'aventure': 'Aventure',
    'football': 'Football',
    'espace': 'Espace',
    'chevaliers': 'Chevaliers',
    'pirates': 'Pirates',
    'dinosaures': 'Dinosaures',
    'magie': 'Magie',
    'robots': 'Robots',
    'enquete': 'Enquête',
  };

  /// Les dix lores les plus connus par univers (couche de personnages/ambiance).
  static const Map<String, List<String>> lores = {
    'dragon_ball': ['Dragon Ball', 'Naruto', 'One Piece', 'Bleach', 'My Hero Academia', 'Pokémon', 'Saint Seiya', 'Yu-Gi-Oh', 'Fairy Tail', 'Dragon Quest'],
    'arts_martiaux': ['Kung Fu Panda', 'Karaté Kid', 'Avatar le dernier maître de l\'air', 'Naruto', 'Mulan', 'Cobra Kai', 'Jackie Chan', 'Bruce Lee', 'Tekken', 'Street Fighter'],
    'animaux': ['Le Roi Lion', 'Zootopie', 'Madagascar', 'Le Livre de la jungle', 'Rox et Rouky', 'Bambi', 'Kung Fu Panda', 'Ratatouille', 'La Ferme se rebelle', 'Robin des Bois (Disney)'],
    'aventure': ['Indiana Jones', 'Tintin', 'Jumanji', 'Pirates des Caraïbes', 'Uncharted', 'Le Seigneur des Anneaux', 'Astérix', 'Jurassic Park', 'Les Goonies', 'Le Voyage de Chihiro'],
    'football': ['Captain Tsubasa (Olive et Tom)', 'Inazuma Eleven', 'Blue Lock', 'Shaolin Soccer', 'FIFA', 'Les Légendes du foot', 'Coupe du Monde', 'Ligue des Champions', 'Football Manager', 'Panini'],
    'espace': ['Star Wars', 'Star Trek', 'Les Gardiens de la Galaxie', 'Wall-E', 'Toy Story (Buzz)', 'Interstellar', 'Valérian', 'Rick et Morty', 'Dune', 'Mass Effect'],
    'chevaliers': ['Le Seigneur des Anneaux', 'Kaamelott', 'Game of Thrones', 'Excalibur', 'Merlin', 'Donjons & Dragons', 'Warhammer', 'Shrek', 'Zelda', 'Les Chevaliers du Zodiaque'],
    'pirates': ['One Piece', 'Pirates des Caraïbes', 'Peter Pan', 'L\'Île au trésor', 'Tintin', 'Astérix', 'Monkey Island', 'Assassin\'s Creed', 'Sinbad', 'Barbe Noire'],
    'dinosaures': ['Jurassic Park', 'Le Petit Dinosaure', 'Denver le dernier dinosaure', 'Dino Riders', 'Dinotopia', 'ARK', 'Primal', 'Gon', 'T-Rex Express', 'Ice Age'],
    'magie': ['Harry Potter', 'Le Seigneur des Anneaux', 'Le Monde de Narnia', 'Merlin', 'Donjons & Dragons', 'Fairy Tail', 'Kirikou', 'Fantasia (Disney)', 'Warhammer', 'Le Petit Sorcier'],
    'robots': ['Transformers', 'Wall-E', 'Big Hero 6', 'Astro Boy', 'Gundam', 'Real Steel', 'I, Robot', 'Robots (le film)', 'Portal', 'Terminator'],
    'enquete': ['Sherlock Holmes', 'Scooby-Doo', 'Détective Conan', 'Cluedo', 'Le Club des Cinq', 'Inspecteur Gadget', 'Agatha Christie', 'Columbo', 'Blake et Mortimer', 'Lovecraft'],
  };

  /// Les six tons (id → libellé).
  static const Map<String, String> tons = {
    'drole': 'Drôle',
    'aventureux': 'Aventureux',
    'enquete': 'Enquête',
    'epique': 'Épique',
    'tendre': 'Tendre',
    'tranquille': 'Tranquille',
  };

  Future<void> load() async {
    await _chargerCatalogue();
    await _chargerCampagnes();
    _loading = false;
    notifyListeners();
  }

  Future<void> _chargerCatalogue() async {
    try {
      final l = jsonDecode(
          await rootBundle.loadString('assets/data/campagne_lieux.json'));
      _lieux = [
        for (final e in (l['lieux'] as List))
          LieuHistoire.fromJson(e as Map<String, dynamic>)
      ];
      final m = jsonDecode(
          await rootBundle.loadString('assets/data/campagne_mechants.json'));
      _mechants = [
        for (final e in (m['mechants'] as List))
          MechantHistoire.fromJson(e as Map<String, dynamic>)
      ];
      final a = jsonDecode(
          await rootBundle.loadString('assets/data/campagne_archetypes.json'));
      _archetypes = [
        for (final e in (a['archetypes'] as List))
          ArchetypeHistoire.fromJson(e as Map<String, dynamic>)
      ];
      _objectifs = [for (final o in (a['objectifs'] as List)) '$o'];
    } catch (_) {}
  }

  Future<void> _chargerCampagnes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prochainId = prefs.getInt(_kProchainId) ?? 1;
      final raw = prefs.getString(_kCampagnes);
      if (raw != null) {
        _campagnes = [
          for (final e in (jsonDecode(raw) as List))
            _campagneFromJson(e as Map<String, dynamic>)
        ];
      }
      final rawS = prefs.getString(_kSeances);
      if (rawS != null) {
        final map = jsonDecode(rawS) as Map<String, dynamic>;
        for (final entry in map.entries) {
          _seances[int.parse(entry.key)] = [
            for (final s in (entry.value as List))
              SeanceJouee.fromJson(s as Map<String, dynamic>)
          ];
        }
      }
    } catch (_) {}
  }

  Future<void> _sauver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kProchainId, _prochainId);
      await prefs.setString(
          _kCampagnes, jsonEncode([for (final c in _campagnes) _campagneToJson(c)]));
      await prefs.setString(
          _kSeances,
          jsonEncode({
            for (final e in _seances.entries)
              '${e.key}': [for (final s in e.value) s.toJson()]
          }));
    } catch (_) {}
  }

  // --- Catalogue ---
  List<LieuHistoire> lieuxDe(String univers) =>
      _lieux.where((l) => l.univers == univers).toList();
  List<MechantHistoire> mechantsDe(String univers) =>
      _mechants.where((m) => m.univers == univers).toList();

  // --- Campagnes ---
  List<SeanceJouee> seancesDe(int campagneId) =>
      List.unmodifiable(_seances[campagneId] ?? const []);

  Campagne? byId(int id) {
    for (final c in _campagnes) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Campagne> creer({
    required String nom,
    required String univers,
    required String ton,
    String public = 'enfant',
    String lore = '',
    String contexte = '',
  }) async {
    final c = Campagne(
        id: _prochainId++,
        nom: nom,
        univers: univers,
        ton: ton,
        public: public,
        lore: lore,
        contexte: contexte);
    _campagnes = [..._campagnes, c];
    await _sauver();
    notifyListeners();
    return c;
  }

  /// Compose l'épisode [numero] d'une campagne (null si univers vide).
  Episode? composer(Campagne campagne, int numero, List<String> joueurs) {
    return _constructeur.construire(
      campagne: campagne,
      numero: numero,
      joueurs: joueurs,
      lieux: lieuxDe(campagne.univers),
      mechants: mechantsDe(campagne.univers),
      archetypes: _archetypes,
      objectifs: _objectifs,
    );
  }

  /// Enregistre un épisode joué et incrémente le compteur de la campagne.
  Future<void> enregistrerSeance(
    Campagne campagne,
    Episode episode, {
    String phrase = '',
    String ceQuiAMarche = '',
    String transcription = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    (_seances[campagne.id] ??= []).add(SeanceJouee(
      numero: episode.numero,
      dateMs: now,
      intitule: episode.intitule,
      amorceId: episode.amorceId,
      phrase: phrase,
      ceQuiAMarche: ceQuiAMarche,
      transcription: transcription,
    ));
    final i = _campagnes.indexWhere((c) => c.id == campagne.id);
    if (i >= 0) {
      _campagnes[i] =
          _campagnes[i].copyWith(episodesJoues: episode.numero);
    }
    await _sauver();
    notifyListeners();
  }

  /// Met à jour le résumé cumulé et l'accroche d'une campagne (résumé IA).
  Future<void> majResumeAccroche(int campagneId,
      {String? resume, String? accroche}) async {
    final i = _campagnes.indexWhere((c) => c.id == campagneId);
    if (i < 0) return;
    _campagnes[i] =
        _campagnes[i].copyWith(resume: resume, accroche: accroche);
    await _sauver();
    notifyListeners();
  }

  /// Retire une campagne. Ses épisodes déjà joués restent enregistrés.
  Future<void> supprimer(int campagneId) async {
    _campagnes.removeWhere((c) => c.id == campagneId);
    await _sauver();
    notifyListeners();
  }

  // --- (de)sérialisation d'une campagne ---
  Map<String, dynamic> _campagneToJson(Campagne c) => {
        'id': c.id,
        'nom': c.nom,
        'univers': c.univers,
        'ton': c.ton,
        'public': c.public,
        'lore': c.lore,
        'contexte': c.contexte,
        'resume': c.resume,
        'accroche': c.accroche,
        'episodesJoues': c.episodesJoues,
      };

  Campagne _campagneFromJson(Map<String, dynamic> j) => Campagne(
        id: (j['id'] as num).toInt(),
        nom: j['nom'] as String,
        univers: j['univers'] as String,
        ton: j['ton'] as String,
        public: j['public'] as String? ?? 'enfant',
        lore: j['lore'] as String? ?? '',
        contexte: j['contexte'] as String? ?? '',
        resume: j['resume'] as String? ?? '',
        accroche: j['accroche'] as String? ?? '',
        episodesJoues: (j['episodesJoues'] as num?)?.toInt() ?? 0,
      );
}
