// Destiny Note en ligne de commande : les notes privées de Marouene, chiffrées
// sur la branche orpheline `destiny-story-data`.
//
//   dart run tool/destiny_notes.dart init    crée la branche, crypto.json et canari.enc
//   dart run tool/destiny_notes.dart pull    déchiffre tout dans .destiny_notes/
//   dart run tool/destiny_notes.dart push [-m "notes: CR répète du 22/11"]
//                                            chiffre .destiny_notes/ et pousse
//
// Le mot de passe est lu SEULEMENT dans la variable d'environnement
// DESTINY_NOTES_PASSWORD. Il n'est jamais écrit, affiché ni journalisé.
// Rien n'est jamais supprimé de la branche : l'historique reste.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:destiny/domain/notes/chiffrement_notes.dart';
import 'package:destiny/domain/notes/notes.dart';

const _branche = 'destiny-story-data';
const _local = '.destiny_notes';
const _empreintes = '$_local/.dernier_pull.json';

Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync() || !Directory('.git').existsSync() && !File('.git').existsSync()) {
    _stop('Lance l\'outil depuis la racine du dépôt DestinyStory.');
  }
  final commande = args.isEmpty ? '' : args.first;
  switch (commande) {
    case 'init':
      await _init();
    case 'pull':
      await _pull(force: args.contains('--force'));
    case 'push':
      final i = args.indexOf('-m');
      await _push(i >= 0 && i + 1 < args.length ? args[i + 1] : null);
    default:
      stdout.writeln('Usage : dart run tool/destiny_notes.dart init | pull [--force] | push [-m "message"]');
      exit(64);
  }
}

Never _stop(String message) {
  stderr.writeln(message);
  exit(1);
}

String _motDePasse() {
  final m = Platform.environment['DESTINY_NOTES_PASSWORD'];
  if (m == null || m.isEmpty) {
    _stop('La variable DESTINY_NOTES_PASSWORD n\'est pas définie.\n'
        'Marouene la définit lui-même, dans son terminal, sans l\'écrire dans un fichier :\n'
        '  read -s DESTINY_NOTES_PASSWORD && export DESTINY_NOTES_PASSWORD\n'
        'ou, une fois pour toutes, dans le trousseau macOS :\n'
        '  security add-generic-password -a "\$USER" -s destiny-notes -w\n'
        'puis : DESTINY_NOTES_PASSWORD="\$(security find-generic-password -s destiny-notes -w)" dart run tool/destiny_notes.dart …');
  }
  return m;
}

Future<String> _git(List<String> args, {String? dans, bool tolerer = false}) async {
  final r = await Process.run('git', args, workingDirectory: dans);
  if (r.exitCode != 0 && !tolerer) _stop('git ${args.first} a échoué :\n${r.stderr}');
  return (r.stdout as String).trim();
}

Future<bool> _brancheDistanteExiste() async =>
    (await _git(['ls-remote', '--heads', 'origin', _branche])).isNotEmpty;

Future<void> _recuperer() async {
  await _git(['fetch', '-q', 'origin', '$_branche:refs/remotes/origin/$_branche']);
}

Future<SecretKey> _cle(Map<String, Object?> parametres, String canari) async {
  final cle = await ChiffrementNotes.deriverCle(_motDePasse(), parametres);
  if (!await ChiffrementNotes.verifierCanari(cle, canari)) _stop('Mot de passe incorrect : le canari ne se déchiffre pas.');
  return cle;
}

Future<void> _init() async {
  _motDePasse();
  if (await _brancheDistanteExiste()) _stop('La branche $_branche existe déjà sur GitHub : rien à initialiser.');
  final tmp = await Directory.systemTemp.createTemp('destiny_notes_');
  try {
    await _git(['worktree', 'add', '-q', '--detach', tmp.path, 'HEAD']);
    await _git(['checkout', '-q', '--orphan', _branche], dans: tmp.path);
    await _git(['rm', '-rfq', '.'], dans: tmp.path);
    final sel = ChiffrementNotes.nouveauSel();
    final parametres = ChiffrementNotes.parametres(sel);
    final cle = await ChiffrementNotes.deriverCle(_motDePasse(), parametres);
    Directory('${tmp.path}/notes/entries').createSync(recursive: true);
    File('${tmp.path}/notes/crypto.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(parametres)}\n');
    File('${tmp.path}/notes/canari.enc').writeAsStringSync(await ChiffrementNotes.canari(cle));
    await _git(['add', 'notes'], dans: tmp.path);
    await _git(['commit', '-q', '-m', 'notes: création de Destiny Note (chiffré)'], dans: tmp.path);
    await _git(['-c', 'http.postBuffer=524288000', 'push', '-q', 'origin', 'HEAD:refs/heads/$_branche'], dans: tmp.path);
    stdout.writeln('Branche $_branche créée et poussée (crypto.json + canari.enc).');
  } finally {
    await _git(['worktree', 'remove', '--force', tmp.path], tolerer: true);
    await _git(['branch', '-q', '-D', _branche], tolerer: true);
  }
}

Future<String> _empreinte(String texte) async =>
    base64.encode((await Sha256().hash(utf8.encode(texte))).bytes);

Future<Map<String, String>> _lireEmpreintes() async {
  final f = File(_empreintes);
  if (!f.existsSync()) return {};
  return (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>).cast<String, String>();
}

/// Les fichiers en clair de .destiny_notes/ (chemin relatif à notes/, sans .json).
Map<String, File> _fichiersLocaux() {
  final dossier = Directory('$_local/notes');
  if (!dossier.existsSync()) return {};
  return {
    for (final f in dossier.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.json'))
        f.path.substring(dossier.path.length + 1, f.path.length - '.json'.length): f,
  };
}

Future<void> _pull({bool force = false}) async {
  if (!await _brancheDistanteExiste()) _stop('La branche $_branche n\'existe pas encore : lance d\'abord « init ».');
  await _recuperer();
  const ref = 'origin/$_branche';
  // Des modifications locales pas encore poussées ? On ne les écrase pas.
  final avant = await _lireEmpreintes();
  if (!force) {
    for (final e in _fichiersLocaux().entries) {
      final connue = avant[e.key];
      if (connue == null || connue != await _empreinte(e.value.readAsStringSync())) {
        _stop('.destiny_notes/notes/${e.key}.json a été modifié depuis le dernier pull : '
            'lance d\'abord « push » (ou « pull --force » pour l\'écraser).');
      }
    }
  }
  final parametres = jsonDecode(await _git(['show', '$ref:notes/crypto.json'])) as Map<String, dynamic>;
  final cle = await _cle(parametres, await _git(['show', '$ref:notes/canari.enc']));
  final noms = (await _git(['ls-tree', '-r', '--name-only', ref, 'notes/'])).split('\n');
  final empreintes = <String, String>{};
  var n = 0;
  for (final nom in noms) {
    if (!nom.endsWith('.enc') || nom == 'notes/canari.enc') continue;
    final texte = await ChiffrementNotes.dechiffrer(cle, await _git(['show', '$ref:$nom']));
    final rel = nom.substring('notes/'.length, nom.length - '.enc'.length);
    final f = File('$_local/notes/$rel.json')..parent.createSync(recursive: true);
    f.writeAsStringSync(texte.endsWith('\n') ? texte : '$texte\n');
    empreintes[rel] = await _empreinte(f.readAsStringSync());
    n++;
  }
  File(_empreintes)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(empreintes));
  stdout.writeln('$n fichiers déchiffrés dans $_local/notes/.');
}

/// L'index, reconstruit depuis les entrées.
Future<void> _reconstruireIndex() async {
  final entrees = <ResumeNote>[];
  final dossier = Directory('$_local/notes/entries');
  if (dossier.existsSync()) {
    for (final f in dossier.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      entrees.add(EntreeNote.depuisJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>).resumeIndex);
    }
  }
  final index = {
    'entrees': [for (final r in trierIndex(entrees)) r.versJson()],
    'mis_a_jour_le': DateTime.now().toIso8601String().substring(0, 10),
  };
  final f = File('$_local/notes/index.json')..parent.createSync(recursive: true);
  final ancien = f.existsSync() ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic> : null;
  // La date seule ne justifie pas une réécriture.
  if (ancien != null && jsonEncode(ancien['entrees']) == jsonEncode(index['entrees'])) return;
  f.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(index)}\n');
}

Future<void> _push(String? message) async {
  if (!await _brancheDistanteExiste()) _stop('La branche $_branche n\'existe pas encore : lance d\'abord « init ».');
  if (_fichiersLocaux().isEmpty) _stop('Rien dans $_local/notes/ : lance d\'abord « pull ».');
  // Chaque entrée doit se relire.
  for (final e in _fichiersLocaux().entries.where((e) => e.key.startsWith('entries/'))) {
    final j = jsonDecode(e.value.readAsStringSync()) as Map<String, dynamic>;
    if ('entries/${j['id']}' != e.key) _stop('${e.value.path} : son id (${j['id']}) ne correspond pas au nom du fichier.');
  }
  await _reconstruireIndex();
  await _recuperer();
  final tmp = await Directory.systemTemp.createTemp('destiny_notes_');
  try {
    await _git(['worktree', 'add', '-q', '--detach', tmp.path, 'origin/$_branche']);
    final parametres = jsonDecode(File('${tmp.path}/notes/crypto.json').readAsStringSync()) as Map<String, dynamic>;
    final cle = await _cle(parametres, File('${tmp.path}/notes/canari.enc').readAsStringSync());
    var changes = 0;
    for (final e in _fichiersLocaux().entries) {
      final texte = e.value.readAsStringSync();
      jsonDecode(texte); // JSON valide, sinon on s'arrête.
      final cible = File('${tmp.path}/notes/${e.key}.enc');
      if (cible.existsSync()) {
        final distant = await ChiffrementNotes.dechiffrer(cle, cible.readAsStringSync());
        if (distant.trim() == texte.trim()) continue;
      }
      cible.parent.createSync(recursive: true);
      cible.writeAsStringSync(await ChiffrementNotes.chiffrer(cle, texte));
      changes++;
    }
    if (changes == 0) {
      stdout.writeln('Rien de nouveau à pousser.');
      return;
    }
    await _git(['add', 'notes'], dans: tmp.path);
    final m = message ?? 'notes: mise à jour du ${DateTime.now().toIso8601String().substring(0, 10)}';
    await _git(['commit', '-q', '-m', m], dans: tmp.path);
    await _git(['-c', 'http.postBuffer=524288000', 'push', '-q', 'origin', 'HEAD:refs/heads/$_branche'], dans: tmp.path);
    final empreintes = await _lireEmpreintes();
    for (final e in _fichiersLocaux().entries) {
      empreintes[e.key] = await _empreinte(e.value.readAsStringSync());
    }
    File(_empreintes).writeAsStringSync(jsonEncode(empreintes));
    stdout.writeln('$changes fichier(s) chiffré(s) et poussé(s) sur $_branche : « $m ».');
  } finally {
    await _git(['worktree', 'remove', '--force', tmp.path], tolerer: true);
  }
}
