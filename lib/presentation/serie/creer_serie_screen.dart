import 'package:flutter/material.dart';

import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'contexte_serie.dart';
import 'personnages_screen.dart';

/// Créer un épisode (qui pourra devenir une saison) ou une saison : le
/// public, le titre et les réglages. Pas d'univers ni de ton : entre humains,
/// ce sont les joueurs qui inventent leur monde.
class CreerSerieScreen extends StatefulWidget {
  const CreerSerieScreen({super.key, required this.contexte, required this.saison});

  final ContexteSerie contexte;

  /// Vrai : on commence directement une saison.
  final bool saison;

  @override
  State<CreerSerieScreen> createState() => _CreerSerieScreenState();
}

class _CreerSerieScreenState extends State<CreerSerieScreen> {
  late PublicSerie _public = widget.contexte.reglages.kidsParDefaut ? PublicSerie.kids : PublicSerie.adulte;
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

  void _changerPublic(PublicSerie p) => setState(() {
        _public = p;
        // En kids, le traître reste éteint tant que le parent ne l'active pas.
        if (_kids) _reglages.traitre = false;
      });

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
        Paragraphe(k('intro')),
        SectionDestiny(titre: k('public'), espace: 0, enfants: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ChoiceChip(
              label: Text(k('adulte')),
              selected: !_kids,
              onSelected: (_) => _changerPublic(PublicSerie.adulte),
            ),
            ChoiceChip(
              avatar: const SigleKids(petit: true),
              label: Text(k('kids')),
              selected: _kids,
              onSelected: (_) => _changerPublic(PublicSerie.kids),
            ),
          ]),
        ]),
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
