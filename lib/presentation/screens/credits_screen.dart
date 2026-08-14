import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

/// Crédits des sons d'ambiance (freesound.org — licences Creative Commons).
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<_Credit> _credits = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = <_Credit>[];
    for (final path in const [
      'assets/audio/ambiences/attributions.json',
      'assets/audio/universes/attributions.json',
    ]) {
      try {
        final raw = await rootBundle.loadString(path);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        for (final v in data.values) {
          final m = v as Map<String, dynamic>;
          list.add(_Credit(
            name: m['name'] as String? ?? '',
            author: m['author'] as String? ?? '',
            license: m['license'] as String? ?? '',
            url: m['url'] as String? ?? '',
          ));
        }
      } catch (_) {}
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _credits = list;
      _loading = false;
    });
  }

  String _licenseLabel(String url) {
    final u = url.toLowerCase();
    if (u.contains('publicdomain') || u.contains('zero')) return 'CC0';
    if (u.contains('by-nc')) return 'CC BY-NC';
    if (u.contains('by-sa')) return 'CC BY-SA';
    if (u.contains('/by/')) return 'CC BY';
    if (u.contains('sampling')) return 'Sampling+';
    return 'CC';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crédits')),
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
                  Text('Sons d\'ambiance', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Les ambiances de lieux proviennent de freesound.org, sous '
                    'licences Creative Commons. Merci à leurs auteurs.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  if (_credits.isEmpty)
                    const Text('Aucun crédit à afficher.',
                        style: TextStyle(color: Colors.white54)),
                  for (final c in _credits)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        title: Text(c.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            'par ${c.author} · ${_licenseLabel(c.license)}'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: c.url.isEmpty
                            ? null
                            : () => launchUrl(Uri.parse(c.url),
                                mode: LaunchMode.externalApplication),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Credit {
  const _Credit({
    required this.name,
    required this.author,
    required this.license,
    required this.url,
  });
  final String name;
  final String author;
  final String license;
  final String url;
}
