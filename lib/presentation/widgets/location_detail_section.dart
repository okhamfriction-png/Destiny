import 'package:flutter/material.dart';

import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';

/// Les trois familles de détails d'un lieu, chacune avec sa couleur, son icône
/// et son intitulé. Une identité visuelle par catégorie.
enum LocationDetailKind { sousEspaces, fonctions, vocabulaire }

class _KindStyle {
  const _KindStyle(this.cle, this.icon, this.color);

  /// La clé de l'intitulé dans `details_lieux` (son aide : `<cle>_aide`).
  final String cle;
  final IconData icon;
  final Color color;
}

const Map<LocationDetailKind, _KindStyle> _styles = {
  LocationDetailKind.sousEspaces: _KindStyle(
    'sous_espaces',
    Icons.map_outlined,
    Color(0xFF5EE0C4), // teal
  ),
  LocationDetailKind.fonctions: _KindStyle(
    'fonctions',
    Icons.badge_outlined,
    Color(0xFFB79CFF), // violet
  ),
  LocationDetailKind.vocabulaire: _KindStyle(
    'vocabulaire',
    Icons.forum_outlined,
    Color(0xFFFFC24B), // or
  ),
};

/// La couleur d'une catégorie quand elle colore du texte ou une icône :
/// éclaircie en sombre, assombrie en clair, pour rester lisible.
Color _teinte(DestinyCouleurs d, Color couleur) =>
    d.sombre ? Color.lerp(couleur, Colors.white, 0.2)! : Color.lerp(couleur, d.encre, 0.6)!;

/// Section colorée d'une catégorie : en-tête (pastille + titre + compteur) et
/// puces teintées. [dense] = variante compacte pour les tuiles du catalogue.
class LocationDetailSection extends StatelessWidget {
  const LocationDetailSection({
    required this.kind,
    required this.items,
    this.dense = false,
    super.key,
  });

  final LocationDetailKind kind;
  final List<String> items;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final s = _styles[kind]!;
    final color = s.color;
    final d = context.destiny;

    final rayon = dense ? 12.0 : 16.0;
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 10 : 16),
      decoration: BoxDecoration(
        // Fond de carte très légèrement teinté + liseré coloré à gauche.
        color: Color.alphaBlend(color.withValues(alpha: dense ? 0.05 : 0.06), d.carte),
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rayon - 1),
        child: Stack(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(dense ? 13 : 17, dense ? 10 : 14, dense ? 10 : 14, dense ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, s, color),
                SizedBox(height: dense ? 8 : 12),
                Wrap(
                  spacing: dense ? 6 : 8,
                  runSpacing: dense ? 6 : 8,
                  children: [for (final it in items) _chip(d, it, color)],
                ),
              ],
            ),
          ),
          Positioned(left: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: color)),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, _KindStyle s, Color color) {
    final d = context.destiny;
    final t = context.textes;
    final teinte = _teinte(d, color);
    final badge = dense ? 26.0 : 36.0;
    return Row(
      children: [
        Container(
          width: badge,
          height: badge,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(dense ? 8 : 10),
          ),
          alignment: Alignment.center,
          child: Icon(s.icon, color: teinte, size: dense ? 16 : 20),
        ),
        SizedBox(width: dense ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.t('details_lieux.${s.cle}'),
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  color: teinte,
                  fontWeight: FontWeight.w800,
                  fontSize: dense ? 13 : 15,
                  letterSpacing: 0.2,
                ),
              ),
              if (!dense)
                Text(
                  t.t('details_lieux.${s.cle}_aide'),
                  style: TextStyle(fontFamily: kPoliceTexte, color: d.texteSecondaire, fontSize: 12),
                ),
            ],
          ),
        ),
        // Compteur.
        Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 1 : 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${items.length}',
            style: TextStyle(
              fontFamily: kPoliceTexte,
              color: teinte,
              fontWeight: FontWeight.w800,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(DestinyCouleurs d, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 5 : 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kPoliceTexte,
          color: d.texte,
          fontSize: dense ? 12 : 13.5,
          height: 1.1,
        ),
      ),
    );
  }
}
