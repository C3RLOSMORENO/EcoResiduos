import 'material_residuo.dart';

/// Modelo de dominio fuertemente tipado para la tabla 'public.solicitudes_recoleccion'.
class SolicitudRecoleccion {
  final int? id;
  final int generadorId;
  final int materialId;
  final double cantidadEstimada;
  final String unidadMedida;
  final String? descripcion;
  final String direccionRecoleccion;
  final String municipio;
  final String telefono;
  final String estado;
  final String? fotoUrl;
  final String? certificadoUrl;
  final double? latitud;
  final double? longitud;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final MaterialResiduo? material;

  final DateTime? recolectadoAt;
  final DateTime? confirmadoAt;
  final bool problemaReportado;
  final String? problemaDetalle;
  final int? gestorAsignadoId;

  const SolicitudRecoleccion({
    this.id,
    required this.generadorId,
    required this.materialId,
    required this.cantidadEstimada,
    required this.unidadMedida,
    this.descripcion,
    required this.direccionRecoleccion,
    required this.municipio,
    required this.telefono,
    this.estado = 'PUBLICADO',
    this.fotoUrl,
    this.certificadoUrl,
    this.latitud,
    this.longitud,
    this.createdAt,
    this.updatedAt,
    this.material,
    this.recolectadoAt,
    this.confirmadoAt,
    this.problemaReportado = false,
    this.problemaDetalle,
    this.gestorAsignadoId,
  });

  /// Construye una entidad a partir de los datos retornados por la base de datos o API.
  factory SolicitudRecoleccion.fromMap(Map<String, dynamic> map) {
    MaterialResiduo? materialAsociado;
    if (map['materiales_residuos'] != null && map['materiales_residuos'] is Map<String, dynamic>) {
      materialAsociado = MaterialResiduo.fromMap(map['materiales_residuos'] as Map<String, dynamic>);
    }

    return SolicitudRecoleccion(
      id: (map['id'] as num?)?.toInt(),
      generadorId: (map['generador_id'] as num?)?.toInt() ?? 0,
      materialId: (map['material_id'] as num?)?.toInt() ?? 0,
      cantidadEstimada: (map['cantidad_estimada'] as num?)?.toDouble() ?? 0.0,
      unidadMedida: (map['unidad_medida'] ?? 'KG').toString().toUpperCase(),
      descripcion: map['descripcion']?.toString(),
      direccionRecoleccion: (map['direccion_recoleccion'] ?? '').toString(),
      municipio: (map['municipio'] ?? '').toString(),
      telefono: (map['telefono'] ?? '').toString(),
      estado: (map['estado'] ?? 'PUBLICADO').toString().toUpperCase(),
      fotoUrl: map['foto_url']?.toString(),
      certificadoUrl: map['certificado_url']?.toString(),
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      material: materialAsociado,
      recolectadoAt: map['recolectado_at'] != null ? DateTime.tryParse(map['recolectado_at'].toString()) : null,
      confirmadoAt: map['confirmado_at'] != null ? DateTime.tryParse(map['confirmado_at'].toString()) : null,
      problemaReportado: map['problema_reportado'] == true || map['problema_reportado'] == 'true',
      problemaDetalle: map['problema_detalle']?.toString(),
      gestorAsignadoId: (map['gestor_asignado_id'] as num?)?.toInt(),
    );
  }

  /// Serializa los campos que edita el generador. Las columnas de recolecciÃ³n
  /// (`recolectado_at`, `confirmado_at`, `problema_*`, `gestor_asignado_id`)
  /// solo las escriben las funciones RPC del servidor.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'generador_id': generadorId,
      'material_id': materialId,
      'cantidad_estimada': cantidadEstimada,
      'unidad_medida': unidadMedida,
      'descripcion': descripcion ?? '',
      'direccion_recoleccion': direccionRecoleccion,
      'municipio': municipio,
      'telefono': telefono,
      'estado': estado,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (certificadoUrl != null) 'certificado_url': certificadoUrl,
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
    };

    if (!forInsert && id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Campos que el generador puede cambiar al editar. El estado, el dueÃ±o y
  /// las fechas los cambian solo las funciones del servidor.
  Map<String, dynamic> toMapEdicion() {
    return {
      'material_id': materialId,
      'cantidad_estimada': cantidadEstimada,
      'unidad_medida': unidadMedida,
      'descripcion': descripcion ?? '',
      'direccion_recoleccion': direccionRecoleccion,
      'municipio': municipio,
      'telefono': telefono,
      'foto_url': fotoUrl,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  /// Genera una copia con campos modificados.
  SolicitudRecoleccion copyWith({
    int? id,
    int? generadorId,
    int? materialId,
    double? cantidadEstimada,
    String? unidadMedida,
    String? descripcion,
    String? direccionRecoleccion,
    String? municipio,
    String? telefono,
    String? estado,
    String? fotoUrl,
    String? certificadoUrl,
    double? latitud,
    double? longitud,
    DateTime? createdAt,
    DateTime? updatedAt,
    MaterialResiduo? material,
    DateTime? recolectadoAt,
    DateTime? confirmadoAt,
    bool? problemaReportado,
    String? problemaDetalle,
    int? gestorAsignadoId,
  }) {
    return SolicitudRecoleccion(
      id: id ?? this.id,
      generadorId: generadorId ?? this.generadorId,
      materialId: materialId ?? this.materialId,
      cantidadEstimada: cantidadEstimada ?? this.cantidadEstimada,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      descripcion: descripcion ?? this.descripcion,
      direccionRecoleccion: direccionRecoleccion ?? this.direccionRecoleccion,
      municipio: municipio ?? this.municipio,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      certificadoUrl: certificadoUrl ?? this.certificadoUrl,
    this.certificadoUrl,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      material: material ?? this.material,
      recolectadoAt: recolectadoAt ?? this.recolectadoAt,
      confirmadoAt: confirmadoAt ?? this.confirmadoAt,
      problemaReportado: problemaReportado ?? this.problemaReportado,
      problemaDetalle: problemaDetalle ?? this.problemaDetalle,
      gestorAsignadoId: gestorAsignadoId ?? this.gestorAsignadoId,
    );
  }

  bool get estaRecolectado => recolectadoAt != null;
  bool get estaConfirmado => confirmadoAt != null;
  bool get tieneProblema => problemaReportado;

  /// El gestor marcÃ³ la recolecciÃ³n y el generador aÃºn no responde.
  bool get pendienteConfirmacion => estado == 'RECOLECTADO' && confirmadoAt == null && !problemaReportado;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SolicitudRecoleccion && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

