import 'package:flutter/material.dart';

import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';

/// Habillage sombre pour un écran-contenu poussé en route (Chat, Spectacle) :
/// il fournit le fond dégradé du shell et un bouton retour, que ces écrans
/// n'ont pas puisqu'ils étaient conçus pour vivre dans l'onglet.
class EcranSombre extends StatelessWidget {
  const EcranSombre({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ThemeSombre(child: _contenu(context));
  }

  Widget _contenu(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0818),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 44),
                  child: child,
                ),
              ),
              const Align(
                alignment: Alignment.topLeft,
                child: BackButton(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Garde un écran en thème sombre, même quand l'appli est en thème clair :
/// les anciens écrans (histoire et spectacle avec l'IA, éditeurs, exercices)
/// ont été dessinés pour le sombre.
class ThemeSombre extends StatelessWidget {
  const ThemeSombre({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: themeDestiny(context.grammaire, sombre: true), child: child);
}
