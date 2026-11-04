import 'package:flutter/material.dart';

import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'personnages_screen.dart';

/// Créer un épisode (qui pourra devenir une saison) ou une saison, dans le
/// mode choisi en entrant dans le jeu de rôle (adulte ou enfant) : le titre
/// et les réglages. Pas d'univers ni de ton : entre humains, ce sont les
/// joueurs qui inventent leur monde.
class CreerSerieScreen extends StatefulWidget {
  const CreerSerieScreen({super.key, required this.contexte, required this.saison, required this.public});

  final ContexteSerie contexte;

  /// Vrai : on commence directement une saison.
  final bool saison;

  /// Le mode du jeu de rôle, choisi en entrant.
  final PublicSerie public;

  @override
  State<CreerSerieScreen> createState() => _CreerSerieScreenState();
}

class _CreerSerieScreenState extends State<CreerSerieScreen> {
  PublicSerie get _public => widget.public;
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _contexte = TextEditingController();
  late final ReglagesSerie _reglages = ReglagesSerie(
    traitre: widget.contexte.reglages.moduleTraitre && !_kids,
    registre: widget.contexte.reglages.registreParDefaut,
  );

  bool get _kids => _public == PublicSerie.kids;

  @override
  void dispose() {
    _nom.dispose();
    _contexte.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    final s = await widget.contexte.store.creer(
      nom: _nom.text.trim(),
      public: _public,
      contexte: _contexte.text.trim(),
      reglages: _reglages,
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => PersonnagesScreen(
        contexte: widget.contexte,
        serie: s,
        apres: widget.saison ? ApresPersonnages.saison : ApresPersonnages.episode,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x) => t.t('serie.creer.$x');

    return PageDestiny(
      titre: widget.saison ? k('titre_saison') : k('titre_episode'),
      enfants: [
        BandeauMode(public: _public),
        const SizedBox(height: 12),
        Paragraphe(k('intro')),
        SectionDestiny(titre: k('nom'), enfants: [
          TextField(controller: _nom, decoration: InputDecoration(helperText: k('nom_aide'), isDense: true)),
          // Le contexte ne sert qu'à l'IA : sans elle, on ne le demande pas.
          if (widget.contexte.store.iaConfiguree) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _contexte,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: k('contexte'), helperText: k('contexte_aide'), helperMaxLines: 2),
            ),
          ],
        ]),
        SectionDestiny(titre: k('reglages'), enfants: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(k('traitre')),
            subtitle: Text(_kids ? '${k('traitre_aide')} ${k('traitre_kids')}' : k('traitre_aide')),
            value: _reglages.traitre,
            onChanged: (v) => setState(() => _reglages.traitre = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(k('registre')),
            subtitle: Text(k('registre_aide')),
            value: _reglages.registre,
            onChanged: (v) => setState(() => _reglages.registre = v),
          ),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _creer,
          icon: const Icon(Icons.groups_rounded),
          label: Text(k('suivant')),
        ),
      ],
    );
  }
}
