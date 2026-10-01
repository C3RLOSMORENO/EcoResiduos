import '../features/solicitudes/models/solicitud_recoleccion.dart';

/// Quién paga a quién en la propuesta del gestor.
enum TipoValor {
  /// El generador le paga al gestor por recoger el residuo.
  cobroRecoleccion('COBRO_RECOLECCION', 'Valor cobrado por recolección externa', 'Cobra por recoger'),

  /// El gestor le paga al generador por el material que aprovecha.
  pagoAprovechamiento('PAGO_APROVECHAMIENTO', 'Valor pagado por aprovechamiento', 'Paga por el material');

  const TipoValor(this.valor, this.etiqueta, this.etiquetaCorta);

  /// Valor guardado en la base de datos.
  final String valor;
  final String etiqueta;
  final String etiquetaCorta;

  static TipoValor? desde(String? valor) {
    for (final tipo in values) {
      if (tipo.valor == valor?.toUpperCase()) return tipo;
    }
    return null;
  }
}

/// Modelo de dominio para la tabla 'public.postulaciones_recoleccion'.
class PostulacionRecoleccion {
  final int? id;
  final int solicitudId;
  final int gestorId;
  final String estado;
  final String? propuesta;
  final TipoValor? tipoValor;

  /// Pesos colombianos, sin decimales.
  final int? valor;
  final DateTime? createdAt;
  final SolicitudRecoleccion? solicitud;

  final String? gestorRazonSocial;
  final String? gestorMunicipio;
  final String? gestorTelefono;

  const PostulacionRecoleccion({
    this.id,
    required this.solicitudId,
    required this.gestorId,
    this.estado = 'PROPUESTA',
    this.propuesta,
    this.tipoValor,
    this.valor,
    this.createdAt,
    this.solicitud,
    this.gestorRazonSocial,
    this.gestorMunicipio,
    this.gestorTelefono,
  });

  /// Instancia una postulación desde un mapa de base de datos.
  factory PostulacionRecoleccion.fromMap(Map<String, dynamic> map) {
    SolicitudRecoleccion? sol;
    if (map['solicitudes_recoleccion'] != null && map['solicitudes_recoleccion'] is Map<String, dynamic>) {
      sol = SolicitudRecoleccion.fromMap(map['solicitudes_recoleccion'] as Map<String, dynamic>);
    }

    String? razonSocial;
    String? municipio;
    String? telefono;
    if (map['perfiles_gestor'] != null && map['perfiles_gestor'] is Map<String, dynamic>) {
      final pg = map['perfiles_gestor'] as Map<String, dynamic>;
      razonSocial = pg['razon_social']?.toString();
      municipio = pg['municipio']?.toString();
      telefono = pg['telefono_contacto']?.toString();
    }

    return PostulacionRecoleccion(
      id: (map['id'] as num?)?.toInt(),
      solicitudId: (map['solicitud_id'] as num?)?.toInt() ?? 0,
      gestorId: (map['gestor_id'] as num?)?.toInt() ?? 0,
      estado: (map['estado'] ?? 'PROPUESTA').toString().toUpperCase(),
      propuesta: map['propuesta']?.toString(),
      tipoValor: TipoValor.desde(map['tipo_valor']?.toString()),
      valor: (map['valor'] as num?)?.toInt(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      solicitud: sol,
      gestorRazonSocial: razonSocial,
      gestorMunicipio: municipio,
      gestorTelefono: telefono,
    );
  }

  /// Serializa a mapa para persistencia.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'solicitud_id': solicitudId,
      'gestor_id': gestorId,
      'estado': estado,
      if (propuesta != null && propuesta!.trim().isNotEmpty) 'propuesta': propuesta!.trim(),
      if (tipoValor != null) 'tipo_valor': tipoValor!.valor,
      if (valor != null) 'valor': valor,
    };
    if (!forInsert && id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Retorna una copia con campos actualizados.
  PostulacionRecoleccion copyWith({
    int? id,
    int? solicitudId,
    int? gestorId,
    String? estado,
    String? propuesta,
    TipoValor? tipoValor,
    int? valor,
    DateTime? createdAt,
    SolicitudRecoleccion? solicitud,
    String? gestorRazonSocial,
    String? gestorMunicipio,
    String? gestorTelefono,
  }) {
    return PostulacionRecoleccion(
      id: id ?? this.id,
      solicitudId: solicitudId ?? this.solicitudId,
      gestorId: gestorId ?? this.gestorId,
      estado: estado ?? this.estado,
      propuesta: propuesta ?? this.propuesta,
      tipoValor: tipoValor ?? this.tipoValor,
      valor: valor ?? this.valor,
      createdAt: createdAt ?? this.createdAt,
      solicitud: solicitud ?? this.solicitud,
      gestorRazonSocial: gestorRazonSocial ?? this.gestorRazonSocial,
      gestorMunicipio: gestorMunicipio ?? this.gestorMunicipio,
      gestorTelefono: gestorTelefono ?? this.gestorTelefono,
    );
  }

  bool get tieneValor => tipoValor != null && valor != null;

  bool get esPropuesta => estado == 'PROPUESTA';
  bool get esAceptada => estado == 'ACEPTADA';
  bool get esRechazada => estado == 'RECHAZADA';
  bool get esNoSeleccionada => estado == 'NO_SELECCIONADA';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostulacionRecoleccion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          solicitudId == other.solicitudId &&
          gestorId == other.gestorId;

  @override
  int get hashCode => id.hashCode ^ solicitudId.hashCode ^ gestorId.hashCode;
}
