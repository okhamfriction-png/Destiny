/// Un chrono de spectacle : sa durée totale et les trois moments où tombe
/// Destiny. Les quatre actes en découlent.
class ChronoSpectacle {
  const ChronoSpectacle({required this.dureeMinutes, required this.destinyMinutes});

  final int dureeMinutes;

  /// Les trois Destiny, en minutes depuis le début.
  final List<int> destinyMinutes;

  /// Les durées des quatre actes, en minutes.
  List<int> get dureesActes {
    if (!valide) return const [];
    final d = destinyMinutes;
    return [d[0], d[1] - d[0], d[2] - d[1], dureeMinutes - d[2]];
  }

  /// Trois Destiny strictement croissants, tous avant la fin.
  bool get valide =>
      destinyMinutes.length == 3 &&
      destinyMinutes[0] > 0 &&
      destinyMinutes[0] < destinyMinutes[1] &&
      destinyMinutes[1] < destinyMinutes[2] &&
      destinyMinutes[2] < dureeMinutes;

  /// L'acte en cours à [minute] écoulée (1 à 4).
  int acteA(double minute) {
    var acte = 1;
    for (final d in destinyMinutes) {
      if (minute >= d) acte++;
    }
    return acte.clamp(1, 4);
  }

  ChronoSpectacle copierAvec({int? dureeMinutes, List<int>? destinyMinutes}) =>
      ChronoSpectacle(
        dureeMinutes: dureeMinutes ?? this.dureeMinutes,
        destinyMinutes: destinyMinutes ?? this.destinyMinutes,
      );

  Map<String, dynamic> versJson() => {'duree': dureeMinutes, 'destiny': destinyMinutes};

  static ChronoSpectacle? depuisJson(Object? j) {
    if (j is! Map) return null;
    final duree = (j['duree'] as num?)?.toInt();
    final destiny = [for (final x in (j['destiny'] as List? ?? const [])) (x as num).toInt()];
    if (duree == null) return null;
    final c = ChronoSpectacle(dureeMinutes: duree, destinyMinutes: destiny);
    return c.valide ? c : null;
  }

  @override
  bool operator ==(Object other) =>
      other is ChronoSpectacle &&
      other.dureeMinutes == dureeMinutes &&
      other.destinyMinutes.join(',') == destinyMinutes.join(',');

  @override
  int get hashCode => Object.hash(dureeMinutes, destinyMinutes.join(','));
}

/// Les trois chronos de base, choisis par la troupe. Modifiables dans les
/// réglages.
const List<ChronoSpectacle> kChronosParDefaut = [
  ChronoSpectacle(dureeMinutes: 20, destinyMinutes: [8, 15, 18]),
  ChronoSpectacle(dureeMinutes: 30, destinyMinutes: [10, 18, 27]),
  ChronoSpectacle(dureeMinutes: 45, destinyMinutes: [10, 25, 40]),
];
