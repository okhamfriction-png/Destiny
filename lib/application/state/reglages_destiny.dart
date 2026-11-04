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

  // La musique de chaque acte (la 1ʳᵉ au début, puis une après chaque
  // Destiny), le son de Destiny et la musique importée à chaque Destiny.
  static const List<String> musiquesActesParDefaut = [
    ChoixMusique.commencement,
    ChoixMusique.aucune,
    ChoixMusique.lieu,
    ChoixMusique.conclusion,
  ];
  List<String> _musiquesActes = [...musiquesActesParDefaut];
  String _sonDestiny = 'storm';
  String _musiqueDestiny = ChoixMusique.aucune;

  /// Le bouton « Son » de la régie (la tablette son en fenêtre).
  bool _regieSon = true;

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

  // L'accueil « Découvrir Destiny », vu une fois au premier lancement.
  bool _decouverteVue = false;

  List<ChronoSpectacle> get chronos => List.unmodifiable(_chronos);
  int get chronoChoisi => _chronoChoisi.clamp(0, _chronos.length - 1);
  ChronoSpectacle get chrono => _chronos[chronoChoisi];
  Declenchement get declenchement => _declenchement;
  /// La musique de l'acte [acte] (1 à 4) : l'acte 1 au début du spectacle,
  /// l'acte n + 1 après le n-ième Destiny.
  String musiqueActe(int acte) => _musiquesActes[(acte - 1).clamp(0, 3)];
  List<String> get musiquesActes => List.unmodifiable(_musiquesActes);

  /// Les noms d'avant la 2.0.3 : l'acte 1, l'acte 3 et l'acte 4.
  String get musiqueDebut => musiqueActe(1);
  String get ambianceActe2 => musiqueActe(3);
  String get musiqueFin => musiqueActe(4);
  String get sonDestiny => _sonDestiny;
  String get musiqueDestiny => _musiqueDestiny;
  bool get regieSon => _regieSon;
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
  /// Ancien « public par défaut » (avant la 2.1.0) : gardé, mais l'appli ne
  /// s'en sert plus. Le mode enfant ou adulte se choisit en entrant dans le
  /// jeu de rôle, et le théâtre se joue toujours en adulte.
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

  /// Vrai une fois l'accueil « Découvrir Destiny » vu (ou passé).
  bool get decouverteVue => _decouverteVue;

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
    final actes = [for (final x in (j['musiques_actes'] as List? ?? const [])) if (x is String) x];
    if (actes.length == 4) {
      _musiquesActes = actes;
    } else {
      // Avant la 2.0.3 : le début, l'ambiance après le 2ᵉ Destiny et la fin ;
      // rien après le 1er.
      _musiquesActes = [
        j['musique_debut'] as String? ?? _musiquesActes[0],
        ChoixMusique.aucune,
        j['ambiance_acte2'] as String? ?? _musiquesActes[2],
        j['musique_fin'] as String? ?? _musiquesActes[3],
      ];
    }
    _sonDestiny = j['son_destiny'] as String? ?? _sonDestiny;
    _musiqueDestiny = j['musique_destiny'] as String? ?? _musiqueDestiny;
    _regieSon = j['regie_son'] as bool? ?? _regieSon;
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
    _decouverteVue = j['decouverte_vue'] as bool? ?? _decouverteVue;
  }

  Map<String, dynamic> versJson() => {
        'chronos': [for (final c in _chronos) c.versJson()],
        'chrono_choisi': _chronoChoisi,
        'declenchement': _declenchement.name,
        'musiques_actes': _musiquesActes,
        // Les anciennes clés, gardées pour une version d'avant la 2.0.3.
        'musique_debut': musiqueActe(1),
        'ambiance_acte2': musiqueActe(3),
        'musique_fin': musiqueActe(4),
        'son_destiny': _sonDestiny,
        'musique_destiny': _musiqueDestiny,
        'regie_son': _regieSon,
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
        'decouverte_vue': _decouverteVue,
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

  /// Change la musique de l'acte [acte] (1 à 4).
  Future<void> changerMusiqueActe(int acte, String choix) async {
    if (acte < 1 || acte > 4) return;
    _musiquesActes = [..._musiquesActes]..[acte - 1] = choix;
    await _sauver();
  }

  Future<void> changer({
    Declenchement? declenchement,
    String? musiqueDebut,
    String? sonDestiny,
    String? ambianceActe2,
    String? musiqueFin,
    String? musiqueDestiny,
    bool? regieSon,
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
    bool? decouverteVue,
  }) async {
    _declenchement = declenchement ?? _declenchement;
    // Les anciens noms : l'acte 1, l'acte 3 et l'acte 4.
    _musiquesActes = [
      musiqueDebut ?? _musiquesActes[0],
      _musiquesActes[1],
      ambianceActe2 ?? _musiquesActes[2],
      musiqueFin ?? _musiquesActes[3],
    ];
    _sonDestiny = sonDestiny ?? _sonDestiny;
    _musiqueDestiny = musiqueDestiny ?? _musiqueDestiny;
    _regieSon = regieSon ?? _regieSon;
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
    _decouverteVue = decouverteVue ?? _decouverteVue;
    await _sauver();
  }
}
