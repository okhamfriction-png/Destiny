import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';

/// Description visuelle d'une entité : une « image » générée localement
/// (dégradé + icône Material ou emoji), sans aucun téléchargement.
class EntityVisual {
  const EntityVisual({
    required this.gradient,
    this.icon,
    this.emoji,
    this.query,
    this.assetPath,
  });

  final List<Color> gradient;
  final IconData? icon;
  final String? emoji;

  /// Terme de recherche (en anglais) pour récupérer une vraie photo.
  final String? query;

  /// Chemin de l'image IA locale (assets/images/...), si disponible.
  final String? assetPath;
}

class EntityVisuals {
  EntityVisuals._();

  static const List<List<Color>> _locationPalettes = [
    [Color(0xFF2E3192), Color(0xFF1BFFFF)],
    [Color(0xFF373B44), Color(0xFF4286f4)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFF614385), Color(0xFF516395)],
    [Color(0xFF0F2027), Color(0xFF2C5364)],
    [Color(0xFF4B6CB7), Color(0xFF182848)],
    [Color(0xFF5C258D), Color(0xFF4389A2)],
    [Color(0xFF1D4350), Color(0xFFA43931)],
    [Color(0xFF42275A), Color(0xFF734B6D)],
    [Color(0xFF135058), Color(0xFFF1F2B5)],
  ];

  static const Map<String, IconData> _locationIcons = {
    'aeroport': Icons.flight,
    'laboratoire': Icons.science,
    'hotel_luxe': Icons.hotel,
    'ferme': Icons.agriculture,
    'bunker_militaire': Icons.military_tech,
    'bibliotheque': Icons.local_library,
    'usine': Icons.factory,
    'restaurant_gastronomique': Icons.restaurant,
    'commissariat': Icons.local_police,
    'centre_commercial': Icons.local_mall,
    'zoo': Icons.pets,
    'musee': Icons.museum,
    'camping': Icons.holiday_village,
    'plateau_tele': Icons.tv,
    'boite_nuit': Icons.nightlife,
    'base_spatiale': Icons.rocket_launch,
    'bureau': Icons.business_center,
    'palais_presidentiel': Icons.account_balance,
    'manoir_abandonne': Icons.castle,
    'prison': Icons.lock,
    'stade': Icons.stadium,
    'refuge_montagne': Icons.terrain,
    'banque': Icons.account_balance_wallet,
    'aquarium': Icons.water,
    'avion': Icons.flight,
    'port_maritime': Icons.anchor,
    'eglise': Icons.church,
    'salle_sport': Icons.fitness_center,
    'foret': Icons.forest,
    'sous_marin': Icons.scuba_diving,
    'metro': Icons.subway,
    'navire_croisiere': Icons.directions_boat,
    'universite': Icons.school,
    'hopital': Icons.local_hospital,
    'ecole': Icons.backpack,
    'supermarche': Icons.shopping_cart,
    'casino': Icons.casino,
    'theatre': Icons.theater_comedy,
    'tribunal': Icons.gavel,
    'station_service': Icons.local_gas_station,
  };

  // --- Style de danger -> icône + dégradé ---
  static const Map<String, IconData> _styleIcons = {
    'Catastrophe': Icons.crisis_alert,
    'Fantastique': Icons.auto_awesome,
    'Mystère': Icons.search,
    'Social / Dilemme': Icons.groups,
    'Survie / Dilemme': Icons.health_and_safety,
    'Thriller': Icons.bolt,
  };

  static const Map<String, List<Color>> _styleGradients = {
    'Catastrophe': [Color(0xFFFF512F), Color(0xFFDD2476)],
    'Fantastique': [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    'Mystère': [Color(0xFF0F2027), Color(0xFF2C5364)],
    'Social / Dilemme': [Color(0xFFF7971E), Color(0xFFFFD200)],
    'Survie / Dilemme': [Color(0xFF11998E), Color(0xFF38EF7D)],
    'Thriller': [Color(0xFF232526), Color(0xFFE53935)],
  };

  // --- Termes de recherche (anglais) pour les vraies photos ---
  static const Map<String, String> _locationQueries = {
    'aeroport': 'airport terminal',
    'laboratoire': 'science laboratory',
    'hotel_luxe': 'luxury hotel lobby',
    'ferme': 'farm countryside',
    'bunker_militaire': 'military bunker',
    'bibliotheque': 'library books',
    'usine': 'factory industrial',
    'restaurant_gastronomique': 'fine dining restaurant',
    'commissariat': 'police station',
    'centre_commercial': 'shopping mall',
    'zoo': 'zoo animals',
    'musee': 'art museum',
    'camping': 'campsite tent',
    'plateau_tele': 'television studio',
    'boite_nuit': 'nightclub',
    'base_spatiale': 'space station',
    'bureau': 'office workplace',
    'palais_presidentiel': 'presidential palace',
    'manoir_abandonne': 'abandoned mansion',
    'prison': 'prison cell',
    'stade': 'sports stadium',
    'refuge_montagne': 'mountain hut',
    'banque': 'bank interior',
    'aquarium': 'aquarium fish',
    'avion': 'airplane cabin in flight',
    'port_maritime': 'harbor port',
    'eglise': 'church interior',
    'salle_sport': 'gym fitness',
    'foret': 'forest woods',
    'sous_marin': 'submarine interior',
    'metro': 'subway train',
    'navire_croisiere': 'cruise ship',
    'universite': 'university campus',
    'hopital': 'hospital',
    'ecole': 'school classroom',
    'supermarche': 'supermarket',
    'casino': 'casino',
    'theatre': 'theater stage',
    'tribunal': 'courtroom',
    'station_service': 'gas station',
  };

  static const Map<String, String> _dangerQueries = {
    'crash_exterieur': 'crash wreckage debris',
    'effondrement_batiment': 'building collapse',
    'emeute_hostile': 'riot crowd',
    'incendie': 'fire flames',
    'inondation': 'flood water',
    'nuage_toxique': 'toxic smoke',
    'reaction_chimique': 'chemical reaction',
    'siege_arme': 'siege soldiers',
    'tempete': 'storm lightning',
    'tremblement_terre': 'earthquake ruins',
    'apparition_spectrale': 'ghost spooky',
    'boucle_temporelle': 'clock time',
    'brume_etrange': 'fog mist',
    'invasion_creature': 'monster creature',
    'lois_physiques_dereglees': 'surreal gravity',
    'malediction_ancienne': 'ancient curse skull',
    'objet_maudit': 'cursed object',
    'pacte_ancien': 'ritual candles occult',
    'possession_progressive': 'possession horror',
    'presence_invisible_hostile': 'dark shadow',
    'prophetie_maudite': 'ancient scroll',
    'cadavre_decouvert': 'crime scene',
    'intrusion_imminente': 'intruder door',
    'disparition_inexpliquee': 'missing person',
    'message_anonyme_menacant': 'threatening letter',
    'ceremonie_irreversible': 'ceremony ritual',
    'heritage_ultimatum': 'last will testament',
    'mariage_force': 'wedding rings',
    'proche_condamne': 'hospital bed',
    'accouchement_imminent': 'newborn baby',
    'coupure_monde_exterieur': 'isolated darkness',
    'empoisonnement_collectif': 'poison vial',
    'execution_annoncee': 'prison execution',
    'maladie_contagieuse': 'virus contagion',
    'bombe_retardement': 'time bomb',
    'chantage': 'blackmail money',
    'video_compromettante': 'hidden camera',
    'prise_otage': 'hostage',
    'tueur_en_serie': 'crime knife',
    'sabotage_en_cours': 'sabotage wires',
  };

  static List<Color> _paletteFor(String id) {
    final index = id.hashCode.abs() % _locationPalettes.length;
    return _locationPalettes[index];
  }

  static EntityVisual forLocation(Location location) {
    return EntityVisual(
      gradient: _paletteFor(location.id),
      icon: _locationIcons[location.id] ?? Icons.place,
      query: _locationQueries[location.id] ?? location.name,
      assetPath: 'assets/images/locations/${location.id}.jpg',
    );
  }

  static EntityVisual forDanger(Danger danger) {
    return EntityVisual(
      gradient: _styleGradients[danger.style] ??
          const [Color(0xFF434343), Color(0xFF000000)],
      icon: _styleIcons[danger.style] ?? Icons.warning_amber,
      query: _dangerQueries[danger.id] ?? danger.name,
      assetPath: 'assets/images/dangers/${danger.id}.jpg',
    );
  }

  static IconData styleIcon(String style) =>
      _styleIcons[style] ?? Icons.warning_amber;

  static List<Color> styleGradient(String style) =>
      _styleGradients[style] ?? const [Color(0xFF434343), Color(0xFF000000)];
}
