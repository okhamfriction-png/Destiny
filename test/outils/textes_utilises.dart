import 'dart:convert';
import 'dart:io';

/// Les clés de `destiny_textes.json` utilisées dans [chemins] (fichiers ou
/// dossiers) qui n'existent pas. Lit les chemins écrits en entier
/// (`t.t('serie.creer.titre')`) et les raccourcis locaux
/// (`String k(String x) => t.t('reglages.$x')` puis `k('titre')`).
List<String> textesManquants(List<String> chemins) {
  final textes = jsonDecode(File('assets/data/destiny_textes.json').readAsStringSync()) as Map<String, dynamic>;
  bool existe(String chemin) {
    Object? v = textes;
    for (final cle in chemin.split('.')) {
      if (v is! Map) return false;
      v = v[cle];
    }
    return v is String || v is List || v is Map;
  }

  final fichiers = <File>[
    for (final c in chemins)
      if (FileSystemEntity.isDirectorySync(c))
        ...Directory(c).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
      else
        File(c),
  ];
  final manquants = <String>[];
  final raccourci = RegExp(
      r"String (\w+)\(String \w+(?:, \[Map<String, String> \w+ = const \{\}\])?\) => t\.t\('([a-z_\.]+)\.\$");
  for (final f in fichiers) {
    final code = f.readAsStringSync();
    for (final m in RegExp(r"(?:\bt|textes)\.t\('([a-z_]+\.[a-z_\.]+)'").allMatches(code)) {
      if (!existe(m.group(1)!)) manquants.add('${f.path} : ${m.group(1)}');
    }
    final prefixes = <String, List<String>>{};
    for (final m in raccourci.allMatches(code)) {
      (prefixes[m.group(1)!] ??= []).add(m.group(2)!);
    }
    for (final e in prefixes.entries) {
      for (final m in RegExp("\\b${e.key}\\('([a-z_\\.]+)'").allMatches(code)) {
        if (!e.value.any((p) => existe('$p.${m.group(1)}'))) manquants.add('${f.path} : ${e.key}(${m.group(1)})');
      }
    }
  }
  return manquants;
}
