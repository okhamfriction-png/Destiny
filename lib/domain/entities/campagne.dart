// Entités du module Histoire → Campagne (théâtre improvisé en famille).
// Vocabulaire PbtA adapté aux enfants : but (impulsion), manœuvres, présages,
// sbires. Aucun contenu violent : le danger est un problème jouable.

/// Un sous-espace nommé d'un lieu (« La place du marché », son détail).
class EspaceLieu {
  const EspaceLieu({required this.nom, required this.detail});
  final String nom;
  final String detail;

  factory EspaceLieu.fromJson(Map<String, dynamic> j) => EspaceLieu(
        nom: j['nom'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
      );
}

/// Un lieu d'un univers, avec ses sous-espaces et ses rôles jouables.
class LieuHistoire {
  const LieuHistoire({
    required this.id,
    required this.univers,
    required this.nom,
    required this.description,
    required this.espaces,
    required this.roles,
    this.origine = 'livre',
  });

  final String id;
  final String univers;
  final String nom;
  final String description;
  final List<EspaceLieu> espaces;
  final List<String> roles;
  final String origine; // 'livre' ou 'ia'

  factory LieuHistoire.fromJson(Map<String, dynamic> j) => LieuHistoire(
        id: j['id'] as String,
        univers: j['univers'] as String,
        nom: j['nom'] as String,
        description: j['description'] as String? ?? '',
        espaces: [
          for (final e in (j['espaces'] as List? ?? const []))
            EspaceLieu.fromJson(e as Map<String, dynamic>)
        ],
        roles: _roles(j['roles']),
        origine: j['origine'] as String? ?? 'livre',
      );

  static List<String> _roles(Object? v) {
    if (v is List) return [for (final e in v) '$e'.trim()];
    if (v is String) {
      return v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}

/// Un sbire d'un méchant : il agit à sa place, avec ses propres manœuvres.
class Sbire {
  const Sbire(
      {required this.nom, required this.description, required this.manoeuvres});
  final String nom;
  final String description;
  final List<String> manoeuvres;

  factory Sbire.fromJson(Map<String, dynamic> j) => Sbire(
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String? ?? '',
        manoeuvres: [for (final m in (j['manoeuvres'] as List? ?? const [])) '$m'],
      );
}

/// Un méchant récurrent : son but (impulsion), ses manœuvres, ses 4 présages,
/// et ses sbires.
class MechantHistoire {
  const MechantHistoire({
    required this.id,
    required this.univers,
    required this.nom,
    required this.description,
    required this.but,
    required this.manoeuvres,
    required this.presages,
    required this.sbires,
    this.origine = 'livre',
  });

  final String id;
  final String univers;
  final String nom;
  final String description;
  final String but;
  final List<String> manoeuvres;
  final List<String> presages;
  final List<Sbire> sbires;
  final String origine;

  factory MechantHistoire.fromJson(Map<String, dynamic> j) => MechantHistoire(
        id: j['id'] as String,
        univers: j['univers'] as String,
        nom: j['nom'] as String,
        description: j['description'] as String? ?? '',
        but: j['but'] as String? ?? '',
        manoeuvres: [for (final m in (j['manoeuvres'] as List? ?? const [])) '$m'],
        presages: [for (final p in (j['presages'] as List? ?? const [])) '$p'],
        sbires: [
          for (final s in (j['sbires'] as List? ?? const []))
            Sbire.fromJson(s as Map<String, dynamic>)
        ],
        origine: j['origine'] as String? ?? 'livre',
      );
}

/// Un archétype d'animal : une posture et un moteur, pas un texte à dire.
class ArchetypeHistoire {
  const ArchetypeHistoire({
    required this.id,
    required this.nom,
    required this.temperament,
    required this.port,
    required this.moteur,
  });

  final String id;
  final String nom;
  final String temperament;
  final String port;
  final String moteur;

  factory ArchetypeHistoire.fromJson(Map<String, dynamic> j) => ArchetypeHistoire(
        id: j['id'] as String,
        nom: j['nom'] as String,
        temperament: j['temperament'] as String? ?? '',
        port: j['port'] as String? ?? '',
        moteur: j['moteur'] as String? ?? '',
      );
}

/// Un figurant : ni allié ni ennemi, il a sa propre affaire en cours.
class Figurant {
  const Figurant({
    required this.role,
    required this.archetype,
    required this.objectif,
    required this.visage,
  });
  final String role;
  final ArchetypeHistoire archetype;
  final String objectif;
  final int visage; // rang → icône de visage distincte
}

/// L'attribution d'un joueur : son rôle dans le lieu et son archétype.
class RoleJoueur {
  const RoleJoueur(
      {required this.joueur, required this.role, required this.archetype});
  final String joueur;
  final String role;
  final ArchetypeHistoire archetype;
}

/// Une marche d'escalade : qui agit, ce qu'il fait, ce que ça produit.
class Escalade {
  const Escalade({
    required this.rang,
    required this.quiAgit,
    required this.ceQuilFait,
    required this.ceQueCaProduit,
    required this.estMechant,
  });
  final int rang;
  final String quiAgit;
  final String ceQuilFait;
  final String ceQueCaProduit;
  final bool estMechant;
}

/// Un épisode composé, prêt à jouer.
class Episode {
  const Episode({
    required this.numero,
    required this.lieu,
    required this.mechant,
    required this.roles,
    required this.figurants,
    required this.escalade,
  });
  final int numero;
  final LieuHistoire lieu;
  final MechantHistoire mechant;
  final List<RoleJoueur> roles;
  final List<Figurant> figurants;
  final List<Escalade> escalade;

  /// Intitulé « lieu — méchant ».
  String get intitule => '${lieu.nom} — ${mechant.nom}';

  /// Identifiant de scène « lieu|méchant ».
  String get amorceId => '${lieu.id}|${mechant.id}';
}

/// Une campagne : un monde, un méchant, et des épisodes qui se suivent.
class Campagne {
  const Campagne({
    required this.id,
    required this.nom,
    required this.univers,
    required this.ton,
    this.contexte = '',
    this.resume = '',
    this.accroche = '',
    this.episodesJoues = 0,
  });

  final int id;
  final String nom;
  final String univers;
  final String ton;
  final String contexte;
  final String resume;
  final String accroche;
  final int episodesJoues;

  Campagne copyWith({
    String? nom,
    String? resume,
    String? accroche,
    int? episodesJoues,
  }) =>
      Campagne(
        id: id,
        nom: nom ?? this.nom,
        univers: univers,
        ton: ton,
        contexte: contexte,
        resume: resume ?? this.resume,
        accroche: accroche ?? this.accroche,
        episodesJoues: episodesJoues ?? this.episodesJoues,
      );
}
