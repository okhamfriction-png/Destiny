import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/textes.dart';
import '../../domain/serie/pbta.dart';

/// Un bloc du livret.
sealed class BlocLivret {
  const BlocLivret();

  /// Tout le texte du bloc (recherche, tests).
  String get texte;
}

/// Un intertitre à l'intérieur d'une section.
class IntertitreLivret extends BlocLivret {
  const IntertitreLivret(this.texte);
  @override
  final String texte;
}

/// Un paragraphe.
class ParagrapheLivret extends BlocLivret {
  const ParagrapheLivret(this.texte, {this.italique = false});
  @override
  final String texte;
  final bool italique;
}

/// Une liste à puces, ou numérotée.
class PucesLivret extends BlocLivret {
  const PucesLivret(this.items, {this.numerotees = false});
  final List<String> items;
  final bool numerotees;
  @override
  String get texte => items.join('\n');
}

/// Une ligne « libellé : texte ».
class InfoLivret extends BlocLivret {
  const InfoLivret(this.libelle, this.valeur);
  final String libelle;
  final String valeur;
  @override
  String get texte => '$libelle : $valeur';
}

/// Un encadré à retenir.
class EncartLivret extends BlocLivret {
  const EncartLivret(this.texte);
  @override
  final String texte;
}

/// Un tableau : une ligne d'en-têtes, puis les lignes.
class TableauLivret extends BlocLivret {
  const TableauLivret(this.entetes, this.lignes);
  final List<String> entetes;
  final List<List<String>> lignes;
  @override
  String get texte => [entetes.join(' | '), for (final l in lignes) l.join(' | ')].join('\n');
}

/// Une section du livret.
class SectionLivret {
  const SectionLivret(this.id, this.titre, this.blocs);
  final String id;
  final String titre;
  final List<BlocLivret> blocs;
}

/// Le livret de règles : composé une fois, affiché dans la Bibliothèque et
/// exporté en PDF. Chaque règle vient de la grammaire ; les textes
/// `livret.*` ne font que les présenter.
class Livret {
  const Livret({required this.titre, required this.sousTitre, required this.promesse, required this.sections});
  final String titre;
  final String sousTitre;
  final String promesse;
  final List<SectionLivret> sections;
}

/// Les identifiants des sections, dans l'ordre du livret.
const List<String> kSectionsLivret = [
  'but',
  'materiel',
  'roles',
  'mise_en_place',
  'deroule',
  'fin',
  'variantes',
  'regles_d_or',
];

/// « Trouver son vouloir » : la formule, les trois tests, ce qui ne marche
/// pas, pourquoi, la manière que donne le vêtement, et un exemple par animal.
List<BlocLivret> _trouverSonVouloir(Grammaire g, TextesDestiny t, {required bool kids}) {
  String k(String x) => t.t('trouver_vouloir.$x');
  return [
    IntertitreLivret(k('titre')),
    InfoLivret(k('formule_titre'), k(kids ? 'formule_kids' : 'formule')),
    ParagrapheLivret('${k('tests_titre')} :'),
    PucesLivret(t.liste('trouver_vouloir.tests'), numerotees: true),
    InfoLivret(k('ne_marche_pas_titre'), k('ne_marche_pas')),
    InfoLivret(k('pourquoi_titre'), k('pourquoi')),
    EncartLivret(k('vetement')),
    ParagrapheLivret(k('exemples_intro'), italique: true),
    TableauLivret(t.liste('trouver_vouloir.colonnes'), [
      for (final a in g.animaux)
        if (a.exempleVouloirPour(kids: kids).trim().isNotEmpty)
          [g.archetype(a.archetypeId)?.nom ?? '', a.nom, a.exempleVouloirPour(kids: kids)],
    ]),
  ];
}

String _majuscule(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// La composition d'une partie à [c].joueurs joueurs, en clair.
String compositionEnClair(Grammaire g, TextesDestiny t, CompositionDistribution c) => [
      t.t('bibliotheque.regles.alarmiste'),
      for (final f in FamilleId.values)
        if (c.minimumPour(f) > 0) '${c.minimumPour(f)} · ${g.famille(f).nom.toLowerCase()}',
      if (c.auChoix > 0) t.t('bibliotheque.regles.au_choix', {'n': '${c.auChoix}'}),
    ].join(', ');

/// Le jeu de rôle entre humains (la Série), aussi simple que le théâtre : la
/// même conduite (chrono, Destiny, musique, régie), le cœur et le cerveau de
/// chaque personnage, et le compte rendu écrit par l'IA.
List<BlocLivret> _jeuDeRole(TextesDestiny t) {
  String p(String x) => t.t('serie.livret.$x');
  String coeur(String x) => t.t('serie.sante.coeur.$x');
  String esprit(String x) => t.t('serie.sante.esprit.$x');
  return [
    IntertitreLivret(p('titre')),
    ParagrapheLivret(p('principe')),
    IntertitreLivret(p('sante_titre')),
    ParagrapheLivret(p('sante')),
    InfoLivret(
        coeur('titre'),
        [
          for (final x in ['enForme', 'blesse', 'sorti']) coeur(x)
        ].join(' · ')),
    InfoLivret(
        t.t('serie.sante.esprit_titre'),
        [
          for (final x in ['lucide', 'ebranle', 'auBord', 'fou']) esprit(x)
        ].join(' · ')),
    InfoLivret(t.t('serie.creer.kids'), p('kids')),
    IntertitreLivret(p('compte_rendu_titre')),
    ParagrapheLivret(p('compte_rendu')),
  ];
}

/// Compose le livret depuis la grammaire [g] et les textes [t].
/// [kids] : la version pour jouer avec des enfants (la formule du vouloir
/// et les exemples des enfants).
Livret construireLivret(Grammaire g, TextesDestiny t, {bool kids = false}) {
  String k(String x, [Map<String, String> v = const {}]) => t.t('livret.$x', v);
  String sous(String x) => k('sous.$x');
  RegleDOr? regle(String id) => g.regle(id);
  final p = g.personnage;

  final sections = <String, List<BlocLivret>>{
    'but': [
      ParagrapheLivret(k('but')),
      EncartLivret(g.promesse),
    ],
    'materiel': [PucesLivret(t.liste('livret.materiel'))],
    'roles': [PucesLivret(t.liste('livret.roles'))],
    'mise_en_place': [
      IntertitreLivret(sous('lieu_groupe')),
      for (final r in [regle('se_connaitre'), regle('un_lieu'), regle('comediens')])
        if (r != null) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('public')),
      ParagrapheLivret(k('public')),
      IntertitreLivret(sous('liens')),
      ParagrapheLivret(k('liens')),
      IntertitreLivret(sous('danger')),
      ParagrapheLivret(k('danger')),
      PucesLivret([for (final pa in g.paliers) '${pa.nom} · ${pa.ambiance}'], numerotees: true),
      IntertitreLivret(sous('mystere')),
      InfoLivret(t.t('mise_en_place.mystere'), t.t('mise_en_place.mystere_aide')),
      InfoLivret(t.t('mise_en_place.reponse'), t.t('mise_en_place.reponse_aide')),
      IntertitreLivret(sous('distribution')),
      ParagrapheLivret(g.distribution.regle),
      for (final c in g.distribution.compositions)
        InfoLivret(t.t('bibliotheque.regles.joueurs', {'n': '${c.joueurs}'}), compositionEnClair(g, t, c)),
      if (regle('directions') case final r?) ...[
        IntertitreLivret(sous('directions')),
        EncartLivret(r.texte),
      ],
      IntertitreLivret(sous('animaux')),
      ParagrapheLivret(k('animaux')),
      IntertitreLivret(sous('personnage')),
      PucesLivret([for (final c in p.couches) _majuscule(c)]),
      for (final c in p.troisCartes) InfoLivret(c.titre, '${c.sousTitre} ${c.texte}'),
      if (p.vouloirTests.isNotEmpty) PucesLivret(p.vouloirTests, numerotees: true),
      if (p.vouloirMethode.isNotEmpty) ParagrapheLivret(p.vouloirMethode),
      EncartLivret(p.piege),
      ..._trouverSonVouloir(g, t, kids: kids),
      IntertitreLivret(sous('echauffement')),
      ParagrapheLivret('${_majuscule(p.echauffement.quand)}.'),
      PucesLivret(p.echauffement.questions, numerotees: true),
      ParagrapheLivret(p.echauffement.limite, italique: true),
    ],
    'deroule': [
      IntertitreLivret(sous('actes')),
      for (final a in g.actes) ...[
        InfoLivret(
          '${t.t('rituel.acte', {'numero': '${a.numero}'})} · ${g.palier(a.palier).nom}',
          a.ambiance,
        ),
        PucesLivret(a.consignes),
      ],
      IntertitreLivret(sous('rituel')),
      ParagrapheLivret('${_majuscule(g.rituel.quand)} · ${g.rituel.quiDeclenche}.'),
      PucesLivret([for (final s in g.rituel.sequence) _majuscule(s)], numerotees: true),
      if (g.rituel.pendantDestiny.isNotEmpty) ParagrapheLivret(g.rituel.pendantDestiny),
      if (g.rituel.questions.isNotEmpty) ...[
        ParagrapheLivret(g.rituel.questionsIntro),
        PucesLivret([
          for (final e in g.rituel.questions.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            '${t.t('rituel.avant_acte', {'n': '${e.key}'})} : ${e.value}',
        ]),
      ],
      if (g.rituel.suite.isNotEmpty) ...[
        ParagrapheLivret(k('rituel_suite')),
        PucesLivret([for (final s in g.rituel.suite) _majuscule(s)], numerotees: true),
      ],
      if (g.rituel.musiqueMax.isNotEmpty) ParagrapheLivret(g.rituel.musiqueMax),
      if (g.rituel.musiqueDescend.isNotEmpty) ParagrapheLivret(g.rituel.musiqueDescend),
      ParagrapheLivret(g.rituel.reprise),
      if (g.rituel.acte1.isNotEmpty) EncartLivret(g.rituel.acte1),
      EncartLivret(g.rituel.premierFige),
      IntertitreLivret(sous('alarmiste')),
      if (regle('danger_regie') case final r?) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('progression')),
      if (regle('progression') case final r?) ParagrapheLivret(r.texte),
      if (p.planterPourPayer.isNotEmpty) EncartLivret(p.planterPourPayer),
      IntertitreLivret(sous('montee')),
      for (final pa in g.paliers) InfoLivret(pa.nom, _majuscule(pa.etatArchetype)),
      IntertitreLivret(sous('gestes')),
      for (final ge in p.acteParActe) InfoLivret('${ge.moment} · ${ge.verbe}', ge.consigne),
    ],
    'fin': [
      IntertitreLivret(sous('acte_4')),
      if (g.actes.isNotEmpty) PucesLivret(g.actes.last.consignes),
      if (regle('dernier_acte') case final r?) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('prix')),
      if (p.troisCartes.length > 2) ParagrapheLivret('${p.troisCartes[2].sousTitre} ${p.troisCartes[2].texte}'),
      IntertitreLivret(sous('debrief')),
      ParagrapheLivret(k('debrief')),
      EncartLivret(p.phraseCle),
      ParagrapheLivret(p.detecterPasJouer, italique: true),
    ],
    'variantes': [
      IntertitreLivret(sous('a_456')),
      for (final c in g.distribution.compositions)
        InfoLivret(t.t('bibliotheque.regles.joueurs', {'n': '${c.joueurs}'}), compositionEnClair(g, t, c)),
      if (g.distribution.aSix.isNotEmpty) ParagrapheLivret(g.distribution.aSix),
      IntertitreLivret(sous('serie')),
      InfoLivret(t.t('serie.natures.episode'), g.serie.episode),
      InfoLivret(t.t('serie.natures.saison'), g.serie.saison),
      InfoLivret(t.t('serie.natures.serie'), g.serie.serie),
      ..._jeuDeRole(t),
      IntertitreLivret(sous('mechants')),
      PucesLivret(g.serie.reglesDuMechant),
      IntertitreLivret(sous('sbires')),
      ParagrapheLivret(g.figurants.modes[ModePnj.sbire] ?? ''),
      IntertitreLivret(sous('figurants')),
      if (g.figurants.spectacle.isNotEmpty) ParagrapheLivret(g.figurants.spectacle),
      ParagrapheLivret(g.figurants.modes[ModePnj.figurant] ?? ''),
      for (final ty in g.figurants.types) InfoLivret(ty.nom, '${ty.ceQuIlEst} ${ty.commentLeJouer}'),
      for (final r in g.figurants.regles) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('registre')),
      ParagrapheLivret(g.serie.registre.principe),
      PucesLivret([for (final c in g.serie.registre.categories) _majuscule(c)]),
      ParagrapheLivret(g.serie.registre.suggestion),
      IntertitreLivret(sous('kids')),
      ParagrapheLivret(g.modeKids.principe),
      for (final r in g.modeKids.regles) InfoLivret(r.titre, r.texte),
      ParagrapheLivret(t.t('mode_enfant.explication')),
      InfoLivret(
        k('mots_doux'),
        [
          for (final e in t.table('mode_enfant.mots').entries) '${t.t('livret.mots.${e.key}')} : ${e.value}',
        ].join(' · '),
      ),
    ],
    'regles_d_or': [for (final r in g.reglesDOr) InfoLivret(r.titre, r.texte)],
  };

  return Livret(
    titre: k('titre'),
    sousTitre: k('sous_titre'),
    promesse: g.promesse,
    sections: [
      for (final id in kSectionsLivret)
        SectionLivret(id, k('sections.$id'), [
          for (final b in sections[id] ?? const <BlocLivret>[])
            if (b.texte.trim().isNotEmpty && !(b is InfoLivret && b.valeur.trim().isEmpty)) b,
        ]),
    ],
  );
}
