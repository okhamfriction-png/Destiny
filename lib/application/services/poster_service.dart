import 'dart:convert';

import 'package:http/http.dart' as http;

/// Récupère l'URL de l'affiche officielle d'un film via l'API Wikipédia
/// (aucune clé requise, CORS activé par `origin=*`). Renvoie `null` si aucune
/// affiche n'est trouvée — l'appelant affiche alors une affiche stylisée.
///
/// Chaîne de résolution (les affiches, non libres, vivent sur EN.wikipedia) :
///   1. titre FR → page anglaise (via langlinks), sinon recherche EN directe ;
///   2. page EN → fichier dont le nom contient « poster » / « affiche » ;
///   3. fichier → URL d'image (imageinfo).
/// Les résultats sont mémoïsés en mémoire.
class PosterService {
  PosterService._();
  static final PosterService instance = PosterService._();

  final Map<String, String?> _cache = {};
  static const _timeout = Duration(seconds: 8);

  /// Cherche l'affiche du [film] (l'[annee] aide à lever l'ambiguïté).
  Future<String?> posterUrl(String film, {String annee = ''}) async {
    final title = film.trim();
    if (title.isEmpty) return null;
    final key = '${title.toLowerCase()}|$annee';
    if (_cache.containsKey(key)) return _cache[key];

    String? url;
    final enTitle = await _enTitle(title, annee);
    if (enTitle != null) {
      final file = await _posterFile(enTitle);
      if (file != null) url = await _fileThumb(file);
    }
    _cache[key] = url;
    return url;
  }

  /// Trouve le titre de la page anglaise du film.
  Future<String?> _enTitle(String title, String annee) async {
    // a) Recherche FR + langlink EN : gère les titres français.
    final frQuery = annee.isEmpty ? '$title film' : '$title film $annee';
    try {
      final resp = await http.get(Uri.https('fr.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrsearch': frQuery,
        'gsrlimit': '1',
        'prop': 'langlinks',
        'lllang': 'en',
        'lllimit': '1',
        'redirects': '1',
        'origin': '*',
      })).timeout(_timeout);
      if (resp.statusCode == 200) {
        for (final page in _pages(resp.body)) {
          final ll = page['langlinks'];
          if (ll is List && ll.isNotEmpty && ll.first is Map) {
            final t = (ll.first as Map)['*'];
            if (t is String && t.trim().isNotEmpty) return t;
          }
        }
      }
    } catch (_) {}

    // b) Fallback : recherche directe EN (titres anglais / originaux).
    final enQuery = annee.isEmpty ? '$title film' : '$title $annee film';
    try {
      final resp = await http.get(Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrsearch': enQuery,
        'gsrlimit': '1',
        'redirects': '1',
        'origin': '*',
      })).timeout(_timeout);
      if (resp.statusCode == 200) {
        final pages = _pages(resp.body);
        if (pages.isNotEmpty) {
          final t = pages.first['title'];
          if (t is String && t.trim().isNotEmpty) return t;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Sur la page EN, repère le fichier de l'affiche (nom contenant « poster »).
  Future<String?> _posterFile(String enTitle) async {
    try {
      final resp = await http.get(Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'parse',
        'format': 'json',
        'page': enTitle,
        'prop': 'images',
        'redirects': '1',
        'origin': '*',
      })).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body);
      if (data is! Map) return null;
      final parse = data['parse'];
      if (parse is! Map) return null;
      final images = parse['images'];
      if (images is! List) return null;

      bool isImage(String f) {
        final l = f.toLowerCase();
        return (l.endsWith('.jpg') ||
                l.endsWith('.jpeg') ||
                l.endsWith('.png')) &&
            !l.contains('logo') &&
            !l.contains('icon');
      }

      // On ne retient qu'un vrai fichier d'affiche, jamais une photo d'acteur :
      // si rien ne contient « poster » / « affiche », on renvoie null et
      // l'appelant montre l'affiche stylisée.
      for (final f in images) {
        if (f is String && isImage(f)) {
          final l = f.toLowerCase();
          if (l.contains('poster') || l.contains('affiche')) return f;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Résout un nom de fichier en URL d'image (miniature 500 px).
  Future<String?> _fileThumb(String file) async {
    try {
      final resp = await http.get(Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'titles': 'File:$file',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'iiurlwidth': '500',
        'origin': '*',
      })).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      for (final page in _pages(resp.body)) {
        final ii = page['imageinfo'];
        if (ii is List && ii.isNotEmpty && ii.first is Map) {
          final info = ii.first as Map;
          final thumb = info['thumburl'];
          if (thumb is String && thumb.isNotEmpty) return thumb;
          final url = info['url'];
          if (url is String && url.isNotEmpty) return url;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extrait la liste `query.pages` d'une réponse MediaWiki.
  List<Map<String, dynamic>> _pages(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map) return const [];
      final q = data['query'];
      if (q is! Map) return const [];
      final pages = q['pages'];
      if (pages is! Map) return const [];
      return [
        for (final p in pages.values)
          if (p is Map) p.cast<String, dynamic>(),
      ];
    } catch (_) {
      return const [];
    }
  }
}
