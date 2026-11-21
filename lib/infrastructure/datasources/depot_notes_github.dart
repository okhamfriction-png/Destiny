import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/notes/depot_notes.dart';

/// Les notes sur GitHub, par l'API Contents, sur la branche de données.
/// Le token (fine-grained, Contents : Read and write, sur ce seul dépôt) n'est
/// jamais journalisé.
class DepotNotesGithub implements DepotNotes {
  DepotNotesGithub({
    required String token,
    http.Client? client,
    this.depot = 'okhamfriction-png/Destiny',
    this.branche = 'destiny-story-data',
  })  : _token = token,
        _client = client ?? http.Client();

  final String _token;
  final http.Client _client;
  final String depot;
  final String branche;

  Map<String, String> get _entetes => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Uri _uri(String chemin, [Map<String, String>? requete]) =>
      Uri.https('api.github.com', '/repos/$depot/contents/notes/$chemin', requete);

  Future<http.Response> _envoyer(Future<http.Response> Function() requete) async {
    try {
      return await requete().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const HorsLigne('délai');
    } on http.ClientException catch (e) {
      throw HorsLigne(e.message);
    }
  }

  @override
  Future<FichierDistant?> lire(String chemin) async {
    final r = await _envoyer(() => _client.get(
          // `t` : pas de réponse en cache juste après une écriture.
          _uri(chemin, {'ref': branche, 't': '${DateTime.now().millisecondsSinceEpoch}'}),
          headers: _entetes,
        ));
    if (r.statusCode == 404) return null;
    if (r.statusCode == 401 || r.statusCode == 403) throw AccesRefuse(r.statusCode);
    if (r.statusCode != 200) throw HorsLigne('statut ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final brut = (j['content'] as String? ?? '').replaceAll(RegExp(r'\s'), '');
    return FichierDistant(contenu: utf8.decode(base64.decode(brut)), sha: j['sha'] as String);
  }

  @override
  Future<String> ecrire(String chemin, String contenu, {String? sha, required String message}) async {
    final r = await _envoyer(() => _client.put(
          _uri(chemin),
          headers: {..._entetes, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'content': base64.encode(utf8.encode(contenu)),
            'branch': branche,
            if (sha != null) 'sha': sha,
          }),
        ));
    if (r.statusCode == 409 || (r.statusCode == 422 && r.body.contains('sha'))) throw ConflitSha(chemin);
    if (r.statusCode == 401 || r.statusCode == 403) throw AccesRefuse(r.statusCode);
    if (r.statusCode != 200 && r.statusCode != 201) throw HorsLigne('statut ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['content'] as Map<String, dynamic>)['sha'] as String;
  }
}
