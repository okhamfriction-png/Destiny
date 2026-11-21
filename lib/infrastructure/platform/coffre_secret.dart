import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Le coffre de l'appareil, pour le token GitHub et la clé de Destiny Note :
/// Keychain sur iOS, Keystore sur Android. Jamais `shared_preferences`.
abstract class CoffreSecret {
  Future<String?> lire(String cle);
  Future<void> ecrire(String cle, String valeur);
  Future<void> effacer(String cle);
}

class CoffreAppareil implements CoffreSecret {
  CoffreAppareil([FlutterSecureStorage? stockage]) : _s = stockage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  @override
  Future<String?> lire(String cle) => _s.read(key: cle);

  @override
  Future<void> ecrire(String cle, String valeur) => _s.write(key: cle, value: valeur);

  @override
  Future<void> effacer(String cle) => _s.delete(key: cle);
}

/// Un coffre en mémoire, pour les tests.
class CoffreMemoire implements CoffreSecret {
  final Map<String, String> valeurs = {};

  @override
  Future<String?> lire(String cle) async => valeurs[cle];

  @override
  Future<void> ecrire(String cle, String valeur) async => valeurs[cle] = valeur;

  @override
  Future<void> effacer(String cle) async => valeurs.remove(cle);
}
