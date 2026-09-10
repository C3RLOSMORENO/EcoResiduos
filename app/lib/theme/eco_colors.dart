import 'package:flutter/material.dart';

/// Paleta compartida de EcoResiduos, tomada del wireframe MD3 en Figma.
/// Importa este archivo en cada pantalla en vez de repetir los hex.
class EcoColors {
  EcoColors._();

  static const background = Color(0xFFFCFDF6);
  static const onSurface = Color(0xFF1A1C18);
  static const onSurfaceVariant = Color(0xFF43483E);
  static const surfaceVariant = Color(0xFFDFE4D7);
  static const outline = Color(0xFFC3C8BB);
  static const outlineVariant = Color(0xFF73796D);

  static const primary = Color(0xFF4A6B21);
  static const onPrimary = Colors.white;

  /// Verde suave usado en avatares e íconos circulares pequeños.
  static const primaryContainer = Color(0xFFDCEDC1);
  static const onPrimaryContainer = Color(0xFF121F0D);

  /// Verde más saturado usado en tarjetas grandes de acento (ej. WF-02).
  static const accentSurface = Color(0xFFBFE89C);

  /// Usado en estados de error/advertencia (permisos denegados, fallos).
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF410002);

  /// Fondo casi negro de la pantalla de cámara.
  static const cameraBackground = Color(0xFF171717);
}
