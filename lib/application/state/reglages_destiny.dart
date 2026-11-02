import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/grammaire/chronos.dart';

/// Comment se déclenche le rituel Destiny pendant un spectacle.
enum Declenchement {
  /// Aux minutes prévues par le chrono.
  automatique,

  /// Seulement quand la régie appuie sur le bouton.
  manuel,

  /// Les deux : le chrono propose, la régie peut aussi le lancer avant.
  lesDeux;

  static Declenchement depuisTexte(String? s) {
    for (final d in Declenchement.values) {
      if (d.name == s) return d;
    }
    return Declenchement.lesDeux;
  }
}

/// Le thème de l'appli.
enum ThemeDestiny {
  sombre,
  clair,
  auto;

  static ThemeDestiny depuisTexte(String? s) {
    for (final t in ThemeDestiny.values) {
      if (t.name == s) return t;
    }
    return ThemeDestiny.sombre;
  }
}

/// Valeurs spéciales des choix de musique.
abstract final class ChoixMusique {
  static const String aucune = 'aucune';

  /// L'ambiance sonore du lieu joué.
  static const String lieu = 'lieu';

  /// Une musique importée tirée au hasard.
  static const String aleatoire = 'aleatoire';

  static const String commencement = 'music/01_commencement.m4a';
  static const String conclusion = 'music/02_conclusionainsique.m4a';
}

/// Les réglages de Destiny, gardés tant qu'on ne les change pas.
class ReglagesDestiny extends ChangeNotifier {
  ReglagesDestiny();

  static const String _cle = 'reglages_destiny_v1';

  // Chronos.
  List<ChronoSpectacle> _chronos = [...kChronosParDefaut];
  int _chronoChoisi = 1;
  Declenchement _declenchement = Declenchement.lesDeux;

  // Musiques des quatre moments, et la musique importée à chaque Destiny.
  String _musiqueDebut = ChoixMusique.commencement;
  String _sonDestiny = 'storm';
  String _ambianceActe2 = ChoixMusique.lieu;
  String _musiqueFin = ChoixMusique.conclusion;
  String _musiqueDestiny = ChoixMusique.aucune;

  // Rituel.
  bool _lumiereBleue = true;
  int _dureeFigeSecondes = 4;
  String _texteEllipse = '';
  bool _rappelPremierFige = true;
  bool _rappelsRegie = true;
  bool _reduireAnimations = false;

  // Distribution et jeu.
  int _joueursParDefaut = 4;
  String _modeDistribution = 'tirage';
  bool _leaderObligatoire = false;
  bool _moduleTraitre = false;
  bool _kidsParDefaut = false;
  int _minuteurEchauffement = 30;
  bool _afficherRepliques = true;

  // La Série, par défaut.
  bool _registreParDefaut = true;
  bool _combatParDefaut = true;
  bool _pieceParDefaut = true;
  bool _evolutionArchetype = true;

  // Apparence.
  ThemeDestiny _theme = ThemeDestiny.sombre;

  List<ChronoSpectacle> get chronos => List.unmodifiable(_chronos);
  int get chronoChoisi => _chronoChoisi.clamp(0, _chronos.length - 1);
  ChronoSpectacle get chrono => _chronos[chronoChoisi];
  Declenchement get declenchement => _declenchement;
  String get musiqueDebut => _musiqueDebut;
  String get sonDestiny => _sonDestiny;
  String get ambianceActe2 => _ambianceActe2;
  String get musiqueFin => _musiqueFin;
  String get musiqueDestiny => _musiqueDestiny;
  bool get lumiereBleue => _lumiereBleue;
  int get dureeFigeSecondes => _dureeFigeSecondes;

  /// Texte d'ellipse personnalisé (vide = celui de l'appli).
  String get texteEllipse => _texteEllipse;
  bool get rappelPremierFige => _rappelPremierFige;
  bool get rappelsRegie => _rappelsRegie;
  bool get reduireAnimations => _reduireAnimations;
  int get joueursParDefaut => _joueursParDefaut;
  String get modeDistribution => _modeDistribution;
  bool get leaderObligatoire => _leaderObligatoire;
  bool get moduleTraitre => _moduleTraitre;
  bool get kidsParDefaut => _kidsParDefaut;
  int get minuteurEchauffement => _minuteurEchauffement;
  bool get afficherRepliques => _afficherRepliques;
  bool get registreParDefaut => _registreParDefaut;
  bool get combatParDefaut => _combatParDefaut;
  bool get pieceParDefaut => _pieceParDefaut;

  /// Entre deux saisons, un personnage qui a payé son besoin peut changer
  /// d'archétype.
  bool get evolutionArchetype => _evolutionArchetype;
  ThemeDestiny get theme => _theme;

  Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) {
        // Reprise des anciens réglages de son du chrono (1.x).
        _sonDestiny = prefs.getString('son_destiny') ?? _sonDestiny;
        _musiqueDestiny = prefs.getString('son_destiny_musique') ?? _musiqueDestiny;
      } else {
        _depuisJson(jsonDecode(brut) as Map<String, dynamic>);
      }
    } catch (_) {}
    notifyListeners();
  }

  void _depuisJson(Map<String, dynamic> j) {
    final chronos = [
      for (final c in (j['chronos'] as List? ?? const [])) ChronoSpectacle.depuisJson(c),
    ].whereType<ChronoSpectacle>().toList();
    if (chronos.length == kChronosParDefaut.length) _chronos = chronos;
    _chronoChoisi = (j['chrono_choisi'] as num?)?.toInt() ?? _chronoChoisi;
    _declenchement = Declenchement.depuisTexte(j['declenchement'] as String?);
    _musiqueDebut = j['musique_debut'] as String? ?? _musiqueDebut;
    _sonDestiny = j['son_destiny'] as String? ?? _sonDestiny;
    _ambianceActe2 = j['ambiance_acte2'] as String? ?? _ambianceActe2;
    _musiqueFin = j['musique_fin'] as String? ?? _musiqueFin;
    _musiqueDestiny = j['musique_destiny'] as String? ?? _musiqueDestiny;
    _lumiereBleue = j['lumiere_bleue'] as bool? ?? _lumiereBleue;
    _dureeFigeSecondes = (j['duree_fige'] as num?)?.toInt() ?? _dureeFigeSecondes;
    _texteEllipse = j['texte_ellipse'] as String? ?? _texteEllipse;
    _rappelPremierFige = j['rappel_premier_fige'] as bool? ?? _rappelPremierFige;
    _rappelsRegie = j['rappels_regie'] as bool? ?? _rappelsRegie;
    _reduireAnimations = j['reduire_animations'] as bool? ?? _reduireAnimations;
    _joueursParDefaut = (j['joueurs'] as num?)?.toInt() ?? _joueursParDefaut;
    _modeDistribution = j['mode_distribution'] as String? ?? _modeDistribution;
    _leaderObligatoire = j['leader_obligatoire'] as bool? ?? _leaderObligatoire;
    _moduleTraitre = j['module_traitre'] as bool? ?? _moduleTraitre;
    _kidsParDefaut = j['kids'] as bool? ?? _kidsParDefaut;
    _minuteurEchauffement = (j['echauffement'] as num?)?.toInt() ?? _minuteurEchauffement;
    _afficherRepliques = j['repliques'] as bool? ?? _afficherRepliques;
    _registreParDefaut = j['serie_registre'] as bool? ?? _registreParDefaut;
    _combatParDefaut = j['serie_combat'] as bool? ?? _combatParDefaut;
    _pieceParDefaut = j['serie_piece'] as bool? ?? _pieceParDefaut;
    _evolutionArchetype = j['evolution_archetype'] as bool? ?? _evolutionArchetype;
    _theme = ThemeDestiny.depuisTexte(j['theme'] as String?);
  }

  Map<String, dynamic> versJson() => {
        'chronos': [for (final c in _chronos) c.versJson()],
        'chrono_choisi': _chronoChoisi,
        'declenchement': _declenchement.name,
        'musique_debut': _musiqueDebut,
        'son_destiny': _sonDestiny,
        'ambiance_acte2': _ambianceActe2,
        'musique_fin': _musiqueFin,
        'musique_destiny': _musiqueDestiny,
        'lumiere_bleue': _lumiereBleue,
        'duree_fige': _dureeFigeSecondes,
        'texte_ellipse': _texteEllipse,
        'rappel_premier_fige': _rappelPremierFige,
        'rappels_regie': _rappelsRegie,
        'reduire_animations': _reduireAnimations,
        'joueurs': _joueursParDefaut,
        'mode_distribution': _modeDistribution,
        'leader_obligatoire': _leaderObligatoire,
        'module_traitre': _moduleTraitre,
        'kids': _kidsParDefaut,
        'echauffement': _minuteurEchauffement,
        'repliques': _afficherRepliques,
        'serie_registre': _registreParDefaut,
        'serie_combat': _combatParDefaut,
        'serie_piece': _pieceParDefaut,
        'evolution_archetype': _evolutionArchetype,
        'theme': _theme.name,
      };

  Future<void> _sauver() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, jsonEncode(versJson()));
    } catch (_) {}
  }

  /// Change un des chronos de base (il doit rester valide).
  Future<bool> modifierChrono(int index, ChronoSpectacle c) async {
    if (!c.valide || index < 0 || index >= _chronos.length) return false;
    _chronos[index] = c;
    await _sauver();
    return true;
  }

  Future<void> remettreChronos() async {
    _chronos = [...kChronosParDefaut];
    await _sauver();
  }

  Future<void> choisirChrono(int index) async {
    _chronoChoisi = index;
    await _sauver();
  }

  Future<void> changer({
    Declenchement? declenchement,
    String? musiqueDebut,
    String? sonDestiny,
    String? ambianceActe2,
    String? musiqueFin,
    String? musiqueDestiny,
    bool? lumiereBleue,
    int? dureeFigeSecondes,
    String? texteEllipse,
    bool? rappelPremierFige,
    bool? rappelsRegie,
    bool? reduireAnimations,
    int? joueursParDefaut,
    String? modeDistribution,
    bool? leaderObligatoire,
    bool? moduleTraitre,
    bool? kidsParDefaut,
    int? minuteurEchauffement,
    bool? afficherRepliques,
    bool? registreParDefaut,
    bool? combatParDefaut,
    bool? pieceParDefaut,
    bool? evolutionArchetype,
    ThemeDestiny? theme,
  }) async {
    _declenchement = declenchement ?? _declenchement;
    _musiqueDebut = musiqueDebut ?? _musiqueDebut;
    _sonDestiny = sonDestiny ?? _sonDestiny;
    _ambianceActe2 = ambianceActe2 ?? _ambianceActe2;
    _musiqueFin = musiqueFin ?? _musiqueFin;
    _musiqueDestiny = musiqueDestiny ?? _musiqueDestiny;
    _lumiereBleue = lumiereBleue ?? _lumiereBleue;
    _dureeFigeSecondes = (dureeFigeSecondes ?? _dureeFigeSecondes).clamp(1, 15);
    _texteEllipse = texteEllipse ?? _texteEllipse;
    _rappelPremierFige = rappelPremierFige ?? _rappelPremierFige;
    _rappelsRegie = rappelsRegie ?? _rappelsRegie;
    _reduireAnimations = reduireAnimations ?? _reduireAnimations;
    _joueursParDefaut = (joueursParDefaut ?? _joueursParDefaut).clamp(4, 6);
    _modeDistribution = modeDistribution ?? _modeDistribution;
    _leaderObligatoire = leaderObligatoire ?? _leaderObligatoire;
    _moduleTraitre = moduleTraitre ?? _moduleTraitre;
    _kidsParDefaut = kidsParDefaut ?? _kidsParDefaut;
    _minuteurEchauffement = (minuteurEchauffement ?? _minuteurEchauffement).clamp(5, 90);
    _afficherRepliques = afficherRepliques ?? _afficherRepliques;
    _registreParDefaut = registreParDefaut ?? _registreParDefaut;
    _combatParDefaut = combatParDefaut ?? _combatParDefaut;
    _pieceParDefaut = pieceParDefaut ?? _pieceParDefaut;
    _evolutionArchetype = evolutionArchetype ?? _evolutionArchetype;
    _theme = theme ?? _theme;
    await _sauver();
  }
}
