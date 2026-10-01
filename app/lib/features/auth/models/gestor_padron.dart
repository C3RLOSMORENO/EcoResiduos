/// Entidad inmutable que representa a un gestor ambiental registrado en el padrón oficial.
class GestorPadron {
  final int id;
  final String nit;
  final String razonSocial;
  final String? emailOficial;
  final String estadoVerificacion;
  final String? usuarioId;
  final String? telefono;
  final String? direccion;
  final String? municipio;

  /// Materiales que la empresa ya tiene registrados en el padrón.
  final List<int> materialIds;

  const GestorPadron({
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

  /// Indica si la entidad gestora ya cuenta con una cuenta de usuario vinculada.
  bool get tieneCuentaActiva => usuarioId != null && usuarioId!.isNotEmpty;

  /// Indica si el registro se encuentra aprobado en el padrón ambiental.
  bool get estaAprobado => estadoVerificacion.toUpperCase() == 'APROBADO';

  /// Sin correo en el padrón no hay a dónde enviar el enlace de activación.
  bool get tieneCorreo => emailOficial?.isNotEmpty ?? false;

  /// Construye una instancia a partir de la respuesta relacional de la base de datos.
  factory GestorPadron.fromMap(Map<String, dynamic> map) {
    String? texto(String clave) {
      final valor = map[clave]?.toString().trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    return GestorPadron(
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

  /// Serializa la entidad a formato mapa.
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
