import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/migration_campagnes.dart';
import '../../domain/serie/serie.dart';
import '../../domain/serie/univers.dart';
import '../assistant/campagne_assistant.dart';
import '../services/llm_service.dart';
import 'ai_settings.dart';

/// Les séries (le jeu de rôle entre humains). Le catalogue des univers est
/// chargé ici pour les modes avec l'IA, la Bibliothèque et la relecture des
/// anciennes campagnes : le jeu entre humains, lui, n'a pas d'univers. Tout
/// reste sur l'appareil ; seul l'assistant parle à l'IA, avec des textes déjà
/// nettoyés des prénoms, et sans univers ni ton.
class SerieStore extends ChangeNotifier {
  SerieStore({Future<String> Function(String chemin)? lire, LlmService? llm, AiSettings? aiSettings})
      : _lire = lire ?? rootBundle.loadString,
        _aiSettings = aiSettings,
        _assistant = llm == null ? null : CampagneAssistant(llm);

  static const String cleSeries = 'series_v2';
  static const String cleMigrees = 'series_campagnes_migrees_v1';
  static const String cleCampagnesV1 = 'campagnes_v1';
  static const String cleSeancesV1 = 'campagne_seances_v1';

  final Future<String> Function(String) _lire;
  final AiSettings? _aiSettings;
  final CampagneAssistant? _assistant;

  CatalogueUnivers _catalogue = CatalogueUnivers.vide;
  CatalogueUnivers get catalogue => _catalogue;

  final List<Serie> _series = [];
  bool _lectureEchouee = false;
  bool _charge = false;
  int _compteur = 0;

  bool get charge => _charge;

  /// Vrai si les séries enregistrées n'ont pas pu être lues : rien n'est alors
  /// écrit, pour ne jamais écraser ce qu'on n'a pas su lire.
  bool get lectureEchouee => _lectureEchouee;

  /// Les séries, la plus récemment jouée d'abord.
  List<Serie> get series {
    DateTime derniere(Serie s) =>
        s.episodes.isEmpty ? s.creee : s.episodes.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
    return List.unmodifiable([..._series]..sort((a, b) => derniere(b).compareTo(derniere(a))));
  }

  Serie? serie(String id) {
    for (final s in _series) {
      if (s.id == id) return s;
    }
    return null;
  }

  String nouvelId([String prefixe = 's']) => '$prefixe${DateTime.now().microsecondsSinceEpoch}-${_compteur++}';

  Future<Map<String, dynamic>> _json(String chemin) async =>
      Map<String, dynamic>.from(jsonDecode(await _lire(chemin)) as Map);

  /// Charge le catalogue, les séries, et migre une fois les anciennes
  /// campagnes (leurs clés restent intactes).
  Future<void> charger({Grammaire? grammaire}) async {
    try {
      _catalogue = CatalogueUnivers.depuisJson(
        univers: await _json('assets/data/univers.json'),
        lieux: await _json('assets/data/campagne_lieux.json'),
        mechants: await _json('assets/data/campagne_mechants.json'),
        archetypesCampagne: await _json('assets/data/campagne_archetypes.json'),
        grammaire: grammaire,
      );
    } catch (_) {
      _catalogue = CatalogueUnivers.vide;
    }

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _lectureEchouee = true;
      _charge = true;
      notifyListeners();
      return;
    }
    try {
      final brut = prefs.getString(cleSeries);
      _series
        ..clear()
        ..addAll([
          if (brut != null)
            for (final e in jsonDecode(brut) as List) Serie.depuisJson(Map<String, dynamic>.from(e as Map)),
        ]);
    } catch (_) {
      _lectureEchouee = true;
    }
    if (!_lectureEchouee) await _migrer(prefs);
    _charge = true;
    notifyListeners();
  }

  Future<void> _migrer(SharedPreferences prefs) async {
    try {
      final brut = prefs.getString(cleCampagnesV1);
      if (brut == null) return;
      final migrees = {...?prefs.getStringList(cleMigrees)};
      final campagnes = [
        for (final c in jsonDecode(brut) as List)
          if (!migrees.contains('${(c as Map)['id']}')) Map<String, dynamic>.from(c),
      ];
      if (campagnes.isEmpty) return;
      final brutSeances = prefs.getString(cleSeancesV1);
      final seances = brutSeances == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(brutSeances) as Map);
      final nouvelles = migrerCampagnes(
        campagnes: campagnes,
        seances: seances,
        catalogue: _catalogue,
        maintenant: DateTime.now(),
      );
      for (final s in nouvelles) {
        if (serie(s.id) == null) _series.add(s);
      }
      await _sauver();
      await prefs.setStringList(cleMigrees, [...migrees, for (final c in campagnes) '${c['id']}']);
    } catch (_) {
      // Une ancienne sauvegarde illisible n'empêche pas de jouer ; elle reste
      // intacte et on réessaiera au prochain démarrage.
    }
  }

  Future<void> _sauver() async {
    if (_lectureEchouee) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cleSeries, jsonEncode([for (final s in _series) s.versJson()]));
    } catch (_) {}
  }

  /// Crée une série (vide : on y prépare ensuite le premier épisode).
  Future<Serie> creer({
    String nom = '',
    PublicSerie public = PublicSerie.adulte,
    String contexte = '',
    ReglagesSerie? reglages,
  }) async {
    final s = Serie(
      id: nouvelId(),
      creee: DateTime.now(),
      nom: nom,
      public: public,
      contexte: contexte,
      reglages: reglages,
    );
    _series.add(s);
    await enregistrer(s);
    return s;
  }

  /// Enregistre une série modifiée.
  Future<void> enregistrer(Serie s) async {
    if (!_series.contains(s)) {
      _series.removeWhere((x) => x.id == s.id);
      _series.add(s);
    }
    notifyListeners();
    await _sauver();
  }

  /// Retire une série. Une ancienne campagne n'est pas remigrée.
  Future<void> supprimer(String id) async {
    _series.removeWhere((s) => s.id == id);
    notifyListeners();
    await _sauver();
  }

  // --- L'IA (facultative) ---

  bool get iaConfiguree => _assistant != null && (_aiSettings?.configured ?? false);

  /// Le rôle qui remplace le prénom de chaque joueur, avant tout envoi.
  static Map<String, String> rolesParPrenom(Serie s, {String parDefaut = 'un personnage'}) => {
        for (final p in s.personnages)
          if (p.joueur.trim().isNotEmpty)
            p.joueur.trim(): p.nomSansPrenom.isNotEmpty ? p.nomSansPrenom : parDefaut,
      };

  /// Le résumé, l'accroche et les entrées du registre d'un épisode. Le texte
  /// part sans prénoms, et ce qui revient est nettoyé encore une fois.
  Future<MemoireEpisode> resumer(Serie s, {required String transcription, List<String> categories = const []}) async {
    if (!iaConfiguree) return const MemoireEpisode();
    final roles = rolesParPrenom(s);
    final m = await _assistant!.resumer(
      settings: _aiSettings!,
      contexte: sansPrenoms(s.contexte, roles),
      transcription: sansPrenoms(transcription, roles),
      public: s.kids ? 'enfant' : 'adulte',
      categoriesRegistre: s.reglages.registre ? categories : const [],
    );
    return m.sansPrenoms(roles);
  }

  /// Les quatre présages proposés par l'IA pour un méchant.
  Future<List<String>> proposerPresages(Serie s, Mechant m, {required List<String> paliers}) async {
    if (!iaConfiguree) return const ['', '', '', ''];
    final roles = rolesParPrenom(s);
    final texte = [
      m.nom,
      m.histoirePour(kids: s.kids),
      if (m.veut.isNotEmpty) 'Il veut : ${m.veut}',
      for (final sb in m.sbires) 'Son sbire ${sb.nom} : ${sb.fait}',
    ].join('\n');
    final p = await _assistant!.proposerPresages(
      settings: _aiSettings!,
      contexte: sansPrenoms(s.contexte, roles),
      mechant: texte,
      paliers: paliers,
      public: s.kids ? 'enfant' : 'adulte',
    );
    return [for (final x in p) sansPrenoms(x, roles)];
  }

  /// Deux ou trois entrées du registre à ressortir.
  Future<List<Ressorti>> proposerRessortis(Serie s, List<EntreeRegistre> entrees, {String prochain = ''}) async {
    if (!iaConfiguree || entrees.isEmpty) return const [];
    final roles = rolesParPrenom(s);
    return _assistant!.proposerRessortis(
      settings: _aiSettings!,
      contexte: sansPrenoms(s.contexte, roles),
      entrees: [for (final e in entrees) sansPrenoms('${e.nom} — ${e.detail}', roles)],
      prochainEpisode: sansPrenoms(prochain, roles),
      public: s.kids ? 'enfant' : 'adulte',
    );
  }

  /// Range ce que l'IA a rendu : le résumé de l'épisode, l'accroche de la
  /// série, et les nouvelles entrées du registre. En kids, personne ne meurt :
  /// une « mort » devient un personnage parti.
  void integrerMemoire(Serie s, EpisodeSerie e, MemoireEpisode m) {
    if (m.resume.isNotEmpty) {
      e.resume = m.resume;
      s.resume = s.resume.trim().isEmpty ? m.resume : '${s.resume.trim()}\n\n${m.resume}';
    }
    if (m.suite.isNotEmpty) {
      e.suite = m.suite;
      s.accroche = m.suite;
    }
    if (!s.reglages.registre) return;
    for (final n in m.registre) {
      var categorie = CategorieRegistre.depuisTexte(n.categorie);
      var statut = StatutRegistre.depuisTexte(n.statut);
      if (s.kids && (categorie == CategorieRegistre.mort || statut == StatutRegistre.tombe)) {
        if (categorie == CategorieRegistre.mort) categorie = CategorieRegistre.figurant;
        statut = StatutRegistre.parti;
      }
      s.registre.add(EntreeRegistre(
        id: nouvelId('r'),
        categorie: categorie,
        nom: n.nom,
        detail: n.detail,
        statut: statut,
        liens: n.liens,
        saison: e.saison,
        episode: e.numero,
        deLIa: true,
      ));
    }
  }
}
