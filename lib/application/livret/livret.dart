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

String _majuscule(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// La composition d'une partie à [c].joueurs joueurs, en clair.
String compositionEnClair(Grammaire g, TextesDestiny t, CompositionDistribution c) => [
      t.t('bibliotheque.regles.alarmiste'),
      for (final f in FamilleId.values)
        if (c.minimumPour(f) > 0) '${c.minimumPour(f)} · ${g.famille(f).nom.toLowerCase()}',
      if (c.auChoix > 0) t.t('bibliotheque.regles.au_choix', {'n': '${c.auChoix}'}),
    ].join(', ');

/// Les codes du jeu de rôle entre humains (la Série) : la pièce du destin
/// BRAVE / SMART, le bonus et le second lancer, les mouvements des joueurs,
/// l'agenda, les principes et les mouvements du Maître du destin, les
/// horloges et les blessures. Tout vient de la section `pbta` des textes.
List<BlocLivret> _jeuDeRole(TextesDestiny t) {
  String p(String x) => t.t('pbta.$x');
  final r = ReglesPbta.depuis(t);
  return [
    IntertitreLivret(p('piece.titre')),
    ParagrapheLivret(p('intro')),
    ParagrapheLivret(p('piece.principe')),
    for (final f in FacePiece.values) InfoLivret(p('piece.faces.${f.name}.nom'), p('piece.faces.${f.name}.approche')),
    ParagrapheLivret(p('piece.quand')),
    InfoLivret(p('piece.succes'), p('piece.succes_texte')),
    InfoLivret(p('piece.echec'), p('piece.echec_texte')),
    PucesLivret([p('piece.doux'), p('piece.dur')]),
    IntertitreLivret(p('bonus.titre')),
    ParagrapheLivret(p('bonus.principe')),
    ParagrapheLivret(p('bonus.choisir')),
    ParagrapheLivret(p('bonus.seconde_chance')),
    ParagrapheLivret(p('bonus.gene')),
    IntertitreLivret(p('mouvements_titre')),
    for (final m in r.mouvements)
      InfoLivret(
        m.nom,
        [
          m.quand,
          m.approche,
          if (m.avecPiece) ...['${p('piece.succes')} : ${m.reussite}', '${p('piece.echec')} : ${m.echec}'] else m.effet,
        ].where((x) => x.isNotEmpty).join(' '),
      ),
    IntertitreLivret(p('agenda_titre')),
    PucesLivret(r.agenda, numerotees: true),
    IntertitreLivret(p('principes_titre')),
    PucesLivret(r.principes),
    IntertitreLivret(p('mouvements_mj.titre')),
    ParagrapheLivret(p('mouvements_mj.principe')),
    ParagrapheLivret(p('mouvements_mj.regle'), italique: true),
    InfoLivret(p('mouvements_mj.doux_titre'), [for (final m in r.mouvementsMjDe(GraviteMouvement.doux)) m.nom].join(' · ')),
    InfoLivret(p('mouvements_mj.durs_titre'), [for (final m in r.mouvementsMjDe(GraviteMouvement.dur)) m.nom].join(' · ')),
    for (final m in r.mouvementsMj) InfoLivret(m.nom, m.texte),
    EncartLivret(p('mouvements_mj.que_fais_tu')),
    IntertitreLivret(p('horloges.titre')),
    PucesLivret([p('horloges.episode'), p('horloges.saison')]),
    IntertitreLivret(p('blessures.titre')),
    ParagrapheLivret(p('blessures.principe')),
    InfoLivret(t.t('serie.creer.adulte'), r.blessures(kids: false).join(' · ')),
    InfoLivret(t.t('serie.creer.kids'), r.blessures(kids: true).join(' · ')),
    ParagrapheLivret(p('blessures.hors_jeu')),
    ParagrapheLivret(p('blessures.hors_jeu_kids')),
  ];
}

/// Compose le livret depuis la grammaire [g] et les textes [t].
Livret construireLivret(Grammaire g, TextesDestiny t) {
  String k(String x, [Map<String, String> v = const {}]) => t.t('livret.$x', v);
  String sous(String x) => k('sous.$x');
  RegleDOr? regle(int i) => i < g.reglesDOr.length ? g.reglesDOr[i] : null;
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
      for (final r in [regle(0), regle(1)])
        if (r != null) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('liens')),
      ParagrapheLivret(k('liens')),
      IntertitreLivret(sous('danger')),
      ParagrapheLivret(k('danger')),
      PucesLivret([for (final pa in g.paliers) '${pa.nom} · ${pa.ambiance}'], numerotees: true),
      IntertitreLivret(sous('objets')),
      InfoLivret(t.t('mise_en_place.objets'), t.t('mise_en_place.objets_aide')),
      InfoLivret(t.t('mise_en_place.mystere'), t.t('mise_en_place.mystere_aide')),
      InfoLivret(t.t('mise_en_place.reponse'), t.t('mise_en_place.reponse_aide')),
      IntertitreLivret(sous('distribution')),
      ParagrapheLivret(g.distribution.regle),
      for (final c in g.distribution.compositions)
        InfoLivret(t.t('bibliotheque.regles.joueurs', {'n': '${c.joueurs}'}), compositionEnClair(g, t, c)),
      IntertitreLivret(sous('animaux')),
      ParagrapheLivret(k('animaux')),
      IntertitreLivret(sous('personnage')),
      PucesLivret([for (final c in p.couches) _majuscule(c)]),
      for (final c in p.troisCartes) InfoLivret(c.titre, '${c.sousTitre} ${c.texte}'),
      EncartLivret(p.piege),
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
      ParagrapheLivret(g.rituel.reprise),
      EncartLivret(g.rituel.premierFige),
      IntertitreLivret(sous('alarmiste')),
      if (regle(3) case final r?) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('montee')),
      for (final pa in g.paliers) InfoLivret(pa.nom, _majuscule(pa.etatArchetype)),
      IntertitreLivret(sous('gestes')),
      for (final ge in p.acteParActe) InfoLivret('${ge.moment} · ${ge.verbe}', ge.consigne),
    ],
    'fin': [
      IntertitreLivret(sous('acte_4')),
      if (g.actes.isNotEmpty) PucesLivret(g.actes.last.consignes),
      if (regle(6) case final r?) InfoLivret(r.titre, r.texte),
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
      ParagrapheLivret(g.figurants.modes[ModePnj.figurant] ?? ''),
      for (final ty in g.figurants.types) InfoLivret(ty.nom, '${ty.ceQuIlEst} ${ty.commentLeJouer}'),
      for (final r in g.figurants.regles) InfoLivret(r.titre, r.texte),
      IntertitreLivret(sous('registre')),
      ParagrapheLivret(g.serie.registre.principe),
      PucesLivret([for (final c in g.serie.registre.categories) _majuscule(c)]),
      ParagrapheLivret(g.serie.registre.suggestion),
      IntertitreLivret(sous('traitre')),
      ParagrapheLivret(t.t('module_traitre.explication')),
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
