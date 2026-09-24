import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'eco_colors.dart';
import 'etiqueta_border.dart';

export 'eco_colors.dart';
export 'etiqueta_border.dart';

/// Escala de radios de Material 3 usada en EcoResiduos (máx 4 valores + corte de firma)
abstract final class EcoRadius {
  static const double small = 8.0; // Campos, tiles, miniaturas, avatar
  static const double medium = 12.0; // Etiquetas, tarjetas, botones modales
  static const double extraLarge = 28.0; // Bottom sheets, diálogos
  static const double full = 9999.0; // Botones píldora, badges, SearchBar
  static const double corte = 16.0; // Corte de firma a 45°
}

/// Escala de espaciado estándar de 4 dp
abstract final class EcoSpace {
  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s28 = 28.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;
}

/// Duraciones y curvas oficiales del sistema de diseño
abstract final class EcoMotion {
  static const Duration pantalla = Duration(milliseconds: 300);
  static const Duration resultado = Duration(milliseconds: 450);
  static const Duration conteo = Duration(milliseconds: 600);
  static const Duration exito = Duration(milliseconds: 500);
  static const Duration estado = Duration(milliseconds: 250);
  static const Duration skeleton = Duration(milliseconds: 1200);

  static Duration duracion(BuildContext context, Duration base) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : base;
  }
}

/// Escala tipográfica oficial de EcoResiduos
TextTheme ecoTextTheme([Color? textColor]) {
  const tabular = [FontFeature.tabularFigures()];

  return TextTheme(
    displayLarge: GoogleFonts.barlowCondensed(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      height: 60 / 56,
      letterSpacing: -0.5,
      fontFeatures: tabular,
      color: textColor,
    ),
    displayMedium: GoogleFonts.barlowCondensed(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 48 / 44,
      letterSpacing: -0.25,
      fontFeatures: tabular,
      color: textColor,
    ),
    displaySmall: GoogleFonts.barlowCondensed(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 40 / 36,
      letterSpacing: 0,
      fontFeatures: tabular,
      color: textColor,
    ),
    headlineLarge: GoogleFonts.barlowCondensed(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 36 / 32,
      letterSpacing: 0,
      fontFeatures: tabular,
      color: textColor,
    ),
    headlineMedium: GoogleFonts.barlowCondensed(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 32 / 28,
      letterSpacing: 0,
      fontFeatures: tabular,
      color: textColor,
    ),
    headlineSmall: GoogleFonts.barlowCondensed(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 28 / 24,
      letterSpacing: 0,
      fontFeatures: tabular,
      color: textColor,
    ),
    titleLarge: GoogleFonts.publicSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 26 / 20,
      letterSpacing: 0,
      color: textColor,
    ),
    titleMedium: GoogleFonts.publicSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 22 / 16,
      letterSpacing: 0.1,
      color: textColor,
    ),
    titleSmall: GoogleFonts.publicSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      letterSpacing: 0.1,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.publicSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      letterSpacing: 0.15,
      color: textColor,
    ),
    bodyMedium: GoogleFonts.publicSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      letterSpacing: 0.2,
      color: textColor,
    ),
    bodySmall: GoogleFonts.publicSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      letterSpacing: 0.3,
      color: textColor,
    ),
    labelLarge: GoogleFonts.publicSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      letterSpacing: 0.1,
      color: textColor,
    ),
    labelMedium: GoogleFonts.publicSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      letterSpacing: 0.4,
      color: textColor,
    ),
    labelSmall: GoogleFonts.publicSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 16 / 11,
      letterSpacing: 0.5,
      color: textColor,
    ),
  );
}

/// Generador de ThemeData para EcoResiduos
ThemeData ecoTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? ecoLightColorScheme : ecoDarkColorScheme;
  final ecoExt = brightness == Brightness.light ? ecoColoresLight : ecoColoresDark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: ecoTextTheme(scheme.onSurface),
    scaffoldBackgroundColor: scheme.surface,
    extensions: [ecoExt],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      centerTitle: false,
      titleSpacing: EcoSpace.s16,
      titleTextStyle: GoogleFonts.barlowCondensed(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 30 / 26,
        color: scheme.onSurface,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
      labelStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s8),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      minVerticalPadding: EcoSpace.s12,
      contentPadding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 48),
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        textStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.small))),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: EcoRadius.corte),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: scheme.primary,
        textStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: scheme.primary,
        textStyle: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.tertiaryContainer,
      foregroundColor: scheme.onTertiaryContainer,
      elevation: 3,
      shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: 12),
      extendedTextStyle: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcoRadius.small), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoRadius.small),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoRadius.small),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoRadius.small),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcoRadius.small),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      errorStyle: TextStyle(color: scheme.error, fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      height: 80,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.publicSans(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(size: 24, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant);
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
      dragHandleSize: const Size(32, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.extraLarge)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.extraLarge)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.small)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
  );
}
