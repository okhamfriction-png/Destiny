import 'package:flutter/material.dart';

import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'contexte_serie.dart';
import 'personnages_screen.dart';

/// Créer un épisode (qui pourra devenir une saison) ou une saison : le
/// public, l'univers, le ton, le lore, le contexte et les réglages.
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
  String _univers = '';
  String _ton = '';
  String _lore = '';
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _contexte = TextEditingController();
  late final ReglagesSerie _reglages = ReglagesSerie(
    traitre: widget.contexte.reglages.moduleTraitre && !_kids,
    registre: widget.contexte.reglages.registreParDefaut,
    combat: widget.contexte.reglages.combatParDefaut,
    piece: widget.contexte.reglages.pieceParDefaut,
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
        final u = widget.contexte.store.catalogue.universDe(_univers);
        if (u != null && !u.pour(kids: _kids)) _univers = '';
        _lore = '';
        // En kids, le traître reste éteint tant que le parent ne l'active pas.
        if (_kids) _reglages.traitre = false;
      });

  Future<void> _creer() async {
    final s = await widget.contexte.store.creer(
      nom: _nom.text.trim(),
      public: _public,
      univers: _univers,
      ton: _ton,
      lore: _lore,
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
    final cat = widget.contexte.store.catalogue;
    final univers = cat.universPour(kids: _kids);
    final lores = cat.universDe(_univers)?.lores ?? const <String>[];

    return PageDestiny(
      titre: widget.saison ? k('titre_saison') : k('titre_episode'),
      enfants: [
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
        SectionDestiny(titre: k('univers'), enfants: [
          Text(k('univers_aide'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              label: Text(k('sans_univers')),
              selected: _univers.isEmpty,
              onSelected: (_) => setState(() {
                _univers = '';
                _lore = '';
              }),
            ),
            for (final u in univers)
              ChoiceChip(
                label: Text(u.nom),
                selected: _univers == u.id,
                onSelected: (_) => setState(() {
                  _univers = u.id;
                  _lore = '';
                }),
              ),
          ]),
        ]),
        if (lores.isNotEmpty)
          SectionDestiny(titre: k('lore'), enfants: [
            Text(k('lore_aide'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ChoiceChip(label: Text(k('aucun_lore')), selected: _lore.isEmpty, onSelected: (_) => setState(() => _lore = '')),
              for (final l in lores)
                ChoiceChip(label: Text(l), selected: _lore == l, onSelected: (_) => setState(() => _lore = l)),
            ]),
          ]),
        SectionDestiny(titre: k('ton'), enfants: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in cat.tons.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _ton == e.key,
                onSelected: (sel) => setState(() => _ton = sel ? e.key : ''),
              ),
          ]),
        ]),
        SectionDestiny(titre: k('nom'), enfants: [
          TextField(controller: _nom, decoration: InputDecoration(helperText: k('nom_aide'), isDense: true)),
          const SizedBox(height: 12),
          TextField(
            controller: _contexte,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: k('contexte'), helperText: k('contexte_aide'), helperMaxLines: 2),
          ),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(k('combat')),
            value: _reglages.combat,
            onChanged: (v) => setState(() => _reglages.combat = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(k('piece')),
            value: _reglages.piece,
            onChanged: (v) => setState(() => _reglages.piece = v),
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
