/// Les données de Destiny Note : les entrées datées, la prochaine séance, les
/// règles en vigueur, le journal des décisions et les modèles WhatsApp. En
/// Dart pur : l'outil `tool/destiny_notes.dart` s'en sert aussi.
library;

/// Les types d'entrée, dans l'ordre des filtres.
enum TypeNote {
  repetition('repetition', 'Répétition', 'Répétitions'),
  spectacle('spectacle', 'Spectacle', 'Spectacles'),
  seanceMarkJane('seance_mark_jane', 'Séance Mark Jane', 'Séances Mark Jane'),
  decision('decision', 'Décision', 'Décisions'),
  regie('regie', 'Régie', 'Régie'),
  troupe('troupe', 'Troupe', 'Troupe'),
  promo('promo', 'Promo', 'Promo'),
  idee('idee', 'Idée', 'Idées');

  const TypeNote(this.id, this.libelle, this.pluriel);

  final String id;
  final String libelle;
  final String pluriel;

  static TypeNote depuis(String? id) =>
      TypeNote.values.firstWhere((t) => t.id == id, orElse: () => TypeNote.idee);
}

List<String> _liste(Object? x) => [for (final e in (x as List?) ?? const []) '$e'];

/// Une entrée datée (`entries/AAAA-MM-JJ_type_slug.enc`).
class EntreeNote {
  const EntreeNote({
    required this.id,
    required this.date,
    required this.type,
    required this.titre,
    this.resume = '',
    this.contenuMd = '',
    this.whatsapp = '',
    this.tags = const [],
    this.personnes = const [],
    required this.creeLe,
    required this.misAJourLe,
  });

  final String id;

  /// AAAA-MM-JJ.
  final String date;
  final TypeNote type;
  final String titre;

  /// Deux lignes, pour le fil.
  final String resume;

  /// Le compte rendu complet, en markdown, avec les minutages.
  final String contenuMd;

  /// Le texte prêt à coller dans le groupe WhatsApp de la troupe.
  final String whatsapp;
  final List<String> tags;
  final List<String> personnes;
  final String creeLe;
  final String misAJourLe;

  /// Le fichier de l'entrée, dans `notes/`.
  String get fichier => 'entries/$id.enc';

  factory EntreeNote.depuisJson(Map<String, dynamic> j) => EntreeNote(
        id: j['id'] as String,
        date: j['date'] as String? ?? '',
        type: TypeNote.depuis(j['type'] as String?),
        titre: j['titre'] as String? ?? '',
        resume: j['resume'] as String? ?? '',
        contenuMd: j['contenu_md'] as String? ?? '',
        whatsapp: j['whatsapp'] as String? ?? '',
        tags: _liste(j['tags']),
        personnes: _liste(j['personnes']),
        creeLe: j['cree_le'] as String? ?? j['date'] as String? ?? '',
        misAJourLe: j['mis_a_jour_le'] as String? ?? j['cree_le'] as String? ?? '',
      );

  Map<String, Object?> versJson() => {
        'id': id,
        'date': date,
        'type': type.id,
        'titre': titre,
        'resume': resume,
        'contenu_md': contenuMd,
        'whatsapp': whatsapp,
        'tags': tags,
        'personnes': personnes,
        'cree_le': creeLe,
        'mis_a_jour_le': misAJourLe,
      };

  /// La ligne de l'index (`index.enc`).
  ResumeNote get resumeIndex => ResumeNote(
        id: id,
        date: date,
        type: type,
        titre: titre,
        resume: resume,
        tags: tags,
        personnes: personnes,
        fichier: fichier,
        misAJour: misAJourLe,
      );

  /// Corrigée le [jour] : la date de création reste.
  EntreeNote copie({
    String? date,
    TypeNote? type,
    String? titre,
    String? resume,
    String? contenuMd,
    String? whatsapp,
    List<String>? tags,
    List<String>? personnes,
    required String jour,
  }) =>
      EntreeNote(
        id: id,
        date: date ?? this.date,
        type: type ?? this.type,
        titre: titre ?? this.titre,
        resume: resume ?? this.resume,
        contenuMd: contenuMd ?? this.contenuMd,
        whatsapp: whatsapp ?? this.whatsapp,
        tags: tags ?? this.tags,
        personnes: personnes ?? this.personnes,
        creeLe: creeLe,
        misAJourLe: jour,
      );
}

/// Une ligne de l'index : de quoi afficher le fil sans tout déchiffrer.
class ResumeNote {
  const ResumeNote({
    required this.id,
    required this.date,
    required this.type,
    required this.titre,
    this.resume = '',
    this.tags = const [],
    this.personnes = const [],
    required this.fichier,
    this.misAJour = '',
  });

  final String id;
  final String date;
  final TypeNote type;
  final String titre;
  final String resume;
  final List<String> tags;
  final List<String> personnes;
  final String fichier;
  final String misAJour;

  factory ResumeNote.depuisJson(Map<String, dynamic> j) => ResumeNote(
        id: j['id'] as String,
        date: j['date'] as String? ?? '',
        type: TypeNote.depuis(j['type'] as String?),
        titre: j['titre'] as String? ?? '',
        resume: j['resume'] as String? ?? '',
        tags: _liste(j['tags']),
        personnes: _liste(j['personnes']),
        fichier: j['fichier'] as String? ?? 'entries/${j['id']}.enc',
        misAJour: j['mis_a_jour'] as String? ?? '',
      );

  Map<String, Object?> versJson() => {
        'id': id,
        'date': date,
        'type': type.id,
        'titre': titre,
        'resume': resume,
        'tags': tags,
        'personnes': personnes,
        'fichier': fichier,
        'mis_a_jour': misAJour,
      };

  /// La recherche plein texte du fil (titre, résumé, tags, personnes).
  bool correspond(String requete) {
    final q = normaliserRecherche(requete);
    if (q.isEmpty) return true;
    final texte = normaliserRecherche([titre, resume, date, type.libelle, ...tags, ...personnes].join(' '));
    return q.split(' ').where((m) => m.isNotEmpty).every(texte.contains);
  }
}

/// L'index, de la plus récente à la plus ancienne.
List<ResumeNote> trierIndex(Iterable<ResumeNote> index) =>
    [...index]..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.id.compareTo(a.id);
      });

/// Minuscules, sans accents : « Répète » trouve « repete ».
String normaliserRecherche(String s) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ú': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', '’': "'",
  };
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(accents[c] ?? c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Une séance prévue plus tard (le calendrier sous la prochaine séance) :
/// les répétitions avec leur salle, et les spectacles.
class SeanceAVenir {
  const SeanceAVenir({required this.date, this.heure = '', this.lieu = '', this.type = TypeNote.repetition});

  final String date;
  final String heure;
  final String lieu;
  final TypeNote type;

  factory SeanceAVenir.depuisJson(Map<String, dynamic> j) => SeanceAVenir(
        date: j['date'] as String? ?? '',
        heure: j['heure'] as String? ?? '',
        lieu: j['lieu'] as String? ?? '',
        type: TypeNote.depuis(j['type'] as String? ?? 'repetition'),
      );

  Map<String, Object?> versJson() => {'date': date, 'heure': heure, 'lieu': lieu, 'type': type.id};
}

/// La prochaine séance (`prochaine_seance.enc`).
class ProchaineSeance {
  const ProchaineSeance({
    required this.date,
    this.heure = '',
    this.lieu = '',
    this.type = TypeNote.repetition,
    this.objectif = '',
    this.deroule = const [],
    this.distribution = '',
    this.aPreparer = const [],
    this.prochainSpectacle = '',
    this.devise = '',
    this.contenuMd = '',
    this.whatsapp = '',
    this.misAJourLe = '',
    this.suivantes = const [],
  });

  /// AAAA-MM-JJ.
  final String date;

  /// Les séances d'après, dans l'ordre : quand celle-ci est passée, la
  /// première prend sa place.
  final List<SeanceAVenir> suivantes;

  /// « 14 h – 17 h ».
  final String heure;
  final String lieu;

  /// Répétition ou spectacle.
  final TypeNote type;
  final String objectif;

  /// Le déroulé, une étape par ligne (avec son minutage s'il y en a un).
  final List<String> deroule;
  final String distribution;
  final List<String> aPreparer;

  /// « jeudi 3 décembre · Marouene, Gabriel, Elena… ».
  final String prochainSpectacle;
  final String devise;

  /// Le reste (l'ouverture, les lieux de départ…), en markdown.
  final String contenuMd;
  final String whatsapp;
  final String misAJourLe;

  factory ProchaineSeance.depuisJson(Map<String, dynamic> j) => ProchaineSeance(
        date: j['date'] as String? ?? '',
        heure: j['heure'] as String? ?? '',
        lieu: j['lieu'] as String? ?? '',
        type: TypeNote.depuis(j['type'] as String? ?? 'repetition'),
        objectif: j['objectif'] as String? ?? '',
        deroule: _liste(j['deroule']),
        distribution: j['distribution'] as String? ?? '',
        aPreparer: _liste(j['a_preparer']),
        prochainSpectacle: j['prochain_spectacle'] as String? ?? '',
        devise: j['devise'] as String? ?? '',
        contenuMd: j['contenu_md'] as String? ?? '',
        whatsapp: j['whatsapp'] as String? ?? '',
        misAJourLe: j['mis_a_jour_le'] as String? ?? '',
        suivantes: [
          for (final x in (j['suivantes'] as List?) ?? const []) SeanceAVenir.depuisJson(x as Map<String, dynamic>),
        ]..sort((a, b) => a.date.compareTo(b.date)),
      );

  /// Les séances d'après qui ne sont pas encore passées au [jour] (AAAA-MM-JJ).
  List<SeanceAVenir> suivantesApres(String jour) => [for (final x in suivantes) if (x.date.compareTo(jour) >= 0) x];

  Map<String, Object?> versJson() => {
        'date': date,
        'heure': heure,
        'lieu': lieu,
        'type': type.id,
        'objectif': objectif,
        'deroule': deroule,
        'distribution': distribution,
        'a_preparer': aPreparer,
        'prochain_spectacle': prochainSpectacle,
        'devise': devise,
        'contenu_md': contenuMd,
        'whatsapp': whatsapp,
        'mis_a_jour_le': misAJourLe,
        'suivantes': [for (final x in suivantes) x.versJson()],
      };
}

/// Un texte daté en markdown : les règles en vigueur.
class TexteNote {
  const TexteNote({required this.contenuMd, this.misAJourLe = ''});

  final String contenuMd;
  final String misAJourLe;

  factory TexteNote.depuisJson(Map<String, dynamic> j) =>
      TexteNote(contenuMd: j['contenu_md'] as String? ?? '', misAJourLe: j['mis_a_jour_le'] as String? ?? '');

  Map<String, Object?> versJson() => {'contenu_md': contenuMd, 'mis_a_jour_le': misAJourLe};
}

/// Une décision du journal. Remplacée, elle reste, avec la date et ce qui
/// la remplace.
class Decision {
  const Decision({required this.date, required this.titre, this.texte = '', this.remplaceeLe = '', this.remplaceePar = ''});

  final String date;
  final String titre;
  final String texte;
  final String remplaceeLe;
  final String remplaceePar;

  bool get enVigueur => remplaceeLe.isEmpty;

  factory Decision.depuisJson(Map<String, dynamic> j) => Decision(
        date: j['date'] as String? ?? '',
        titre: j['titre'] as String? ?? '',
        texte: j['texte'] as String? ?? '',
        remplaceeLe: j['remplacee_le'] as String? ?? '',
        remplaceePar: j['remplacee_par'] as String? ?? '',
      );

  Map<String, Object?> versJson() => {
        'date': date,
        'titre': titre,
        'texte': texte,
        if (remplaceeLe.isNotEmpty) 'remplacee_le': remplaceeLe,
        if (remplaceePar.isNotEmpty) 'remplacee_par': remplaceePar,
      };
}

/// Le journal des décisions, de la plus ancienne à la plus récente.
class JournalDecisions {
  const JournalDecisions({this.decisions = const [], this.misAJourLe = ''});

  final List<Decision> decisions;
  final String misAJourLe;

  factory JournalDecisions.depuisJson(Map<String, dynamic> j) => JournalDecisions(
        decisions: [
          for (final d in (j['decisions'] as List?) ?? const []) Decision.depuisJson(d as Map<String, dynamic>),
        ]..sort((a, b) => a.date.compareTo(b.date)),
        misAJourLe: j['mis_a_jour_le'] as String? ?? '',
      );

  Map<String, Object?> versJson() => {
        'decisions': [for (final d in decisions) d.versJson()],
        'mis_a_jour_le': misAJourLe,
      };
}

/// Les deux modèles WhatsApp (`modeles.enc`), modifiables dans l'appli.
class ModelesWhatsApp {
  const ModelesWhatsApp({this.compteRendu = modeleCompteRendu, this.prochaineSeance = modeleProchaineSeance});

  final String compteRendu;
  final String prochaineSeance;

  factory ModelesWhatsApp.depuisJson(Map<String, dynamic> j) => ModelesWhatsApp(
        compteRendu: j['compte_rendu'] as String? ?? modeleCompteRendu,
        prochaineSeance: j['prochaine_seance'] as String? ?? modeleProchaineSeance,
      );

  Map<String, Object?> versJson() => {'compte_rendu': compteRendu, 'prochaine_seance': prochaineSeance};
}

const String modeleCompteRendu = '''🎭 *Destiny — {type} du {date}*

Merci à tous pour {occasion} !

*✅ Ce qui a marché*
• {point 1}
• {point 2}
• {point 3}

*🎯 Ce qu'on travaille ensuite*
• {axe 1}
• {axe 2}

*📅 Prochain rendez-vous*
{jour date} · {heure} · {lieu}

{phrase de motivation}
À {jour} ! 🔥''';

const String modeleProchaineSeance = '''🎭 *Destiny — répète du {jour date}*
🕑 {heure} · 📍 {lieu}

*🎯 Objectif*
{objectif en une phrase}

*🗓️ Déroulé*
1️⃣ {étape}
2️⃣ {étape}
3️⃣ {étape}

*🎬 Prochain spectacle*
{date} · {distribution, si elle est annoncée}

{devise}
À {jour} ! 🔥''';

const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

DateTime? _jourIso(String iso) => DateTime.tryParse(iso.length >= 10 ? iso.substring(0, 10) : iso);

/// « dimanche 22 novembre ».
String jourEtDate(String iso) {
  final d = _jourIso(iso);
  return d == null ? iso : '${_jours[d.weekday - 1]} ${d.day == 1 ? '1er' : d.day} ${_mois[d.month - 1]}';
}

/// « dimanche ».
String jourDeLaSemaine(String iso) {
  final d = _jourIso(iso);
  return d == null ? '' : _jours[d.weekday - 1];
}

/// « 19/11 ».
String dateCourte(String iso) {
  final d = _jourIso(iso);
  return d == null ? iso : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Les chiffres-touches des listes numérotées.
const _touches = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];

/// Remplit un modèle WhatsApp.
///
/// - `{nom}` prend la valeur texte de [valeurs] ;
/// - une liste ([listes]) remplace les lignes qui se suivent avec `{nom}` ou
///   `{nom N}` (« • {point 1} », « 2️⃣ {étape} ») : une ligne par élément, en
///   gardant la puce de la première, et la numérotation 1️⃣ 2️⃣ 3️⃣ ;
/// - ce qui n'a pas de valeur reste tel quel (`{occasion}`), à compléter à la
///   main avant de copier.
String remplirModele(String modele, {Map<String, String> valeurs = const {}, Map<String, List<String>> listes = const {}}) {
  final lignes = modele.split('\n');
  final sortie = <String>[];
  var i = 0;
  while (i < lignes.length) {
    final ligne = lignes[i];
    final cle = _cleDeListe(ligne, listes.keys);
    if (cle == null) {
      sortie.add(_remplacer(ligne, valeurs));
      i++;
      continue;
    }
    // Le bloc de lignes de la même liste.
    var fin = i;
    while (fin < lignes.length && _cleDeListe(lignes[fin], listes.keys) == cle) {
      fin++;
    }
    final motif = RegExp('\\{${RegExp.escape(cle)}( \\d+)?\\}');
    final m = motif.firstMatch(ligne)!;
    var prefixe = ligne.substring(0, m.start);
    final suffixe = ligne.substring(m.end);
    final numerote = _touches.any((t) => prefixe.startsWith(t));
    final elements = listes[cle]!;
    for (final (n, e) in elements.indexed) {
      if (numerote) prefixe = '${_touches[n.clamp(0, _touches.length - 1)]} ';
      sortie.add(_remplacer('$prefixe$e$suffixe', valeurs));
    }
    i = fin;
  }
  return sortie.join('\n');
}

String? _cleDeListe(String ligne, Iterable<String> cles) {
  for (final c in cles) {
    if (RegExp('\\{${RegExp.escape(c)}( \\d+)?\\}').hasMatch(ligne)) return c;
  }
  return null;
}

String _remplacer(String ligne, Map<String, String> valeurs) => ligne.replaceAllMapped(
      RegExp(r'\{([^{}]+)\}'),
      (m) {
        final v = valeurs[m.group(1)];
        return v == null || v.isEmpty ? m.group(0)! : v;
      },
    );

/// Le texte WhatsApp de la prochaine séance, tiré du modèle.
String whatsappSeance(ProchaineSeance s, String modele) => remplirModele(
      modele,
      valeurs: {
        'jour date': jourEtDate(s.date),
        'heure': s.heure,
        'lieu': s.lieu,
        'objectif en une phrase': s.objectif,
        'date': s.prochainSpectacle,
        'distribution, si elle est annoncée': s.distribution,
        'devise': s.devise,
        'jour': jourDeLaSemaine(s.date),
      },
      listes: {'étape': s.deroule},
    ).replaceAll(' · {distribution, si elle est annoncée}', '');

/// Le texte WhatsApp d'un compte rendu, tiré du modèle : la date, le type et
/// le prochain rendez-vous (la prochaine séance) ; le reste se complète à la
/// main.
String whatsappCompteRendu(EntreeNote e, String modele, {ProchaineSeance? suivante}) => remplirModele(
      modele,
      valeurs: {
        'type': e.type == TypeNote.repetition ? 'répète' : e.type.libelle.toLowerCase(),
        'date': dateCourte(e.date),
        if (suivante != null) ...{
          'jour date': jourEtDate(suivante.date),
          'heure': suivante.heure,
          'lieu': suivante.lieu,
          'jour': jourDeLaSemaine(suivante.date),
        },
      },
    );

/// L'aperçu WhatsApp : des morceaux de texte, en gras (`*…*`) ou en
/// italique (`_…_`).
class MorceauWhatsApp {
  const MorceauWhatsApp(this.texte, {this.gras = false, this.italique = false});

  final String texte;
  final bool gras;
  final bool italique;
}

List<MorceauWhatsApp> morceauxWhatsApp(String texte) {
  final morceaux = <MorceauWhatsApp>[];
  final motif = RegExp(r'\*([^*\n]+)\*|_([^_\n]+)_');
  var position = 0;
  for (final m in motif.allMatches(texte)) {
    if (m.start > position) morceaux.add(MorceauWhatsApp(texte.substring(position, m.start)));
    if (m.group(1) != null) {
      morceaux.add(MorceauWhatsApp(m.group(1)!, gras: true));
    } else {
      morceaux.add(MorceauWhatsApp(m.group(2)!, italique: true));
    }
    position = m.end;
  }
  if (position < texte.length) morceaux.add(MorceauWhatsApp(texte.substring(position)));
  return morceaux;
}

/// Un identifiant d'entrée : `AAAA-MM-JJ_type_slug`.
String idEntree(String date, TypeNote type, String titre) {
  final slug = normaliserRecherche(titre)
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final court = slug.length > 40 ? slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '') : slug;
  return '${date}_${type.id}_${court.isEmpty ? 'note' : court}';
}
