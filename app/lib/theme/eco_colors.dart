import 'package:flutter/material.dart';

/// Categorías oficiales de residuos en la base de datos y el modelo de IA.
enum Categoria { aprovechable, peligroso, raee, rcd, riesgoBiologico, organico, ordinario }

/// Estados posibles de una solicitud o postulación.
enum EstadoSolicitud {
  publicado,
  enNegociacion,
  recolectado,
  cancelado,
  propuesta,
  aceptada,
  rechazada,
  noSeleccionada,
}

/// Conjunto de 4 colores semánticos para una categoría o estado.
@immutable
class CategoriaColor {
  const CategoriaColor({
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });

  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;

  /// Mezcla dos juegos de colores, para la animación al cambiar de tema.
  static CategoriaColor lerp(CategoriaColor a, CategoriaColor b, double t) {
    return CategoriaColor(
      color: Color.lerp(a.color, b.color, t)!,
      onColor: Color.lerp(a.onColor, b.onColor, t)!,
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
    );
  }
}

/// ThemeExtension de Flutter para los colores de categoría y estados de solicitud.
class EcoColores extends ThemeExtension<EcoColores> {
  const EcoColores({required this.categorias, required this.estados});

  final Map<Categoria, CategoriaColor> categorias;
  final Map<EstadoSolicitud, CategoriaColor> estados;

  /// Colores de la categoría; los de Aprovechable si no está definida.
  CategoriaColor categoria(Categoria c) => categorias[c] ?? categorias[Categoria.aprovechable]!;

  /// Colores del estado; los de Publicado si no está definido.
  CategoriaColor estado(EstadoSolicitud s) => estados[s] ?? estados[EstadoSolicitud.publicado]!;

  @override
  EcoColores copyWith({Map<Categoria, CategoriaColor>? categorias, Map<EstadoSolicitud, CategoriaColor>? estados}) {
    return EcoColores(categorias: categorias ?? this.categorias, estados: estados ?? this.estados);
  }

  @override
  EcoColores lerp(EcoColores? other, double t) {
    if (other == null) return this;
    return EcoColores(
      categorias: {
        for (final k in categorias.keys)
          k: CategoriaColor.lerp(categorias[k]!, other.categorias[k] ?? categorias[k]!, t),
      },
      estados: {for (final k in estados.keys) k: CategoriaColor.lerp(estados[k]!, other.estados[k] ?? estados[k]!, t)},
    );
  }
}

/// Colores de categoría y estado en Modo Claro (cumplen WCAG AA)
const ecoColoresLight = EcoColores(
  categorias: {
    Categoria.aprovechable: CategoriaColor(
      color: Color(0xFF0A5F7A),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFCDEBF5),
      onContainer: Color(0xFF003544),
    ),
    Categoria.peligroso: CategoriaColor(
      color: Color(0xFFF2B200),
      onColor: Color(0xFF1F1600),
      container: Color(0xFFFFEFC2),
      onContainer: Color(0xFF261A00),
    ),
    Categoria.raee: CategoriaColor(
      color: Color(0xFF5B3FA0),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFE8DEFF),
      onContainer: Color(0xFF1D0B52),
    ),
    Categoria.rcd: CategoriaColor(
      color: Color(0xFF6D5A4B),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFF0E2D6),
      onContainer: Color(0xFF261A10),
    ),
    Categoria.riesgoBiologico: CategoriaColor(
      color: Color(0xFFB3261E),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFFFDAD5),
      onContainer: Color(0xFF410002),
    ),
    Categoria.organico: CategoriaColor(
      color: Color(0xFF2F6B1F),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFC9EDB2),
      onContainer: Color(0xFF082100),
    ),
    Categoria.ordinario: CategoriaColor(
      color: Color(0xFF2B2F2C),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFDFE4DE),
      onContainer: Color(0xFF151A16),
    ),
  },
  estados: {
    EstadoSolicitud.publicado: CategoriaColor(
      color: Color(0xFF1F5FA8),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFD6E3FF),
      onContainer: Color(0xFF001B3E),
    ),
    EstadoSolicitud.enNegociacion: CategoriaColor(
      color: Color(0xFF8A5100),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFFFDDB8),
      onContainer: Color(0xFF2C1600),
    ),
    EstadoSolicitud.propuesta: CategoriaColor(
      color: Color(0xFF8A5100),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFFFDDB8),
      onContainer: Color(0xFF2C1600),
    ),
    EstadoSolicitud.recolectado: CategoriaColor(
      color: Color(0xFF1F6B35),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFB7F0C0),
      onContainer: Color(0xFF00210B),
    ),
    EstadoSolicitud.aceptada: CategoriaColor(
      color: Color(0xFF1F6B35),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFB7F0C0),
      onContainer: Color(0xFF00210B),
    ),
    EstadoSolicitud.cancelado: CategoriaColor(
      color: Color(0xFF5D5F5A),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFE3E3DC),
      onContainer: Color(0xFF1A1C18),
    ),
    EstadoSolicitud.rechazada: CategoriaColor(
      color: Color(0xFF5D5F5A),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFE3E3DC),
      onContainer: Color(0xFF1A1C18),
    ),
    EstadoSolicitud.noSeleccionada: CategoriaColor(
      color: Color(0xFF5D5F5A),
      onColor: Color(0xFFFFFFFF),
      container: Color(0xFFE3E3DC),
      onContainer: Color(0xFF1A1C18),
    ),
  },
);

/// Colores de categoría y estado en Modo Oscuro
const ecoColoresDark = EcoColores(
  categorias: {
    Categoria.aprovechable: CategoriaColor(
      color: Color(0xFF86D1EC),
      onColor: Color(0xFF003544),
      container: Color(0xFF004D63),
      onContainer: Color(0xFFCDEBF5),
    ),
    Categoria.peligroso: CategoriaColor(
      color: Color(0xFFF2B200),
      onColor: Color(0xFF1F1600),
      container: Color(0xFF5A4300),
      onContainer: Color(0xFFFFE08A),
    ),
    Categoria.raee: CategoriaColor(
      color: Color(0xFFCFBDFF),
      onColor: Color(0xFF2F1A75),
      container: Color(0xFF44298A),
      onContainer: Color(0xFFE8DEFF),
    ),
    Categoria.rcd: CategoriaColor(
      color: Color(0xFFD8C2AF),
      onColor: Color(0xFF3A2C20),
      container: Color(0xFF54433A),
      onContainer: Color(0xFFF0E2D6),
    ),
    Categoria.riesgoBiologico: CategoriaColor(
      color: Color(0xFFFFB4AA),
      onColor: Color(0xFF690004),
      container: Color(0xFF8C1D18),
      onContainer: Color(0xFFFFDAD5),
    ),
    Categoria.organico: CategoriaColor(
      color: Color(0xFFA5D889),
      onColor: Color(0xFF0F3900),
      container: Color(0xFF1A500A),
      onContainer: Color(0xFFC9EDB2),
    ),
    Categoria.ordinario: CategoriaColor(
      color: Color(0xFFC4C8C3),
      onColor: Color(0xFF2C312D),
      container: Color(0xFF444945),
      onContainer: Color(0xFFDFE4DE),
    ),
  },
  estados: {
    EstadoSolicitud.publicado: CategoriaColor(
      color: Color(0xFFA9C7FF),
      onColor: Color(0xFF002F65),
      container: Color(0xFF00468C),
      onContainer: Color(0xFFD6E3FF),
    ),
    EstadoSolicitud.enNegociacion: CategoriaColor(
      color: Color(0xFFFFB95F),
      onColor: Color(0xFF4A2800),
      container: Color(0xFF693C00),
      onContainer: Color(0xFFFFDDB8),
    ),
    EstadoSolicitud.propuesta: CategoriaColor(
      color: Color(0xFFFFB95F),
      onColor: Color(0xFF4A2800),
      container: Color(0xFF693C00),
      onContainer: Color(0xFFFFDDB8),
    ),
    EstadoSolicitud.recolectado: CategoriaColor(
      color: Color(0xFF8DD9A0),
      onColor: Color(0xFF00391A),
      container: Color(0xFF005226),
      onContainer: Color(0xFFB7F0C0),
    ),
    EstadoSolicitud.aceptada: CategoriaColor(
      color: Color(0xFF8DD9A0),
      onColor: Color(0xFF00391A),
      container: Color(0xFF005226),
      onContainer: Color(0xFFB7F0C0),
    ),
    EstadoSolicitud.cancelado: CategoriaColor(
      color: Color(0xFFC6C7C0),
      onColor: Color(0xFF2F312C),
      container: Color(0xFF454742),
      onContainer: Color(0xFFE3E3DC),
    ),
    EstadoSolicitud.rechazada: CategoriaColor(
      color: Color(0xFFC6C7C0),
      onColor: Color(0xFF2F312C),
      container: Color(0xFF454742),
      onContainer: Color(0xFFE3E3DC),
    ),
    EstadoSolicitud.noSeleccionada: CategoriaColor(
      color: Color(0xFFC6C7C0),
      onColor: Color(0xFF2F312C),
      container: Color(0xFF454742),
      onContainer: Color(0xFFE3E3DC),
    ),
  },
);

/// ColorScheme M3 oficial para EcoResiduos (Claro)
const ecoLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1F4A2C),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFB8E6BE),
  onPrimaryContainer: Color(0xFF00210D),
  secondary: Color(0xFF5C6F52),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDDE8D2),
  onSecondaryContainer: Color(0xFF192313),
  tertiary: Color(0xFFB4552D),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFFDBCC),
  onTertiaryContainer: Color(0xFF3A0D00),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF8F6EE),
  onSurface: Color(0xFF1A1C18),
  onSurfaceVariant: Color(0xFF43483E),
  surfaceDim: Color(0xFFD9D7CF),
  surfaceBright: Color(0xFFF8F6EE),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF2F0E8),
  surfaceContainer: Color(0xFFECEAE2),
  surfaceContainerHigh: Color(0xFFE6E4DC),
  surfaceContainerHighest: Color(0xFFE0DED6),
  outline: Color(0xFF73796E),
  outlineVariant: Color(0xFFC3C8BB),
  inverseSurface: Color(0xFF2F312C),
  onInverseSurface: Color(0xFFF1F1EA),
  inversePrimary: Color(0xFF9DD3A5),
  surfaceTint: Colors.transparent,
);

/// ColorScheme M3 oficial para EcoResiduos (Oscuro)
const ecoDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9DD3A5),
  onPrimary: Color(0xFF00391A),
  primaryContainer: Color(0xFF0F5230),
  onPrimaryContainer: Color(0xFFB8E6BE),
  secondary: Color(0xFFC1CCB6),
  onSecondary: Color(0xFF2B3525),
  secondaryContainer: Color(0xFF424E3B),
  onSecondaryContainer: Color(0xFFDDE8D2),
  tertiary: Color(0xFFFFB596),
  onTertiary: Color(0xFF5A1C00),
  tertiaryContainer: Color(0xFF8E3D18),
  onTertiaryContainer: Color(0xFFFFDBCC),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF121410),
  onSurface: Color(0xFFE3E3DB),
  onSurfaceVariant: Color(0xFFC3C8BB),
  surfaceDim: Color(0xFF121410),
  surfaceBright: Color(0xFF383A35),
  surfaceContainerLowest: Color(0xFF0D0F0B),
  surfaceContainerLow: Color(0xFF1A1C18),
  surfaceContainer: Color(0xFF1E201C),
  surfaceContainerHigh: Color(0xFF292B26),
  surfaceContainerHighest: Color(0xFF333530),
  outline: Color(0xFF8D9387),
  outlineVariant: Color(0xFF43483E),
  inverseSurface: Color(0xFFE3E3DB),
  onInverseSurface: Color(0xFF2F312C),
  inversePrimary: Color(0xFF1F4A2C),
  surfaceTint: Colors.transparent,
);

/// Mapeos legibles para UI (nunca mostrar códigos crudos de BD)
const Map<String, String> catLabel = {
  'APROVECHABLE': 'Aprovechable',
  'PELIGROSO': 'Peligroso (RESPEL)',
  'RAEE': 'RAEE',
  'RCD': 'Escombros (RCD)',
  'RIESGO_BIOLOGICO': 'Riesgo biológico',
  'ORGANICO': 'Orgánico',
  'ORDINARIO': 'Ordinario',
};

const Map<String, String> estadoLabel = {
  'PUBLICADO': 'Publicado',
  'EN_NEGOCIACION': 'En negociación',
  'RECOLECTADO': 'Recolectado',
  'CANCELADO': 'Cancelado',
  'PROPUESTA': 'Propuesta enviada',
  'ACEPTADA': 'Aceptada',
  'RECHAZADA': 'Rechazada',
  'NO_SELECCIONADA': 'Asignada a otro gestor',
  'ASIGNADA_OTRO': 'Asignada a otro gestor',
};

/// Conversión segura de String a Categoria
Categoria categoriaFromString(String? raw) {
  if (raw == null) return Categoria.aprovechable;
  final clean = raw.trim().toUpperCase();
  switch (clean) {
    case 'PELIGROSO':
    case 'RESPEL':
      return Categoria.peligroso;
    case 'RAEE':
      return Categoria.raee;
    case 'RCD':
    case 'ESCOMBROS':
      return Categoria.rcd;
    case 'RIESGO_BIOLOGICO':
    case 'BIOLOGICO':
      return Categoria.riesgoBiologico;
    case 'ORGANICO':
      return Categoria.organico;
    case 'ORDINARIO':
      return Categoria.ordinario;
    case 'APROVECHABLE':
    default:
      return Categoria.aprovechable;
  }
}

/// Conversión segura de String a EstadoSolicitud
EstadoSolicitud estadoFromString(String? raw) {
  if (raw == null) return EstadoSolicitud.publicado;
  final clean = raw.trim().toUpperCase();
  switch (clean) {
    case 'EN_NEGOCIACION':
    case 'NEGOCIACION':
      return EstadoSolicitud.enNegociacion;
    case 'RECOLECTADO':
      return EstadoSolicitud.recolectado;
    case 'CANCELADO':
      return EstadoSolicitud.cancelado;
    case 'PROPUESTA':
      return EstadoSolicitud.propuesta;
    case 'ACEPTADA':
      return EstadoSolicitud.aceptada;
    case 'RECHAZADA':
      return EstadoSolicitud.rechazada;
    case 'NO_SELECCIONADA':
    case 'ASIGNADA_OTRO':
      return EstadoSolicitud.noSeleccionada;
    case 'PUBLICADO':
    default:
      return EstadoSolicitud.publicado;
  }
}

/// Fondo del visor de cámara y del análisis: siempre oscuro, en claro y en oscuro.
const colorVisorCamara = Color(0xFF171717);
