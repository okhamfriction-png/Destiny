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

  /// Fond des pages.
  Color get fond => sombre ? nuit : creme;

  /// Fond des cartes.
  Color get carte => sombre ? const Color(0xFF1C170F) : Colors.white;

  /// Texte principal et secondaire.
  Color get texte => sombre ? creme : encre;
  Color get texteSecondaire => sombre ? const Color(0xFFB9AE98) : texteDoux;

  /// Couleur des titres (or en sombre, or foncé en clair).
  Color get titre => sombre ? or : orFonce;

  /// Le bleu Destiny quand il colore du texte : éclairci en sombre, assombri
  /// en clair, pour rester lisible (contraste d'au moins 4,5).
  Color get bleuTexte =>
      sombre ? Color.lerp(bleuDestiny, Colors.white, 0.35)! : Color.lerp(bleuDestiny, encre, 0.25)!;

  /// Filets dorés.
  Color get filet => sombre ? orFonce.withValues(alpha: 0.7) : trait;

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
ThemeData themeDestiny(Grammaire g, {required bool sombre}) {
  final c = DestinyCouleurs.depuisGrammaire(g, sombre: sombre);
  final scheme = ColorScheme(
    brightness: sombre ? Brightness.dark : Brightness.light,
    primary: sombre ? c.or : c.orFonce,
    onPrimary: sombre ? c.nuit : Colors.white,
    secondary: c.bleuDestiny,
    onSecondary: Colors.white,
    error: const Color(0xFFC0392B),
    onError: Colors.white,
    surface: c.carte,
    onSurface: c.texte,
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
        height: 1.35,
      );

  final textes = TextTheme(
    displayLarge: titre(44, poids: FontWeight.w900),
    displayMedium: titre(36, poids: FontWeight.w900),
    displaySmall: titre(30),
    headlineLarge: titre(28),
    headlineMedium: titre(24),
    headlineSmall: titre(20),
    titleLarge: titre(18),
    titleMedium: texte(16, poids: FontWeight.w600),
    titleSmall: texte(14, poids: FontWeight.w600),
    bodyLarge: texte(16),
    bodyMedium: texte(14),
    bodySmall: texte(12, couleur: c.texteSecondaire),
    labelLarge: texte(15, poids: FontWeight.w600),
    labelMedium: texte(13, poids: FontWeight.w500),
    labelSmall: texte(11, poids: FontWeight.w500, couleur: c.texteSecondaire),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    fontFamily: kPoliceTexte,
    textTheme: textes,
    scaffoldBackgroundColor: c.fond,
    canvasColor: c.fond,
    dividerColor: c.filet,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.fond,
      foregroundColor: c.titre,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: titre(20),
    ),
    cardTheme: CardThemeData(
      color: c.carte,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.filet),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 52),
        textStyle: texte(15, poids: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.titre,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: c.titre),
        textStyle: texte(14, poids: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.titre,
        textStyle: texte(14, poids: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.carte,
      side: BorderSide(color: c.filet),
      labelStyle: texte(13, poids: FontWeight.w500),
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: sombre ? const Color(0xFF17120B) : Colors.white,
      indicatorColor: c.or.withValues(alpha: 0.25),
      labelTextStyle: WidgetStatePropertyAll(texte(12, poids: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.titre : c.texteSecondaire)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.carte,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.filet),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.filet),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.titre, width: 1.6),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.carte,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.carte),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: sombre ? c.creme : c.encre,
      contentTextStyle: texte(14, couleur: sombre ? c.encre : c.creme),
    ),
  );
}
