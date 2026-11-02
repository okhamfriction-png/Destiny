import 'package:flutter/material.dart';

import '../../application/state/reglages_destiny.dart';
import '../../application/state/visual_settings.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';

/// L'apparence : le thème (sombre, clair ou comme le téléphone), les visuels
/// des cartes, et le texte de l'histoire avec l'IA.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({required this.visualSettings, required this.reglages, super.key});

  final VisualSettings visualSettings;
  final ReglagesDestiny reglages;

  static const _tailles = <double>[0.85, 1.0, 1.2, 1.45];

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x) => t.t('reglages.$x');
    return ListenableBuilder(
      listenable: Listenable.merge([visualSettings, reglages]),
      builder: (context, _) => PageDestiny(
        titre: k('apparence'),
        enfants: [
          SectionDestiny(titre: k('theme'), espace: 0, enfants: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final th in ThemeDestiny.values)
                ChoiceChip(
                  label: Text(k('themes.${th.name}')),
                  selected: reglages.theme == th,
                  onSelected: (_) => reglages.changer(theme: th),
                ),
            ]),
          ]),
          SectionDestiny(titre: k('visuels'), enfants: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final s in VisualSource.values)
                ChoiceChip(
                  label: Text(k('visuels_noms.${s.name}')),
                  selected: visualSettings.source == s,
                  onSelected: (_) => visualSettings.setSource(s),
                ),
            ]),
            const SizedBox(height: 4),
            Text(k('visuels_aide'), style: Theme.of(context).textTheme.bodySmall),
          ]),
          SectionDestiny(titre: k('texte_histoire'), enfants: [
            Text(k('taille'), style: Theme.of(context).textTheme.titleSmall),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final v in _tailles)
                ChoiceChip(
                  label: Text('×${v.toStringAsFixed(2)}'),
                  selected: (visualSettings.textScale - v).abs() < 0.01,
                  onSelected: (_) => visualSettings.setTextScale(v),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(k('manuscrite')),
              value: visualSettings.handwritten,
              onChanged: visualSettings.setHandwritten,
            ),
            Text(
              context.grammaire.promesse,
              style: TextStyle(
                fontSize: 18 * visualSettings.textScale,
                fontFamily: visualSettings.handwritten ? VisualSettings.handwrittenFamily : null,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
