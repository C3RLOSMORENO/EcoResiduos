class GestorDirectorio {
  final int id;
  final String nit;
  final String razonSocial;
  final String? emailOficial;
  final String estadoVerificacion;
  final String? usuarioId;
  final String? telefono;
  final String? direccion;
  final String? municipio;
  final List<int> materialIds;

  const GestorDirectorio({
    required this.id,
    required this.nit,
    required this.razonSocial,
    this.emailOficial,
    required this.estadoVerificacion,
    this.usuarioId,
    this.telefono,
    this.direccion,
    this.municipio,
    this.materialIds = const [],
  });

  bool get tieneCuentaActiva => usuarioId != null && usuarioId!.isNotEmpty;
  bool get estaAprobado => estadoVerificacion.toUpperCase() == 'APROBADO';
  bool get tieneCorreo => emailOficial?.isNotEmpty ?? false;

  factory GestorDirectorio.fromMap(Map<String, dynamic> map) {
    String? texto(String clave) {
      final valor = map[clave]?.toString().trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    return GestorDirectorio(
      id: (map['id'] as num?)?.toInt() ?? 0,
      nit: (map['nit'] ?? '').toString().trim(),
      razonSocial: (map['razon_social'] ?? map['nombre_empresa'] ?? '').toString().trim(),
      emailOficial: (map['email_contacto'] ?? map['email_oficial'] ?? map['email'])?.toString().trim(),
      estadoVerificacion: (map['estado_verificacion'] ?? 'PENDIENTE').toString().trim().toUpperCase(),
      usuarioId: map['usuario_id']?.toString().trim(),
      telefono: texto('telefono_contacto'),
      direccion: texto('direccion'),
      municipio: texto('municipio'),
      materialIds: [
        for (final fila in (map['gestor_material'] as List?) ?? const [])
          if ((fila as Map)['material_id'] is num) (fila['material_id'] as num).toInt(),
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nit': nit,
      'razon_social': razonSocial,
      if (emailOficial != null) 'email_contacto': emailOficial,
      'estado_verificacion': estadoVerificacion,
      if (usuarioId != null) 'usuario_id': usuarioId,
    };
  }
}
