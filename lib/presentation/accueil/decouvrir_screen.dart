import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// « Découvrir Destiny » : quatre écrans pour comprendre le format en deux
/// minutes, tous tirés de la grammaire. La promesse ; le lieu et le groupe ;
/// le danger en quatre paliers et le rituel Destiny ; les personnages
/// (archétype, animal, vouloir, besoin). Montré au premier lancement, et à
/// revoir depuis la Bibliothèque ou les Réglages.
class DecouvrirScreen extends StatefulWidget {
  const DecouvrirScreen({super.key, this.quandFini});

  /// Appelé quand on termine ou qu'on passe.
  final VoidCallback? quandFini;

  @override
  State<DecouvrirScreen> createState() => _DecouvrirScreenState();
}

class _DecouvrirScreenState extends State<DecouvrirScreen> {
  final PageController _pages = PageController();
  int _courant = 0;
  static const _nombre = 4;

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
                child: Text(k('titre').toUpperCase(),
                    style: TextStyle(
                        fontFamily: kPoliceTexte,
                        fontSize: 11.5,
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
              children: const [_EcranPromesse(), _EcranLieu(), _EcranDanger(), _EcranPersonnages()],
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
            style: TextStyle(fontFamily: kPoliceTitres, fontSize: 16, fontWeight: FontWeight.w700, color: c.texte)),
        const SizedBox(height: 4),
        Text(regle.texte,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texte)),
      ]),
    );
  }
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

class _EcranLieu extends StatelessWidget {
  const _EcranLieu();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    return _Ecran(titre: t.t('decouvrir.ecrans.lieu.titre'), enfants: [
      for (final r in g.reglesDOr.take(2)) _Regle(r),
    ]);
  }
}

class _EcranDanger extends StatelessWidget {
  const _EcranDanger();

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final alarmiste = g.reglesDOr.length > 3 ? g.reglesDOr[3] : null;
    return _Ecran(titre: t.t('decouvrir.ecrans.danger.titre'), enfants: [
      FrisePaliers(textes: [for (final p in g.paliers) p.ambiance], compacte: true),
      const SizedBox(height: 14),
      Text(t.t('decouvrir.ecrans.danger.rituel'),
          style: TextStyle(fontFamily: kPoliceTitres, fontSize: 17, fontWeight: FontWeight.w700, color: c.bleuTexte)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in g.rituel.sequence)
          Chip(
            label: Text(s),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: c.bleuDestiny.withValues(alpha: 0.6)),
          ),
      ]),
      const SizedBox(height: 10),
      if (alarmiste != null) _Regle(alarmiste, couleur: c.bleuDestiny),
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
                style: TextStyle(fontFamily: kPoliceTitres, fontSize: 16, fontWeight: FontWeight.w700, color: c.texte)),
            Text(carte.sousTitre,
                style: TextStyle(
                    fontFamily: kPoliceTexte, fontSize: 13, fontStyle: FontStyle.italic, color: c.texteSecondaire)),
            const SizedBox(height: 4),
            Text(carte.texte, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: c.texte)),
          ]),
        ),
    ]);
  }
}
