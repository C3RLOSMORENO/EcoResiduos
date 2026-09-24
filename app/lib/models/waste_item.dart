/// Resultado del modelo de IA sobre una foto.
class WasteItem {
  const WasteItem({required this.nombre, required this.categoria, required this.confianza, this.imagenPath});

  /// Nombre descriptivo de la categoría detectada, p. ej. «Residuo aprovechable».
  final String nombre;

  /// Código de categoría del modelo (APROVECHABLE, PELIGROSO, RAEE, RCD,
  /// RIESGO_BIOLOGICO, ORGANICO u ORDINARIO).
  final String categoria;

  /// Confianza del modelo, en %.
  final int confianza;

  /// Ruta local de la foto analizada.
  final String? imagenPath;
}
