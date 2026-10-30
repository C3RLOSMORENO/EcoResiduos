import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../legal/politica_datos.dart';

/// Autorización del tratamiento de datos personales (Ley 1581 de 2012): si el
/// usuario ya aceptó la versión vigente de la política y el registro de su
/// aceptación.
///
/// La aceptación se guarda en la base (`usuarios.autorizacion_datos_version`,
/// con fecha) y también en el teléfono, para no bloquear la app sin conexión.
class AutorizacionDatosService {
  AutorizacionDatosService({SupabaseClient? client}) : _clientInyectado = client;

  final SupabaseClient? _clientInyectado;
  SupabaseClient get _client => _clientInyectado ?? Supabase.instance.client;

  static String _clave(String usuarioId) => 'autorizacion_datos_$usuarioId';

  /// true si el usuario aceptó la versión vigente.
  Future<bool> vigente(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    final aceptoEnEsteTelefono = prefs.getString(_clave(usuarioId)) == versionPoliticaDatos;
    try {
      final fila = await _client
          .from('usuarios')
          .select('autorizacion_datos_version')
          .eq('id', usuarioId)
          .maybeSingle();
      if (fila?['autorizacion_datos_version'] == versionPoliticaDatos) {
        await prefs.setString(_clave(usuarioId), versionPoliticaDatos);
        return true;
      }
      // Aceptó sin conexión y no alcanzó a enviarse: se envía ahora.
      if (aceptoEnEsteTelefono) {
        await _registrarEnLaBase();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('No se pudo consultar la autorización de datos: $e');
      return aceptoEnEsteTelefono;
    }
  }

  /// Registra la aceptación. Si no hay conexión queda guardada en el teléfono
  /// y [vigente] la envía después.
  Future<void> aceptar(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave(usuarioId), versionPoliticaDatos);
    try {
      await _registrarEnLaBase();
    } catch (e) {
      debugPrint('La autorización de datos se enviará cuando haya conexión: $e');
    }
  }

  Future<void> _registrarEnLaBase() =>
      _client.rpc('registrar_autorizacion_datos', params: {'p_version': versionPoliticaDatos});
}
