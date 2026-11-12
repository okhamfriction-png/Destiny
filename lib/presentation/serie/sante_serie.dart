import 'package:flutter/material.dart';

import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';
import '../troupe/composants_troupe.dart' show PastilleEtape;

/// Les couleurs des deux pistes : le cœur du vert au rouge, le cerveau du
/// bleu au violet.
const List<Color> kCouleursCoeur = [Color(0xFF43A047), Color(0xFFFB8C00), Color(0xFFE53935)];
const List<Color> kCouleursEsprit = [Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFF7B1FA2), Color(0xFFD81B60)];

const List<IconData> kIconesCoeur = [Icons.favorite_rounded, Icons.heart_broken_rounded, Icons.dangerous_rounded];

/// Le libellé d'un état du cœur (en kids, on ne meurt pas : on quitte
/// l'histoire).
String libelleSante(BuildContext context, Sante s, {required bool kids}) {
  final t = context.textes;
  if (s == Sante.sorti && kids) return t.t('serie.sante.coeur.sorti_kids');
  return t.t('serie.sante.coeur.${s.name}');
}

/// Le libellé d'un état du cerveau.
String libelleEsprit(BuildContext context, Esprit e, {required bool kids}) =>
    context.textes.t(kids ? 'serie.sante.esprit_kids.${e.name}' : 'serie.sante.esprit.${e.name}');

/// La santé d'un personnage, en deux pistes : le cœur (en forme, blessé,
/// mort) et le cerveau (lucide, ébranlé, au bord de la folie, fou). Un appui
/// sur un état le choisit.
class PistesSante extends StatelessWidget {
  const PistesSante({
    super.key,
    required this.sante,
    required this.esprit,
    required this.kids,
    required this.onSante,
    required this.onEsprit,
    this.cle = '',
  });

  final Sante sante;
  final Esprit esprit;
  final bool kids;
  final ValueChanged<Sante>? onSante;
  final ValueChanged<Esprit>? onEsprit;

  /// Pour retrouver les pastilles dans les tests (l'identifiant du personnage).
  final String cle;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Piste(
        icone: Icons.favorite_rounded,
        titre: t.t('serie.sante.coeur.titre'),
        etats: [
          for (final (i, s) in Sante.values.indexed)
            _Etat(
              cle: 'coeur_${s.name}_$cle',
              libelle: libelleSante(context, s, kids: kids),
              icone: kIconesCoeur[i],
              couleur: kCouleursCoeur[i],
              choisi: s == sante,
              onTap: onSante == null ? null : () => onSante!(s),
            ),
        ],
      ),
      const SizedBox(height: 6),
      _Piste(
        icone: Icons.psychology_rounded,
        titre: t.t('serie.sante.esprit_titre'),
        etats: [
          for (final (i, e) in Esprit.values.indexed)
            _Etat(
              cle: 'esprit_${e.name}_$cle',
              libelle: libelleEsprit(context, e, kids: kids),
              icone: i == 0 ? Icons.psychology_rounded : Icons.psychology_alt_rounded,
              couleur: kCouleursEsprit[i],
              choisi: e == esprit,
              onTap: onEsprit == null ? null : () => onEsprit!(e),
            ),
        ],
      ),
    ]);
  }
}

class _Piste extends StatelessWidget {
  const _Piste({required this.icone, required this.titre, required this.etats});

  final IconData icone;
  final String titre;
  final List<Widget> etats;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icone, size: 16, color: c.texteSecondaire),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            titre.toUpperCase(),
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: 1.2,
              color: c.texteSecondaire,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 6, children: etats),
    ]);
  }
}

class _Etat extends StatelessWidget {
  const _Etat({
    required this.cle,
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.choisi,
    required this.onTap,
  });

  final String cle;
  final String libelle;
  final IconData icone;
  final Color couleur;
  final bool choisi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final forme = StadiumBorder(side: BorderSide(color: choisi ? couleur : c.ligne, width: choisi ? 2 : 1));
    return Semantics(
      button: true,
      selected: choisi,
      label: libelle,
      excludeSemantics: true,
      child: Material(
        key: ValueKey(cle),
        color: choisi ? couleur.withValues(alpha: 0.18) : c.carte,
        shape: forme,
        child: InkWell(
          customBorder: forme,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icone, size: 18, color: choisi ? couleur : c.texteSecondaire),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    libelle,
                    style: TextStyle(
                      fontFamily: kPoliceTexte,
                      fontWeight: choisi ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                      color: choisi ? c.texte : c.texteSecondaire,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les étapes d'un épisode, comme au théâtre : Préparer, Jeu, Régie.
enum EtapeFil { preparer, jeu, regie }

/// Le fil des étapes d'un épisode : où on en est, et chaque étape à un appui.
class FilEpisode extends StatelessWidget {
  const FilEpisode({super.key, required this.courante, this.onPreparer, this.onJeu, this.onRegie});

  final EtapeFil courante;
  final VoidCallback? onPreparer;
  final VoidCallback? onJeu;
  final VoidCallback? onRegie;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final etapes = [
      (EtapeFil.preparer, Icons.style_rounded, onPreparer),
      (EtapeFil.jeu, Icons.theater_comedy_rounded, onJeu),
      (EtapeFil.regie, Icons.play_circle_rounded, onRegie),
    ];
    return Semantics(
      container: true,
      label: t.t('troupe.fil.titre'),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (etape, icone, action) in etapes)
          PastilleEtape(
            key: ValueKey('fil_${etape.name}'),
            libelle: t.t('serie.fil.${etape.name}'),
            icone: icone,
            courante: etape == courante,
            regie: etape == EtapeFil.regie,
            onTap: etape == courante && etape != EtapeFil.regie ? null : action,
          ),
      ]),
    );
  }
}
