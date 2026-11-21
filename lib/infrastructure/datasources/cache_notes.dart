import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Le cache hors ligne de Destiny Note. Il ne garde que les enveloppes
/// chiffrées (illisibles sans la clé) et leur `sha`, plus les écritures en
/// attente de réseau. Jamais de texte en clair, ni le token, ni la clé.
abstract class CacheNotes {
  Future<Map<String, ({String contenu, String sha})>> lireTout();
  Future<void> garder(String chemin, String contenu, String sha);
  Future<List<EcritureEnAttente>> enAttente();
  Future<void> mettreEnAttente(List<EcritureEnAttente> ecritures);
  Future<void> vider();
}

/// Une écriture faite hors ligne, à envoyer au retour du réseau.
class EcritureEnAttente {
  const EcritureEnAttente({required this.chemin, required this.contenu, this.sha, required this.message});

  final String chemin;

  /// L'enveloppe chiffrée.
  final String contenu;

  /// La version qu'elle remplace.
  final String? sha;
  final String message;

  factory EcritureEnAttente.depuisJson(Map<String, dynamic> j) => EcritureEnAttente(
        chemin: j['chemin'] as String,
        contenu: j['contenu'] as String,
        sha: j['sha'] as String?,
        message: j['message'] as String? ?? 'notes',
      );

  Map<String, Object?> versJson() => {'chemin': chemin, 'contenu': contenu, 'sha': sha, 'message': message};
}

class CachePreferences implements CacheNotes {
  static const _kFichiers = 'destiny_note_cache_v1';
  static const _kAttente = 'destiny_note_en_attente_v1';

  @override
  Future<Map<String, ({String contenu, String sha})>> lireTout() async {
    final p = await SharedPreferences.getInstance();
    final brut = p.getString(_kFichiers);
    if (brut == null) return {};
    final j = jsonDecode(brut) as Map<String, dynamic>;
    return {
      for (final e in j.entries)
        e.key: (contenu: (e.value as Map)['contenu'] as String, sha: (e.value as Map)['sha'] as String),
    };
  }

  @override
  Future<void> garder(String chemin, String contenu, String sha) async {
    final tout = await lireTout();
    tout[chemin] = (contenu: contenu, sha: sha);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFichiers, jsonEncode({
      for (final e in tout.entries) e.key: {'contenu': e.value.contenu, 'sha': e.value.sha},
    }));
  }

  @override
  Future<List<EcritureEnAttente>> enAttente() async {
    final p = await SharedPreferences.getInstance();
    final brut = p.getString(_kAttente);
    if (brut == null) return const [];
    return [for (final e in jsonDecode(brut) as List) EcritureEnAttente.depuisJson(e as Map<String, dynamic>)];
  }

  @override
  Future<void> mettreEnAttente(List<EcritureEnAttente> ecritures) async {
    final p = await SharedPreferences.getInstance();
    if (ecritures.isEmpty) {
      await p.remove(_kAttente);
    } else {
      await p.setString(_kAttente, jsonEncode([for (final e in ecritures) e.versJson()]));
    }
  }

  @override
  Future<void> vider() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kFichiers);
    await p.remove(_kAttente);
  }
}

/// Un cache en mémoire, pour les tests.
class CacheMemoire implements CacheNotes {
  final Map<String, ({String contenu, String sha})> fichiers = {};
  List<EcritureEnAttente> attente = [];

  @override
  Future<Map<String, ({String contenu, String sha})>> lireTout() async => {...fichiers};

  @override
  Future<void> garder(String chemin, String contenu, String sha) async => fichiers[chemin] = (contenu: contenu, sha: sha);

  @override
  Future<List<EcritureEnAttente>> enAttente() async => [...attente];

  @override
  Future<void> mettreEnAttente(List<EcritureEnAttente> ecritures) async => attente = [...ecritures];

  @override
  Future<void> vider() async {
    fichiers.clear();
    attente = [];
  }
}
