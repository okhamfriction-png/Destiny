/// Modèle typé de la grammaire de Destiny.
///
/// Tous les textes viennent de `assets/data/destiny_grammaire.json` : aucun
/// texte de grammaire n'est écrit dans le code. Ces classes ne font que
/// porter les données, sans logique d'affichage.
library;

/// Les quatre paliers du danger, dans l'ordre. L'identifiant technique du
/// quatrième est `supprime` (son nom affiché vient du fichier : « Il bloque
/// les sorties »).
enum PalierId {
  signale,
  enferme,
  envahit,
  supprime;

  /// Numéro du palier, de 1 à 4.
  int get numero => index + 1;

  /// Palier à partir de son numéro (1 à 4).
  static PalierId deNumero(int n) => PalierId.values[(n - 1).clamp(0, 3)];

  /// Palier à partir de son identifiant texte (`signale`…).
  static PalierId? depuisTexte(String? id) {
    for (final p in PalierId.values) {
      if (p.name == id) return p;
    }
    return null;
  }
}

/// Les trois familles d'archétypes.
enum FamilleId {
  tient,
  interprete,
  fissure;

  static FamilleId? depuisTexte(String? id) {
    for (final f in FamilleId.values) {
      if (f.name == id) return f;
    }
    return null;
  }
}

/// Statut de départ d'un animal.
enum Statut {
  haut,
  neutre,
  bas;

  static Statut depuisTexte(String? s) {
    for (final v in Statut.values) {
      if (v.name == s) return v;
    }
    return Statut.neutre;
  }
}

/// Une famille : tient le groupe, interprète le danger, fissure le groupe.
class Famille {
  const Famille({
    required this.id,
    required this.nom,
    required this.couleur,
    required this.couleurClaire,
    required this.idee,
    required this.pourquoi,
  });

  final FamilleId id;
  final String nom;

  /// Couleur au format `#RRGGBB`.
  final String couleur;
  final String couleurClaire;
  final String idee;
  final String pourquoi;
}

/// Un archétype : la conviction du personnage sur le danger.
class Archetype {
  const Archetype({
    required this.id,
    required this.nom,
    required this.famille,
    required this.ceQuIlFait,
    required this.montee,
    required this.animalIds,
  });

  /// Identifiant venu du fichier (`leader`, `gardien_de_l_ordre`…).
  final String id;
  final String nom;
  final FamilleId famille;
  final String ceQuIlFait;

  /// Ce que fait l'archétype à chaque palier.
  final Map<PalierId, String> montee;

  /// Les deux animaux de l'archétype.
  final List<String> animalIds;

  String monteeA(PalierId p) => montee[p] ?? '';
}

/// Un animal : le vêtement et la posture d'un archétype.
class Animal {
  const Animal({
    required this.id,
    required this.nom,
    required this.archetypeId,
    required this.statutDepart,
    required this.port,
    required this.posture,
    required this.replique,
    required this.sourceReplique,
    this.repliqueKids = '',
    this.sourceRepliqueKids = '',
    this.repliqueAdulteSeulement = false,
    this.temperament = '',
    this.niveauxCorps = const {},
    this.ancienMoteur = '',
    this.ancienneIntention = '',
  });

  final String id;
  final String nom;
  final String archetypeId;
  final Statut statutDepart;
  final String port;
  final String posture;

  /// La réplique propre à cet animal.
  final String replique;

  /// L'œuvre d'où vient la réplique. À n'afficher que dans la fiche détaillée.
  final String sourceReplique;

  /// La réplique pour jouer avec des enfants, et son œuvre.
  final String repliqueKids;
  final String sourceRepliqueKids;

  /// Vrai si la réplique ordinaire est réservée aux adultes.
  final bool repliqueAdulteSeulement;

  /// La réplique à afficher : la version kids en mode kids.
  String repliquePour({bool kids = false}) =>
      kids && repliqueKids.isNotEmpty ? repliqueKids : replique;

  String sourcePour({bool kids = false}) =>
      kids && sourceRepliqueKids.isNotEmpty ? sourceRepliqueKids : sourceReplique;

  /// Tempérament (venu des données des animaux de l'appli).
  final String temperament;

  /// Comment le corps de l'animal joue chaque palier (les anciens niveaux,
  /// rattachés aux paliers).
  final Map<PalierId, String> niveauxCorps;

  /// Ancien moteur de l'animal. Obsolète : conservé, jamais affiché.
  @Deprecated('Grammaire 1.x : remplacé par l\'archétype et le vouloir.')
  final String ancienMoteur;

  /// Ancienne intention de l'animal. Obsolète : conservée, jamais affichée.
  @Deprecated('Grammaire 1.x : remplacée par l\'archétype et le vouloir.')
  final String ancienneIntention;

  String corpsA(PalierId p) => niveauxCorps[p] ?? '';

  /// Chemin de l'image de l'animal dans l'appli.
  String get image => 'assets/images/archetypes/$id.jpg';
}

/// Un palier du danger (commun à tous les dangers).
class Palier {
  const Palier({
    required this.id,
    required this.nom,
    required this.acte,
    required this.ambiance,
    required this.etatArchetype,
  });

  final PalierId id;
  final String nom;
  final int acte;
  final String ambiance;

  /// Ce que fait l'archétype à ce palier (« dort », « il éclate »…).
  final String etatArchetype;

  int get numero => id.numero;
}

/// Un acte du spectacle.
class Acte {
  const Acte({
    required this.numero,
    required this.palier,
    required this.ambiance,
    required this.consignes,
  });

  final int numero;
  final PalierId palier;
  final String ambiance;
  final List<String> consignes;
}

/// Une règle d'or.
class RegleDOr {
  const RegleDOr({required this.titre, required this.texte});
  final String titre;
  final String texte;
}

/// Le rituel Destiny, entre deux actes.
class RituelDestiny {
  const RituelDestiny({
    required this.quand,
    required this.quiDeclenche,
    required this.sequence,
    required this.reprise,
    required this.premierFige,
  });

  final String quand;
  final String quiDeclenche;
  final List<String> sequence;
  final String reprise;
  final String premierFige;
}

/// Combien d'archétypes de chaque famille pour un nombre de joueurs.
class CompositionDistribution {
  const CompositionDistribution({
    required this.joueurs,
    required this.alarmiste,
    required this.tient,
    required this.interprete,
    required this.fissure,
    required this.auChoix,
  });

  final int joueurs;
  final int alarmiste;
  final int tient;

  /// Nombre d'archétypes « interprète le danger » en plus de l'alarmiste.
  final int interprete;
  final int fissure;
  final int auChoix;

  int minimumPour(FamilleId f) => switch (f) {
        FamilleId.tient => tient,
        FamilleId.interprete => interprete,
        FamilleId.fissure => fissure,
      };
}

/// Un exemple de distribution équilibrée.
class ExempleDistribution {
  const ExempleDistribution({
    required this.aQuatre,
    required this.plusACinq,
    required this.plusASix,
  });

  final List<String> aQuatre;
  final String plusACinq;
  final String plusASix;

  /// Les archétypes de l'exemple pour [joueurs] (4, 5 ou 6 ; à 3, voir
  /// `exemplesDistribution`).
  List<String> pour(int joueurs) => [
        ...aQuatre,
        if (joueurs >= 5) plusACinq,
        if (joueurs >= 6) plusASix,
      ];
}

/// Les règles de distribution.
class RegleDistribution {
  const RegleDistribution({
    required this.regle,
    required this.compositions,
    required this.exemples,
    required this.aSix,
  });

  final String regle;
  final List<CompositionDistribution> compositions;
  final List<ExempleDistribution> exemples;
  final String aSix;

  CompositionDistribution? pour(int joueurs) {
    for (final c in compositions) {
      if (c.joueurs == joueurs) return c;
    }
    return null;
  }
}

/// Une des trois cartes vouloir / besoin / prix à payer.
class CartePersonnage {
  const CartePersonnage({
    required this.titre,
    required this.sousTitre,
    required this.texte,
    required this.exemple,
  });

  final String titre;
  final String sousTitre;
  final String texte;
  final String exemple;
}

/// Un moment du tableau acte par acte (Dire, Fixer, Bloquer, Nommer, Choisir).
class GesteActe {
  const GesteActe({
    required this.moment,
    required this.verbe,
    required this.consigne,
  });

  final String moment;
  final String verbe;
  final String consigne;
}

/// Un exemple des « six directions ».
class Direction {
  const Direction({
    required this.archetypeId,
    required this.personnage,
    required this.besoin,
    required this.acte1Veut,
    required this.acte1Blessure,
    required this.acte2,
    required this.acte3,
    required this.acte4,
  });

  final String archetypeId;
  final String personnage;
  final String besoin;
  final String acte1Veut;
  final String acte1Blessure;
  final String acte2;
  final String acte3;
  final String acte4;
}

/// L'échauffement d'archétype.
class Echauffement {
  const Echauffement({
    required this.quand,
    required this.questions,
    required this.limite,
  });

  final String quand;
  final List<String> questions;
  final String limite;
}

/// La partie « personnage » de la grammaire : les six couches et leur
/// pédagogie.
class PedagogiePersonnage {
  const PedagogiePersonnage({
    required this.couches,
    required this.phraseCle,
    required this.piege,
    required this.chaine,
    required this.detecterPasJouer,
    required this.troisCartes,
    required this.acteParActe,
    required this.sixDirections,
    required this.echauffement,
  });

  final List<String> couches;
  final String phraseCle;
  final String piege;
  final List<String> chaine;
  final String detecterPasJouer;
  final List<CartePersonnage> troisCartes;
  final List<GesteActe> acteParActe;
  final List<Direction> sixDirections;
  final Echauffement echauffement;
}

/// Un danger tel que décrit dans la grammaire.
class DangerGrammaire {
  const DangerGrammaire({
    required this.id,
    required this.nom,
    required this.paliers,
    this.kids = false,
    this.supprimeKids = '',
  });

  final String id;
  final String nom;
  final Map<PalierId, String> paliers;

  /// Jouable avec des enfants.
  final bool kids;

  /// Le palier 4 en mode kids : personne ne meurt.
  final String supprimeKids;

  /// Les quatre textes dans l'ordre des paliers.
  List<String> get textes => [for (final p in PalierId.values) paliers[p] ?? ''];

  /// Les quatre textes, avec le palier 4 kids en mode kids.
  List<String> textesPour({bool kids = false}) => [
        for (final p in PalierId.values)
          kids && p == PalierId.supprime && supprimeKids.isNotEmpty
              ? supprimeKids
              : paliers[p] ?? '',
      ];
}

/// Un lieu tel que décrit dans la grammaire.
class LieuGrammaire {
  const LieuGrammaire({
    required this.id,
    required this.nom,
    required this.espaces,
    required this.roles,
    this.kids = false,
    this.figurants = const [],
  });

  final String id;
  final String nom;
  final List<String> espaces;
  final List<String> roles;

  /// Jouable avec des enfants.
  final bool kids;

  /// Trois figurants prêts à jouer : un aide, un témoin (ou assimilé), une
  /// victime (ou assimilée).
  final List<FigurantPret> figurants;
}

/// Mode d'un personnage non joueur.
enum ModePnj {
  /// Neutre, ou du côté des protagonistes.
  figurant,

  /// Au service du méchant.
  sbire;

  static ModePnj depuisTexte(String? s) => s == 'sbire' ? ModePnj.sbire : ModePnj.figurant;
}

/// Un figurant prêt à jouer, attaché à un lieu.
class FigurantPret {
  const FigurantPret({
    required this.id,
    required this.nom,
    required this.type,
    required this.archetypeId,
    required this.animalId,
    required this.veut,
    required this.vientDe,
    required this.sait,
    this.mode = ModePnj.figurant,
  });

  /// Identifiant stable : `<lieu>.<rang>` (ex. `aquarium.0`).
  final String id;
  final String nom;

  /// Type de figurant (`temoin`, `aide`…).
  final String type;
  final String archetypeId;
  final String animalId;
  final String veut;
  final String vientDe;

  /// Ce qu'il sait ou apporte.
  final String sait;
  final ModePnj mode;
}

/// Un type de figurant (inspiré des « bystanders » de Monster of the Week).
class TypeFigurant {
  const TypeFigurant({
    required this.id,
    required this.nom,
    required this.ceQuIlEst,
    required this.veut,
    required this.commentLeJouer,
    required this.sertA,
  });

  final String id;
  final String nom;
  final String ceQuIlEst;
  final String veut;
  final String commentLeJouer;
  final String sertA;
}

/// Les règles des figurants : les deux modes, les huit types, les règles.
class ReglesFigurants {
  const ReglesFigurants({
    required this.modes,
    required this.types,
    required this.regles,
    required this.parLieu,
    required this.inspiration,
  });

  /// Texte de chaque mode.
  final Map<ModePnj, String> modes;
  final List<TypeFigurant> types;
  final List<RegleDOr> regles;
  final String parLieu;
  final String inspiration;

  TypeFigurant? type(String id) {
    for (final t in types) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Un sbire d'un grand méchant : jouable, avec un archétype et un animal des
/// comédiens.
class Sbire {
  const Sbire({
    required this.id,
    required this.nom,
    required this.archetypeId,
    required this.animalId,
    required this.veut,
    required this.vientDe,
    required this.fait,
    this.kids = false,
  });

  final String id;
  final String nom;
  final String archetypeId;
  final String animalId;
  final String veut;
  final String vientDe;

  /// Ce qu'il fait pour son maître.
  final String fait;
  final bool kids;

  ModePnj get mode => ModePnj.sbire;
}

/// Un grand méchant de saison.
class Mechant {
  const Mechant({
    required this.id,
    required this.nom,
    required this.archetypeId,
    required this.animal,
    required this.inspiration,
    required this.posture,
    required this.histoire,
    required this.veut,
    required this.besoin,
    required this.faille,
    required this.cible,
    required this.offreAuTraitre,
    required this.sbires,
    this.kids = false,
    this.versionKids = '',
    this.failleKids = '',
  });

  final String id;
  final String nom;

  /// Même archétype que le protagoniste qu'il vise (son reflet).
  final String archetypeId;

  /// Son animal à lui, hors des 24 des comédiens.
  final String animal;
  final String inspiration;
  final String posture;
  final String histoire;
  final String veut;
  final String besoin;
  final String faille;
  final String cible;
  final String offreAuTraitre;
  final List<Sbire> sbires;
  final bool kids;
  final String versionKids;
  final String failleKids;

  /// L'histoire à montrer : la version kids en mode kids.
  String histoirePour({bool kids = false}) =>
      kids && versionKids.isNotEmpty ? versionKids : histoire;

  String faillePour({bool kids = false}) =>
      kids && failleKids.isNotEmpty ? failleKids : faille;
}

/// Le registre de la série : la mémoire de ce qui a été joué.
class RegistreSerie {
  const RegistreSerie({
    required this.principe,
    required this.categories,
    required this.suggestion,
  });

  final String principe;
  final List<String> categories;
  final String suggestion;
}

/// Épisode, saison, série.
class ReglesSerie {
  const ReglesSerie({
    required this.episode,
    required this.saison,
    required this.serie,
    required this.reglesDuMechant,
    required this.registre,
  });

  final String episode;
  final String saison;
  final String serie;
  final List<String> reglesDuMechant;
  final RegistreSerie registre;
}

/// Le mode kids.
class ModeKids {
  const ModeKids({
    required this.sigleTexte,
    required this.sigleFond,
    required this.sigleTexteCouleur,
    required this.principe,
    required this.regles,
    required this.pouvoirsExemples,
    required this.pouvoirRegle,
    required this.palier4,
    required this.dureeEpisodeMinutes,
    required this.mechantIds,
    required this.dangerIds,
    required this.lieuxAdultesSeulement,
  });

  final String sigleTexte;
  final String sigleFond;
  final String sigleTexteCouleur;
  final String principe;
  final List<RegleDOr> regles;
  final List<String> pouvoirsExemples;
  final String pouvoirRegle;
  final String palier4;

  /// Durée d'un épisode kids : de [0] à [1] minutes.
  final List<int> dureeEpisodeMinutes;
  final List<String> mechantIds;
  final List<String> dangerIds;
  final List<String> lieuxAdultesSeulement;
}

/// Catégorie d'œuvre de référence.
enum CategorieOeuvre {
  serieRoman,
  theatre,
  cinema;

  static CategorieOeuvre depuisTexte(String? s) => switch (s) {
        'theatre' => CategorieOeuvre.theatre,
        'cinema' => CategorieOeuvre.cinema,
        _ => CategorieOeuvre.serieRoman,
      };
}

/// Un personnage d'une œuvre de référence.
class PersonnageOeuvre {
  const PersonnageOeuvre({
    required this.archetypeId,
    required this.animalNom,
    required this.nom,
    required this.veut,
    required this.besoin,
    required this.faceAuDanger,
    required this.choix,
  });

  final String archetypeId;
  final String animalNom;
  final String nom;
  final String veut;
  final String besoin;
  final String faceAuDanger;
  final String choix;
}

/// Une œuvre de référence.
class Oeuvre {
  const Oeuvre({
    required this.categorie,
    required this.titre,
    required this.fiche,
    required this.pitch,
    required this.lieu,
    required this.groupe,
    required this.danger,
    required this.paliers,
    required this.personnages,
    required this.lecon,
  });

  final CategorieOeuvre categorie;
  final String titre;
  final String fiche;
  final String pitch;
  final String lieu;
  final String groupe;
  final String danger;
  final List<String> paliers;
  final List<PersonnageOeuvre> personnages;
  final String lecon;
}

/// Une scène de référence (les scènes de Tarantino).
class SceneReference {
  const SceneReference({
    required this.titre,
    required this.film,
    required this.lieu,
    required this.danger,
    required this.paliers,
    required this.lecon,
  });

  final String titre;
  final String film;
  final String lieu;
  final String danger;
  final List<String> paliers;
  final String lecon;
}

/// Un thème d'exercices venu de la grammaire (CROW, Lieu, Destiny).
class ThemeExercice {
  const ThemeExercice({
    required this.id,
    required this.nom,
    required this.sousTitre,
    required this.principe,
    required this.explication,
  });

  final String id;
  final String nom;
  final String sousTitre;
  final String principe;
  final String explication;
}

/// Un exercice venu de la grammaire.
class ExerciceGrammaire {
  const ExerciceGrammaire({
    required this.id,
    required this.titre,
    required this.source,
    required this.duree,
    required this.joueurs,
    required this.notion,
    required this.but,
    required this.consignes,
    required this.exemples,
    required this.debrief,
    required this.variante,
    required this.themeId,
    this.cartesATirer = const [],
  });

  final String id;
  final String titre;
  final String source;
  final String duree;
  final String joueurs;
  final String notion;
  final String but;
  final List<String> consignes;
  final List<String> exemples;
  final String debrief;
  final String variante;
  final String themeId;
  final List<String> cartesATirer;
}

/// La direction artistique.
class DirectionArtistique {
  const DirectionArtistique({
    required this.couleurs,
    required this.policeTitres,
    required this.policeTexte,
    required this.statuts,
  });

  /// nuit, or, or_fonce, or_clair, creme, encre, trait, texte_doux,
  /// bleu_destiny → `#RRGGBB`.
  final Map<String, String> couleurs;
  final String policeTitres;
  final String policeTexte;

  /// Couleur de pastille par statut.
  final Map<Statut, String> statuts;
}

/// Toute la grammaire de Destiny, chargée depuis le fichier de données.
class Grammaire {
  Grammaire({
    required this.version,
    required this.nom,
    required this.promesse,
    required this.familles,
    required this.archetypes,
    required this.animaux,
    required this.paliers,
    required this.actes,
    required this.reglesDOr,
    required this.rituel,
    required this.distribution,
    required this.personnage,
    required this.dangers,
    required this.lieux,
    required this.oeuvres,
    required this.scenes,
    required this.exercices,
    required this.themesExercices,
    required this.obsolete,
    required this.directionArtistique,
    required this.serie,
    required this.mechants,
    required this.figurants,
    required this.modeKids,
  })  : _archetypesParId = {for (final a in archetypes) a.id: a},
        _animauxParId = {for (final a in animaux) a.id: a},
        _famillesParId = {for (final f in familles) f.id: f};

  final String version;
  final String nom;
  final String promesse;
  final List<Famille> familles;
  final List<Archetype> archetypes;
  final List<Animal> animaux;
  final List<Palier> paliers;
  final List<Acte> actes;
  final List<RegleDOr> reglesDOr;
  final RituelDestiny rituel;
  final RegleDistribution distribution;
  final PedagogiePersonnage personnage;
  final List<DangerGrammaire> dangers;
  final List<LieuGrammaire> lieux;
  final List<Oeuvre> oeuvres;
  final List<SceneReference> scenes;
  final List<ExerciceGrammaire> exercices;
  final List<ThemeExercice> themesExercices;
  final List<String> obsolete;
  final DirectionArtistique directionArtistique;
  final ReglesSerie serie;
  final List<Mechant> mechants;
  final ReglesFigurants figurants;
  final ModeKids modeKids;

  final Map<String, Archetype> _archetypesParId;
  final Map<String, Animal> _animauxParId;
  final Map<FamilleId, Famille> _famillesParId;

  /// L'identifiant de l'archétype qui porte le danger.
  static const String alarmisteId = 'alarmiste';

  /// L'identifiant du leader (facultatif dans la distribution).
  static const String leaderId = 'leader';

  Archetype? archetype(String id) => _archetypesParId[id];
  Animal? animal(String id) => _animauxParId[id];
  Famille famille(FamilleId id) => _famillesParId[id]!;

  /// La famille d'un archétype.
  Famille familleDe(Archetype a) => famille(a.famille);

  /// L'archétype d'un animal.
  Archetype? archetypeDeLAnimal(String animalId) {
    final a = _animauxParId[animalId];
    return a == null ? null : _archetypesParId[a.archetypeId];
  }

  /// Les deux animaux d'un archétype.
  List<Animal> animauxDe(String archetypeId) => [
        for (final id in _archetypesParId[archetypeId]?.animalIds ?? const [])
          if (_animauxParId[id] != null) _animauxParId[id]!,
      ];

  /// Les archétypes d'une famille, dans l'ordre du fichier.
  List<Archetype> archetypesDe(FamilleId f) =>
      [for (final a in archetypes) if (a.famille == f) a];

  Palier palier(PalierId id) => paliers.firstWhere((p) => p.id == id);

  /// L'animal qui porte ce nom (« Souris »), ou null.
  Animal? animalNomme(String nom) {
    final cle = normaliser(nom);
    for (final a in animaux) {
      if (normaliser(a.nom) == cle) return a;
    }
    return null;
  }

  Mechant? mechant(String id) {
    for (final m in mechants) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Les méchants « reflets » d'un archétype : ceux qui visent un
  /// protagoniste de cet archétype. En mode kids, seulement les méchants kids.
  List<Mechant> mechantsReflets(String archetypeId, {bool kids = false}) => [
        for (final m in mechants)
          if (m.archetypeId == archetypeId && (!kids || m.kids)) m,
      ];

  /// Le sbire qui porte cet identifiant, avec son maître.
  ({Mechant mechant, Sbire sbire})? sbire(String id) {
    for (final m in mechants) {
      for (final s in m.sbires) {
        if (s.id == id) return (mechant: m, sbire: s);
      }
    }
    return null;
  }

  /// Le danger de la grammaire qui porte ce nom (comparaison sans casse ni
  /// accents), ou null.
  DangerGrammaire? dangerNomme(String nom) {
    final cle = normaliser(nom);
    for (final d in dangers) {
      if (normaliser(d.nom) == cle) return d;
    }
    return null;
  }

  /// Le lieu de la grammaire qui porte ce nom, ou null.
  LieuGrammaire? lieuNomme(String nom) {
    final cle = normaliser(nom);
    for (final l in lieux) {
      if (normaliser(l.nom) == cle) return l;
    }
    return null;
  }

  /// Les personnages d'œuvres qui ont cet archétype, avec leur œuvre.
  List<({Oeuvre oeuvre, PersonnageOeuvre personnage})> modelesDe(
          String archetypeId) =>
      [
        for (final o in oeuvres)
          for (final p in o.personnages)
            if (p.archetypeId == archetypeId) (oeuvre: o, personnage: p),
      ];

  /// L'exemple des six directions pour cet archétype, s'il existe.
  Direction? directionDe(String archetypeId) {
    for (final d in personnage.sixDirections) {
      if (d.archetypeId == archetypeId) return d;
    }
    return null;
  }

  /// Découpe un texte en mots normalisés (« D'argent ! » → [d, argent]).
  static List<String> normaliserMots(String s) => [
        for (final m in s.toLowerCase().split(RegExp(r"[^a-z0-9àâäáçéèêëîïíôöóùûüúÿœæ]+")))
          if (normaliser(m).isNotEmpty) normaliser(m),
      ];

  /// Minuscules, sans accents ni ponctuation : sert à rapprocher deux noms.
  static String normaliser(String s) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
      'ç': 'c',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
      'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
    };
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final r = accents[ch] ?? ch;
      if (RegExp(r'[a-z0-9]').hasMatch(r) || r.length > 1) buf.write(r);
    }
    return buf.toString();
  }
}
