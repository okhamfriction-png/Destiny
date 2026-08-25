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
    this.morts = const [],
    this.blesses = const [],
  });
  final int numero;
  final int dateMs;
  final String intitule;
  final String amorceId;
  final String phrase;
  final String ceQuiAMarche;
  final String transcription;

  /// Récap de combat : libellés des personnages tombés / blessés durant l'épisode.
  final List<String> morts;
  final List<String> blesses;

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'dateMs': dateMs,
        'intitule': intitule,
        'amorceId': amorceId,
        'phrase': phrase,
        'ceQuiAMarche': ceQuiAMarche,
        'transcription': transcription,
        'morts': morts,
        'blesses': blesses,
      };

  factory SeanceJouee.fromJson(Map<String, dynamic> j) => SeanceJouee(
        numero: (j['numero'] as num).toInt(),
        dateMs: (j['dateMs'] as num).toInt(),
        intitule: j['intitule'] as String? ?? '',
        amorceId: j['amorceId'] as String? ?? '',
        phrase: j['phrase'] as String? ?? '',
        ceQuiAMarche: j['ceQuiAMarche'] as String? ?? '',
        transcription: j['transcription'] as String? ?? '',
        morts: [for (final m in (j['morts'] as List? ?? const [])) '$m'],
        blesses: [for (final b in (j['blesses'] as List? ?? const [])) '$b'],
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

  /// Univers du mode Adulte (identiques au mode Histoire IA).
  static const Map<String, String> universAdulte = {
    'contemporain': 'Contemporain',
    'policier': 'Policier',
    'high_fantasy': 'High Fantasy',
    'shonen': 'Shonen',
    'science_fiction': 'Science-Fiction',
    'dark_fantasy': 'Dark Fantasy',
    'cyberpunk': 'Cyberpunk',
    'horreur': 'Horreur',
    'post_apo': 'Post-apocalyptique',
    'steampunk': 'Steampunk',
    'super_heros': 'Super-héros',
    'historique': 'Historique',
  };

  /// Univers du mode Enfant (identiques au mode Histoire IA).
  static const Map<String, String> universEnfant = {
    'conte_fees': 'Conte de fées',
    'dessin_anime': 'Dessin animé',
    'manga_rigolo': 'Manga rigolo',
    'animaux_parlent': 'Animaux qui parlent',
    'super_heros': 'Super-héros',
    'pirates': 'Pirates',
    'espace_rigolo': 'Espace rigolo',
    'monde_magique': 'Monde magique',
    'sous_la_mer': 'Sous la mer',
    'chevaliers_dragons': 'Chevaliers & dragons',
  };

  /// Tous les univers (pour les recherches de libellé).
  static final Map<String, String> univers = {
    ...universAdulte,
    ...universEnfant,
  };

  /// Les univers proposés selon le public.
  static Map<String, String> universPour(String public) =>
      public == 'adulte' ? universAdulte : universEnfant;

  /// Les dix lores les plus connus par univers (couche de personnages/ambiance).
  static const Map<String, List<String>> lores = {
    // Adulte
    'contemporain': ['Breaking Bad', 'Peaky Blinders', 'The Wire', 'Les Soprano', 'Better Call Saul', 'Narcos', 'Gomorra', 'Succession', 'Le Parrain', 'Scarface'],
    'policier': ['Sherlock Holmes', 'True Detective', 'Columbo', 'Les Experts', 'Engrenages', 'Fargo', 'Seven', 'Mindhunter', 'Agatha Christie', 'Blake et Mortimer'],
    'high_fantasy': ['Le Seigneur des Anneaux', 'Game of Thrones', 'The Witcher', 'Donjons & Dragons', 'Warhammer', 'Le Monde de Narnia', 'Elden Ring', 'Dragon Age', 'Kaamelott', 'Harry Potter'],
    'shonen': ['Dragon Ball', 'Naruto', 'One Piece', 'Bleach', 'My Hero Academia', 'Demon Slayer', 'L\'Attaque des Titans', 'Hunter x Hunter', 'Jujutsu Kaisen', 'Fairy Tail'],
    'science_fiction': ['Star Wars', 'Star Trek', 'Dune', 'Blade Runner', 'The Expanse', 'Fondation', 'Alien', 'Mass Effect', 'Interstellar', 'Matrix'],
    'dark_fantasy': ['The Witcher', 'Berserk', 'Dark Souls', 'Bloodborne', 'Elden Ring', 'Warhammer', 'Game of Thrones', 'Castlevania', 'Diablo', 'Hellboy'],
    'cyberpunk': ['Cyberpunk 2077', 'Blade Runner', 'Ghost in the Shell', 'Deus Ex', 'Akira', 'Neuromancer', 'Matrix', 'Altered Carbon', 'Shadowrun', 'Watch Dogs'],
    'horreur': ['Lovecraft', 'Stranger Things', 'The Thing', 'Alien', 'Silent Hill', 'Resident Evil', 'Ça (It)', 'Scream', 'The Walking Dead', 'Conjuring'],
    'post_apo': ['Mad Max', 'Fallout', 'The Last of Us', 'The Walking Dead', 'Metro', 'La Route', 'Snowpiercer', 'Le Livre d\'Eli', 'Je suis une légende', 'Waterworld'],
    'steampunk': ['Arcane', 'Bioshock', 'Dishonored', 'Le Château ambulant', 'Les Mystérieuses Cités d\'or', '20000 lieues sous les mers', 'Wild Wild West', 'Sherlock Holmes (Guy Ritchie)', 'Fullmetal Alchemist', 'Girl Genius'],
    'super_heros': ['Marvel (Avengers)', 'DC (Justice League)', 'Spider-Man', 'Batman', 'X-Men', 'The Boys', 'Invincible', 'Watchmen', 'Hellboy', 'My Hero Academia'],
    'historique': ['Rome', 'Vikings', 'Gladiator', 'Kingdom', 'Braveheart', 'Assassin\'s Creed', 'Napoléon', 'Les Trois Mousquetaires', 'Peaky Blinders', 'Versailles'],
    // Enfant
    'conte_fees': ['La Belle au bois dormant', 'Cendrillon', 'Blanche-Neige', 'Raiponce', 'La Reine des Neiges', 'Shrek', 'Les frères Grimm', 'Andersen', 'La Belle et la Bête', 'Peter Pan'],
    'dessin_anime': ['Tom et Jerry', 'Les Simpson', 'Bob l\'éponge', 'Scooby-Doo', 'Les Razmoket', 'Astérix', 'Kirikou', 'Pat\' Patrouille', 'Miraculous', 'Oggy et les cafards'],
    'manga_rigolo': ['Doraemon', 'Pokémon', 'Dr. Slump', 'Crayon Shin-chan', 'Beyblade', 'Digimon', 'Yo-kai Watch', 'Bakugan', 'Chi une vie de chat', 'Hamtaro'],
    'animaux_parlent': ['Le Roi Lion', 'Zootopie', 'Madagascar', 'Le Livre de la jungle', 'La Ferme se rebelle', 'Kung Fu Panda', 'Robin des Bois (Disney)', 'Ratatouille', 'Rox et Rouky', 'Bambi'],
    'pirates': ['One Piece', 'Pirates des Caraïbes', 'Peter Pan', 'L\'Île au trésor', 'Tintin', 'Astérix', 'Jake et les Pirates', 'Sinbad', 'Vaiana', 'Barbe Rouge'],
    'espace_rigolo': ['Toy Story (Buzz)', 'Wall-E', 'Buzz l\'Éclair', 'Planète 51', 'Les Gardiens de la Galaxie', 'E.T.', 'Star Wars', 'Lightyear', 'Astro Boy', 'Les Minions'],
    'monde_magique': ['Harry Potter', 'Le Monde de Narnia', 'Merlin', 'Kirikou', 'Fantasia', 'Raiponce', 'La Reine des Neiges', 'Aladdin', 'Winx', 'Le Petit Sorcier'],
    'sous_la_mer': ['Le Monde de Nemo', 'La Petite Sirène', 'Vaiana', 'Bob l\'éponge', 'Atlantide', 'Bubulle Guppies', 'Aquaman', 'Océane', 'Splash', '20000 lieues sous les mers'],
    'chevaliers_dragons': ['Dragons (Krokmou)', 'Shrek', 'Merlin', 'Le Seigneur des Anneaux', 'Kaamelott', 'Zelda', 'Excalibur', 'Les Chevaliers du Zodiaque', 'Mulan', 'Rebelle'],
  };

  /// Peuples proposés par univers (couche « origine / espèce » du personnage).
  /// Le premier de la liste est le plus évident → proposé par défaut.
  static const Map<String, List<String>> peuplesParUnivers = {
    // Adulte
    'contemporain': ['Civils', 'Policiers', 'Truands', 'Notables', 'Marginaux', 'Journalistes'],
    'policier': ['Enquêteurs', 'Témoins', 'Suspects', 'Notables', 'Petites frappes', 'Légistes'],
    'high_fantasy': ['Humains', 'Elfes', 'Nains', 'Halfelins', 'Orcs', 'Gobelins', 'Fées'],
    'shonen': ['Humains', 'Guerriers', 'Ninjas', 'Mages', 'Esprits', 'Démons', 'Créatures'],
    'science_fiction': ['Humains', 'Androïdes', 'Extraterrestres', 'Cyborgs', 'Clones', 'Mutants'],
    'dark_fantasy': ['Humains', 'Sorciers', 'Morts-vivants', 'Démons', 'Chasseurs', 'Maudits', 'Bêtes'],
    'cyberpunk': ['Humains', 'Cyborgs', 'Hackers', 'Corpos', 'Androïdes', 'Gangs des rues'],
    'horreur': ['Survivants', 'Villageois', 'Possédés', 'Monstres', 'Cultistes', 'Fantômes'],
    'post_apo': ['Survivants', 'Pillards', 'Mutants', 'Charognards', 'Colons', 'Nomades'],
    'steampunk': ['Humains', 'Ingénieurs', 'Aristocrates', 'Automates', 'Aviateurs', 'Bas-fonds'],
    'super_heros': ['Humains', 'Super-héros', 'Super-vilains', 'Mutants', 'Extraterrestres', 'Androïdes'],
    'historique': ['Roturiers', 'Nobles', 'Soldats', 'Marchands', 'Clergé', 'Artisans', 'Hors-la-loi'],
    // Enfant
    'conte_fees': ['Humains', 'Fées', 'Princes et princesses', 'Lutins', 'Ogres', 'Sorcières', 'Animaux enchantés'],
    'dessin_anime': ['Enfants', 'Animaux rigolos', 'Voisins', 'Héros du quartier', 'Farceurs', 'Robots'],
    'manga_rigolo': ['Enfants', 'Créatures de poche', 'Écoliers', 'Robots', 'Petits monstres', 'Mascottes'],
    'animaux_parlent': ['Animaux de la savane', 'Animaux de la ferme', 'Animaux de la jungle', 'Animaux de la forêt', 'Animaux de la ville'],
    'pirates': ['Pirates', 'Marins', 'Habitants des îles', 'Corsaires', 'Sirènes', 'Chasseurs de trésor'],
    'espace_rigolo': ['Astronautes', 'Petits aliens', 'Robots', 'Explorateurs', 'Cosmonautes'],
    'monde_magique': ['Apprentis sorciers', 'Fées', 'Créatures magiques', 'Magiciens', 'Lutins', 'Elfes'],
    'sous_la_mer': ['Poissons', 'Sirènes', 'Créatures des récifs', 'Crustacés', 'Dauphins', 'Peuples des abysses'],
    'chevaliers_dragons': ['Chevaliers', 'Dragons', 'Villageois', 'Magiciens', 'Écuyers', 'Princesses'],
  };

  /// Surcharges de peuples propres à certains lores (plus fin que l'univers).
  /// La clé est le nom exact du lore ; sinon on retombe sur l'univers.
  static const Map<String, List<String>> peuplesParLore = {
    // animaux_parlent — le décor animalier change selon l'histoire
    'Le Roi Lion': ['Lions', 'Hyènes', 'Suricates', 'Éléphants', 'Zèbres', 'Oiseaux'],
    'Le Livre de la jungle': ['Loups', 'Panthères', 'Ours', 'Singes', 'Serpents', 'Éléphants'],
    'La Ferme se rebelle': ['Vaches', 'Cochons', 'Poules', 'Chevaux', 'Moutons', 'Chiens'],
    'Zootopie': ['Prédateurs', 'Proies', 'Animaux de la ville', 'Renards', 'Lapins', 'Fauves'],
    'Madagascar': ['Lions', 'Zèbres', 'Girafes', 'Hippopotames', 'Lémuriens', 'Pingouins'],
    'Ratatouille': ['Rats', 'Humains', 'Cuisiniers'],
    // shonen — grandes factions
    'One Piece': ['Pirates', 'Marines', 'Humains', 'Hommes-poissons', 'Géants'],
    'Naruto': ['Ninjas', 'Villageois', 'Clans', 'Bêtes à queues', 'Sages'],
    // pirates
    'Peter Pan': ['Enfants perdus', 'Pirates', 'Fées', 'Sirènes', 'Indiens'],
    // sous_la_mer
    'Le Monde de Nemo': ['Poissons', 'Requins', 'Tortues', 'Crustacés', 'Méduses'],
    // super_heros / science_fiction restent au niveau univers
  };

  /// Peuples cohérents avec l'univers ET le lore choisis. Le premier est le
  /// plus évident (proposé par défaut). Retombe sur l'univers, puis un défaut.
  static List<String> peuplesPour(String univers, String lore) {
    final parLore = peuplesParLore[lore.trim()];
    if (parLore != null && parLore.isNotEmpty) return parLore;
    final parUniv = peuplesParUnivers[univers];
    if (parUniv != null && parUniv.isNotEmpty) return parUniv;
    return const ['Habitants', 'Voyageurs', 'Notables', 'Marginaux'];
  }

  /// Les tons proposés (id → libellé).
  static const Map<String, String> tons = {
    'drole': 'Drôle',
    'aventureux': 'Aventureux',
    'enquete': 'Enquête',
    'epique': 'Épique',
    'tendre': 'Tendre',
    'tranquille': 'Tranquille',
    'sombre': 'Sombre',
    'dramatique': 'Dramatique',
    'burlesque': 'Burlesque',
    'mysterieux': 'Mystérieux',
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
  List<ArchetypeHistoire> get archetypes => List.unmodifiable(_archetypes);

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
    List<String> morts = const [],
    List<String> blesses = const [],
    List<String> figurantsMortsIds = const [],
    List<String> sbiresMortsNoms = const [],
    bool mechantMort = false,
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
      morts: morts,
      blesses: blesses,
    ));
    final i = _campagnes.indexWhere((c) => c.id == campagne.id);
    if (i >= 0) {
      final c = _campagnes[i];
      // Continuité : on cumule les morts pour les exclure des épisodes suivants.
      List<String> fusion(List<String> a, List<String> b) =>
          {...a, ...b}.toList();
      _campagnes[i] = c.copyWith(
        episodesJoues: episode.numero,
        figurantsMorts: fusion(c.figurantsMorts, figurantsMortsIds),
        sbiresMorts: fusion(c.sbiresMorts, sbiresMortsNoms),
        mechantsMorts:
            mechantMort ? fusion(c.mechantsMorts, [episode.mechant.id]) : null,
      );
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
        'figurantsMorts': c.figurantsMorts,
        'sbiresMorts': c.sbiresMorts,
        'mechantsMorts': c.mechantsMorts,
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
        figurantsMorts: [
          for (final m in (j['figurantsMorts'] as List? ?? const [])) '$m'
        ],
        sbiresMorts: [
          for (final m in (j['sbiresMorts'] as List? ?? const [])) '$m'
        ],
        mechantsMorts: [
          for (final m in (j['mechantsMorts'] as List? ?? const [])) '$m'
        ],
      );
}
