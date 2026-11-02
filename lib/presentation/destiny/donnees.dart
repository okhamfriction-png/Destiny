import 'package:flutter/widgets.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/textes.dart';

/// Rend la grammaire et les textes de l'appli disponibles dans tout l'arbre
/// des widgets.
class DestinyDonnees extends InheritedWidget {
  const DestinyDonnees({
    super.key,
    required this.grammaire,
    required this.textes,
    required super.child,
  });

  final Grammaire grammaire;
  final TextesDestiny textes;

  static DestinyDonnees of(BuildContext context) {
    final d = context.dependOnInheritedWidgetOfExactType<DestinyDonnees>();
    if (d == null) {
      throw StateError('DestinyDonnees manquant au-dessus de ce widget.');
    }
    return d;
  }

  @override
  bool updateShouldNotify(DestinyDonnees oldWidget) =>
      grammaire != oldWidget.grammaire || textes != oldWidget.textes;
}

extension DestinyDonneesContexte on BuildContext {
  Grammaire get grammaire => DestinyDonnees.of(this).grammaire;
  TextesDestiny get textes => DestinyDonnees.of(this).textes;
}
