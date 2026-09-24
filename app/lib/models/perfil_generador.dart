/// Modelo de dominio para la tabla 'public.perfiles_generador'.
class PerfilGenerador {
  final int id;
  final String usuarioId;
  final String nombreCompletoOEmpresa;
  final String documentoNit;
  final String telefono;
  final String municipio;
  final String email;
  final DateTime? createdAt;

  const PerfilGenerador({
    required this.id,
    required this.usuarioId,
    required this.nombreCompletoOEmpresa,
    required this.documentoNit,
    required this.telefono,
    required this.municipio,
    required this.email,
    this.createdAt,
  });

  /// Instancia un perfil de generador desde la base de datos.
  factory PerfilGenerador.fromMap(Map<String, dynamic> map) {
    return PerfilGenerador(
      id: (map['id'] as num?)?.toInt() ?? 0,
      usuarioId: map['usuario_id']?.toString() ?? '',
      nombreCompletoOEmpresa: (map['nombre_completo_o_empresa'] ?? '').toString(),
      documentoNit: (map['documento_nit'] ?? '').toString(),
      telefono: (map['telefono'] ?? '').toString(),
      municipio: (map['municipio'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  /// Serializa a mapa para persistencia.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'usuario_id': usuarioId,
      'nombre_completo_o_empresa': nombreCompletoOEmpresa,
      'documento_nit': documentoNit,
      'telefono': telefono,
      'municipio': municipio,
      'email': email,
    };
    if (!forInsert && id != 0) {
      map['id'] = id;
    }
    return map;
  }

  /// Retorna una copia con campos modificados.
  PerfilGenerador copyWith({
    int? id,
    String? usuarioId,
    String? nombreCompletoOEmpresa,
    String? documentoNit,
    String? telefono,
    String? municipio,
    String? email,
    DateTime? createdAt,
  }) {
    return PerfilGenerador(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombreCompletoOEmpresa: nombreCompletoOEmpresa ?? this.nombreCompletoOEmpresa,
      documentoNit: documentoNit ?? this.documentoNit,
      telefono: telefono ?? this.telefono,
      municipio: municipio ?? this.municipio,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerfilGenerador && runtimeType == other.runtimeType && id == other.id && usuarioId == other.usuarioId;

  @override
  int get hashCode => id.hashCode ^ usuarioId.hashCode;
}
