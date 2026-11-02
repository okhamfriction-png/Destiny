/// Un spectacle ou une répétition de la troupe : la distribution, la mise en
/// place choisie par le public, ce qui s'est passé pendant la régie, et le
/// débrief.
library;

/// Le choix final de l'acte 4.
enum ChoixFinal {
  aucun,
  vouloir,
  besoin;

  static ChoixFinal depuisTexte(String? s) {
    for (final c in ChoixFinal.values) {
      if (c.name == s) return c;
    }
    return ChoixFinal.aucun;
  }
}

/// Un personnage joué par un comédien de la troupe.
class PersonnageTroupe {
  PersonnageTroupe({
    required this.joueur,
    required this.archetypeId,
    this.animalId = '',
    this.blessure = '',
    this.vouloir = '',
    this.fixeVeut = '',
    this.fixeBesoin = '',
    this.groupeVeut = '',
    this.groupeBesoin = '',
    this.choixFinal = ChoixFinal.aucun,
    this.prixPaye = '',
  });

  String joueur;
  String archetypeId;
  String animalId;
  String blessure;
  String vouloir;

  /// La phrase choisie en silence au premier figé : « il veut… mais il a
  /// besoin de… ».
  String fixeVeut;
  String fixeBesoin;

  /// La même phrase, formulée par le groupe au débrief.
  String groupeVeut;
  String groupeBesoin;
  ChoixFinal choixFinal;
  String prixPaye;

  Map<String, dynamic> versJson() => {
        'joueur': joueur,
        'archetype': archetypeId,
        'animal': animalId,
        'blessure': blessure,
        'vouloir': vouloir,
        'fixe_veut': fixeVeut,
        'fixe_besoin': fixeBesoin,
        'groupe_veut': groupeVeut,
        'groupe_besoin': groupeBesoin,
        'choix_final': choixFinal.name,
        'prix_paye': prixPaye,
      };

  factory PersonnageTroupe.depuisJson(Map<String, dynamic> j) => PersonnageTroupe(
        joueur: j['joueur'] as String? ?? '',
        archetypeId: j['archetype'] as String? ?? '',
        animalId: j['animal'] as String? ?? '',
        blessure: j['blessure'] as String? ?? '',
        vouloir: j['vouloir'] as String? ?? '',
        fixeVeut: j['fixe_veut'] as String? ?? '',
        fixeBesoin: j['fixe_besoin'] as String? ?? '',
        groupeVeut: j['groupe_veut'] as String? ?? '',
        groupeBesoin: j['groupe_besoin'] as String? ?? '',
        choixFinal: ChoixFinal.depuisTexte(j['choix_final'] as String?),
        prixPaye: j['prix_paye'] as String? ?? '',
      );
}

/// Un rituel Destiny passé pendant le spectacle.
class EvenementDestiny {
  const EvenementDestiny({required this.numero, required this.secondes, required this.manuel});

  /// 1, 2 ou 3.
  final int numero;

  /// Moment du rituel, en secondes depuis le début.
  final int secondes;

  /// Lancé à la main par la régie (sinon par le chrono).
  final bool manuel;

  Map<String, dynamic> versJson() => {'numero': numero, 'secondes': secondes, 'manuel': manuel};

  factory EvenementDestiny.depuisJson(Map<String, dynamic> j) => EvenementDestiny(
        numero: (j['numero'] as num?)?.toInt() ?? 0,
        secondes: (j['secondes'] as num?)?.toInt() ?? 0,
        manuel: j['manuel'] as bool? ?? false,
      );
}

/// Un moment fort noté par la régie (« 23:10 : la sœur nomme le besoin du
/// frère »).
class NoteRegie {
  const NoteRegie({required this.secondes, required this.texte});

  final int secondes;
  final String texte;

  String get horodatage {
    final m = secondes ~/ 60;
    final s = secondes % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> versJson() => {'secondes': secondes, 'texte': texte};

  factory NoteRegie.depuisJson(Map<String, dynamic> j) =>
      NoteRegie(secondes: (j['secondes'] as num?)?.toInt() ?? 0, texte: j['texte'] as String? ?? '');
}

/// Spectacle ou répétition.
enum TypeSession { spectacle, repetition }

/// Où en est la session.
enum EtapeSession { preparation, echauffement, miseEnPlace, regie, debrief, terminee }

class SessionTroupe {
  SessionTroupe({
    required this.id,
    required this.date,
    this.type = TypeSession.spectacle,
    this.etape = EtapeSession.preparation,
    List<PersonnageTroupe>? personnages,
    this.lieuId = '',
    this.lieuNom = '',
    this.groupe = '',
    this.dangerId = '',
    this.dangerNom = '',
    List<String>? paliers,
    List<String>? objets,
    this.mystere = '',
    this.reponseMystere = '',
    this.dureeMinutes = 30,
    List<int>? destinyMinutes,
    this.palierAtteint = 1,
    List<EvenementDestiny>? destinys,
    List<NoteRegie>? notes,
    List<String>? ceQuiAMarche,
    this.kids = false,
  })  : personnages = personnages ?? [],
        paliers = paliers ?? [],
        objets = objets ?? ['', '', ''],
        destinyMinutes = destinyMinutes ?? [10, 18, 27],
        destinys = destinys ?? [],
        notes = notes ?? [],
        ceQuiAMarche = ceQuiAMarche ?? [];

  final String id;
  final DateTime date;
  TypeSession type;
  EtapeSession etape;
  List<PersonnageTroupe> personnages;
  String lieuId;
  String lieuNom;
  String groupe;
  String dangerId;
  String dangerNom;

  /// Les quatre paliers du danger, tels que joués.
  List<String> paliers;

  /// Les trois objets donnés au départ.
  List<String> objets;
  String mystere;
  String reponseMystere;
  int dureeMinutes;
  List<int> destinyMinutes;

  /// Palier atteint (1 à 4).
  int palierAtteint;
  List<EvenementDestiny> destinys;
  List<NoteRegie> notes;
  List<String> ceQuiAMarche;
  bool kids;

  Map<String, dynamic> versJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'etape': etape.name,
        'personnages': [for (final p in personnages) p.versJson()],
        'lieu_id': lieuId,
        'lieu': lieuNom,
        'groupe': groupe,
        'danger_id': dangerId,
        'danger': dangerNom,
        'paliers': paliers,
        'objets': objets,
        'mystere': mystere,
        'reponse_mystere': reponseMystere,
        'duree': dureeMinutes,
        'destiny_minutes': destinyMinutes,
        'palier': palierAtteint,
        'destinys': [for (final d in destinys) d.versJson()],
        'notes': [for (final n in notes) n.versJson()],
        'ce_qui_a_marche': ceQuiAMarche,
        'kids': kids,
      };

  factory SessionTroupe.depuisJson(Map<String, dynamic> j) {
    List<String> ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
    List<Map<String, dynamic>> ms(Object? v) =>
        [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    T enumer<T extends Enum>(List<T> valeurs, Object? s, T defaut) {
      for (final v in valeurs) {
        if (v.name == s) return v;
      }
      return defaut;
    }

    return SessionTroupe(
      id: j['id'] as String? ?? '',
      date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
      type: enumer(TypeSession.values, j['type'], TypeSession.spectacle),
      etape: enumer(EtapeSession.values, j['etape'], EtapeSession.preparation),
      personnages: [for (final p in ms(j['personnages'])) PersonnageTroupe.depuisJson(p)],
      lieuId: j['lieu_id'] as String? ?? '',
      lieuNom: j['lieu'] as String? ?? '',
      groupe: j['groupe'] as String? ?? '',
      dangerId: j['danger_id'] as String? ?? '',
      dangerNom: j['danger'] as String? ?? '',
      paliers: ls(j['paliers']),
      objets: ls(j['objets']).length == 3 ? ls(j['objets']) : null,
      mystere: j['mystere'] as String? ?? '',
      reponseMystere: j['reponse_mystere'] as String? ?? '',
      dureeMinutes: (j['duree'] as num?)?.toInt() ?? 30,
      destinyMinutes: [for (final x in (j['destiny_minutes'] as List? ?? const [])) (x as num).toInt()],
      palierAtteint: (j['palier'] as num?)?.toInt() ?? 1,
      destinys: [for (final d in ms(j['destinys'])) EvenementDestiny.depuisJson(d)],
      notes: [for (final n in ms(j['notes'])) NoteRegie.depuisJson(n)],
      ceQuiAMarche: ls(j['ce_qui_a_marche']),
      kids: j['kids'] as bool? ?? false,
    );
  }
}
