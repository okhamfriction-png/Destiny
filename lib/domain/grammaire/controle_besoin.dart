import 'modeles.dart';
import 'textes.dart';

/// Ce que dit le contrôle d'un besoin.
enum AvisBesoin {
  /// Rien à signaler.
  ok,

  /// Le besoin est vide.
  vide,

  /// Le besoin commence par un nom (« la confiance ») : mieux vaut un verbe.
  nom,

  /// Le besoin est un objet (« de l'argent ») : c'est un vouloir.
  objet,
}

/// Contrôle simple d'un besoin : un besoin n'est jamais un objet, c'est un
/// changement à l'intérieur, qui se dit avec un verbe. Les listes de mots
/// viennent de `destiny_textes.json` (`besoin.*`).
AvisBesoin controlerBesoin(String besoin, TextesDestiny t) {
  var s = ' ${besoin.trim().toLowerCase().replaceAll('’', "'")}';
  if (s.trim().isEmpty) return AvisBesoin.vide;
  for (final debut in t.liste('besoin.debuts_a_retirer')) {
    final d = ' $debut';
    if (s.startsWith(d)) {
      s = ' ${s.substring(d.length)}';
      break;
    }
  }
  // Mots, sans accents (« d'argent » → « d », « argent »).
  final mots = Grammaire.normaliserMots(s);
  if (mots.isEmpty) return AvisBesoin.vide;
  final determinants = {for (final d in t.liste('besoin.determinants')) Grammaire.normaliser(d)};
  final objets = {for (final o in t.liste('besoin.objets')) Grammaire.normaliser(o)};

  var i = 0;
  var avecDeterminant = false;
  while (i < mots.length && determinants.contains(mots[i])) {
    avecDeterminant = true;
    i++;
  }
  if (i < mots.length && objets.contains(mots[i])) return AvisBesoin.objet;
  if (avecDeterminant) return AvisBesoin.nom;
  return AvisBesoin.ok;
}

/// Le message à afficher sous un besoin (vide si tout va bien).
String messageBesoin(AvisBesoin avis, Grammaire g, TextesDestiny t) => switch (avis) {
      AvisBesoin.ok || AvisBesoin.vide => '',
      AvisBesoin.objet => '${t.t('besoin.titre_alerte_objet')} ${g.personnage.piege}',
      AvisBesoin.nom => '${t.t('besoin.titre_alerte_nom')} ${t.t('besoin.conseil')}',
    };
