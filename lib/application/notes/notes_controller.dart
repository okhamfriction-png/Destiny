import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/notes/chiffrement_notes.dart';
import '../../domain/notes/depot_notes.dart';
import '../../domain/notes/notes.dart';
import '../../infrastructure/datasources/cache_notes.dart';
import 'acces_admin.dart';

/// Les fichiers fixes de Destiny Note (dans `notes/`).
abstract final class FichiersNotes {
  static const index = 'index.enc';
  static const seance = 'prochaine_seance.enc';
  static const regles = 'regles_en_vigueur.enc';
  static const journal = 'journal_decisions.enc';
  static const modeles = 'modeles.enc';
}

/// Le fichier a changé sur GitHub pendant qu'on le modifiait : les deux
/// versions, pour laisser Marouene choisir.
class ConflitNotes implements Exception {
  const ConflitNotes({required this.chemin, required this.mienne, required this.distante, required this.shaDistant});

  final String chemin;

  /// Les deux textes en clair (JSON indenté), pour montrer la différence.
  final String mienne;
  final String distante;
  final String shaDistant;
}

/// L'état de Destiny Note : lecture (GitHub, sinon le cache chiffré),
/// déchiffrement, écriture chiffrée avec le `sha`, file d'attente hors ligne.
class NotesController extends ChangeNotifier {
  NotesController({required this.acces, CacheNotes? cache, String Function()? aujourdhui})
      : _cache = cache ?? CachePreferences(),
        _aujourdhui = aujourdhui ?? _jourIso;

  final AccesAdmin acces;
  final CacheNotes _cache;
  final String Function() _aujourdhui;

  static String _jourIso() => DateTime.now().toIso8601String().substring(0, 10);

  String get aujourdhui => _aujourdhui();

  List<ResumeNote> _index = const [];
  ProchaineSeance? _seance;
  TexteNote? _regles;
  JournalDecisions? _journal;
  ModelesWhatsApp _modeles = const ModelesWhatsApp();
  final Map<String, String> _shas = {};
  final Map<String, EntreeNote> _entrees = {};
  bool _chargement = false;
  bool _horsLigne = false;
  int _enAttente = 0;
  String? _erreur;
  bool _premierChargement = false;

  List<ResumeNote> get index => _index;
  ProchaineSeance? get seance => _seance;
  TexteNote? get regles => _regles;
  JournalDecisions? get journal => _journal;
  ModelesWhatsApp get modeles => _modeles;
  bool get chargement => _chargement;
  bool get horsLigne => _horsLigne;
  int get enAttente => _enAttente;
  String? get erreur => _erreur;
  bool get premierChargement => _premierChargement;

  /// Le fil filtré : [types] vides = tout ; [recherche] plein texte.
  List<ResumeNote> fil({Set<TypeNote> types = const {}, String recherche = ''}) => [
        for (final r in _index)
          if ((types.isEmpty || types.contains(r.type)) && r.correspond(recherche)) r,
      ];

  /// Une première fois à l'ouverture de l'écran.
  Future<void> ouvrir() async {
    if (_premierChargement) return;
    _premierChargement = true;
    await rafraichir();
  }

  /// Recharge depuis GitHub (« tirer pour rafraîchir ») ; hors ligne, depuis
  /// le cache. Envoie d'abord ce qui attendait le réseau.
  Future<void> rafraichir() async {
    final depot = acces.depot;
    final cle = acces.cle;
    if (depot == null || cle == null) return;
    _chargement = true;
    _erreur = null;
    notifyListeners();
    final cache = await _cache.lireTout();
    try {
      await _envoyerEnAttente(depot);
      _horsLigne = false;
      for (final f in [FichiersNotes.index, FichiersNotes.seance, FichiersNotes.regles, FichiersNotes.journal, FichiersNotes.modeles]) {
        final d = await depot.lire(f);
        if (d != null) {
          _shas[f] = d.sha;
          await _cache.garder(f, d.contenu, d.sha);
          cache[f] = (contenu: d.contenu, sha: d.sha);
        }
      }
      _entrees.clear();
    } on HorsLigne {
      _horsLigne = true;
      for (final e in cache.entries) {
        _shas[e.key] = e.value.sha;
      }
    } on AccesRefuse {
      _erreur = 'acces_refuse';
    }
    try {
      Future<Map<String, dynamic>?> lire(String f) async {
        final c = cache[f];
        if (c == null) return null;
        return jsonDecode(await ChiffrementNotes.dechiffrer(cle, c.contenu)) as Map<String, dynamic>;
      }

      final index = await lire(FichiersNotes.index);
      _index = trierIndex([
        for (final e in (index?['entrees'] as List?) ?? const []) ResumeNote.depuisJson(e as Map<String, dynamic>),
      ]);
      final s = await lire(FichiersNotes.seance);
      _seance = s == null ? null : ProchaineSeance.depuisJson(s);
      final r = await lire(FichiersNotes.regles);
      _regles = r == null ? null : TexteNote.depuisJson(r);
      final j = await lire(FichiersNotes.journal);
      _journal = j == null ? null : JournalDecisions.depuisJson(j);
      final m = await lire(FichiersNotes.modeles);
      _modeles = m == null ? const ModelesWhatsApp() : ModelesWhatsApp.depuisJson(m);
    } on MotDePasseIncorrect {
      _erreur = 'cle';
    } on FichierNotesIllisible {
      _erreur = 'illisible';
    }
    _enAttente = (await _cache.enAttente()).length;
    _chargement = false;
    notifyListeners();
  }

  /// Une entrée complète (déchiffrée à la demande, puis gardée).
  Future<EntreeNote?> entree(ResumeNote r) async {
    final deja = _entrees[r.id];
    if (deja != null) return deja;
    final cle = acces.cle;
    final depot = acces.depot;
    if (cle == null || depot == null) return null;
    final chemin = r.fichier;
    String? contenu;
    try {
      final d = await depot.lire(chemin);
      if (d != null) {
        contenu = d.contenu;
        _shas[chemin] = d.sha;
        await _cache.garder(chemin, d.contenu, d.sha);
      }
    } on HorsLigne {
      final c = (await _cache.lireTout())[chemin];
      if (c != null) {
        contenu = c.contenu;
        _shas[chemin] = c.sha;
      }
    }
    if (contenu == null) return null;
    final e = EntreeNote.depuisJson(jsonDecode(await ChiffrementNotes.dechiffrer(cle, contenu)) as Map<String, dynamic>);
    _entrees[r.id] = e;
    return e;
  }

  /// Enregistre une entrée (nouvelle ou corrigée), puis l'index. Lève
  /// [ConflitNotes] si elle a changé sur GitHub entre-temps.
  Future<void> enregistrerEntree(EntreeNote e) async {
    await _ecrireJson(e.fichier, e.versJson(), 'notes: ${e.titre} (${e.date})');
    _entrees[e.id] = e;
    _index = trierIndex([for (final r in _index) if (r.id != e.id) r, e.resumeIndex]);
    await _ecrireIndex();
    notifyListeners();
  }

  Future<void> enregistrerSeance(ProchaineSeance s) async {
    await _ecrireJson(FichiersNotes.seance, s.versJson(), 'notes: prochaine séance du ${s.date}');
    _seance = s;
    notifyListeners();
  }

  Future<void> enregistrerModeles(ModelesWhatsApp m) async {
    await _ecrireJson(FichiersNotes.modeles, m.versJson(), 'notes: modèles WhatsApp');
    _modeles = m;
    notifyListeners();
  }

  /// Après un conflit : [garderLaMienne] réécrit par-dessus la version de
  /// GitHub ; sinon on prend la sienne et on recharge.
  Future<void> resoudreConflit(ConflitNotes c, {required bool garderLaMienne}) async {
    if (garderLaMienne) {
      _shas[c.chemin] = c.shaDistant;
      await _ecrireJson(c.chemin, jsonDecode(c.mienne) as Map<String, dynamic>, 'notes: ${c.chemin} (version gardée)');
      if (c.chemin.startsWith('entries/')) await _ecrireIndex();
    }
    _entrees.clear();
    await rafraichir();
  }

  Future<void> _ecrireIndex() => _ecrireJson(
        FichiersNotes.index,
        {'entrees': [for (final r in _index) r.versJson()], 'mis_a_jour_le': aujourdhui},
        'notes: index',
        conflitEnFusion: true,
      );

  Future<void> _ecrireJson(String chemin, Map<String, Object?> json, String message, {bool conflitEnFusion = false}) async {
    final depot = acces.depot;
    final cle = acces.cle;
    if (depot == null || cle == null) throw StateError('Destiny Note est verrouillé');
    final texte = const JsonEncoder.withIndent('  ').convert(json);
    final enveloppe = await ChiffrementNotes.chiffrer(cle, texte);
    try {
      final sha = await depot.ecrire(chemin, enveloppe, sha: _shas[chemin], message: message);
      _shas[chemin] = sha;
      await _cache.garder(chemin, enveloppe, sha);
    } on HorsLigne {
      final attente = [...await _cache.enAttente()]
        ..removeWhere((e) => e.chemin == chemin)
        ..add(EcritureEnAttente(chemin: chemin, contenu: enveloppe, sha: _shas[chemin], message: message));
      await _cache.mettreEnAttente(attente);
      await _cache.garder(chemin, enveloppe, _shas[chemin] ?? '');
      _enAttente = attente.length;
      _horsLigne = true;
    } on ConflitSha {
      final d = await depot.lire(chemin);
      if (d == null) rethrow;
      final distante = await ChiffrementNotes.dechiffrer(cle, d.contenu);
      if (conflitEnFusion && chemin == FichiersNotes.index) {
        // L'index se fusionne tout seul : les entrées des deux côtés.
        final siennes = [
          for (final e in (jsonDecode(distante) as Map<String, dynamic>)['entrees'] as List? ?? const [])
            ResumeNote.depuisJson(e as Map<String, dynamic>),
        ];
        final miennes = {for (final r in _index) r.id};
        _index = trierIndex([..._index, for (final r in siennes) if (!miennes.contains(r.id)) r]);
        _shas[chemin] = d.sha;
        await _ecrireJson(chemin, {'entrees': [for (final r in _index) r.versJson()], 'mis_a_jour_le': aujourdhui}, message);
        return;
      }
      throw ConflitNotes(chemin: chemin, mienne: texte, distante: distante, shaDistant: d.sha);
    }
  }

  Future<void> _envoyerEnAttente(DepotNotes depot) async {
    final attente = await _cache.enAttente();
    if (attente.isEmpty) return;
    final restantes = <EcritureEnAttente>[];
    for (final e in attente) {
      try {
        final sha = await depot.ecrire(e.chemin, e.contenu, sha: e.sha, message: e.message);
        await _cache.garder(e.chemin, e.contenu, sha);
      } on ConflitSha {
        // Une autre version est arrivée : on garde celle-ci de côté (elle sera
        // proposée à la prochaine modification de ce fichier).
        restantes.add(e);
      }
    }
    await _cache.mettreEnAttente(restantes);
  }

  /// Au verrouillage : on oublie tout (le cache chiffré aussi).
  Future<void> oublier() async {
    _index = const [];
    _seance = null;
    _regles = null;
    _journal = null;
    _modeles = const ModelesWhatsApp();
    _shas.clear();
    _entrees.clear();
    _premierChargement = false;
    await _cache.vider();
    notifyListeners();
  }
}
