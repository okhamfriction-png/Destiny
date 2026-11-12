import 'package:flutter/material.dart';

import '../../domain/son/categories_son.dart';

/// La console de la régie : toujours sombre, comme une vraie table de régie
/// dans le noir de la salle.
abstract final class Console {
  static const Color fond = Color(0xFF0B0B0D);
  static const Color panneau = Color(0xFF141417);
  static const Color pad = Color(0xFF1C1C21);
  static const Color padHaut = Color(0xFF26262D);
  static const Color trait = Color(0xFF2E2E36);
  static const Color texte = Color(0xFFEDEDEF);
  static const Color doux = Color(0xFF9B9BA4);
  static const Color or = Color(0xFFE6B446);
  static const Color bleuDestiny = Color(0xFF3D7BFF);
  static const Color rouge = Color(0xFFFF4D4D);
  static const Color vert = Color(0xFF3DDC84);
}

/// L'icône et la couleur d'un pad.
class StyleSon {
  const StyleSon(this.icone, this.couleur);

  final IconData icone;
  final Color couleur;
}

const Map<CategorieBruitage, StyleSon> kStylesCategories = {
  CategorieBruitage.alertes: StyleSon(Icons.notifications_active_rounded, Color(0xFFFF5A5F)),
  CategorieBruitage.feu: StyleSon(Icons.local_fire_department_rounded, Color(0xFFFF8A3D)),
  CategorieBruitage.eau: StyleSon(Icons.water_rounded, Color(0xFF3FA7FF)),
  CategorieBruitage.meteo: StyleSon(Icons.thunderstorm_rounded, Color(0xFF7DD3FC)),
  CategorieBruitage.structure: StyleSon(Icons.domain_disabled_rounded, Color(0xFFC9A27E)),
  CategorieBruitage.portes: StyleSon(Icons.sensor_door_rounded, Color(0xFFA78BFA)),
  CategorieBruitage.creatures: StyleSon(Icons.pets_rounded, Color(0xFF4ADE80)),
  CategorieBruitage.machines: StyleSon(Icons.smart_toy_rounded, Color(0xFF94A3B8)),
  CategorieBruitage.surnaturel: StyleSon(Icons.auto_awesome_rounded, Color(0xFFE879F9)),
  CategorieBruitage.corps: StyleSon(Icons.favorite_rounded, Color(0xFFF472B6)),
  CategorieBruitage.autres: StyleSon(Icons.graphic_eq_rounded, Color(0xFF9CA3AF)),
};

const Map<String, IconData> _iconesCodes = {
  'ALARME': Icons.notifications_active_rounded,
  'ALARME_INCENDIE': Icons.fire_extinguisher_rounded,
  'SIRENES': Icons.emergency_rounded,
  'SIRENE_TORNADE': Icons.campaign_rounded,
  'BIP_COMPTE': Icons.timer_rounded,
  'BUZZER': Icons.radio_button_checked_rounded,
  'CORNE': Icons.campaign_rounded,
  'TALKIE': Icons.settings_input_antenna_rounded,
  'JEU_COMPTE': Icons.hourglass_bottom_rounded,
  'JEU_JINGLE': Icons.casino_rounded,
  'FEU_CREPITE': Icons.fireplace_rounded,
  'INCENDIE': Icons.local_fire_department_rounded,
  'EXPLOSION': Icons.flare_rounded,
  'DETONATIONS_LOIN': Icons.blur_on_rounded,
  'TIRS': Icons.gps_fixed_rounded,
  'ARME_CHARGEE': Icons.my_location_rounded,
  'VOLCAN': Icons.volcano_rounded,
  'CENDRES': Icons.grain_rounded,
  'GAZ_SIFFLE': Icons.gas_meter_rounded,
  'ETINCELLES': Icons.electric_bolt_rounded,
  'EAU_ENGOUFFRE': Icons.water_rounded,
  'EAU_GOUTTE': Icons.water_drop_rounded,
  'BULLES': Icons.bubble_chart_rounded,
  'VAGUE': Icons.tsunami_rounded,
  'MER_RETIRE': Icons.waves_rounded,
  'COQUE': Icons.sailing_rounded,
  'TONNERRE': Icons.thunderstorm_rounded,
  'TEMPETE': Icons.storm_rounded,
  'VENT': Icons.air_rounded,
  'TORNADE': Icons.cyclone_rounded,
  'BROUILLARD': Icons.foggy,
  'GLACE': Icons.ac_unit_rounded,
  'NATURE_NUIT': Icons.nightlight_round,
  'SOLEIL_CHALEUR': Icons.wb_sunny_rounded,
  'SOLEIL_FROID': Icons.severe_cold_rounded,
  'EFFONDREMENT': Icons.domain_disabled_rounded,
  'GRONDEMENT': Icons.vibration_rounded,
  'SECOUSSE': Icons.vibration_rounded,
  'SOL_CRAQUE': Icons.landslide_rounded,
  'TOIT_CRAQUE': Icons.roofing_rounded,
  'METAL_TORDU': Icons.construction_rounded,
  'PIERRE_RACLE': Icons.view_in_ar_rounded,
  'OBJET_TOMBE': Icons.south_rounded,
  'VERRE_BRISE': Icons.broken_image_rounded,
  'VERRE_FISSURE': Icons.broken_image_outlined,
  'PORTE_CLAQUE': Icons.door_front_door_rounded,
  'PORTE_GRINCE': Icons.sensor_door_rounded,
  'PORTE_METAL': Icons.lock_rounded,
  'VERROUS': Icons.enhanced_encryption_rounded,
  'COUPS_PORTE': Icons.front_hand_rounded,
  'PAS': Icons.directions_walk_rounded,
  'COUPURE': Icons.power_off_rounded,
  'NEON': Icons.light_rounded,
  'VENTIL_STOP': Icons.mode_fan_off_rounded,
  'CREATURE': Icons.pets_rounded,
  'CREATURE_CRI': Icons.record_voice_over_rounded,
  'MONSTRE_RUGIT': Icons.pest_control_rounded,
  'MEUTE': Icons.pets_rounded,
  'ESSAIM': Icons.bug_report_rounded,
  'ZOMBIES': Icons.personal_injury_rounded,
  'GRIFFES': Icons.content_cut_rounded,
  'PAS_GEANTS': Icons.directions_run_rounded,
  'ROBOT_PAS': Icons.smart_toy_rounded,
  'ROBOT_SERVO': Icons.precision_manufacturing_rounded,
  'IA_GLITCH': Icons.memory_rounded,
  'IA_SURCHARGE': Icons.bolt_rounded,
  'IA_VERROU': Icons.lock_person_rounded,
  'PNEUS': Icons.directions_car_rounded,
  'HELICO': Icons.flight_rounded,
  'ALIEN_SCELLE': Icons.shield_rounded,
  'ALIEN_SIGNAL': Icons.cell_tower_rounded,
  'ALIEN_SONDE': Icons.rocket_rounded,
  'PACTE_RITUEL': Icons.menu_book_rounded,
  'PACTE_SOUFFLE': Icons.blur_circular_rounded,
  'COEUR': Icons.favorite_rounded,
  'MONITEUR': Icons.monitor_heart_rounded,
  'RESPIRATION': Icons.air_rounded,
  'TOUX': Icons.sick_rounded,
  'FOULE': Icons.groups_rounded,
};

/// Le style d'un pad de bruitage : l'icône du son, la couleur de sa famille.
StyleSon styleCode(String code) {
  final c = kStylesCategories[CategorieBruitage.de(code)]!;
  return StyleSon(_iconesCodes[code] ?? c.icone, c.couleur);
}

const Map<String, StyleSon> _emotions = {
  'Joie': StyleSon(Icons.sentiment_very_satisfied_rounded, Color(0xFFFFD54F)),
  'Colère': StyleSon(Icons.sentiment_very_dissatisfied_rounded, Color(0xFFFF5252)),
  'Peur': StyleSon(Icons.mood_bad_rounded, Color(0xFFB388FF)),
  'Tristesse': StyleSon(Icons.water_drop_rounded, Color(0xFF64B5F6)),
  'Mystère': StyleSon(Icons.visibility_rounded, Color(0xFF9575CD)),
  'Tension': StyleSon(Icons.bolt_rounded, Color(0xFFFF9100)),
  'Surprise': StyleSon(Icons.priority_high_rounded, Color(0xFFFFEA00)),
  'Trahison': StyleSon(Icons.heart_broken_rounded, Color(0xFFE53935)),
  'Traque': StyleSon(Icons.directions_run_rounded, Color(0xFF66BB6A)),
  'Climax': StyleSon(Icons.whatshot_rounded, Color(0xFFFF6E40)),
  'Nostalgie': StyleSon(Icons.history_rounded, Color(0xFFD7B98E)),
  'Recueillement': StyleSon(Icons.self_improvement_rounded, Color(0xFF4DB6AC)),
  'Émerveillement': StyleSon(Icons.auto_awesome_rounded, Color(0xFFFFD180)),
};

/// Le style d'une piste « Émotions » (« Colère 2 » prend celui de la colère).
StyleSon styleEmotion(String titre) {
  final e = emotionDe(titre);
  return _emotions[e] ??
      _emotions.entries
          .firstWhere((x) => x.key.toLowerCase().substring(0, 4) == e.toLowerCase().padRight(4).substring(0, 4),
              orElse: () => const MapEntry('', StyleSon(Icons.music_note_rounded, Color(0xFFE6B446))))
          .value;
}

const Map<String, IconData> _ambiances = {
  'Blizzard': Icons.ac_unit_rounded,
  'Forêt': Icons.forest_rounded,
  'Grotte': Icons.terrain_rounded,
  'Marais': Icons.grass_rounded,
  'Navire': Icons.sailing_rounded,
  'Orage': Icons.thunderstorm_rounded,
  'Plage': Icons.beach_access_rounded,
  'Taverne': Icons.sports_bar_rounded,
  'Ville': Icons.location_city_rounded,
  'Volcan': Icons.volcano_rounded,
  'Égouts': Icons.plumbing_rounded,
};

StyleSon styleAmbiance(String titre) => StyleSon(_ambiances[titre] ?? Icons.landscape_rounded, const Color(0xFF4FC3F7));

const Map<String, IconData> _themes = {
  'Commencement': Icons.play_circle_rounded,
  'Conclusion': Icons.flag_rounded,
  'Ashen Oath': Icons.shield_moon_rounded,
  'Destiny Storm': Icons.flash_on_rounded,
};

StyleSon styleTheme(String titre) => StyleSon(_themes[titre] ?? Icons.music_note_rounded, Console.or);

const Map<String, IconData> _effets = {
  'storm': Icons.flash_on_rounded,
  'thunder': Icons.thunderstorm_rounded,
  'coin': Icons.monetization_on_rounded,
  'crack': Icons.broken_image_rounded,
  'shine': Icons.auto_awesome_rounded,
  'story': Icons.menu_book_rounded,
  'reveal': Icons.visibility_rounded,
  'dice': Icons.casino_rounded,
};

StyleSon styleEffet(String cle) => StyleSon(_effets[cle] ?? Icons.graphic_eq_rounded, const Color(0xFFFFB74D));
