/// La Série, le jeu de rôle entre humains, avec le vocabulaire de la télé :
/// un **épisode** est un one-shot (un lieu, un danger, quatre actes) ; une
/// **saison** regroupe quatre épisodes et un méchant dans l'ombre ; une
/// **série** enchaîne les saisons. Tout reste sur l'appareil.
library;

import '../grammaire/modeles.dart' show ModePnj;
import '../troupe/session.dart' show ChoixFinal, EvenementDestiny, NoteRegie;

export '../troupe/session.dart' show ChoixFinal, EvenementDestiny, NoteRegie;

/// Pour qui on joue.
enum PublicSerie {
  adulte,
  kids;

  /// Lit aussi l'ancien `public` des campagnes (« enfant »).
  static PublicSerie depuisTexte(String? s) =>
      s == 'kids' || s == 'enfant' ? PublicSerie.kids : PublicSerie.adulte;
}

/// Où en est un épisode.
enum EtapeEpisode {
  preparation,
  jeu,
  bilan,
  termine;

  static EtapeEpisode depuisTexte(String? s) {
    for (final e in EtapeEpisode.values) {
      if (e.name == s) return e;
    }
    return EtapeEpisode.preparation;
  }
}

/// L'état d'un personnage pendant l'épisode (le combat, outil du maître du
/// jeu). En public enfant, personne ne meurt : on « quitte l'histoire ».
enum Sante {
  enForme,
  blesse,
  sorti;

  static Sante depuisTexte(String? s) {
    for (final e in Sante.values) {
      if (e.name == s) return e;
    }
    return Sante.enForme;
  }

  /// En forme → blessé → sorti → en forme.
  Sante get suivante => Sante.values[(index + 1) % Sante.values.length];
}

/// Les catégories du registre, dans l'ordre de `serie.registre.categories`
/// de la grammaire. Les libellés sont dans le fichier de textes.
enum CategorieRegistre {
  figurant,
  sbire,
  bascule,
  objet,
  lieu,
  secret,
  promesse,
  mort,
  traitre,
  heritage;

  static CategorieRegistre depuisTexte(String? s) {
    final v = (s ?? '').trim().toLowerCase();
    for (final c in CategorieRegistre.values) {
      if (c.name == v) return c;
    }
    // Les mots que l'IA peut employer.
    return switch (v) {
      'figurants' => CategorieRegistre.figurant,
      'sbires' => CategorieRegistre.sbire,
      'figurant passé sbire' || 'figurants passés sbires' || 'bascules' => CategorieRegistre.bascule,
      'objets' => CategorieRegistre.objet,
      'lieux' || 'sortie' || 'sorties' => CategorieRegistre.lieu,
      'secrets' => CategorieRegistre.secret,
      'promesses' => CategorieRegistre.promesse,
      'morts' || 'tombé' || 'tombés' => CategorieRegistre.mort,
      'traître' => CategorieRegistre.traitre,
      'ce que le méchant a laissé' || 'héritage' => CategorieRegistre.heritage,
      _ => CategorieRegistre.secret,
    };
  }
}

/// Le statut d'une entrée du registre.
enum StatutRegistre {
  present,
  parti,
  tombe,
  retourne;

  static StatutRegistre depuisTexte(String? s) {
    final v = (s ?? '').trim().toLowerCase();
    return switch (v) {
      'parti' || 'partie' => StatutRegistre.parti,
      'tombe' || 'tombé' || 'tombée' => StatutRegistre.tombe,
      'retourne' || 'retourné' || 'retournée' => StatutRegistre.retourne,
      _ => StatutRegistre.present,
    };
  }
}

List<String> _ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
List<Map<String, dynamic>> _ms(Object? v) =>
    [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
String _s(Object? v) => v is String ? v : '';
int _i(Object? v, [int defaut = 0]) => v is num ? v.toInt() : defaut;
bool _b(Object? v, [bool defaut = false]) => v is bool ? v : defaut;

/// Les réglages d'une série.
class ReglagesSerie {
  ReglagesSerie({this.traitre = false, this.registre = true, this.combat = true, this.piece = true});

  /// Le module traître : désactivé par défaut ; en kids, seul le parent
  /// l'active.
  bool traitre;

  /// Le registre (la mémoire de la série) : activé par défaut.
  bool registre;

  /// Les cœurs, les malus et les bonus.
  bool combat;

  /// La pièce du destin BRAVE / SMART.
  bool piece;

  Map<String, dynamic> versJson() =>
      {'traitre': traitre, 'registre': registre, 'combat': combat, 'piece': piece};

  factory ReglagesSerie.depuisJson(Map<String, dynamic> j) => ReglagesSerie(
        traitre: _b(j['traitre']),
        registre: _b(j['registre'], true),
        combat: _b(j['combat'], true),
        piece: _b(j['piece'], true),
      );
}

/// Un personnage joueur, gardé toute la série, avec ses six couches.
/// Le vouloir change à chaque épisode : il est dans [RoleEpisode].
class PersonnageSerie {
  PersonnageSerie({
    required this.id,
    this.joueur = '',
    this.nom = '',
    this.fonction = '',
    this.peuple = '',
    required this.archetypeId,
    this.animalId = '',
    List<String>? anciensArchetypes,
    this.blessure = '',
    this.besoin = '',
    this.besoinNomme = false,
    this.besoinPaye = false,
    this.pouvoir = '',
    this.sorti = false,
    this.pnj = false,
  }) : anciensArchetypes = anciensArchetypes ?? [];

  final String id;

  /// Le prénom du joueur. Il reste sur l'appareil : il n'est jamais envoyé à
  /// l'IA ni écrit dans le registre.
  String joueur;

  /// Le nom du personnage (facultatif).
  String nom;

  /// Sa place dans le lieu ou dans le groupe (« la serveuse », « le vigile »).
  String fonction;

  /// Son peuple, selon l'univers.
  String peuple;
  String archetypeId;
  String animalId;

  /// Les archétypes qu'il a eus avant (on peut en changer entre deux saisons,
  /// quand on a payé son besoin).
  List<String> anciensArchetypes;
  String blessure;

  /// Le besoin appartient à la saison : fixé à l'épisode 1, nommé à
  /// l'épisode 3, payé au final.
  String besoin;
  bool besoinNomme;
  bool besoinPaye;

  /// En kids : un pouvoir, choisi avec son animal, gardé toute la saison.
  String pouvoir;

  /// Il a quitté l'histoire (mort, en adulte).
  bool sorti;

  /// Tenu par le maître du jeu (l'alarmiste quand on est moins de quatre).
  bool pnj;

  /// Le nom à afficher : le personnage, sinon sa fonction, sinon le joueur.
  String get appel => [nom, fonction].firstWhere((x) => x.trim().isNotEmpty, orElse: () => joueur);

  Map<String, dynamic> versJson() => {
        'id': id,
        'joueur': joueur,
        'nom': nom,
        'fonction': fonction,
        'peuple': peuple,
        'archetype': archetypeId,
        'animal': animalId,
        'anciens_archetypes': anciensArchetypes,
        'blessure': blessure,
        'besoin': besoin,
        'besoin_nomme': besoinNomme,
        'besoin_paye': besoinPaye,
        'pouvoir': pouvoir,
        'sorti': sorti,
        'pnj': pnj,
      };

  factory PersonnageSerie.depuisJson(Map<String, dynamic> j) => PersonnageSerie(
        id: _s(j['id']),
        joueur: _s(j['joueur']),
        nom: _s(j['nom']),
        fonction: _s(j['fonction']),
        peuple: _s(j['peuple']),
        archetypeId: _s(j['archetype']),
        animalId: _s(j['animal']),
        anciensArchetypes: _ls(j['anciens_archetypes']),
        blessure: _s(j['blessure']),
        besoin: _s(j['besoin']),
        besoinNomme: _b(j['besoin_nomme']),
        besoinPaye: _b(j['besoin_paye']),
        pouvoir: _s(j['pouvoir']),
        sorti: _b(j['sorti']),
        pnj: _b(j['pnj']),
      );
}

/// Ce qu'un personnage vit pendant un épisode.
class RoleEpisode {
  RoleEpisode({
    required this.personnageId,
    this.vouloir = '',
    this.choix = ChoixFinal.aucun,
    this.prixPaye = '',
    this.sante = Sante.enForme,
    this.mod = 0,
  });

  final String personnageId;

  /// Le vouloir de cet épisode : concret, dans ce lieu.
  String vouloir;
  ChoixFinal choix;
  String prixPaye;
  Sante sante;

  /// Bonus (+) ou malus (−).
  int mod;

  Map<String, dynamic> versJson() => {
        'personnage': personnageId,
        'vouloir': vouloir,
        'choix': choix.name,
        'prix_paye': prixPaye,
        'sante': sante.name,
        'mod': mod,
      };

  factory RoleEpisode.depuisJson(Map<String, dynamic> j) => RoleEpisode(
        personnageId: _s(j['personnage']),
        vouloir: _s(j['vouloir']),
        choix: ChoixFinal.depuisTexte(j['choix'] as String?),
        prixPaye: _s(j['prix_paye']),
        sante: Sante.depuisTexte(j['sante'] as String?),
        mod: _i(j['mod']),
      );
}

/// Un personnage non joueur de l'épisode : un figurant (neutre, ou du côté
/// des protagonistes) ou un sbire (au service du méchant).
class PnjEpisode {
  PnjEpisode({
    required this.id,
    required this.nom,
    required this.mode,
    this.type = '',
    this.archetypeId = '',
    this.animalId = '',
    this.veut = '',
    this.vientDe = '',
    this.sait = '',
    this.fait = '',
    this.duMechant = false,
    this.aBascule = false,
    this.sante = Sante.enForme,
    this.mod = 0,
  });

  /// Identifiant stable : celui du figurant du lieu ou du sbire.
  final String id;
  final String nom;
  ModePnj mode;
  final String type;
  final String archetypeId;
  final String animalId;
  final String veut;
  final String vientDe;
  final String sait;
  final String fait;

  /// Un des sbires du méchant (et pas un figurant du lieu).
  final bool duMechant;

  /// Un figurant qui a accepté l'offre du méchant : il est passé sbire.
  bool aBascule;
  Sante sante;
  int mod;

  Map<String, dynamic> versJson() => {
        'id': id,
        'nom': nom,
        'mode': mode.name,
        'type': type,
        'archetype': archetypeId,
        'animal': animalId,
        'veut': veut,
        'vient_de': vientDe,
        'sait': sait,
        'fait': fait,
        'du_mechant': duMechant,
        'a_bascule': aBascule,
        'sante': sante.name,
        'mod': mod,
      };

  factory PnjEpisode.depuisJson(Map<String, dynamic> j) => PnjEpisode(
        id: _s(j['id']),
        nom: _s(j['nom']),
        mode: ModePnj.depuisTexte(j['mode'] as String?),
        type: _s(j['type']),
        archetypeId: _s(j['archetype']),
        animalId: _s(j['animal']),
        veut: _s(j['veut']),
        vientDe: _s(j['vient_de']),
        sait: _s(j['sait']),
        fait: _s(j['fait']),
        duMechant: _b(j['du_mechant']),
        aBascule: _b(j['a_bascule']),
        sante: Sante.depuisTexte(j['sante'] as String?),
        mod: _i(j['mod']),
      );
}

/// Un épisode : un lieu, un groupe, un danger en quatre paliers, quatre actes.
class EpisodeSerie {
  EpisodeSerie({
    required this.id,
    required this.date,
    this.saison = 0,
    this.numero = 1,
    this.etape = EtapeEpisode.preparation,
    this.lieuId = '',
    this.lieuNom = '',
    this.lieuDescription = '',
    List<String>? espaces,
    this.groupe = '',
    this.dangerId = '',
    this.dangerNom = '',
    List<String>? paliers,
    this.presage = '',
    this.mechantId = '',
    List<String>? objets,
    this.mystere = '',
    this.reponseMystere = '',
    this.dureeMinutes = 0,
    List<int>? destinyMinutes,
    this.palierAtteint = 1,
    List<EvenementDestiny>? destinys,
    List<NoteRegie>? notes,
    List<RoleEpisode>? roles,
    List<PnjEpisode>? pnjs,
    this.mechantSante = Sante.enForme,
    this.mechantMod = 0,
    List<String>? registreRessorti,
    this.transcrire = false,
    this.transcription = '',
    this.resume = '',
    this.suite = '',
    this.ceQuiAMarche = '',
    this.phrase = '',
    this.sortie = '',
    this.ancienneGrammaire = false,
    this.intituleAncien = '',
    List<String>? mortsAnciens,
    List<String>? blessesAnciens,
  })  : espaces = espaces ?? [],
        paliers = paliers ?? [],
        objets = objets ?? ['', '', ''],
        destinyMinutes = destinyMinutes ?? [],
        destinys = destinys ?? [],
        notes = notes ?? [],
        roles = roles ?? [],
        pnjs = pnjs ?? [],
        registreRessorti = registreRessorti ?? [],
        mortsAnciens = mortsAnciens ?? [],
        blessesAnciens = blessesAnciens ?? [];

  final String id;
  final DateTime date;

  /// Le numéro de la saison (0 : épisode hors saison, un one-shot).
  int saison;

  /// Le numéro de l'épisode dans sa saison (1 à 4).
  int numero;
  EtapeEpisode etape;
  String lieuId;
  String lieuNom;
  String lieuDescription;
  List<String> espaces;
  String groupe;
  String dangerId;
  String dangerNom;

  /// Les quatre phrases du danger, une par palier (en kids, le palier 4 sans
  /// mort).
  List<String> paliers;

  /// En saison : le présage du méchant pour cet épisode (son coup).
  String presage;

  /// Le méchant de l'épisode. En saison, c'est celui de la saison ; hors
  /// saison, il est facultatif (l'ancienne règle de la Campagne).
  String mechantId;
  List<String> objets;
  String mystere;
  String reponseMystere;

  /// 0 : sans chrono, le maître du jeu lance Destiny quand il veut.
  int dureeMinutes;
  List<int> destinyMinutes;
  int palierAtteint;
  List<EvenementDestiny> destinys;
  List<NoteRegie> notes;
  List<RoleEpisode> roles;
  List<PnjEpisode> pnjs;
  Sante mechantSante;
  int mechantMod;

  /// Les entrées du registre que le maître du jeu a choisi de ressortir.
  List<String> registreRessorti;
  bool transcrire;
  String transcription;
  String resume;
  String suite;
  String ceQuiAMarche;
  String phrase;

  /// Par où ils sortent au palier 4 : c'est le lieu de l'épisode suivant.
  String sortie;

  /// Un épisode joué avec l'ancienne Campagne (lecture seule).
  bool ancienneGrammaire;
  String intituleAncien;
  List<String> mortsAnciens;
  List<String> blessesAnciens;

  bool get avecChrono => dureeMinutes > 0;

  /// L'intitulé « lieu · danger » (ou celui de l'ancienne campagne).
  String get intitule {
    if (intituleAncien.isNotEmpty) return intituleAncien;
    return [lieuNom, dangerNom].where((x) => x.isNotEmpty).join(' · ');
  }

  RoleEpisode? role(String personnageId) {
    for (final r in roles) {
      if (r.personnageId == personnageId) return r;
    }
    return null;
  }

  Map<String, dynamic> versJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'saison': saison,
        'numero': numero,
        'etape': etape.name,
        'lieu_id': lieuId,
        'lieu_nom': lieuNom,
        'lieu_description': lieuDescription,
        'espaces': espaces,
        'groupe': groupe,
        'danger_id': dangerId,
        'danger_nom': dangerNom,
        'paliers': paliers,
        'presage': presage,
        'mechant': mechantId,
        'objets': objets,
        'mystere': mystere,
        'reponse_mystere': reponseMystere,
        'duree_minutes': dureeMinutes,
        'destiny_minutes': destinyMinutes,
        'palier_atteint': palierAtteint,
        'destinys': [for (final d in destinys) d.versJson()],
        'notes': [for (final n in notes) n.versJson()],
        'roles': [for (final r in roles) r.versJson()],
        'pnjs': [for (final p in pnjs) p.versJson()],
        'mechant_sante': mechantSante.name,
        'mechant_mod': mechantMod,
        'registre_ressorti': registreRessorti,
        'transcrire': transcrire,
        'transcription': transcription,
        'resume': resume,
        'suite': suite,
        'ce_qui_a_marche': ceQuiAMarche,
        'phrase': phrase,
        'sortie': sortie,
        'ancienne_grammaire': ancienneGrammaire,
        'intitule_ancien': intituleAncien,
        'morts_anciens': mortsAnciens,
        'blesses_anciens': blessesAnciens,
      };

  factory EpisodeSerie.depuisJson(Map<String, dynamic> j) => EpisodeSerie(
        id: _s(j['id']),
        date: DateTime.tryParse(_s(j['date'])) ?? DateTime.fromMillisecondsSinceEpoch(0),
        saison: _i(j['saison']),
        numero: _i(j['numero'], 1),
        etape: EtapeEpisode.depuisTexte(j['etape'] as String?),
        lieuId: _s(j['lieu_id']),
        lieuNom: _s(j['lieu_nom']),
        lieuDescription: _s(j['lieu_description']),
        espaces: _ls(j['espaces']),
        groupe: _s(j['groupe']),
        dangerId: _s(j['danger_id']),
        dangerNom: _s(j['danger_nom']),
        paliers: _ls(j['paliers']),
        presage: _s(j['presage']),
        mechantId: _s(j['mechant']),
        objets: j['objets'] == null ? null : _ls(j['objets']),
        mystere: _s(j['mystere']),
        reponseMystere: _s(j['reponse_mystere']),
        dureeMinutes: _i(j['duree_minutes']),
        destinyMinutes: [for (final x in (j['destiny_minutes'] as List? ?? const [])) (x as num).toInt()],
        palierAtteint: _i(j['palier_atteint'], 1).clamp(1, 4),
        destinys: [for (final d in _ms(j['destinys'])) EvenementDestiny.depuisJson(d)],
        notes: [for (final n in _ms(j['notes'])) NoteRegie.depuisJson(n)],
        roles: [for (final r in _ms(j['roles'])) RoleEpisode.depuisJson(r)],
        pnjs: [for (final p in _ms(j['pnjs'])) PnjEpisode.depuisJson(p)],
        mechantSante: Sante.depuisTexte(j['mechant_sante'] as String?),
        mechantMod: _i(j['mechant_mod']),
        registreRessorti: _ls(j['registre_ressorti']),
        transcrire: _b(j['transcrire']),
        transcription: _s(j['transcription']),
        resume: _s(j['resume']),
        suite: _s(j['suite']),
        ceQuiAMarche: _s(j['ce_qui_a_marche']),
        phrase: _s(j['phrase']),
        sortie: _s(j['sortie']),
        ancienneGrammaire: _b(j['ancienne_grammaire']),
        intituleAncien: _s(j['intitule_ancien']),
        mortsAnciens: _ls(j['morts_anciens']),
        blessesAnciens: _ls(j['blesses_anciens']),
      );
}

/// Le traître d'une saison (module facultatif) : le méchant le recrute en
/// secret avec son offre ; il se révèle à l'épisode 3.
class TraitreSaison {
  TraitreSaison({required this.personnageId, this.accepte, this.revele = false});

  final String personnageId;

  /// null tant que le joueur n'a pas répondu.
  bool? accepte;
  bool revele;

  Map<String, dynamic> versJson() => {'personnage': personnageId, 'accepte': accepte, 'revele': revele};

  factory TraitreSaison.depuisJson(Map<String, dynamic> j) => TraitreSaison(
        personnageId: _s(j['personnage']),
        accepte: j['accepte'] as bool?,
        revele: _b(j['revele']),
      );
}

/// Une saison : quatre épisodes et un méchant dans l'ombre, qui en veut au
/// protagoniste qui a le même archétype que lui. Sa machination tient en
/// quatre présages, un par épisode.
class SaisonSerie {
  SaisonSerie({
    required this.numero,
    required this.mechantId,
    this.cibleId = '',
    List<String>? presages,
    this.presagesValides = false,
    this.traitre,
    this.ceQuIlLaisse = '',
    this.terminee = false,
  }) : presages = presages ?? ['', '', '', ''];

  final int numero;
  String mechantId;

  /// Le personnage visé (son reflet).
  String cibleId;

  /// Les quatre présages : il se signale, il enferme, il envahit, il bloque
  /// les sorties. Proposés par l'IA ou écrits par le maître du jeu, validés
  /// par lui.
  List<String> presages;
  bool presagesValides;
  TraitreSaison? traitre;

  /// Ce que le méchant laisse pour la saison suivante.
  String ceQuIlLaisse;
  bool terminee;

  /// Le présage de l'épisode [numero] (1 à 4).
  String presageDe(int numero) =>
      numero >= 1 && numero <= presages.length ? presages[numero - 1] : '';

  Map<String, dynamic> versJson() => {
        'numero': numero,
        'mechant': mechantId,
        'cible': cibleId,
        'presages': presages,
        'presages_valides': presagesValides,
        if (traitre != null) 'traitre': traitre!.versJson(),
        'ce_qu_il_laisse': ceQuIlLaisse,
        'terminee': terminee,
      };

  factory SaisonSerie.depuisJson(Map<String, dynamic> j) => SaisonSerie(
        numero: _i(j['numero'], 1),
        mechantId: _s(j['mechant']),
        cibleId: _s(j['cible']),
        presages: j['presages'] == null ? null : _ls(j['presages']),
        presagesValides: _b(j['presages_valides']),
        traitre: j['traitre'] is Map ? TraitreSaison.depuisJson(Map<String, dynamic>.from(j['traitre'] as Map)) : null,
        ceQuIlLaisse: _s(j['ce_qu_il_laisse']),
        terminee: _b(j['terminee']),
      );
}

/// Une entrée du registre : la mémoire de la série. Elle ne parle que des
/// personnages, jamais des joueurs.
class EntreeRegistre {
  EntreeRegistre({
    required this.id,
    required this.categorie,
    required this.nom,
    this.detail = '',
    this.statut = StatutRegistre.present,
    List<String>? liens,
    this.saison = 0,
    this.episode = 1,
    this.deLIa = false,
  }) : liens = liens ?? [];

  final String id;
  CategorieRegistre categorie;
  String nom;
  String detail;
  StatutRegistre statut;
  List<String> liens;

  /// Où elle est née.
  final int saison;
  final int episode;

  /// Proposée par l'IA (sinon écrite par le maître du jeu).
  final bool deLIa;

  Map<String, dynamic> versJson() => {
        'id': id,
        'categorie': categorie.name,
        'nom': nom,
        'detail': detail,
        'statut': statut.name,
        'liens': liens,
        'saison': saison,
        'episode': episode,
        'de_l_ia': deLIa,
      };

  factory EntreeRegistre.depuisJson(Map<String, dynamic> j) => EntreeRegistre(
        id: _s(j['id']),
        categorie: CategorieRegistre.depuisTexte(j['categorie'] as String?),
        nom: _s(j['nom']),
        detail: _s(j['detail']),
        statut: StatutRegistre.depuisTexte(j['statut'] as String?),
        liens: _ls(j['liens']),
        saison: _i(j['saison']),
        episode: _i(j['episode'], 1),
        deLIa: _b(j['de_l_ia']),
      );
}

/// Ce qu'est la série, aux yeux du joueur.
enum NatureSerie { episode, saison, serie }

/// Une série : ses personnages, ses saisons, ses épisodes et son registre.
class Serie {
  Serie({
    required this.id,
    required this.creee,
    this.nom = '',
    this.public = PublicSerie.adulte,
    this.univers = '',
    this.ton = '',
    this.lore = '',
    this.contexte = '',
    ReglagesSerie? reglages,
    List<PersonnageSerie>? personnages,
    List<SaisonSerie>? saisons,
    List<EpisodeSerie>? episodes,
    List<EntreeRegistre>? registre,
    this.resume = '',
    this.accroche = '',
    List<String>? pnjSortis,
    this.migreDe = '',
  })  : reglages = reglages ?? ReglagesSerie(),
        personnages = personnages ?? [],
        saisons = saisons ?? [],
        episodes = episodes ?? [],
        registre = registre ?? [],
        pnjSortis = pnjSortis ?? [];

  final String id;
  final DateTime creee;
  String nom;
  PublicSerie public;

  /// L'univers (vide : Destiny, sans univers particulier).
  String univers;
  String ton;
  String lore;

  /// Le contexte écrit par le maître du jeu (il peut partir vers l'IA :
  /// jamais de prénom d'enfant dedans).
  String contexte;
  ReglagesSerie reglages;
  List<PersonnageSerie> personnages;
  List<SaisonSerie> saisons;
  List<EpisodeSerie> episodes;
  List<EntreeRegistre> registre;

  /// Le résumé cumulé et l'accroche (« où on reprend »).
  String resume;
  String accroche;

  /// Les sbires, figurants et méchants qui ont quitté l'histoire : ils ne
  /// reviennent pas.
  List<String> pnjSortis;

  /// `campagne:<id>` quand la série vient d'une ancienne campagne.
  String migreDe;

  bool get kids => public == PublicSerie.kids;

  NatureSerie get nature => switch (saisons.length) {
        0 => NatureSerie.episode,
        1 => NatureSerie.saison,
        _ => NatureSerie.serie,
      };

  SaisonSerie? get saisonEnCours => saisons.isEmpty ? null : saisons.last;

  SaisonSerie? saison(int numero) {
    for (final s in saisons) {
      if (s.numero == numero) return s;
    }
    return null;
  }

  PersonnageSerie? personnage(String id) {
    for (final p in personnages) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Les personnages encore dans l'histoire.
  List<PersonnageSerie> get personnagesActifs => [for (final p in personnages) if (!p.sorti) p];

  /// Les épisodes d'une saison, dans l'ordre.
  List<EpisodeSerie> episodesDe(int saison) =>
      [for (final e in episodes) if (e.saison == saison) e]..sort((a, b) => a.numero.compareTo(b.numero));

  /// L'épisode commencé et pas fini, s'il y en a un.
  EpisodeSerie? get episodeEnCours {
    for (final e in episodes.reversed) {
      if (e.etape != EtapeEpisode.termine) return e;
    }
    return null;
  }

  /// Le dernier épisode terminé.
  EpisodeSerie? get dernierEpisode {
    for (final e in episodes.reversed) {
      if (e.etape == EtapeEpisode.termine) return e;
    }
    return null;
  }

  /// Le numéro du prochain épisode de la saison en cours (null si la saison
  /// est complète ou s'il n'y a pas de saison).
  int? get prochainNumero {
    final s = saisonEnCours;
    if (s == null || s.terminee) return null;
    final faits = episodesDe(s.numero).length;
    return faits >= 4 ? null : faits + 1;
  }

  Map<String, dynamic> versJson() => {
        'version': 2,
        'id': id,
        'creee': creee.toIso8601String(),
        'nom': nom,
        'public': public.name,
        'univers': univers,
        'ton': ton,
        'lore': lore,
        'contexte': contexte,
        'reglages': reglages.versJson(),
        'personnages': [for (final p in personnages) p.versJson()],
        'saisons': [for (final s in saisons) s.versJson()],
        'episodes': [for (final e in episodes) e.versJson()],
        'registre': [for (final r in registre) r.versJson()],
        'resume': resume,
        'accroche': accroche,
        'pnj_sortis': pnjSortis,
        'migre_de': migreDe,
      };

  factory Serie.depuisJson(Map<String, dynamic> j) => Serie(
        id: _s(j['id']),
        creee: DateTime.tryParse(_s(j['creee'])) ?? DateTime.fromMillisecondsSinceEpoch(0),
        nom: _s(j['nom']),
        public: PublicSerie.depuisTexte(j['public'] as String?),
        univers: _s(j['univers']),
        ton: _s(j['ton']),
        lore: _s(j['lore']),
        contexte: _s(j['contexte']),
        reglages: j['reglages'] is Map
            ? ReglagesSerie.depuisJson(Map<String, dynamic>.from(j['reglages'] as Map))
            : null,
        personnages: [for (final p in _ms(j['personnages'])) PersonnageSerie.depuisJson(p)],
        saisons: [for (final s in _ms(j['saisons'])) SaisonSerie.depuisJson(s)],
        episodes: [for (final e in _ms(j['episodes'])) EpisodeSerie.depuisJson(e)],
        registre: [for (final r in _ms(j['registre'])) EntreeRegistre.depuisJson(r)],
        resume: _s(j['resume']),
        accroche: _s(j['accroche']),
        pnjSortis: _ls(j['pnj_sortis']),
        migreDe: _s(j['migre_de']),
      );
}
