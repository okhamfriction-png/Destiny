import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/serie.dart' show Esprit, Sante;
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../serie/sante_serie.dart';
import '../theme/destiny_theme.dart';

/// « Découvrir Destiny » : le tuto du début, simple, sur la Troupe seulement.
/// Cinq écrans : la promesse, Préparer, le jeu, la régie, les personnages.
/// Montré au premier lancement (et une fois après la 2.3.0, qui l'a refait),
/// à revoir depuis la Bibliothèque ou les Réglages. Le jeu de rôle a son
/// propre tuto ([TutoJeuDeRoleScreen]), à sa première visite.
class DecouvrirScreen extends StatelessWidget {
  const DecouvrirScreen({super.key, this.quandFini});

  /// Appelé quand on termine ou qu'on passe.
  final VoidCallback? quandFini;

  @override
  Widget build(BuildContext context) => _Visite(
        titre: context.textes.t('decouvrir.titre'),
        quandFini: quandFini,
        ecrans: const [_EcranPromesse(), _EcranPreparer(), _EcranJeu(), _EcranRegie(), _EcranPersonnages()],
      );
}

/// Le tuto du jeu de rôle : un épisode comme un spectacle, le cœur et le
/// cerveau, le grand méchant, le compte rendu de l'IA. Montré à la première
/// visite du jeu de rôle, et à revoir depuis son bouton d'aide.
class TutoJeuDeRoleScreen extends StatelessWidget {
  const TutoJeuDeRoleScreen({super.key, this.kids = false, this.quandFini});

  final bool kids;
  final VoidCallback? quandFini;

  @override
  Widget build(BuildContext context) => _Visite(
        titre: context.textes.t('tuto_jdr.titre'),
        quandFini: quandFini,
        ecrans: [
          const _EcranEtapes(cle: 'tuto_jdr.ecrans.episode'),
          _EcranSante(kids: kids),
          const _EcranEtapes(cle: 'tuto_jdr.ecrans.mechant'),
          const _EcranEtapes(cle: 'tuto_jdr.ecrans.compte_rendu'),
        ],
      );
}

/// Une suite d'écrans à faire défiler, avec « Passer », les points et
/// « Suivant » / « C'est parti ».
class _Visite extends StatefulWidget {
  const _Visite({required this.titre, required this.ecrans, this.quandFini});

  final String titre;
  final List<Widget> ecrans;
  final VoidCallback? quandFini;

  @override
  State<_Visite> createState() => _VisiteState();
}

class _VisiteState extends State<_Visite> {
  final PageController _pages = PageController();
  int _courant = 0;

  int get _nombre => widget.ecrans.length;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finir() {
    widget.quandFini?.call();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _suivant() {
    if (_courant >= _nombre - 1) {
      _finir();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('decouvrir.$x', v);
    final dernier = _courant == _nombre - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
            child: Row(children: [
              Expanded(
                child: Text(widget.titre.toUpperCase(),
                    style: TextStyle(
                        fontFamily: kPoliceTexte,
                        fontSize: 12.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: c.texteSecondaire)),
              ),
              if (!dernier) TextButton(onPressed: _finir, child: Text(k('passer'))),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _courant = i),
              children: widget.ecrans,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(children: [
              Semantics(
                label: k('ecran', {'n': '${_courant + 1}', 'total': '$_nombre'}),
                child: Row(children: [
                  for (var i = 0; i < _nombre; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _courant ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _courant ? c.titre : c.filet,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _suivant,
                    child: Text(dernier ? k('commencer') : k('suivant'), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// La mise en page commune : un titre, puis le contenu, défilant si l'écran
/// est petit.
class _Ecran extends StatelessWidget {
  const _Ecran({required this.titre, required this.enfants});

  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return LayoutBuilder(
      builder: (context, contraintes) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: contraintes.maxHeight - 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (titre.isNotEmpty) ...[
                    Text(titre,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: kPoliceTitres, fontSize: 24, fontWeight: FontWeight.w900, color: c.titre)),
                    const SizedBox(height: 18),
                  ],
                  ...enfants,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une règle en carte : titre, puis texte.
class _Regle extends StatelessWidget {
  const _Regle(this.regle, {this.couleur});

  final RegleDOr regle;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return CadreLisere(
      couleur: couleur ?? c.or,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(regle.titre,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, fontWeight: FontWeight.w700, color: c.texte)),
        const SizedBox(height: 4),
        Text(regle.texte,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texte)),
      ]),
    );
  }
}

/// Les icônes des étapes, par nom (dans le fichier de textes).
const Map<String, IconData> _icones = {
  'lieu': Icons.place_rounded,
  'archetypes': Icons.style_rounded,
  'chrono': Icons.timer_outlined,
  'echauffement': Icons.self_improvement_rounded,
  'spectacle': Icons.theater_comedy_rounded,
  'regie': Icons.tune_rounded,
  'destiny': Icons.flash_on_rounded,
  'terminer': Icons.flag_rounded,
  'preparer': Icons.style_rounded,
  'jeu': Icons.theater_comedy_rounded,
  'ombre': Icons.visibility_off_rounded,
  'personne': Icons.visibility_rounded,
  'figurants': Icons.groups_rounded,
  'micro': Icons.mic_rounded,
  'ia': Icons.auto_awesome,
  'suite': Icons.video_library_outlined,
};

/// Les étapes d'un écran (« etapes » dans le fichier de textes) : une icône,
/// un titre et une phrase chacune.
class _Etapes extends StatelessWidget {
  const _Etapes(this.cle);

  final String cle;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in t.tables('$cle.etapes'))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.teinte(c.or)),
              child: Icon(_icones['${e['icone']}'] ?? Icons.circle_outlined, size: 20, color: c.titre),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e['titre']}',
                    style:
                        TextStyle(fontFamily: kPoliceTexte, fontSize: 16, fontWeight: FontWeight.w700, color: c.texte)),
                const SizedBox(height: 2),
                Text('${e['texte']}',
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texte)),
              ]),
            ),
          ]),
        ),
    ]);
  }
}

/// Un écran fait d'un titre et d'étapes, tout depuis le fichier de textes.
class _EcranEtapes extends StatelessWidget {
  const _EcranEtapes({required this.cle});

  final String cle;

  @override
  Widget build(BuildContext context) => _Ecran(titre: context.textes.t('$cle.titre'), enfants: [_Etapes(cle)]);
}

/// Des puces pour une séquence (le rituel, puis la régie son).
class _Sequence extends StatelessWidget {
  const _Sequence(this.elements, this.couleur);

  final List<String> elements;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in elements)
          Chip(
            label: Text(s),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: couleur.withValues(alpha: 0.6)),
          ),
      ]);
}

class _EcranPromesse extends StatelessWidget {
  const _EcranPromesse();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    return _Ecran(titre: '', enfants: [
      BandeauAffiche(titre: g.nom.toUpperCase(), sousTitre: g.promesse),
      const SizedBox(height: 24),
      Text(t.t('decouvrir.ecrans.promesse.titre'),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kPoliceTitres, fontSize: 20, fontWeight: FontWeight.w700, color: c.texte)),
      const SizedBox(height: 10),
      Text(t.t('decouvrir.ecrans.promesse.texte'),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, height: 1.45, color: c.texte)),
    ]);
  }
}

class _EcranPreparer extends StatelessWidget {
  const _EcranPreparer();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    return _Ecran(titre: context.textes.t('decouvrir.ecrans.preparer.titre'), enfants: [
      const _Etapes('decouvrir.ecrans.preparer'),
      if (g.regle('comediens') case final r?) _Regle(r),
    ]);
  }
}

class _EcranJeu extends StatelessWidget {
  const _EcranJeu();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    return _Ecran(titre: t.t('decouvrir.ecrans.jeu.titre'), enfants: [
      const _Etapes('decouvrir.ecrans.jeu'),
      FrisePaliers(textes: [for (final p in g.paliers) p.ambiance], compacte: true),
      const SizedBox(height: 14),
      Text(t.t('decouvrir.ecrans.jeu.rituel'),
          style: TextStyle(fontFamily: kPoliceTexte, fontSize: 17, fontWeight: FontWeight.w700, color: c.bleuTexte)),
      const SizedBox(height: 6),
      _Sequence(g.rituel.sequence, c.bleuDestiny),
      if (g.rituel.suite.isNotEmpty) ...[
        const SizedBox(height: 6),
        _Sequence(g.rituel.suite, c.or),
      ],
    ]);
  }
}

class _EcranRegie extends StatelessWidget {
  const _EcranRegie();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    return _Ecran(titre: context.textes.t('decouvrir.ecrans.regie.titre'), enfants: [
      const _Etapes('decouvrir.ecrans.regie'),
      // Le danger vient de la régie : musiques et bruitages, au signal du
      // metteur en scène.
      if (g.regle('danger_regie') case final r?) _Regle(r, couleur: c.bleuDestiny),
    ]);
  }
}

class _EcranPersonnages extends StatelessWidget {
  const _EcranPersonnages();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final cartes = g.personnage.troisCartes;
    return _Ecran(titre: t.t('decouvrir.ecrans.personnages.titre'), enfants: [
      Paragraphe(t.t('decouvrir.ecrans.personnages.texte')),
      for (final f in g.familles)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PuceFamille(f.id, compacte: true),
            const SizedBox(height: 4),
            Text(f.idee, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.35, color: c.texte)),
          ]),
        ),
      const SizedBox(height: 8),
      for (final carte in cartes.take(2))
        CadreLisere(
          couleur: c.or,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(carte.titre,
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, fontWeight: FontWeight.w700, color: c.texte)),
            Text(carte.sousTitre,
                style: TextStyle(
                    fontFamily: kPoliceTexte, fontSize: 14, fontStyle: FontStyle.italic, color: c.texteSecondaire)),
            const SizedBox(height: 4),
            Text(carte.texte, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: c.texte)),
          ]),
        ),
      if (g.regle('directions') case final r?) _Regle(r),
    ]);
  }
}

/// Le cœur et le cerveau, en vrai : les deux pistes d'un personnage, qu'on
/// peut toucher pour essayer.
class _EcranSante extends StatefulWidget {
  const _EcranSante({required this.kids});

  final bool kids;

  @override
  State<_EcranSante> createState() => _EcranSanteState();
}

class _EcranSanteState extends State<_EcranSante> {
  Sante _sante = Sante.blesse;
  Esprit _esprit = Esprit.ebranle;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    return _Ecran(titre: t.t('tuto_jdr.ecrans.sante.titre'), enfants: [
      Paragraphe(t.t('tuto_jdr.ecrans.sante.texte')),
      const SizedBox(height: 6),
      CadreLisere(
        couleur: c.or,
        child: PistesSante(
          cle: 'tuto',
          sante: _sante,
          esprit: _esprit,
          kids: widget.kids,
          onSante: (v) => setState(() => _sante = v),
          onEsprit: (v) => setState(() => _esprit = v),
        ),
      ),
      Paragraphe(t.t(widget.kids ? 'tuto_jdr.ecrans.sante.kids' : 'tuto_jdr.ecrans.sante.essayer'), italique: true),
    ]);
  }
}
