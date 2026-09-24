/// Autoridad ambiental con jurisdicción en Santander (tabla `autoridades_ambientales`).
class AutoridadAmbiental {
  const AutoridadAmbiental({
    this.id,
    required this.nombre,
    this.sigla,
    this.jurisdiccion = '',
    this.telefono = '',
    this.email = '',
    this.sitioWeb = '',
    this.direccion = '',
    this.horario,
  });

  factory AutoridadAmbiental.fromMap(Map<String, dynamic> map) {
    return AutoridadAmbiental(
      id: (map['id'] as num?)?.toInt(),
      nombre: (map['nombre'] ?? '').toString(),
      sigla: map['sigla']?.toString(),
      jurisdiccion: (map['jurisdiccion'] ?? map['descripcion'] ?? '').toString(),
      telefono: (map['telefono'] ?? '').toString(),
      email: (map['email'] ?? map['correo'] ?? '').toString(),
      sitioWeb: (map['sitio_web'] ?? '').toString(),
      direccion: (map['direccion'] ?? '').toString(),
      horario: map['horario']?.toString(),
    );
  }

  final int? id;
  final String nombre;
  final String? sigla;
  final String jurisdiccion;
  final String telefono;
  final String email;
  final String sitioWeb;
  final String direccion;
  final String? horario;

  /// Nombre con su sigla, p. ej. «Área Metropolitana de Bucaramanga (AMB)».
  String get nombreCompleto => sigla == null || nombre.contains('($sigla)') ? nombre : '$nombre ($sigla)';
}
