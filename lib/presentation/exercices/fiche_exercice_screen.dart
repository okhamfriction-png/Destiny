import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../domain/entities/exercice.dart';
import '../../domain/grammaire/modeles.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'chrono_exercice_screen.dart';

/// La notion de la Bibliothèque que travaille chaque exercice de la grammaire
/// (clé d'entrée de `bibliotheque.entrees`). Un exercice absent prend la
/// notion de son thème.
const Map<String, String> kNotionsExercices = {
  'plans_de_genre': 'oeuvres',
  'trois_phrases': 'vouloir_besoin',
  'tout_va_bien': 'vouloir_besoin',
  'crow_30_secondes': 'vouloir_besoin',
  'tout_le_monde_se_connait': 'lieux',
  'vouloir_en_deux_minutes': 'vouloir_besoin',
  'relais_a_quatre': 'lieux',
  'installer_le_lieu': 'lieux',
  'mains_occupees': 'lieux',
  'lieu_quatre_paliers': 'dangers',
  'deuxieme_lieu': 'lieux',
  'archetypes_du_desastre': 'archetypes',
  'sideration': 'archetypes',
  'echauffement_archetype': 'archetypes',
  'phrase_de_blessure': 'vouloir_besoin',
  'fige_du_besoin': 'regles',
  'appuyer_ou_ca_fait_mal': 'regles',
  'choix_seul': 'regles',
  'long_form_labo': 'regles',
  'scene_1_en_duo': 'vouloir_besoin',
  'test_du_mobil_home': 'vouloir_besoin',
};

const Map<String, String> _notionsParTheme = {'crow': 'vouloir_besoin', 'lieu': 'lieux', 'destiny': 'regles'};

/// La clé de la Bibliothèque où revoir la notion de [e].
String notionExercice(ExerciceGrammaire e) => kNotionsExercices[e.id] ?? _notionsParTheme[e.themeId] ?? 'regles';

/// Icône d'un thème d'exercices de la grammaire.
IconData iconeThemeExercice(String themeId) => switch (themeId) {
      'crow' => Icons.people_alt_outlined,
      'lieu' => Icons.place_outlined,
      _ => Icons.flash_on_rounded,
    };

/// Couleur d'un thème d'exercices de la grammaire : l'or, et le bleu Destiny
/// pour le thème Destiny (tout ce qui touche au rituel).
Color couleurThemeExercice(BuildContext context, String themeId) {
  final c = context.destiny;
  return themeId == 'destiny' ? c.bleuDestiny : c.titre;
}

/// Vrai si l'exercice vient d'une séance avec Mark Jane.
bool avecMarkJane(BuildContext context, ExerciceGrammaire e) =>
    e.source.contains(context.textes.t('exercices.mark_jane'));

/// Le badge « Avec Mark Jane ».
class BadgeMarkJane extends StatelessWidget {
  const BadgeMarkJane({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.or.withValues(alpha: c.sombre ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.or),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, size: 13, color: c.titre),
        const SizedBox(width: 4),
        Text(
          context.textes.t('exercices.badge_mark_jane'),
          style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.texte),
        ),
      ]),
    );
  }
}

/// Une petite étiquette « icône + texte » (durée, joueurs).
class EtiquetteExercice extends StatelessWidget {
  const EtiquetteExercice({super.key, required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icone, size: 14, color: c.texteSecondaire),
      const SizedBox(width: 4),
      Flexible(
        child: Text(texte,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
      ),
    ]);
  }
}

/// La fiche d'un exercice de la grammaire : le but, les consignes, les
/// exemples, les cartes à tirer, la question du débrief, la variante, le
/// chrono, et le lien vers la notion dans la Bibliothèque.
class FicheExerciceScreen extends StatelessWidget {
  const FicheExerciceScreen({
    super.key,
    required this.exercice,
    required this.audio,
    this.theme,
    this.bibliotheque,
  });

  final ExerciceGrammaire exercice;
  final ThemeExercice? theme;
  final AudioService audio;
  final ContexteBibliotheque? bibliotheque;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final e = exercice;
    final couleur = couleurThemeExercice(context, e.themeId);
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.$x', v);
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    return PageDestiny(
      titre: theme?.nom ?? e.titre,
      enfants: [
        BandeauAffiche(surtitre: theme?.nom, titre: e.titre, sousTitre: e.notion),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          EtiquetteExercice(icone: Icons.timer_outlined, texte: e.duree),
          EtiquetteExercice(icone: Icons.groups_outlined, texte: e.joueurs),
          if (avecMarkJane(context, e)) const BadgeMarkJane(),
        ]),
        SectionDestiny(titre: k('but'), enfants: [Paragraphe(e.but)]),
        SectionDestiny(titre: k('consignes'), enfants: [
          for (var i = 0; i < e.consignes.length; i++) Puce(e.consignes[i], numero: i + 1),
        ]),
        if (e.exemples.isNotEmpty)
          SectionDestiny(titre: k('exemples'), enfants: [for (final x in e.exemples) Puce(x)]),
        if (e.cartesATirer.isNotEmpty)
          SectionDestiny(titre: k('cartes'), enfants: [TirageCartes(cartes: e.cartesATirer, couleur: couleur)]),
        if (e.debrief.isNotEmpty)
          SectionDestiny(titre: k('debrief'), enfants: [EncartReplique(e.debrief, couleur: couleur, taille: 14.5)]),
        if (e.variante.isNotEmpty) SectionDestiny(titre: k('variante'), enfants: [Paragraphe(e.variante)]),
        SectionDestiny(titre: k('chrono'), enfants: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in minutesDuree(e.duree))
              FilledButton.tonalIcon(
                onPressed: () => ouvrir(ChronoExerciceScreen(
                  titre: e.titre,
                  consigne: e.but,
                  secondes: m * 60,
                  audio: audio,
                  icone: iconeThemeExercice(e.themeId),
                  couleur: couleur,
                )),
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: Text(k('minutes', {'n': '$m'})),
              ),
          ]),
        ]),
        if (bibliotheque != null) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              final page = pageBibliotheque(notionExercice(e), bibliotheque!);
              if (page != null) ouvrir(page);
            },
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: Text(k('voir_bibliotheque')),
          ),
        ],
        if (e.source.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            k('source', {'source': e.source}),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire),
          ),
        ],
      ],
    );
  }
}

/// Le tirage des cartes d'un exercice : une carte au hasard, jamais deux fois
/// la même de suite, et la liste complète repliée.
class TirageCartes extends StatefulWidget {
  const TirageCartes({super.key, required this.cartes, required this.couleur, this.hasard});

  final List<String> cartes;
  final Color couleur;
  final Random? hasard;

  @override
  State<TirageCartes> createState() => _TirageCartesState();
}

class _TirageCartesState extends State<TirageCartes> {
  late final Random _rng = widget.hasard ?? Random();
  int? _courante;

  void _tirer() {
    final n = widget.cartes.length;
    if (n == 0) return;
    var i = _rng.nextInt(n);
    if (n > 1 && i == _courante) i = (i + 1 + _rng.nextInt(n - 1)) % n;
    setState(() => _courante = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final carte = _courante == null ? null : widget.cartes[_courante!];
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.$x', v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Paragraphe(k('cartes_aide')),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey(_courante),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.couleur.withValues(alpha: c.sombre ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.couleur.withValues(alpha: 0.6)),
          ),
          child: Text(
            carte ?? k('cartes_vide'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: carte == null ? kPoliceTexte : kPoliceTitres,
              fontSize: carte == null ? 14 : 20,
              height: 1.3,
              fontWeight: carte == null ? FontWeight.w400 : FontWeight.w700,
              color: carte == null ? c.texteSecondaire : c.texte,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _tirer,
        icon: const Icon(Icons.shuffle_rounded),
        label: Text(k('tirer')),
      ),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(k('toutes_cartes', {'n': '${widget.cartes.length}'}),
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
          children: [
            for (var i = 0; i < widget.cartes.length; i++)
              InkWell(
                onTap: () => setState(() => _courante = i),
                child: Puce(widget.cartes[i]),
              ),
          ],
        ),
      ),
    ]);
  }
}
