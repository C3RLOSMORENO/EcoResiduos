import 'package:flutter/foundation.dart';

import '../repositories/notificaciones_repository.dart';

/// Número de novedades sin leer que muestra la campana de la cabecera.
///
/// Se actualiza al iniciar sesión, en tiempo real con Supabase Realtime y
/// cada vez que el usuario lee o descarta una novedad.
abstract final class ContadorNovedades {
  static final noLeidas = ValueNotifier<int>(0);

  /// Cambia cada vez que llega una notificación en tiempo real. Las pantallas
  /// que dependen de lo que avisa (p. ej. la aprobación del gestor) lo escuchan
  /// para volver a consultar sin que el usuario tenga que actualizar.
  static final llegadas = ValueNotifier<int>(0);

  static NotificacionesRepository? _repository;
  static VoidCallback? _cancelar;

  static void iniciar(NotificacionesRepository repository) {
    detener();
    _repository = repository;
    _cancelar = repository.escucharCambios(() {
      llegadas.value++;
      actualizar();
    });
    actualizar();
  }

  static Future<void> actualizar() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      noLeidas.value = await repository.contarNoLeidas();
    } catch (e) {
      debugPrint('No se pudo contar las novedades: $e');
    }
  }

  static void detener() {
    _cancelar?.call();
    _cancelar = null;
    _repository = null;
    noLeidas.value = 0;
  }
}
