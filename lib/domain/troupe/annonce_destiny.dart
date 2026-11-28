/// L'annonce d'un DESTINY : ce que l'appli affiche et dit, et rien d'autre.
library;

import 'dart:math';

import '../grammaire/modeles.dart';

/// Ce qu'un DESTINY annonce, et rien d'autre :
/// - n°1 : le danger (il enferme) ;
/// - n°2 : « Il se manifeste » ;
/// - n°3 : le nombre de survivants (il tue).
class AnnonceDestiny {
  const AnnonceDestiny({required this.niveau, this.danger = '', this.dangerId = '', this.survivants});

  /// Le niveau du danger que ce DESTINY amène.
  final PalierId niveau;

  /// Le nom du danger (DESTINY n°1).
  final String danger;

  /// Son identifiant, pour chercher son annonce dans le pack audio.
  final String dangerId;

  /// Le nombre de survivants (DESTINY n°3 ; null : pas de dé, la Série).
  final int? survivants;

  /// Le code du son de cette annonce dans le pack audio : s'il y est, il est
  /// joué ; sinon, la synthèse vocale dit [voix].
  String get codeSon => switch (niveau) {
        PalierId.enferme => dangerId.isEmpty ? 'ANNONCE_IL_ENFERME' : 'ANNONCE_DANGER_${dangerId.toUpperCase()}',
        PalierId.manifeste => 'ANNONCE_IL_SE_MANIFESTE',
        PalierId.tue => survivants == null ? 'ANNONCE_IL_TUE' : 'ANNONCE_SURVIVANTS_$survivants',
      };

  /// Le temps de l'annonce à l'écran : 10 s pour le danger, 5 s ensuite.
  Duration get duree => niveau == PalierId.enferme ? kDureeAnnonceDanger : kDureeAnnonce;

  /// « Il reste 2 survivants. »
  static String phraseSurvivants(String Function(String cle, [Map<String, String> v]) t, int n) =>
      n == 1 ? t('annonce.un_survivant') : t('annonce.survivants', {'n': '$n'});

  /// Le petit titre, au-dessus de la phrase (vide : pas de titre).
  String titre() => switch (niveau) {
        PalierId.enferme => danger.isEmpty ? '' : niveau.nom,
        PalierId.manifeste => '',
        PalierId.tue => survivants == null ? '' : niveau.nom,
      };

  /// La phrase affichée en grand.
  String phrase(String Function(String cle, [Map<String, String> v]) t) => switch (niveau) {
        PalierId.enferme => danger.isEmpty ? niveau.nom : danger,
        PalierId.manifeste => niveau.nom,
        PalierId.tue => survivants == null ? niveau.nom : phraseSurvivants(t, survivants!),
      };

  /// Ce que dit la voix.
  String voix(String Function(String cle, [Map<String, String> v]) t) => switch (niveau) {
        PalierId.enferme => danger.isEmpty ? '${niveau.nom}.' : '$danger. ${niveau.nom}.',
        PalierId.manifeste => '${niveau.nom}.',
        PalierId.tue => survivants == null ? '${niveau.nom}.' : phraseSurvivants(t, survivants!),
      };
}

/// L'annonce du danger (DESTINY n°1) reste 10 s, le temps de le lire.
const Duration kDureeAnnonceDanger = Duration(seconds: 10);

/// Les annonces des DESTINY n°2 et n°3 restent 5 s.
const Duration kDureeAnnonce = Duration(seconds: 5);

/// Le nombre de survivants le plus haut qu'annonce le DESTINY n°3.
const int kSurvivantsMax = 3;

/// Les nombres de survivants possibles pour [protagonistes] joueurs : de 1 à
/// 3, et toujours moins que le nombre de protagonistes (à 2 : 1 ; à 3 : 1 ou
/// 2 ; à 4 et plus : 1, 2 ou 3). Vide sous 2 joueurs.
List<int> survivantsPossibles(int protagonistes) =>
    [for (var n = 1; n <= min(kSurvivantsMax, protagonistes - 1); n++) n];

/// Le nombre de survivants, tiré au hasard (null sous 2 joueurs).
int? tirerSurvivants(int protagonistes, {Random? hasard}) {
  final possibles = survivantsPossibles(protagonistes);
  if (possibles.isEmpty) return null;
  return possibles[(hasard ?? Random()).nextInt(possibles.length)];
}
