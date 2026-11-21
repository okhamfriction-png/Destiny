import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Le chiffrement de Destiny Note, en Dart pur : l'appli et l'outil
/// `tool/destiny_notes.dart` le partagent (pas de Flutter ici).
///
/// - La clé vient du mot de passe de Marouene : PBKDF2-HMAC-SHA256,
///   310 000 itérations, avec un sel aléatoire de 16 octets gardé dans
///   `notes/crypto.json` (le sel n'est pas secret).
/// - Chaque fichier `.enc` est chiffré en AES-256-GCM, dans une enveloppe
///   JSON `{ "v": 1, "nonce": "<base64>", "ct": "<base64>" }`, où `ct` est le
///   texte chiffré suivi de l'étiquette d'authentification (16 octets), comme
///   le fait `AESGCM` en Python.
/// - `notes/canari.enc` chiffre un texte connu : s'il se déchiffre, le mot de
///   passe est le bon.
class ChiffrementNotes {
  ChiffrementNotes._();

  static const int iterationsParDefaut = 310000;
  static const int longueurSel = 16;
  static const String texteCanari = "Destiny Note · Rien n'est écrit";

  static final AesGcm _aes = AesGcm.with256bits();

  /// Les paramètres publics (`notes/crypto.json`).
  static Map<String, Object?> parametres(List<int> sel, {int iterations = iterationsParDefaut}) => {
        'v': 1,
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'sel': base64.encode(sel),
        'chiffrement': 'AES-256-GCM',
      };

  /// Un sel aléatoire, tiré d'un générateur sûr.
  static List<int> nouveauSel() {
    final r = Random.secure();
    return List<int>.generate(longueurSel, (_) => r.nextInt(256));
  }

  /// La clé dérivée du mot de passe, avec les paramètres de `crypto.json`.
  static Future<SecretKey> deriverCle(String motDePasse, Map<String, Object?> parametres) async {
    final sel = base64.decode(parametres['sel'] as String);
    final iterations = (parametres['iterations'] as num?)?.toInt() ?? iterationsParDefaut;
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
    return pbkdf2.deriveKeyFromPassword(password: motDePasse, nonce: sel);
  }

  /// La clé à partir de ses octets (gardés dans le coffre de l'appareil).
  static SecretKey cleDepuisOctets(List<int> octets) => SecretKey(List<int>.unmodifiable(octets));

  static Future<List<int>> octetsDeLaCle(SecretKey cle) => cle.extractBytes();

  /// Chiffre un texte : l'enveloppe JSON, prête à écrire dans un `.enc`.
  static Future<String> chiffrer(SecretKey cle, String texte) async {
    final boite = await _aes.encrypt(utf8.encode(texte), secretKey: cle);
    return jsonEncode({
      'v': 1,
      'nonce': base64.encode(boite.nonce),
      'ct': base64.encode([...boite.cipherText, ...boite.mac.bytes]),
    });
  }

  /// Déchiffre une enveloppe. Lève [MotDePasseIncorrect] si la clé n'est pas
  /// la bonne (ou si le fichier a été modifié).
  static Future<String> dechiffrer(SecretKey cle, String enveloppe) async {
    final Map<String, dynamic> e;
    try {
      e = jsonDecode(enveloppe) as Map<String, dynamic>;
    } on FormatException {
      throw const FichierNotesIllisible('enveloppe');
    }
    if (e['v'] != 1) throw const FichierNotesIllisible('version');
    final nonce = base64.decode(e['nonce'] as String);
    final tout = base64.decode(e['ct'] as String);
    if (tout.length < 16) throw const FichierNotesIllisible('taille');
    final boite = SecretBox(
      tout.sublist(0, tout.length - 16),
      nonce: nonce,
      mac: Mac(tout.sublist(tout.length - 16)),
    );
    try {
      return utf8.decode(await _aes.decrypt(boite, secretKey: cle));
    } on SecretBoxAuthenticationError {
      throw const MotDePasseIncorrect();
    }
  }

  /// Le canari chiffré (`notes/canari.enc`).
  static Future<String> canari(SecretKey cle) => chiffrer(cle, texteCanari);

  /// La clé ouvre-t-elle le canari ?
  static Future<bool> verifierCanari(SecretKey cle, String enveloppeCanari) async {
    try {
      return await dechiffrer(cle, enveloppeCanari) == texteCanari;
    } on MotDePasseIncorrect {
      return false;
    }
  }
}

/// Le mot de passe (la clé) ne déchiffre pas les notes.
class MotDePasseIncorrect implements Exception {
  const MotDePasseIncorrect();

  @override
  String toString() => 'Mot de passe incorrect';
}

/// Un fichier `.enc` qui n'a pas la forme attendue.
class FichierNotesIllisible implements Exception {
  const FichierNotesIllisible(this.raison);

  final String raison;

  @override
  String toString() => 'Fichier de notes illisible ($raison)';
}
