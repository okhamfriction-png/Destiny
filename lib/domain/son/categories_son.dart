/// Les rayons de la table de régie : les bruitages du pack rangés par
/// famille de son, pour trouver vite le bon pad pendant le spectacle.
library;

/// Une famille de bruitages (l'icône et la couleur sont côté interface).
enum CategorieBruitage {
  alertes,
  feu,
  eau,
  meteo,
  structure,
  portes,
  creatures,
  machines,
  surnaturel,
  corps,
  autres;

  /// La famille de [code] (« Autres » pour un code inconnu, ajouté plus tard).
  static CategorieBruitage de(String code) => _parCode[code] ?? autres;

  /// Les codes connus de cette famille.
  List<String> get codes => [
        for (final e in _parCode.entries)
          if (e.value == this) e.key,
      ];
}

const Map<String, CategorieBruitage> _parCode = {
  // Alertes et signaux.
  'ALARME': CategorieBruitage.alertes,
  'ALARME_INCENDIE': CategorieBruitage.alertes,
  'SIRENES': CategorieBruitage.alertes,
  'SIRENE_TORNADE': CategorieBruitage.alertes,
  'BIP_COMPTE': CategorieBruitage.alertes,
  'BUZZER': CategorieBruitage.alertes,
  'CORNE': CategorieBruitage.alertes,
  'TALKIE': CategorieBruitage.alertes,
  'JEU_COMPTE': CategorieBruitage.alertes,
  'JEU_JINGLE': CategorieBruitage.alertes,
  // Feu, armes et explosions.
  'FEU_CREPITE': CategorieBruitage.feu,
  'INCENDIE': CategorieBruitage.feu,
  'EXPLOSION': CategorieBruitage.feu,
  'DETONATIONS_LOIN': CategorieBruitage.feu,
  'TIRS': CategorieBruitage.feu,
  'ARME_CHARGEE': CategorieBruitage.feu,
  'VOLCAN': CategorieBruitage.feu,
  'CENDRES': CategorieBruitage.feu,
  'GAZ_SIFFLE': CategorieBruitage.feu,
  'ETINCELLES': CategorieBruitage.feu,
  // Eau.
  'EAU_ENGOUFFRE': CategorieBruitage.eau,
  'EAU_GOUTTE': CategorieBruitage.eau,
  'BULLES': CategorieBruitage.eau,
  'VAGUE': CategorieBruitage.eau,
  'MER_RETIRE': CategorieBruitage.eau,
  'COQUE': CategorieBruitage.eau,
  // Météo et nature.
  'TONNERRE': CategorieBruitage.meteo,
  'TEMPETE': CategorieBruitage.meteo,
  'VENT': CategorieBruitage.meteo,
  'TORNADE': CategorieBruitage.meteo,
  'BROUILLARD': CategorieBruitage.meteo,
  'GLACE': CategorieBruitage.meteo,
  'NATURE_NUIT': CategorieBruitage.meteo,
  'SOLEIL_CHALEUR': CategorieBruitage.meteo,
  'SOLEIL_FROID': CategorieBruitage.meteo,
  // Structure qui cède.
  'EFFONDREMENT': CategorieBruitage.structure,
  'GRONDEMENT': CategorieBruitage.structure,
  'SECOUSSE': CategorieBruitage.structure,
  'SOL_CRAQUE': CategorieBruitage.structure,
  'TOIT_CRAQUE': CategorieBruitage.structure,
  'METAL_TORDU': CategorieBruitage.structure,
  'PIERRE_RACLE': CategorieBruitage.structure,
  'OBJET_TOMBE': CategorieBruitage.structure,
  'VERRE_BRISE': CategorieBruitage.structure,
  'VERRE_FISSURE': CategorieBruitage.structure,
  // Portes, couloirs et lumière : on est enfermés.
  'PORTE_CLAQUE': CategorieBruitage.portes,
  'PORTE_GRINCE': CategorieBruitage.portes,
  'PORTE_METAL': CategorieBruitage.portes,
  'VERROUS': CategorieBruitage.portes,
  'COUPS_PORTE': CategorieBruitage.portes,
  'PAS': CategorieBruitage.portes,
  'COUPURE': CategorieBruitage.portes,
  'NEON': CategorieBruitage.portes,
  'VENTIL_STOP': CategorieBruitage.portes,
  // Créatures.
  'CREATURE': CategorieBruitage.creatures,
  'CREATURE_CRI': CategorieBruitage.creatures,
  'MONSTRE_RUGIT': CategorieBruitage.creatures,
  'MEUTE': CategorieBruitage.creatures,
  'ESSAIM': CategorieBruitage.creatures,
  'ZOMBIES': CategorieBruitage.creatures,
  'GRIFFES': CategorieBruitage.creatures,
  'PAS_GEANTS': CategorieBruitage.creatures,
  // Machines et IA.
  'ROBOT_PAS': CategorieBruitage.machines,
  'ROBOT_SERVO': CategorieBruitage.machines,
  'IA_GLITCH': CategorieBruitage.machines,
  'IA_SURCHARGE': CategorieBruitage.machines,
  'IA_VERROU': CategorieBruitage.machines,
  'PNEUS': CategorieBruitage.machines,
  'HELICO': CategorieBruitage.machines,
  // Surnaturel.
  'ALIEN_SCELLE': CategorieBruitage.surnaturel,
  'ALIEN_SIGNAL': CategorieBruitage.surnaturel,
  'ALIEN_SONDE': CategorieBruitage.surnaturel,
  'PACTE_RITUEL': CategorieBruitage.surnaturel,
  'PACTE_SOUFFLE': CategorieBruitage.surnaturel,
  // Le corps.
  'COEUR': CategorieBruitage.corps,
  'MONITEUR': CategorieBruitage.corps,
  'RESPIRATION': CategorieBruitage.corps,
  'TOUX': CategorieBruitage.corps,
  'FOULE': CategorieBruitage.corps,
};

/// L'émotion d'une piste de la bibliothèque (« Colère 2 » → « Colère »).
String emotionDe(String titre) => titre.replaceFirst(RegExp(r'\s*\d+\s*$'), '').trim();
