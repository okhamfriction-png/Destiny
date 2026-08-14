import 'package:flutter/material.dart';

import '../../domain/repositories/combination_memory.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({required this.combinationMemory, super.key});

  final CombinationMemory combinationMemory;

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  int _cycle = 1;
  int _used = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cycle = await widget.combinationMemory.currentCycle();
    final used = await widget.combinationMemory.usedCombos();
    if (!mounted) return;
    setState(() {
      _cycle = cycle;
      _used = used.length;
      _loading = false;
    });
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser le compteur ?'),
        content: const Text(
          'Cela efface l\'historique des combinaisons déjà tirées et remet le '
          'cycle à 1. Action irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.combinationMemory.reset();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Base de données réinitialisée.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Base de données')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compteur d\'histoires',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Cycle $_cycle · $_used combinaison(s) enregistrée(s).',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Les combinaisons déjà tirées ne reviennent pas tant '
                            'que toutes les autres ne sont pas passées.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white38),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _confirmReset,
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Réinitialiser le compteur'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
