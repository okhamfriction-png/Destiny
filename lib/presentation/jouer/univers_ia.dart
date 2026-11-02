import 'package:flutter/material.dart';

import '../../domain/grammaire/textes.dart';
import '../../domain/serie/univers.dart';

/// Une icône par univers de `univers.json`.
const Map<String, IconData> kIconesUnivers = {
  'contemporain': Icons.location_city,
  'policier': Icons.local_police,
  'high_fantasy': Icons.castle,
  'shonen': Icons.sports_martial_arts,
  'science_fiction': Icons.rocket_launch,
  'dark_fantasy': Icons.dark_mode,
  'cyberpunk': Icons.memory,
  'horreur': Icons.bloodtype,
  'post_apo': Icons.dangerous,
  'steampunk': Icons.settings,
  'super_heros': Icons.shield,
  'historique': Icons.account_balance,
  'conte_fees': Icons.auto_stories,
  'dessin_anime': Icons.movie_filter,
  'manga_rigolo': Icons.sports_martial_arts,
  'animaux_parlent': Icons.pets,
  'pirates': Icons.sailing,
  'espace_rigolo': Icons.rocket_launch,
  'monde_magique': Icons.auto_fix_high,
  'sous_la_mer': Icons.water,
  'chevaliers_dragons': Icons.castle,
};

/// Les univers proposés pour jouer avec l'IA, tirés de `univers.json` : ceux
/// pour adultes, ou ceux pour enfants.
List<({String name, IconData icon})> universPourIa(CatalogueUnivers catalogue, {required bool kids}) => [
      for (final u in catalogue.univers)
        if (kids ? u.kids : u.adulte) (name: u.nom, icon: kIconesUnivers[u.id] ?? Icons.public),
    ];

/// Une icône par ton, dans l'ordre de `histoire_ia.tons`.
const List<IconData> _iconesTons = [
  Icons.explore,
  Icons.sentiment_very_satisfied,
  Icons.theater_comedy,
  Icons.auto_awesome,
  Icons.hiking,
  Icons.favorite,
  Icons.search,
  Icons.bolt,
];

/// Les tons proposés pour jouer avec l'IA (`histoire_ia.tons`, les mêmes pour
/// l'histoire et le spectacle). Leurs noms partent tels quels dans les
/// consignes de l'IA et dans les parties sauvegardées.
List<({String name, IconData icon})> tonsPourIa(TextesDestiny textes) => [
      for (final (i, nom) in textes.liste('histoire_ia.tons').indexed)
        (name: nom, icon: i < _iconesTons.length ? _iconesTons[i] : Icons.auto_stories),
    ];
