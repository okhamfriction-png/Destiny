import 'package:destiny/domain/grammaire/controle_besoin.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  late TextesDestiny t;
  setUpAll(() async => t = (await chargerGrammaire()).textes);

  test('un besoin qui est un objet est signalé', () {
    for (final b in [
      "J'ai besoin d'argent",
      "de l'argent",
      'argent',
      'un prêt',
      'sa maison',
      'Obtenir ce prêt', // verbe d'abord : ce n'est pas l'objet seul
    ].take(5)) {
      expect(controlerBesoin(b, t), AvisBesoin.objet, reason: b);
    }
  });

  test('un vrai besoin, qui se dit avec un verbe, passe', () {
    for (final b in [
      'faire confiance',
      'oser parler',
      'se laisser aider',
      'être vu',
      'lâcher prise',
      'dire ce qu\'il ressent',
    ]) {
      expect(controlerBesoin(b, t), AvisBesoin.ok, reason: b);
    }
  });

  test('un nom abstrait invite à mettre un verbe', () {
    expect(controlerBesoin('la confiance', t), AvisBesoin.nom);
  });

  test('vide', () {
    expect(controlerBesoin('   ', t), AvisBesoin.vide);
  });

  test('le message reprend le piège de la grammaire', () async {
    final g = (await chargerGrammaire()).grammaire;
    expect(messageBesoin(AvisBesoin.objet, g, t), contains("J'ai besoin d'argent"));
    expect(messageBesoin(AvisBesoin.ok, g, t), isEmpty);
  });
}
