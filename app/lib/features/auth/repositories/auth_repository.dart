import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/perfil_generador.dart';
import '../../../models/perfil_gestor.dart';
import '../../../services/archivo_pdf.dart';
import '../../../utils/sesion.dart';
import '../models/gestor_directorio.dart';

/// Autenticación, registro y perfil de la cuenta.
abstract class AuthRepository {
  User? get currentUser;

  Future<AuthResponse> signIn({required String email, required String password});

  /// Vuelve a enviar el enlace de activación de la cuenta.
  Future<void> reenviarConfirmacion(String email);

  Future<AuthResponse> signUpGenerador({
    required String email,
    required String password,
    required String nombre,
    required String documento,
    required String telefono,
    required String municipio,
  });

  /// Busca por su NIT una empresa ya registrada como gestor autorizado, con
  /// sus datos de contacto y los materiales que ya tiene registrados.
  Future<GestorDirectorio?> buscarGestorEnDirectorio(String nit);

  /// Crea la cuenta de un gestor que ya está registrado en el directorio. Los materiales
  /// declarados quedan pendientes de verificación por el administrador.
  Future<AuthResponse> signUpGestor({
    required String email,
    required String password,
    required GestorDirectorio gestorDirectorio,
    required String razonSocial,
    required String telefono,
    required String direccion,
    required String municipio,
    required List<int> materialesDeclarados,
  });

  /// Sube la licencia o permiso ambiental de un gestor que aún no tiene cuenta
  /// y devuelve su ruta en el bucket privado `permisos`.
  Future<String> subirPermisoAmbiental(ArchivoPdf pdf);

  /// Crea la cuenta de una empresa que no está registrada. La empresa se crea
  /// en el primer inicio de sesión y queda PENDIENTE hasta que el administrador
  /// revisa el permiso.
  Future<AuthResponse> signUpGestorNuevo({
    required String email,
    required String password,
    required String nit,
    required String razonSocial,
    required String representanteLegal,
    required String telefono,
    required String direccion,
    required String municipio,
    String? horario,
    required String permisoPath,
    required List<int> materialesDeclarados,
  });

  Future<void> solicitarRecuperacionPassword(String email);

  Future<AuthResponse> verificarOtpRecuperacion({required String email, required String token});

  Future<UserResponse> actualizarPassword(String nuevaPassword);

  Future<void> signOut();

  /// 'GENERADOR' o 'GESTOR'.
  Future<String> getRolUsuario();

  Future<PerfilGenerador?> getPerfilGenerador();

  Future<PerfilGestor?> getPerfilGestor();

  Future<void> actualizarMunicipio(String municipio);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({this.client});

  final SupabaseClient? client;

  SupabaseClient get _client => client ?? Supabase.instance.client;

  @override
  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthResponse> signIn({required String email, required String password}) async {
    try {
      final respuesta = await _client.auth.signInWithPassword(email: email.trim(), password: password);
      final user = respuesta.user;
      if (user != null && user.userMetadata?['rol']?.toString().toUpperCase() == 'GESTOR') {
        await _vincularGestor();
      }
      return respuesta;
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  /// Las filas de `usuarios` y `perfiles_generador` las crea el trigger de
  /// `auth.users` al registrarse. La empresa del gestor se vincula en el primer
  /// inicio de sesión, cuando el correo ya está confirmado; la función del
  /// servidor comprueba que coincida con el registrado para la empresa.
  Future<void> _vincularGestor() async {
    try {
      await _client.rpc('vincular_cuenta_gestor');
    } on PostgrestException catch (e) {
      debugPrint('No se pudo vincular la cuenta con la empresa: ${e.message}');
    }
  }

  @override
  Future<void> reenviarConfirmacion(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email.trim());
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<AuthResponse> signUpGenerador({
    required String email,
    required String password,
    required String nombre,
    required String documento,
    required String telefono,
    required String municipio,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'rol': 'GENERADOR',
          'nombre_completo_o_empresa': nombre.trim(),
          'documento_nit': documento.trim(),
          'telefono': telefono.trim(),
          'municipio': municipio,
        },
      );
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<GestorDirectorio?> buscarGestorEnDirectorio(String nit) async {
    final sinDigitoVerificacion = normalizarNit(nit);
    final todosLosDigitos = nit.replaceAll(RegExp(r'[^0-9]'), '');
    if (sinDigitoVerificacion.isEmpty) return null;
    final filas = await _client
        .from('perfiles_gestor')
        .select(
          'id, nit, razon_social, email_contacto, estado_verificacion, usuario_id, '
          'telefono_contacto, direccion, municipio, gestor_material(material_id)',
        )
        .inFilter('nit', {sinDigitoVerificacion, todosLosDigitos}.toList())
        .limit(1);
    return filas.isEmpty ? null : GestorDirectorio.fromMap(filas.first);
  }

  @override
  Future<AuthResponse> signUpGestor({
    required String email,
    required String password,
    required GestorDirectorio gestorDirectorio,
    required String razonSocial,
    required String telefono,
    required String direccion,
    required String municipio,
    required List<int> materialesDeclarados,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'rol': 'GESTOR',
          'gestor_id': gestorDirectorio.id,
          'nit': gestorDirectorio.nit,
          'razon_social': razonSocial.trim(),
          'telefono': telefono.trim(),
          'direccion': direccion.trim(),
          'municipio': municipio,
          'materiales_declarados': materialesDeclarados,
        },
      );
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<String> subirPermisoAmbiental(ArchivoPdf pdf) async {
    // Sin sesión no hay carpeta propia: el nombre aleatorio evita que otro
    // registro adivine la ruta y la reclame como suya.
    final aleatorio = Random.secure();
    final nombre = List.generate(16, (_) => aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final ruta = 'registro/$nombre.pdf';
    await _client.storage
        .from('permisos')
        .uploadBinary(ruta, pdf.bytes, fileOptions: const FileOptions(contentType: 'application/pdf'));
    return ruta;
  }

  @override
  Future<AuthResponse> signUpGestorNuevo({
    required String email,
    required String password,
    required String nit,
    required String razonSocial,
    required String representanteLegal,
    required String telefono,
    required String direccion,
    required String municipio,
    String? horario,
    required String permisoPath,
    required List<int> materialesDeclarados,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'rol': 'GESTOR',
          'registro_nuevo': true,
          'nit': normalizarNit(nit),
          'razon_social': razonSocial.trim(),
          'representante_legal': representanteLegal.trim(),
          'telefono': telefono.trim(),
          'direccion': direccion.trim(),
          'municipio': municipio,
          if (horario != null && horario.trim().isNotEmpty) 'horario': horario.trim(),
          'permiso_path': permisoPath,
          'materiales_declarados': materialesDeclarados,
        },
      );
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<void> solicitarRecuperacionPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<AuthResponse> verificarOtpRecuperacion({required String email, required String token}) async {
    try {
      return await _client.auth.verifyOTP(email: email.trim(), token: token.trim(), type: OtpType.recovery);
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<UserResponse> actualizarPassword(String nuevaPassword) async {
    try {
      return await _client.auth.updateUser(UserAttributes(password: nuevaPassword));
    } on AuthException catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<String> getRolUsuario() => consultarRol(_client);

  @override
  Future<PerfilGenerador?> getPerfilGenerador() async {
    final id = currentUser?.id;
    if (id == null) return null;
    final fila = await _client.from('perfiles_generador').select().eq('usuario_id', id).maybeSingle();
    return fila == null ? null : PerfilGenerador.fromMap(fila);
  }

  @override
  Future<PerfilGestor?> getPerfilGestor() async {
    final id = currentUser?.id;
    if (id == null) return null;
    final fila = await _client.from('perfiles_gestor').select().eq('usuario_id', id).maybeSingle();
    return fila == null ? null : PerfilGestor.fromMap(fila);
  }

  @override
  Future<void> actualizarMunicipio(String municipio) async {
    final user = currentUser;
    if (user == null) return;
    final tabla = await getRolUsuario() == 'GESTOR' ? 'perfiles_gestor' : 'perfiles_generador';
    await _client.from(tabla).update({'municipio': municipio}).eq('usuario_id', user.id);
    await _client.auth.updateUser(UserAttributes(data: {'municipio': municipio}));
  }

  AuthException _traducir(AuthException e) {
    final mensaje = e.message.toLowerCase();
    if (mensaje.contains('invalid login credentials')) {
      return AuthException('El correo o la contraseña no coinciden.', code: e.code);
    }
    if (mensaje.contains('email not confirmed')) {
      return AuthException('Aún no has activado tu cuenta.', code: 'email_not_confirmed');
    }
    if (mensaje.contains('already registered') || mensaje.contains('already exists')) {
      return AuthException('Ya existe una cuenta con este correo.', code: e.code);
    }
    if (mensaje.contains('expired')) {
      return AuthException('El código venció. Pide uno nuevo.', code: e.code);
    }
    if (mensaje.contains('token') || mensaje.contains('otp')) {
      return AuthException('El código no coincide. Revisa el correo más reciente.', code: e.code);
    }
    if (mensaje.contains('password')) {
      return AuthException('La contraseña debe tener al menos 8 caracteres y un número.', code: e.code);
    }
    return AuthException(e.message, code: e.code);
  }
}

/// NIT sin puntos, espacios ni dígito de verificación: «900.456.789-2» → «900456789».
String normalizarNit(String nit) {
  final sinDv = nit.split('-').first;
  return sinDv.replaceAll(RegExp(r'[^0-9]'), '');
}
