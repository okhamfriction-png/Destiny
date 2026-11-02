import 'package:flutter/material.dart';

import '../../application/state/ai_settings.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Valeur interne de la liste des modèles pour « Personnalisé… » (jamais le
/// nom d'un vrai modèle).
const String _kPersonnalise = '\u0000personnalise';

/// Le fournisseur d'IA, le modèle, la clé et le style du maître du destin.
class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({required this.settings, super.key});

  final AiSettings settings;

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  late final TextEditingController _customModel;
  late final TextEditingController _token;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    final known = s.provider.models.contains(s.model);
    _customModel = TextEditingController(text: known ? '' : s.model);
    _token = TextEditingController(text: s.token);
  }

  @override
  void dispose() {
    _customModel.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('ia_config.$x', v);
    final s = widget.settings;
    final models = s.provider.models;
    final isCustom = !models.contains(s.model);
    final dropdownValue = isCustom ? _kPersonnalise : s.model;
    final petit = TextStyle(fontFamily: kPoliceTexte, fontSize: 13, height: 1.35, color: c.texteSecondaire);

    return PageDestiny(
      titre: k('titre'),
      enfants: [
        SectionDestiny(titre: k('fournisseur'), espace: 4, enfants: [
          SegmentedButton<AiProvider>(
            showSelectedIcon: false,
            segments: [
              for (final p in AiProvider.values) ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {s.provider},
            onSelectionChanged: (sel) async {
              await widget.settings.update(provider: sel.first);
              setState(() => _customModel.text = '');
            },
          ),
        ]),
        SectionDestiny(titre: k('modele'), enfants: [
          DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              for (final m in models) DropdownMenuItem(value: m, child: Text(m)),
              DropdownMenuItem(value: _kPersonnalise, child: Text(k('personnalise'))),
            ],
            onChanged: (v) async {
              if (v == null) return;
              if (v == _kPersonnalise) {
                setState(() {});
                await widget.settings.update(model: _customModel.text.trim());
              } else {
                await widget.settings.update(model: v);
                setState(() {});
              }
            },
          ),
          if (isCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customModel,
              decoration: InputDecoration(
                labelText: k('modele_personnalise'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => widget.settings.update(model: v.trim()),
            ),
          ],
        ]),
        SectionDestiny(titre: k('cle'), enfants: [
          TextField(
            controller: _token,
            obscureText: _obscure,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              hintText: switch (s.provider) {
                AiProvider.openai => 'sk-…',
                AiProvider.anthropic => 'sk-ant-…',
                AiProvider.google => 'AIza…',
              },
              suffixIcon: IconButton(
                tooltip: t.t(_obscure ? 'accessibilite.afficher' : 'accessibilite.masquer'),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (v) {
              widget.settings.update(token: v.trim());
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(
              s.configured ? Icons.check_circle : Icons.info_outline,
              size: 18,
              color: s.configured ? (c.sombre ? const Color(0xFF6FD08C) : const Color(0xFF2E7D4F)) : c.titre,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.configured ? k('prete', {'fournisseur': s.provider.label, 'modele': s.model}) : k('a_configurer'),
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, fontWeight: FontWeight.w600, color: c.texte),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(k('cle_aide'), style: petit),
        ]),
        SectionDestiny(titre: k('style'), espace: 24, enfants: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in NarrationStyle.values)
                ChoiceChip(
                  label: Text(k('styles.${style.name}.nom')),
                  selected: s.narration == style,
                  selectedColor: c.or.withValues(alpha: 0.3),
                  side: BorderSide(color: s.narration == style ? c.titre : c.filet),
                  showCheckmark: false,
                  onSelected: (_) async {
                    await widget.settings.update(narration: style);
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          CadreLisere(
            couleur: DestinyCouleurs.ia,
            child: Row(children: [
              Icon(
                switch (s.narration) {
                  NarrationStyle.punchy => Icons.bolt,
                  NarrationStyle.child => Icons.child_care,
                  NarrationStyle.petit => Icons.child_friendly,
                  NarrationStyle.normal => Icons.auto_stories,
                },
                size: 20,
                color: c.titre,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  k('styles.${s.narration.name}.aide'),
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.35, color: c.texte),
                ),
              ),
            ]),
          ),
        ]),
      ],
    );
  }
}
