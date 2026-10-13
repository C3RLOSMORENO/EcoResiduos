import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notificacion.dart';

/// Novedades del usuario autenticado (tabla `notificaciones`).
abstract class NotificacionesRepository {
  /// Las 50 notificaciones más recientes, de la más nueva a la más antigua.
  Future<List<Notificacion>> listar();

  Future<int> contarNoLeidas();

  Future<void> marcarLeida(int id);

  Future<void> marcarTodasLeidas();

  /// Borra la notificación.
  Future<void> descartar(int id);

  /// Llama a [alCambiar] cada vez que llega o cambia una notificación propia.
  /// Devuelve la función que cancela la suscripción.
  VoidCallback escucharCambios(VoidCallback alCambiar);
}

/// [NotificacionesRepository] sobre la tabla `notificaciones` y Supabase Realtime.
/// Sin sesión devuelve listas vacías y no hace nada.
class SupabaseNotificacionesRepository implements NotificacionesRepository {
  SupabaseNotificacionesRepository({this.client});

  final SupabaseClient? client;

  /// Nulo si Supabase no está inicializado (pruebas de widgets).
  SupabaseClient? get _client {
    if (client != null) return client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Avisos más recientes que se muestran.
  static const _limite = 50;

  String? get _uid => _client?.auth.currentUser?.id;

  @override
  Future<List<Notificacion>> listar() async {
    final uid = _uid;
    if (uid == null) return [];
    final List<dynamic> filas = await _client!
        .from('notificaciones')
        .select()
        .eq('usuario_id', uid)
        .order('created_at', ascending: false)
        .limit(_limite);
    return filas.map((f) => Notificacion.fromMap(f as Map<String, dynamic>)).toList();
  }

  @override
  Future<int> contarNoLeidas() async {
    final uid = _uid;
    if (uid == null) return 0;
    final respuesta = await _client!
        .from('notificaciones')
        .select('id')
        .eq('usuario_id', uid)
        .isFilter('leida_at', null)
        .count(CountOption.exact);
    return respuesta.count;
  }

  @override
  Future<void> marcarLeida(int id) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('notificaciones')
        .update({'leida_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .isFilter('leida_at', null);
  }

  @override
  Future<void> marcarTodasLeidas() async {
    final uid = _uid;
    if (uid == null) return;
    await _client!
        .from('notificaciones')
        .update({'leida_at': DateTime.now().toUtc().toIso8601String()})
        .eq('usuario_id', uid)
        .isFilter('leida_at', null);
  }

  @override
  Future<void> descartar(int id) async {
    await _client?.from('notificaciones').delete().eq('id', id);
  }

  @override
  VoidCallback escucharCambios(VoidCallback alCambiar) {
    final uid = _uid;
    if (uid == null) return () {};
    final client = _client!;
    final canal = client
        .channel('notificaciones-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'usuario_id', value: uid),
          callback: (_) => alCambiar(),
        )
        .subscribe();
    return () => client.removeChannel(canal);
  }
}
