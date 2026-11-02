import 'package:flutter/material.dart';

import '../theme/destiny_theme.dart';
import 'donnees.dart';

/// Un bouton qui demande quelque chose à l'IA : il tourne pendant l'appel et
/// dit en clair si l'IA n'a pas répondu. Sans IA configurée, il ne s'affiche
/// pas.
class BoutonIA extends StatefulWidget {
  const BoutonIA({super.key, required this.libelle, required this.action, this.disponible = true});

  final String libelle;
  final Future<void> Function() action;

  /// L'IA est-elle configurée ?
  final bool disponible;

  @override
  State<BoutonIA> createState() => _BoutonIAState();
}

class _BoutonIAState extends State<BoutonIA> {
  bool _enCours = false;

  Future<void> _lancer() async {
    setState(() => _enCours = true);
    try {
      await widget.action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.textes.t('ia_jeu.echec', {'erreur': '$e'}))));
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.disponible) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _enCours ? null : _lancer,
        icon: _enCours
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome, color: DestinyCouleurs.ia),
        label: Text(_enCours ? context.textes.t('ia_jeu.en_cours') : widget.libelle),
      ),
    );
  }
}
