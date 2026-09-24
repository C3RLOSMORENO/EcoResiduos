import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum PermisoUbicacion { concedido, sinDecidir, denegadoSiempre, gpsApagado }

/// Ubicación del teléfono para ordenar gestores y solicitudes por cercanía.
abstract final class UbicacionService {
  static Position? _ultima;

  /// Posición actual, o null si no hay GPS o el permiso fue negado.
  ///
  /// Con [pedirPermiso] muestra el diálogo del sistema cuando aún no se ha
  /// decidido; si no, solo usa el permiso ya concedido.
  static Future<Position?> actual({bool pedirPermiso = false}) {
    final consulta = _consultar(pedirPermiso);
    // Sin diálogo de por medio, la pantalla no espera al GPS indefinidamente.
    return pedirPermiso ? consulta : consulta.timeout(const Duration(seconds: 6), onTimeout: () => _ultima);
  }

  static Future<Position?> _consultar(bool pedirPermiso) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _ultima;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied && pedirPermiso) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso != LocationPermission.whileInUse && permiso != LocationPermission.always) return null;
      _ultima = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 5)),
      );
    } catch (e) {
      debugPrint('No se pudo obtener la ubicación: $e');
    }
    return _ultima;
  }

  /// Estado del permiso sin mostrar ningún diálogo.
  static Future<PermisoUbicacion> permiso() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return PermisoUbicacion.gpsApagado;
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always || LocationPermission.whileInUse => PermisoUbicacion.concedido,
        LocationPermission.deniedForever => PermisoUbicacion.denegadoSiempre,
        LocationPermission.denied => PermisoUbicacion.sinDecidir,
        _ => PermisoUbicacion.sinDecidir,
      };
    } catch (_) {
      return PermisoUbicacion.sinDecidir;
    }
  }

  /// Abre los ajustes del sistema para activar el GPS o el permiso.
  static Future<void> abrirAjustes(PermisoUbicacion estado) async {
    if (estado == PermisoUbicacion.gpsApagado) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Distancia en km entre la posición [desde] y unas coordenadas, o null si falta algún dato.
  static double? distanciaKm(Position? desde, double? latitud, double? longitud) {
    if (desde == null || latitud == null || longitud == null) return null;
    return Geolocator.distanceBetween(desde.latitude, desde.longitude, latitud, longitud) / 1000;
  }
}
