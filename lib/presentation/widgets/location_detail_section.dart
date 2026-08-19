import 'package:flutter/material.dart';

/// Les trois familles de détails d'un lieu, chacune avec sa couleur, son icône
/// et son intitulé. Une identité visuelle par catégorie (charte sombre/dorée).
enum LocationDetailKind { sousEspaces, fonctions, vocabulaire }

class _KindStyle {
  const _KindStyle(this.label, this.subtitle, this.icon, this.color);
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const Map<LocationDetailKind, _KindStyle> _styles = {
  LocationDetailKind.sousEspaces: _KindStyle(
    'Sous-espaces',
    'Endroits jouables à l\'intérieur du lieu',
    Icons.map_outlined,
    Color(0xFF5EE0C4), // teal
  ),
  LocationDetailKind.fonctions: _KindStyle(
    'Fonctions',
    'Métiers et rôles jouables au lieu',
    Icons.badge_outlined,
    Color(0xFFB79CFF), // violet
  ),
  LocationDetailKind.vocabulaire: _KindStyle(
    'Vocabulaire',
    'Jargon, objets et gestes propres au lieu',
    Icons.forum_outlined,
    Color(0xFFFFC24B), // or
  ),
};

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

    return Container(
      margin: EdgeInsets.only(bottom: dense ? 10 : 16),
      padding: EdgeInsets.fromLTRB(dense ? 10 : 14, dense ? 10 : 14,
          dense ? 10 : 14, dense ? 12 : 16),
      decoration: BoxDecoration(
        // Fond très légèrement teinté + liseré coloré à gauche.
        color: color.withValues(alpha: dense ? 0.05 : 0.06),
        borderRadius: BorderRadius.circular(dense ? 12 : 16),
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: BorderSide(color: color.withValues(alpha: 0.14)),
          right: BorderSide(color: color.withValues(alpha: 0.14)),
          bottom: BorderSide(color: color.withValues(alpha: 0.14)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, s, color),
          SizedBox(height: dense ? 8 : 12),
          Wrap(
            spacing: dense ? 6 : 8,
            runSpacing: dense ? 6 : 8,
            children: [for (final it in items) _chip(it, color)],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, _KindStyle s, Color color) {
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
          child: Icon(s.icon, color: color, size: dense ? 16 : 20),
        ),
        SizedBox(width: dense ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: dense ? 13 : 15,
                  letterSpacing: 0.2,
                ),
              ),
              if (!dense)
                Text(
                  s.subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ),
        // Compteur.
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: dense ? 7 : 9, vertical: dense ? 1 : 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${items.length}',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: dense ? 11 : 12),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 9 : 11, vertical: dense ? 5 : 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: dense ? 12 : 13.5,
          height: 1.1,
        ),
      ),
    );
  }
}
