/// Resultado de una identificación de residuo (real o simulada).
///
/// Cuando se integre el modelo de IA, este objeto es lo que debe construir
/// el clasificador real a partir de la etiqueta que detecte.
class WasteItem {
  const WasteItem({
    required this.nombre,
    required this.categoria,
    required this.etiquetaCategoria,
    required this.confianza,
    required this.descripcion,
    required this.caracteristicas,
    required this.pasosManejo,
    this.imagenPath,
  });

  /// Nombre común del residuo, ej. "Botella PET".
  final String nombre;

  /// Ej. "Reciclable — Plástico".
  final String categoria;

  /// Etiqueta corta para el chip, ej. "Reciclable".
  final String etiquetaCategoria;

  /// Porcentaje de confianza del modelo (0-100).
  final int confianza;

  final String descripcion;
  final String caracteristicas;

  /// Pasos recomendados de manejo, en orden (WF-08).
  final List<String> pasosManejo;

  /// Ruta local de la foto capturada, si hay una disponible.
  final String? imagenPath;

  factory WasteItem.fromJson(Map<String, dynamic> json, {String? imagePath}) {
    // Si guia_manejo es un string con saltos de línea, lo separamos. Si no, lo metemos en una lista.
    List<String> extraerPasos(dynamic guia) {
      if (guia == null) return [];
      if (guia is List) return guia.map((e) => e.toString()).toList();
      if (guia is String) return guia.split('\n').where((s) => s.trim().isNotEmpty).toList();
      return [];
    }

    return WasteItem(
      nombre: json['nombre_comun']?.toString() ?? 'Residuo desconocido',
      categoria: json['categoria']?.toString() ?? 'Sin categoría',
      // Usar la misma categoría o la primera palabra como etiqueta
      etiquetaCategoria: json['categoria']?.toString() ?? 'General',
      confianza: 100, // Para búsquedas manuales asumimos 100% de coincidencia
      descripcion: json['descripcion']?.toString() ?? '',
      caracteristicas: json['codigo'] != null ? 'Código: ${json['codigo']}' : 'Sin características',
      pasosManejo: extraerPasos(json['guia_manejo']),
      imagenPath: imagePath,
    );
  }
}
