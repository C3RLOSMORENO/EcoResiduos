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
    final sigla = map['sigla']?.toString();
    final nombre = (map['nombre'] ?? '').toString();
    final rawHorario = map['horario']?.toString();

    return AutoridadAmbiental(
      id: (map['id'] as num?)?.toInt(),
      nombre: nombre,
      sigla: sigla,
      jurisdiccion: (map['jurisdiccion'] ?? map['descripcion'] ?? '').toString(),
      telefono: (map['telefono'] ?? '').toString(),
      email: (map['email'] ?? map['correo'] ?? '').toString(),
      sitioWeb: (map['sitio_web'] ?? '').toString(),
      direccion: (map['direccion'] ?? '').toString(),
      horario: _horarioOficial(rawHorario, sigla, nombre),
    );
  }

  static String? _horarioOficial(String? horarioDirecto, String? sigla, String nombre) {
    if (horarioDirecto != null && horarioDirecto.trim().isNotEmpty) {
      return horarioDirecto.trim();
    }
    final s = '${sigla ?? ''} $nombre'.toUpperCase();
    if (s.contains('CDMB')) {
      return 'Lun-Vie 7:30 a.m. - 11:45 a.m. y 2:00 - 5:45 p.m.';
    }
    if (s.contains('AMB') || s.contains('METROPOLITANA')) {
      return 'Lun-Jue 8:00 a.m. - 5:00 p.m. | Vie 8:00 a.m. - 4:00 p.m.';
    }
    if (s.contains('CAS')) {
      return 'Lun-Jue 8:00 a.m. - 12:00 m. y 2:00 - 6:00 p.m. | Vie 7:00 a.m. - 3:00 p.m.';
    }
    return 'Lun-Vie 8:00 a.m. - 5:00 p.m.';
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
