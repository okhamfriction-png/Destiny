import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';

/// Polices embarquées.
const String kPoliceTitres = 'Cinzel';
const String kPoliceTexte = 'Montserrat';

/// Lit une couleur `#RRGGBB` (ou rend [defaut]).
Color couleurHex(String? hex, {Color defaut = const Color(0xFF888888)}) {
  final h = (hex ?? '').replaceAll('#', '').trim();
  if (h.length != 6) return defaut;
  final v = int.tryParse(h, radix: 16);
  return v == null ? defaut : Color(0xFF000000 | v);
}

/// Les couleurs propres à Destiny, venues de la direction artistique de la
/// grammaire (`direction_artistique`, `familles`, `mode_kids.sigle`).
@immutable
class DestinyCouleurs extends ThemeExtension<DestinyCouleurs> {
  const DestinyCouleurs({
    required this.sombre,
    required this.nuit,
    required this.or,
    required this.orFonce,
    required this.orClair,
    required this.creme,
    required this.encre,
    required this.trait,
    required this.texteDoux,
    required this.bleuDestiny,
    required this.familles,
    required this.famillesClaires,
    required this.statuts,
    required this.kidsFond,
    required this.kidsTexte,
  });

  /// Vrai en mode sombre.
  final bool sombre;
  final Color nuit;
  final Color or;
  final Color orFonce;
  final Color orClair;
  final Color creme;
  final Color encre;
  final Color trait;
  final Color texteDoux;

  /// Tout ce qui touche au rituel.
  final Color bleuDestiny;
  final Map<FamilleId, Color> familles;
  final Map<FamilleId, Color> famillesClaires;
  final Map<Statut, Color> statuts;
  final Color kidsFond;
  final Color kidsTexte;

  /// Couleurs de l'interface (hors grammaire) : l'IA, et la frise des paliers
  /// qui va de l'or vers la braise (intensité, distincte du rouge Fissure).
  static const Color ia = Color(0xFF8A6FE8);
  static const Color braise = Color(0xFF6B2A14);

  /// Accents vifs, pour distinguer les entrées d'un coup d'œil (pastilles
  /// d'icône, thèmes d'exercices). Ils ne colorent jamais du texte courant.
  static const Color corail = Color(0xFFE5735F);
  static const Color ambre = Color(0xFFD9A030);
  static const Color turquoise = Color(0xFF2FAF95);
  static const Color ciel = Color(0xFF4A90D0);
  static const Color cyan = Color(0xFF2DB0C0);
  static const Color rose = Color(0xFFD06A95);
  static const Color lavande = Color(0xFF9B7FE0);

  /// Fond des pages : un noir chaud neutre en sombre (moins boueux que la
  /// nuit pure), une crème un peu plus soutenue en clair, pour que les cartes
  /// blanches s'en détachent.
  Color get fond => sombre ? const Color(0xFF131210) : const Color(0xFFF4EEE2);

  /// Fond des cartes : nettement plus clair que la page.
  Color get carte => sombre ? const Color(0xFF262420) : Colors.white;

  /// Fond des champs, des puces et des segments non choisis.
  Color get champ => sombre ? const Color(0xFF322F2A) : Colors.white;

  /// Fond de la barre de navigation et des feuilles du bas.
  Color get barre => sombre ? const Color(0xFF1D1B18) : Colors.white;

  /// Fond d'un élément choisi (segment, puce, onglet) : une teinte d'or.
  Color get selection => sombre ? const Color(0xFF5A4B2E) : const Color(0xFFF3E4C2);

  /// Le texte posé sur l'or (boutons pleins).
  Color get surOr => const Color(0xFF1E1A12);

  /// Texte principal et secondaire.
  Color get texte => sombre ? creme : encre;
  Color get texteSecondaire => sombre ? const Color(0xFFCBC2B2) : texteDoux;

  /// Couleur des titres (or en sombre, or foncé en clair).
  Color get titre => sombre ? or : orFonce;

  /// Le bleu Destiny quand il colore du texte : éclairci en sombre, assombri
  /// en clair, pour rester lisible (contraste d'au moins 4,5).
  Color get bleuTexte =>
      sombre ? Color.lerp(bleuDestiny, Colors.white, 0.35)! : Color.lerp(bleuDestiny, encre, 0.25)!;

  /// Filets : neutres et discrets. Une bordure dorée ou colorée doit dire
  /// quelque chose (un choix, une famille).
  Color get filet => sombre ? const Color(0xFF3B3732) : trait;

  /// Contour des commandes non choisies (segments, champs, puces).
  Color get ligne => sombre ? const Color(0xFF57514A) : const Color(0xFFD3C6AC);

  /// L'ombre douce des cartes.
  List<BoxShadow> get ombre => sombre
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3))]
      : const [
          BoxShadow(color: Color(0x14503C1E), blurRadius: 14, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
        ];

  /// La couleur d'une icône d'accent : éclaircie en sombre, assombrie en
  /// clair, pour se lire sur sa pastille.
  Color accent(Color base) =>
      sombre ? Color.lerp(base, Colors.white, 0.3)! : Color.lerp(base, encre, 0.3)!;

  /// Le fond teinté d'une pastille d'accent.
  Color teinte(Color base) => base.withValues(alpha: sombre ? 0.26 : 0.14);

  Color famille(FamilleId f) => familles[f] ?? or;
  Color familleClaire(FamilleId f) => famillesClaires[f] ?? creme;

  /// Teinte d'un palier sur la frise (1 = or clair → 4 = braise).
  Color palier(PalierId p) => Color.lerp(orClair, braise, p.index / 3)!;

  /// Construit les couleurs depuis la grammaire.
  factory DestinyCouleurs.depuisGrammaire(Grammaire g, {required bool sombre}) {
    final da = g.directionArtistique.couleurs;
    return DestinyCouleurs(
      sombre: sombre,
      nuit: couleurHex(da['nuit']),
      or: couleurHex(da['or']),
      orFonce: couleurHex(da['or_fonce']),
      orClair: couleurHex(da['or_clair']),
      creme: couleurHex(da['creme']),
      encre: couleurHex(da['encre']),
      trait: couleurHex(da['trait']),
      texteDoux: couleurHex(da['texte_doux']),
      bleuDestiny: couleurHex(da['bleu_destiny']),
      familles: {for (final f in g.familles) f.id: couleurHex(f.couleur)},
      famillesClaires: {for (final f in g.familles) f.id: couleurHex(f.couleurClaire)},
      statuts: {
        for (final e in g.directionArtistique.statuts.entries) e.key: couleurHex(e.value),
      },
      kidsFond: couleurHex(g.modeKids.sigleFond, defaut: const Color(0xFFF2C230)),
      kidsTexte: couleurHex(g.modeKids.sigleTexteCouleur, defaut: const Color(0xFF2A2108)),
    );
  }

  @override
  DestinyCouleurs copyWith({bool? sombre}) => DestinyCouleurs(
        sombre: sombre ?? this.sombre,
        nuit: nuit,
        or: or,
        orFonce: orFonce,
        orClair: orClair,
        creme: creme,
        encre: encre,
        trait: trait,
        texteDoux: texteDoux,
        bleuDestiny: bleuDestiny,
        familles: familles,
        famillesClaires: famillesClaires,
        statuts: statuts,
        kidsFond: kidsFond,
        kidsTexte: kidsTexte,
      );

  @override
  DestinyCouleurs lerp(ThemeExtension<DestinyCouleurs>? other, double t) =>
      t < 0.5 || other is! DestinyCouleurs ? this : other;
}

/// Raccourci : `context.destiny`.
extension DestinyContexte on BuildContext {
  DestinyCouleurs get destiny =>
      Theme.of(this).extension<DestinyCouleurs>() ??
      (throw StateError('Le thème Destiny n\'est pas installé.'));
}

/// Le thème Destiny (noir et or en sombre, crème et or en clair).
///
/// Cinzel ne sert qu'à l'affichage (titres de page, bandeaux, grands
/// nombres) ; tout ce qui se lit — titres de carte, boutons, puces,
/// intertitres, texte — est en Montserrat, à 15 px au moins pour le texte.
ThemeData themeDestiny(Grammaire g, {required bool sombre}) {
  final c = DestinyCouleurs.depuisGrammaire(g, sombre: sombre);
  final scheme = ColorScheme(
    brightness: sombre ? Brightness.dark : Brightness.light,
    primary: c.or,
    onPrimary: c.surOr,
    primaryContainer: c.selection,
    onPrimaryContainer: c.texte,
    secondary: c.titre,
    onSecondary: sombre ? c.surOr : Colors.white,
    secondaryContainer: c.selection,
    onSecondaryContainer: c.texte,
    tertiary: c.bleuDestiny,
    onTertiary: Colors.white,
    error: sombre ? const Color(0xFFE8776B) : const Color(0xFFB3261E),
    onError: sombre ? c.surOr : Colors.white,
    surface: c.fond,
    onSurface: c.texte,
    onSurfaceVariant: c.texteSecondaire,
    surfaceContainerLowest: c.fond,
    surfaceContainerLow: c.carte,
    surfaceContainer: c.carte,
    surfaceContainerHigh: sombre ? const Color(0xFF2C2925) : Colors.white,
    surfaceContainerHighest: sombre ? c.champ : const Color(0xFFECE4D4),
    outline: c.ligne,
    outlineVariant: c.filet,
    shadow: Colors.black,
    surfaceTint: Colors.transparent,
    inverseSurface: sombre ? c.creme : c.encre,
    onInverseSurface: sombre ? c.encre : c.creme,
    inversePrimary: c.orFonce,
  );

  TextStyle titre(double taille, {FontWeight poids = FontWeight.w700}) => TextStyle(
        fontFamily: kPoliceTitres,
        fontSize: taille,
        fontWeight: poids,
        color: c.titre,
        letterSpacing: 0.5,
        height: 1.15,
      );
  TextStyle texte(double taille, {FontWeight poids = FontWeight.w400, Color? couleur}) =>
      TextStyle(
        fontFamily: kPoliceTexte,
        fontSize: taille,
        fontWeight: poids,
        color: couleur ?? c.texte,
        height: 1.4,
      );

  final textes = TextTheme(
    displayLarge: titre(44, poids: FontWeight.w900),
    displayMedium: titre(36, poids: FontWeight.w900),
    displaySmall: titre(30),
    headlineLarge: titre(28),
    headlineMedium: titre(24),
    headlineSmall: titre(21),
    titleLarge: texte(19, poids: FontWeight.w700),
    titleMedium: texte(16.5, poids: FontWeight.w600),
    titleSmall: texte(15, poids: FontWeight.w600),
    bodyLarge: texte(16),
    bodyMedium: texte(15),
    bodySmall: texte(13.5, couleur: c.texteSecondaire),
    labelLarge: texte(15, poids: FontWeight.w600),
    labelMedium: texte(13.5, poids: FontWeight.w600),
    labelSmall: texte(12.5, poids: FontWeight.w600, couleur: c.texteSecondaire),
  );

  final rayon = BorderRadius.circular(14);
  bool choisi(Set<WidgetState> s) => s.contains(WidgetState.selected);
  bool inactif(Set<WidgetState> s) => s.contains(WidgetState.disabled);
  OutlineInputBorder bord(Color couleur, [double largeur = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: couleur, width: largeur));

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    fontFamily: kPoliceTexte,
    textTheme: textes,
    scaffoldBackgroundColor: c.fond,
    canvasColor: c.fond,
    cardColor: c.carte,
    dividerColor: c.filet,
    extensions: [c],
    iconTheme: IconThemeData(color: c.texte, size: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: c.fond,
      foregroundColor: c.texte,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: c.texte, size: 24),
      actionsIconTheme: IconThemeData(color: c.texte, size: 24),
      titleTextStyle: titre(21),
    ),
    cardTheme: CardThemeData(
      color: c.carte,
      surfaceTintColor: Colors.transparent,
      shadowColor: sombre ? Colors.black : const Color(0x55503C1E),
      elevation: sombre ? 2 : 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => inactif(s) ? c.texte.withValues(alpha: 0.12) : c.or),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => inactif(s) ? c.texte.withValues(alpha: 0.45) : c.surOr),
        iconColor: WidgetStateProperty.resolveWith(
            (s) => inactif(s) ? c.texte.withValues(alpha: 0.45) : c.surOr),
        overlayColor: WidgetStatePropertyAll(c.surOr.withValues(alpha: 0.08)),
        minimumSize: const WidgetStatePropertyAll(Size(48, 54)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
        iconSize: const WidgetStatePropertyAll(22),
        textStyle: WidgetStatePropertyAll(texte(16, poids: FontWeight.w700)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: rayon)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.titre,
        backgroundColor: c.or.withValues(alpha: sombre ? 0.08 : 0.06),
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: c.or.withValues(alpha: sombre ? 0.75 : 0.9), width: 1.4),
        textStyle: texte(15.5, poids: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: rayon),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.titre,
        minimumSize: const Size(48, 44),
        textStyle: texte(15, poids: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.or,
      foregroundColor: c.surOr,
      extendedTextStyle: texte(15.5, poids: FontWeight.w700),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.selection : c.champ),
        foregroundColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.texte : c.texteSecondaire),
        iconColor: WidgetStatePropertyAll(c.titre),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(color: choisi(s) ? c.or : c.ligne)),
        textStyle: WidgetStatePropertyAll(texte(15, poids: FontWeight.w700)),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.champ,
      selectedColor: c.selection,
      disabledColor: c.champ,
      checkmarkColor: c.titre,
      side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: choisi(s) ? c.or : c.ligne, width: choisi(s) ? 1.4 : 1)),
      labelStyle: texte(14, poids: FontWeight.w600),
      secondaryLabelStyle: texte(14, poids: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconTheme: IconThemeData(color: c.titre, size: 18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.surOr : c.texteSecondaire),
      trackColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.or : c.champ),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.or : c.ligne),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.or : Colors.transparent),
      checkColor: WidgetStatePropertyAll(c.surOr),
      side: BorderSide(color: c.ligne, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => choisi(s) ? c.titre : c.texteSecondaire),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.or,
      inactiveTrackColor: c.ligne,
      thumbColor: c.or,
      overlayColor: c.or.withValues(alpha: 0.16),
      valueIndicatorColor: c.or,
      valueIndicatorTextStyle: texte(13, poids: FontWeight.w700, couleur: c.surOr),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.or, linearTrackColor: c.filet),
    tabBarTheme: TabBarThemeData(
      indicatorColor: c.or,
      labelColor: c.texte,
      unselectedLabelColor: c.texteSecondaire,
      labelStyle: texte(15, poids: FontWeight.w700),
      unselectedLabelStyle: texte(15, poids: FontWeight.w500),
      dividerColor: c.filet,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.barre,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: c.selection,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => choisi(s)
          ? texte(13, poids: FontWeight.w700)
          : texte(13, poids: FontWeight.w600, couleur: c.texteSecondaire)),
      iconTheme: WidgetStateProperty.resolveWith((s) => choisi(s)
          ? IconThemeData(color: c.titre, size: 26)
          : IconThemeData(color: c.texteSecondaire, size: 24)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.titre,
      textColor: c.texte,
      titleTextStyle: texte(16, poids: FontWeight.w600),
      subtitleTextStyle: texte(14, couleur: c.texteSecondaire),
      leadingAndTrailingTextStyle: texte(14, poids: FontWeight.w600, couleur: c.texteSecondaire),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: c.titre,
      collapsedIconColor: c.texteSecondaire,
      textColor: c.texte,
      collapsedTextColor: c.texte,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    dividerTheme: DividerThemeData(color: c.filet, thickness: 1, space: 24),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.champ,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: texte(15, couleur: c.texteSecondaire),
      floatingLabelStyle: texte(15, poids: FontWeight.w600, couleur: c.titre),
      hintStyle: texte(15, couleur: c.texteSecondaire),
      helperStyle: texte(13, couleur: c.texteSecondaire),
      prefixIconColor: c.texteSecondaire,
      suffixIconColor: c.texteSecondaire,
      border: bord(c.ligne),
      enabledBorder: bord(c.ligne),
      disabledBorder: bord(c.filet),
      focusedBorder: bord(c.titre, 2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      // En clair, la crème de la page : les cartes blanches s'en détachent.
      backgroundColor: sombre ? c.barre : c.fond,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: c.ligne,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.barre,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: texte(19, poids: FontWeight.w700),
      contentTextStyle: texte(15.5),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.barre,
      surfaceTintColor: Colors.transparent,
      textStyle: texte(15),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: texte(13, poids: FontWeight.w600, couleur: sombre ? c.encre : c.creme),
      decoration: BoxDecoration(color: sombre ? c.creme : c.encre, borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: sombre ? c.creme : c.encre,
      contentTextStyle: texte(15, couleur: sombre ? c.encre : c.creme),
      actionTextColor: sombre ? c.orFonce : c.orClair,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
