import 'package:supabase_flutter/supabase_flutter.dart';

/// Rol de la cuenta: 'GENERADOR' o 'GESTOR'.
///
/// Se lee de la tabla `usuarios`, que solo escribe el servidor. Los
/// `user_metadata` los puede cambiar el propio usuario, así que no deciden permisos.
Future<String> consultarRol(SupabaseClient client) async {
  final uid = client.auth.currentUser?.id;
  if (uid == null) return 'GENERADOR';

  final fila = await client.from('usuarios').select('rol').eq('id', uid).maybeSingle();
  final rol = fila?['rol']?.toString().toUpperCase();
  if (rol == 'GESTOR' || rol == 'GENERADOR') return rol!;

  final gestor = await client.from('perfiles_gestor').select('id').eq('usuario_id', uid).maybeSingle();
  return gestor != null ? 'GESTOR' : 'GENERADOR';
}

/// Datos de la cuenta autenticada tomados de los metadatos de Supabase Auth.
class SesionUsuario {
  const SesionUsuario({
    this.nombre = '',
    this.correo = '',
    this.telefono,
    this.municipio,
    this.documento,
    this.esGestor = false,
    this.fotoUrl,
  });

  /// Lee la sesión actual. Devuelve una sesión vacía si Supabase no está
  /// inicializado (pruebas de widgets) o no hay usuario.
  factory SesionUsuario.actual() {
    User? user;
    try {
      user = Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return const SesionUsuario();
    }
    return SesionUsuario.desdeUsuario(user);
  }

  factory SesionUsuario.desdeUsuario(User? user) {
    final meta = user?.userMetadata ?? const <String, dynamic>{};
    String? texto(List<String> claves) {
      for (final clave in claves) {
        final valor = meta[clave]?.toString().trim();
        if (valor != null && valor.isNotEmpty) return valor;
      }
      return null;
    }

    final rol = texto(['rol', 'rol_usuario', 'role'])?.toUpperCase();
    final esGestor = rol == 'GESTOR';
    return SesionUsuario(
      nombre: texto(['razon_social', 'nombre_completo_o_empresa', 'full_name', 'nombre']) ?? '',
      correo: user?.email ?? '',
      telefono: texto(['telefono']),
      municipio: texto(['municipio']),
      documento: esGestor ? texto(['nit']) : texto(['documento_nit', 'documento']),
      esGestor: esGestor,
      fotoUrl: texto(['foto_url', 'avatar_url']),
    );
  }

  final String nombre;
  final String correo;
  final String? telefono;
  final String? municipio;
  final String? documento;
  final bool esGestor;
  final String? fotoUrl;

  /// Nombre para el saludo: primer nombre de una persona o la razón social
  /// completa de una empresa.
  String get nombreSaludo {
    if (nombre.isEmpty) return '';
    if (esGestor) return nombre.replaceAll(RegExp(r'\s+S\.?A\.?S\.?$', caseSensitive: false), '');
    return nombre.split(RegExp(r'\s+')).first;
  }
}
