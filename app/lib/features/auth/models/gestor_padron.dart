/// Entidad inmutable que representa a un gestor ambiental registrado en el padrón oficial.
class GestorPadron {
  final int id;
  final String nit;
  final String razonSocial;
  final String? emailOficial;
  final String estadoVerificacion;
  final String? usuarioId;

  const GestorPadron({
    required this.id,
    required this.nit,
    required this.razonSocial,
    this.emailOficial,
    required this.estadoVerificacion,
    this.usuarioId,
  });

  /// Indica si la entidad gestora ya cuenta con una cuenta de usuario vinculada.
  bool get tieneCuentaActiva => usuarioId != null && usuarioId!.isNotEmpty;

  /// Indica si el registro se encuentra aprobado en el padrón ambiental.
  bool get estaAprobado => estadoVerificacion.toUpperCase() == 'APROBADO';

  /// Construye una instancia a partir de la respuesta relacional de la base de datos.
  factory GestorPadron.fromMap(Map<String, dynamic> map) {
    return GestorPadron(
      id: (map['id'] as num?)?.toInt() ?? 0,
      nit: (map['nit'] ?? '').toString().trim(),
      razonSocial: (map['razon_social'] ?? map['nombre_empresa'] ?? '').toString().trim(),
      emailOficial: (map['email_contacto'] ?? map['email_oficial'] ?? map['email'])?.toString().trim(),
      estadoVerificacion: (map['estado_verificacion'] ?? 'PENDIENTE').toString().trim().toUpperCase(),
      usuarioId: map['usuario_id']?.toString().trim(),
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
