/// Una autoridad ambiental oficial (WF-18, WF-19).
class AutoridadAmbiental {
  const AutoridadAmbiental({
    required this.nombre,
    required this.descripcion,
    required this.direccion,
    required this.telefono,
    required this.correo,
    required this.sitioWeb,
  });

  factory AutoridadAmbiental.fromJson(Map<String, dynamic> json) {
    return AutoridadAmbiental(
      nombre: json['nombre']?.toString() ?? json['sigla']?.toString() ?? '',
      descripcion: json['jurisdiccion']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      correo: json['email']?.toString() ?? '',
      sitioWeb: json['sitio_web']?.toString() ?? '',
    );
  }

  final String nombre;

  /// Ej. "Autoridad ambiental regional".
  final String descripcion;
  final String direccion;
  final String telefono;
  final String correo;
  final String sitioWeb;
}
