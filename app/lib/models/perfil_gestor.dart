/// Modelo de dominio para la tabla 'public.perfiles_gestor'.
class PerfilGestor {
  final int id;
  final String? usuarioId;
  final String nit;
  final String razonSocial;
  final String? representanteLegal;
  final String direccion;
  final String municipio;
  final String emailContacto;
  final String telefonoContacto;
  final double? latitud;
  final double? longitud;
  final String estadoVerificacion;
  final bool disponible;
  final DateTime? createdAt;
  final List<int>? materialIds;

  const PerfilGestor({
    required this.id,
    this.usuarioId,
    required this.nit,
    required this.razonSocial,
    this.representanteLegal,
    required this.direccion,
    required this.municipio,
    required this.emailContacto,
    required this.telefonoContacto,
    this.latitud,
    this.longitud,
    this.estadoVerificacion = 'PENDIENTE',
    this.disponible = true,
    this.createdAt,
    this.materialIds,
  });

  /// Instancia un perfil de gestor desde la base de datos.
  factory PerfilGestor.fromMap(Map<String, dynamic> map) {
    List<int>? ids;
    if (map['gestor_material'] != null && map['gestor_material'] is List) {
      ids = (map['gestor_material'] as List)
          .map((gm) => (gm['material_id'] as num?)?.toInt())
          .whereType<int>()
          .toList();
    } else if (map['material_ids'] != null && map['material_ids'] is List) {
      ids = (map['material_ids'] as List).map((id) => (id as num?)?.toInt()).whereType<int>().toList();
    }

    return PerfilGestor(
      id: (map['id'] as num?)?.toInt() ?? 0,
      usuarioId: map['usuario_id']?.toString(),
      nit: (map['nit'] ?? '').toString(),
      razonSocial: (map['razon_social'] ?? '').toString(),
      representanteLegal: map['representante_legal']?.toString(),
      direccion: (map['direccion'] ?? '').toString(),
      municipio: (map['municipio'] ?? 'BUCARAMANGA').toString(),
      emailContacto: (map['email_contacto'] ?? '').toString(),
      telefonoContacto: (map['telefono_contacto'] ?? '').toString(),
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
      estadoVerificacion: (map['estado_verificacion'] ?? 'PENDIENTE').toString().toUpperCase(),
      disponible: map['disponible'] is bool ? map['disponible'] as bool : true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      materialIds: ids,
    );
  }

  /// Serializa a mapa para persistencia.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      if (usuarioId != null) 'usuario_id': usuarioId,
      'nit': nit,
      'razon_social': razonSocial,
      if (representanteLegal != null) 'representante_legal': representanteLegal,
      'direccion': direccion,
      'municipio': municipio,
      'email_contacto': emailContacto,
      'telefono_contacto': telefonoContacto,
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
      'estado_verificacion': estadoVerificacion,
      'disponible': disponible,
    };
    if (!forInsert && id != 0) {
      map['id'] = id;
    }
    return map;
  }

  /// Retorna una copia con campos modificados.
  PerfilGestor copyWith({
    int? id,
    String? usuarioId,
    String? nit,
    String? razonSocial,
    String? representanteLegal,
    String? direccion,
    String? municipio,
    String? emailContacto,
    String? telefonoContacto,
    double? latitud,
    double? longitud,
    String? estadoVerificacion,
    bool? disponible,
    DateTime? createdAt,
    List<int>? materialIds,
  }) {
    return PerfilGestor(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nit: nit ?? this.nit,
      razonSocial: razonSocial ?? this.razonSocial,
      representanteLegal: representanteLegal ?? this.representanteLegal,
      direccion: direccion ?? this.direccion,
      municipio: municipio ?? this.municipio,
      emailContacto: emailContacto ?? this.emailContacto,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      estadoVerificacion: estadoVerificacion ?? this.estadoVerificacion,
      disponible: disponible ?? this.disponible,
      createdAt: createdAt ?? this.createdAt,
      materialIds: materialIds ?? this.materialIds,
    );
  }

  bool get estaAprobado => estadoVerificacion == 'APROBADO';
  bool get estaPendiente => estadoVerificacion == 'PENDIENTE';
  bool get estaRechazado => estadoVerificacion == 'RECHAZADO';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerfilGestor && runtimeType == other.runtimeType && id == other.id && nit == other.nit;

  @override
  int get hashCode => id.hashCode ^ nit.hashCode;
}
