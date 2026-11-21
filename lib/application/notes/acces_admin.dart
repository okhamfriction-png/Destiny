import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../domain/notes/chiffrement_notes.dart';
import '../../domain/notes/depot_notes.dart';
import '../../infrastructure/datasources/depot_notes_github.dart';
import '../../infrastructure/platform/coffre_secret.dart';

/// L'accès administrateur : il ouvre Destiny Note, réservé à Marouene.
///
/// Marouene saisit une fois, dans les Réglages, un token GitHub fine-grained
/// et son mot de passe. L'appli lit `notes/crypto.json`, dérive la clé et
/// déchiffre `notes/canari.enc` : si ça marche, le token et la clé (pas le
/// mot de passe) vont dans le coffre de l'appareil. Sinon, rien n'est gardé.
class AccesAdmin extends ChangeNotifier {
  AccesAdmin({CoffreSecret? coffre, DepotNotes Function(String token)? fabriqueDepot, this.deriver = deriverCleEnFond})
      : _coffre = coffre ?? CoffreAppareil(),
        _fabrique = fabriqueDepot ?? ((token) => DepotNotesGithub(token: token));

  static const kToken = 'destiny_note_token';
  static const kCle = 'destiny_note_cle';
  static const kParametres = 'destiny_note_crypto';

  final CoffreSecret _coffre;
  final DepotNotes Function(String token) _fabrique;

  /// La dérivation de la clé (longue : en tâche de fond sur téléphone).
  final Future<List<int>> Function(String motDePasse, Map<String, Object?> parametres) deriver;

  String? _token;
  SecretKey? _cle;
  bool _charge = false;

  /// L'accès est ouvert : le menu Notes s'affiche.
  bool get actif => _token != null && _cle != null;
  bool get charge => _charge;

  /// Le token, masqué : seulement ses 4 derniers caractères.
  String get tokenMasque {
    final t = _token;
    if (t == null) return '';
    return '••••${t.length <= 4 ? t : t.substring(t.length - 4)}';
  }

  SecretKey? get cle => _cle;

  /// Le dépôt des notes, avec le token (null si l'accès est fermé).
  DepotNotes? get depot => _token == null ? null : _fabrique(_token!);

  Future<void> charger() async {
    try {
      final token = await _coffre.lire(kToken);
      final cle = await _coffre.lire(kCle);
      if (token != null && cle != null) {
        _token = token;
        _cle = ChiffrementNotes.cleDepuisOctets(base64.decode(cle));
      }
    } catch (_) {
      // Coffre illisible : l'accès reste fermé.
    }
    _charge = true;
    notifyListeners();
  }

  /// Le détail de la dernière erreur inattendue (pour la comprendre).
  String derniereErreur = '';

  /// L'étape où l'ouverture a échoué ou dépassé son délai.
  EtapeAcces? etapeEnEchec;

  /// Vérifie le token et le mot de passe, puis ouvre l'accès. [etape] suit
  /// l'avancement (lecture, clé, vérification, coffre). Chaque étape a un
  /// délai : rien ne reste bloqué.
  Future<ResultatAcces> deverrouiller({
    required String token,
    required String motDePasse,
    void Function(EtapeAcces etape)? etape,
    Duration delai = const Duration(seconds: 60),
  }) async {
    token = token.trim();
    derniereErreur = '';
    etapeEnEchec = null;
    if (token.isEmpty || motDePasse.isEmpty) return ResultatAcces.champsVides;
    var enCours = EtapeAcces.lecture;
    Future<T> pas<T>(EtapeAcces e, Future<T> Function() action) {
      enCours = e;
      etape?.call(e);
      return action().timeout(delai);
    }

    try {
      final depot = _fabrique(token);
      final FichierDistant? parametres;
      final FichierDistant? canari;
      try {
        parametres = await pas(EtapeAcces.lecture, () => depot.lire('crypto.json'));
        canari = await pas(EtapeAcces.lecture, () => depot.lire('canari.enc'));
      } on AccesRefuse {
        return ResultatAcces.tokenRefuse;
      } on HorsLigne {
        return ResultatAcces.horsLigne;
      }
      if (parametres == null || canari == null) return ResultatAcces.notesIntrouvables;
      final texteParametres = parametres.contenu;
      final texteCanari = canari.contenu;
      final p = jsonDecode(texteParametres) as Map<String, dynamic>;
      final octets = await pas(EtapeAcces.cle, () => deriver(motDePasse, p));
      final cle = ChiffrementNotes.cleDepuisOctets(octets);
      if (!await pas(EtapeAcces.verification, () => ChiffrementNotes.verifierCanari(cle, texteCanari))) {
        return ResultatAcces.motDePasseIncorrect;
      }
      await pas(EtapeAcces.coffre, () async {
        await _coffre.ecrire(kToken, token);
        await _coffre.ecrire(kCle, base64.encode(octets));
        await _coffre.ecrire(kParametres, texteParametres);
      });
      _token = token;
      _cle = cle;
      notifyListeners();
      return ResultatAcces.ok;
    } on TimeoutException {
      etapeEnEchec = enCours;
      return ResultatAcces.delai;
    } catch (e) {
      etapeEnEchec = enCours;
      derniereErreur = '${e.runtimeType} : $e';
      return ResultatAcces.erreur;
    }
  }

  /// Le mot de passe est-il le bon ? (pour afficher le token en clair)
  Future<bool> verifierMotDePasse(String motDePasse) async {
    final brut = await _coffre.lire(kParametres);
    final cle = await _coffre.lire(kCle);
    if (brut == null || cle == null) return false;
    final octets = await deriver(motDePasse, jsonDecode(brut) as Map<String, dynamic>);
    return base64.encode(octets) == cle;
  }

  /// Le token en clair, après [verifierMotDePasse].
  Future<String?> tokenEnClair(String motDePasse) async =>
      await verifierMotDePasse(motDePasse) ? _token : null;

  /// Ferme l'accès : le token, la clé et les paramètres sont effacés du
  /// coffre, et le menu Notes disparaît.
  Future<void> verrouiller() async {
    await _coffre.effacer(kToken);
    await _coffre.effacer(kCle);
    await _coffre.effacer(kParametres);
    _token = null;
    _cle = null;
    notifyListeners();
  }
}

enum ResultatAcces { ok, champsVides, tokenRefuse, horsLigne, notesIntrouvables, motDePasseIncorrect, delai, erreur }

/// Les étapes de l'ouverture, affichées pendant la vérification.
enum EtapeAcces { lecture, cle, verification, coffre }

/// Dérive la clé hors du fil de l'interface (sur le web, le navigateur le
/// fait lui-même, sans bloquer).
Future<List<int>> deriverCleEnFond(String motDePasse, Map<String, Object?> parametres) {
  if (kIsWeb) return _deriver((motDePasse, parametres));
  return compute(_deriver, (motDePasse, parametres));
}

Future<List<int>> _deriver((String, Map<String, Object?>) e) async =>
    ChiffrementNotes.octetsDeLaCle(await ChiffrementNotes.deriverCle(e.$1, e.$2));
