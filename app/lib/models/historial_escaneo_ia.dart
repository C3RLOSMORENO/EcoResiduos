/// Modelo de dominio para la tabla 'public.historial_escaneos_ia'.
class HistorialEscaneoIa {
  final int? id;
  final String usuarioId;
  final String nombreDetectado;
  final String categoriaDetectada;
  final double nivelConfianza;
  final String imagenPath;
  final DateTime? createdAt;

  const HistorialEscaneoIa({
    this.id,
    required this.usuarioId,
    required this.nombreDetectado,
    required this.categoriaDetectada,
    required this.nivelConfianza,
    required this.imagenPath,
    this.createdAt,
  });

  /// Instancia un registro a partir del mapa de base de datos.
  factory HistorialEscaneoIa.fromMap(Map<String, dynamic> map) {
    return HistorialEscaneoIa(
      id: (map['id'] as num?)?.toInt(),
      usuarioId: (map['usuario_id'] ?? '').toString(),
      nombreDetectado: (map['nombre_detectado'] ?? '').toString(),
      categoriaDetectada: (map['categoria_detectada'] ?? '').toString(),
      nivelConfianza: (map['nivel_confianza'] as num?)?.toDouble() ?? 0.0,
      imagenPath: (map['imagen_path'] ?? '').toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  /// Serializa a mapa para persistencia.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'usuario_id': usuarioId,
      'nombre_detectado': nombreDetectado,
      'categoria_detectada': categoriaDetectada,
      'nivel_confianza': nivelConfianza,
      'imagen_path': imagenPath,
    };
    if (!forInsert && id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Retorna una copia con campos modificados.
  HistorialEscaneoIa copyWith({
    int? id,
    String? usuarioId,
    String? nombreDetectado,
    String? categoriaDetectada,
    double? nivelConfianza,
    String? imagenPath,
    DateTime? createdAt,
  }) {
    return HistorialEscaneoIa(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombreDetectado: nombreDetectado ?? this.nombreDetectado,
      categoriaDetectada: categoriaDetectada ?? this.categoriaDetectada,
      nivelConfianza: nivelConfianza ?? this.nivelConfianza,
      imagenPath: imagenPath ?? this.imagenPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HistorialEscaneoIa && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
