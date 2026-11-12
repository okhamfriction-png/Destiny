import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Les valeurs de la régie son du spectacle. Les listes de 4 vont de l'acte 1
/// à l'acte 4 ; les durées sont en secondes, les volumes de 0 à 1.
class ValeursRegieSon {
  ValeursRegieSon();

  /// La conduite son automatique, quand le pack est importé.
  bool packActif = true;

  // Musique.
  List<bool> musiqueActe = [true, true, true, true];
  List<double> volumeActe = [0.7, 0.7, 0.7, 0.7];
  List<double> fonduEntree = [3, 5, 5, 5];
  double fonduSortie = 2;
  List<double> silenceAvant = [0, 0, 0, 2];
  bool repliFamille = true;
  bool boucle = true;

  // Son Destiny (clés de `AudioService.effets`).
  String sonOuverture = 'storm';
  String sonDestiny = 'storm';

  /// Lancer la suite tant de secondes avant la fin du son Destiny (0 : on
  /// attend sa fin).
  double chevauchement = 0;

  // Bruitage du danger.
  List<bool> bruitageAuto = [false, true, true, true];
  double volumeBruitage = 0.9;
  double dureeMaxBruitage = 10;
  double fonduBruitage = 2;
  double decalageCodes = 0.8;

  // Atténuation de la musique sous un bruitage.
  double attenuation = 0.35;
  double remontee = 1.5;

  // Stinger de révélation (REVEAL).
  List<bool> revealActe = [false, false, true, false];

  /// Rang du stinger (0 = le fichier 1), ou -1 : au hasard.
  int revealFichier = 0;
  double revealMax = 8;

  // Banque de sons : le fichier choisi (rang, ou -1 : au hasard) et le
  // volume de chaque code.
  Map<String, int> choixCandidat = {};
  Map<String, double> volumeCode = {};

  // Fin du spectacle.
  bool conclusionFinChrono = false;
  bool coupureFinChrono = false;
  double fonduFin = 8;

  double volumeDe(String code) => volumeCode[code] ?? 1;

  Map<String, dynamic> versJson() => {
        'pack_actif': packActif,
        'musique_acte': musiqueActe,
        'volume_acte': volumeActe,
        'fondu_entree': fonduEntree,
        'fondu_sortie': fonduSortie,
        'silence_avant': silenceAvant,
        'repli_famille': repliFamille,
        'boucle': boucle,
        'son_ouverture': sonOuverture,
        'son_destiny': sonDestiny,
        'chevauchement': chevauchement,
        'bruitage_auto': bruitageAuto,
        'volume_bruitage': volumeBruitage,
        'duree_max_bruitage': dureeMaxBruitage,
        'fondu_bruitage': fonduBruitage,
        'decalage_codes': decalageCodes,
        'attenuation': attenuation,
        'remontee': remontee,
        'reveal_acte': revealActe,
        'reveal_fichier': revealFichier,
        'reveal_max': revealMax,
        'choix_candidat': choixCandidat,
        'volume_code': volumeCode,
        'conclusion_fin_chrono': conclusionFinChrono,
        'coupure_fin_chrono': coupureFinChrono,
        'fondu_fin': fonduFin,
      };

  static List<T> _quatre<T>(Object? j, List<T> defaut, T Function(Object) f) {
    if (j is! List || j.length != 4) return defaut;
    try {
      return [for (final x in j) f(x as Object)];
    } catch (_) {
      return defaut;
    }
  }

  static ValeursRegieSon depuisJson(Map<String, dynamic> j) {
    final v = ValeursRegieSon();
    double d(String k, double defaut) => (j[k] as num?)?.toDouble() ?? defaut;
    bool b(String k, bool defaut) => j[k] as bool? ?? defaut;
    double nombre(Object x) => (x as num).toDouble();
    bool booleen(Object x) => x as bool;
    v
      ..packActif = b('pack_actif', v.packActif)
      ..musiqueActe = _quatre(j['musique_acte'], v.musiqueActe, booleen)
      ..volumeActe = _quatre(j['volume_acte'], v.volumeActe, nombre)
      ..fonduEntree = _quatre(j['fondu_entree'], v.fonduEntree, nombre)
      ..fonduSortie = d('fondu_sortie', v.fonduSortie)
      ..silenceAvant = _quatre(j['silence_avant'], v.silenceAvant, nombre)
      ..repliFamille = b('repli_famille', v.repliFamille)
      ..boucle = b('boucle', v.boucle)
      ..sonOuverture = j['son_ouverture'] as String? ?? v.sonOuverture
      ..sonDestiny = j['son_destiny'] as String? ?? v.sonDestiny
      ..chevauchement = d('chevauchement', v.chevauchement)
      ..bruitageAuto = _quatre(j['bruitage_auto'], v.bruitageAuto, booleen)
      ..volumeBruitage = d('volume_bruitage', v.volumeBruitage)
      ..dureeMaxBruitage = d('duree_max_bruitage', v.dureeMaxBruitage)
      ..fonduBruitage = d('fondu_bruitage', v.fonduBruitage)
      ..decalageCodes = d('decalage_codes', v.decalageCodes)
      ..attenuation = d('attenuation', v.attenuation)
      ..remontee = d('remontee', v.remontee)
      ..revealActe = _quatre(j['reveal_acte'], v.revealActe, booleen)
      ..revealFichier = (j['reveal_fichier'] as num?)?.toInt() ?? v.revealFichier
      ..revealMax = d('reveal_max', v.revealMax)
      ..choixCandidat = {
        for (final e in (j['choix_candidat'] as Map? ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      }
      ..volumeCode = {
        for (final e in (j['volume_code'] as Map? ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      }
      ..conclusionFinChrono = b('conclusion_fin_chrono', v.conclusionFinChrono)
      ..coupureFinChrono = b('coupure_fin_chrono', v.coupureFinChrono)
      ..fonduFin = d('fondu_fin', v.fonduFin);
    return v;
  }
}

/// Les réglages de la régie son du spectacle, gardés tant qu'on ne les change
/// pas (SharedPreferences, comme les autres réglages).
class ReglagesRegieSon extends ChangeNotifier {
  ReglagesRegieSon([ValeursRegieSon? valeurs]) : _v = valeurs ?? ValeursRegieSon();

  static const String _cle = 'regie_son_spectacle_v1';

  ValeursRegieSon _v;
  ValeursRegieSon get v => _v;

  Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut != null) _v = ValeursRegieSon.depuisJson(jsonDecode(brut) as Map<String, dynamic>);
    } catch (_) {}
    notifyListeners();
  }

  /// Change une ou plusieurs valeurs, puis enregistre.
  Future<void> modifier(void Function(ValeursRegieSon v) f) async {
    f(_v);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, jsonEncode(_v.versJson()));
    } catch (_) {}
  }

  /// Revient aux valeurs de départ (la banque de sons comprise).
  Future<void> remettre() => modifier((v) => _v = ValeursRegieSon());
}
