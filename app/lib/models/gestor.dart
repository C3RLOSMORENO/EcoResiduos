/// Gestor certificado tal como se muestra en el directorio y en las fichas.
class Gestor {
  const Gestor({
    required this.id,
    required this.nombre,
    required this.municipio,
    this.nit = '',
    this.direccion = '',
    this.telefono = '',
    this.correo = '',
    this.horario,
    this.latitud,
    this.longitud,
    this.categorias = const [],
    this.distanciaKm,
    this.fotoPerfilPath,
    this.portadaPath,
  });

  /// Construye un gestor desde `perfiles_gestor` con sus materiales
  /// verificados (`gestor_material` → `materiales_residuos.categoria`).
  factory Gestor.fromMap(Map<String, dynamic> map) {
    final materiales = map['gestor_material'] as List<dynamic>? ?? const [];
    final categorias = <String>{
      for (final fila in materiales.whereType<Map<String, dynamic>>())
        if (fila['verificado'] != false && fila['materiales_residuos'] is Map)
          (fila['materiales_residuos'] as Map)['categoria']?.toString().toUpperCase() ?? '',
    }..remove('');

    return Gestor(
      id: (map['id'] as num?)?.toInt() ?? 0,
      nombre: (map['razon_social'] ?? '').toString(),
      municipio: (map['municipio'] ?? '').toString(),
      nit: (map['nit'] ?? '').toString(),
      direccion: (map['direccion'] ?? '').toString(),
      telefono: (map['telefono_contacto'] ?? '').toString(),
      correo: (map['email_contacto'] ?? '').toString(),
      horario: (map['horario'] ?? map['horario_atencion'])?.toString(),
      latitud: double.tryParse(map['latitud']?.toString() ?? ''),
      longitud: double.tryParse(map['longitud']?.toString() ?? ''),
      categorias: categorias.toList(),
      fotoPerfilPath: _textoOpcional(map['foto_perfil_path']),
      portadaPath: _textoOpcional(map['portada_path']),
    );
  }

  static String? _textoOpcional(Object? valor) {
    final texto = valor?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  final int id;
  final String nombre;
  final String municipio;
  final String nit;
  final String direccion;
  final String telefono;
  final String correo;
  final String? horario;
  final double? latitud;
  final double? longitud;

  /// Categorías que recibe (códigos de `materiales_residuos.categoria`).
  final List<String> categorias;

  /// Distancia al usuario en km; null si no se conoce su ubicación.
  final double? distanciaKm;

  /// Rutas de su foto de perfil y su portada en el bucket `fotos_perfil`.
  final String? fotoPerfilPath;
  final String? portadaPath;

  /// Copia del gestor con la distancia al usuario, en kilómetros.
  Gestor conDistancia(double? km) => Gestor(
    id: id,
    nombre: nombre,
    municipio: municipio,
    nit: nit,
    direccion: direccion,
    telefono: telefono,
    correo: correo,
    horario: horario,
    latitud: latitud,
    longitud: longitud,
    categorias: categorias,
    distanciaKm: km,
    fotoPerfilPath: fotoPerfilPath,
    portadaPath: portadaPath,
  );
}
