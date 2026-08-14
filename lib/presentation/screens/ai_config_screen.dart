import 'package:flutter/material.dart';

import '../../application/state/ai_settings.dart';

const String _kCustom = 'Personnalisé…';

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
    final theme = Theme.of(context);
    final s = widget.settings;
    final models = s.provider.models;
    final isCustom = !models.contains(s.model);
    final dropdownValue = isCustom ? _kCustom : s.model;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurer l\'IA')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(Icons.hub_outlined, 'Fournisseur'),
            const SizedBox(height: 8),
            SegmentedButton<AiProvider>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AiProvider.openai, label: Text('OpenAI')),
                ButtonSegment(
                    value: AiProvider.anthropic, label: Text('Anthropic')),
                ButtonSegment(value: AiProvider.google, label: Text('Google')),
              ],
              selected: {s.provider},
              onSelectionChanged: (sel) async {
                await widget.settings.update(provider: sel.first);
                setState(() => _customModel.text = '');
              },
            ),
            const SizedBox(height: 20),
            _header(Icons.smart_toy_outlined, 'Modèle'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: dropdownValue,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final m in models)
                  DropdownMenuItem(value: m, child: Text(m)),
                const DropdownMenuItem(value: _kCustom, child: Text(_kCustom)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                if (v == _kCustom) {
                  setState(() {});
                  await widget.settings.update(
                      model: _customModel.text.trim().isEmpty
                          ? _customModel.text.trim()
                          : _customModel.text.trim());
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
                decoration: const InputDecoration(
                  labelText: 'Nom du modèle (personnalisé)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => widget.settings.update(model: v.trim()),
              ),
            ],
            const SizedBox(height: 20),
            _header(Icons.key_outlined, 'Jeton API'),
            const SizedBox(height: 8),
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
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (v) =>
                  setState(() => widget.settings.update(token: v.trim())),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(s.configured ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: s.configured
                        ? Colors.greenAccent
                        : theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.configured
                        ? 'IA configurée — ${s.provider.label} · ${s.model}'
                        : 'Saisis un jeton pour activer le Chat.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Le jeton reste sur l\'appareil. Le Chat IA fonctionne sur mobile ; '
              'dans le navigateur, les API IA bloquent les appels (CORS).',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _header(Icons.theater_comedy_outlined, 'Style du Maître du jeu'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in NarrationStyle.values)
                  ChoiceChip(
                    label: Text(style.label),
                    selected: s.narration == style,
                    onSelected: (_) async {
                      await widget.settings.update(narration: style);
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Icon(
                    switch (s.narration) {
                      NarrationStyle.punchy => Icons.bolt,
                      NarrationStyle.child => Icons.child_care,
                      NarrationStyle.petit => Icons.child_friendly,
                      NarrationStyle.normal => Icons.auto_stories,
                    },
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      switch (s.narration) {
                        NarrationStyle.punchy =>
                          'Ultra direct : sujet-verbe-complément, une phrase '
                              'très concise par DONC et par MAIS.',
                        NarrationStyle.child =>
                          'Enfant (CP-CE2) : une phrase de 8 mots max, mots '
                              'simples, très percutant.',
                        NarrationStyle.petit =>
                          'Petit (5-6 ans) : 6 mots MAX, mots basiques, pour '
                              'apprendre à lire tout seul.',
                        NarrationStyle.normal =>
                          'Narration immersive habituelle, 2 à 3 lignes par '
                              'réponse.',
                      },
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(IconData icon, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
