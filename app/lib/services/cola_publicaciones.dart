import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../features/solicitudes/repositories/solicitudes_repository.dart';

/// Indica si el fallo se debe a la falta de conexión y no a los datos.
bool esErrorDeConexion(Object error) {
  if (error is SocketException || error is TimeoutException || error is AuthRetryableFetchException) return true;
  final texto = error.toString();
  return texto.contains('SocketException') || texto.contains('ClientException') || texto.contains('Failed host lookup');
}

/// Publicación hecha sin conexión, guardada en el teléfono hasta poder enviarla.
class PublicacionPendiente {
  const PublicacionPendiente({
    required this.id,
    required this.solicitud,
    required this.nombreMaterial,
    required this.creada,
    this.fotoLocal,
  });

  factory PublicacionPendiente.fromJson(Map<String, dynamic> json) => PublicacionPendiente(
    id: json['id'] as String,
    solicitud: SolicitudRecoleccion.fromMap(json['solicitud'] as Map<String, dynamic>),
    nombreMaterial: json['nombre_material'] as String,
    creada: DateTime.parse(json['creada'] as String),
    fotoLocal: json['foto_local'] as String?,
  );

  final String id;

  /// Datos de la publicación sin generador: se resuelve al enviarla.
  final SolicitudRecoleccion solicitud;
  final String nombreMaterial;
  final DateTime creada;

  /// Copia de la foto en el almacenamiento de la app (la original puede estar en caché).
  final String? fotoLocal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'solicitud': solicitud.toMap(forInsert: true),
    'nombre_material': nombreMaterial,
    'creada': creada.toIso8601String(),
    'foto_local': fotoLocal,
  };
}

/// Publicaciones pendientes de enviar. Se guardan en el teléfono y se envían
/// al abrir la app, al volver a ella o cuando el usuario lo pide.
abstract final class ColaPublicaciones {
  static const _clave = 'publicaciones_pendientes';

  static final pendientes = ValueNotifier<List<PublicacionPendiente>>(const []);
  static bool _enviando = false;

  /// Lee del teléfono las publicaciones que quedaron sin enviar.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getStringList(_clave) ?? const [];
      pendientes.value = [
        for (final item in crudo) PublicacionPendiente.fromJson(jsonDecode(item) as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('No se pudo leer la cola de publicaciones: $e');
    }
  }

  /// Guarda la publicación y una copia de su foto para enviarlas después.
  static Future<void> agregar({
    required SolicitudRecoleccion solicitud,
    required String nombreMaterial,
    String? foto,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    String? copia;
    if (foto != null) {
      final carpeta = Directory(p.join((await getApplicationSupportDirectory()).path, 'publicaciones_pendientes'));
      await carpeta.create(recursive: true);
      copia = (await File(foto).copy(p.join(carpeta.path, '$id${p.extension(foto)}'))).path;
    }
    final pendiente = PublicacionPendiente(
      id: id,
      solicitud: solicitud,
      nombreMaterial: nombreMaterial,
      creada: DateTime.now(),
      fotoLocal: copia,
    );
    await _guardar([...pendientes.value, pendiente]);
  }

  /// Envía las pendientes en orden. Se detiene si sigue sin haber conexión.
  /// Devuelve cuántas se publicaron.
  static Future<int> enviar(SolicitudesRepository repository) async {
    if (_enviando || pendientes.value.isEmpty) return 0;
    _enviando = true;
    var enviadas = 0;
    try {
      for (final pendiente in List.of(pendientes.value)) {
        try {
          await _enviarUna(pendiente, repository);
        } catch (e) {
          debugPrint('No se pudo enviar la publicación pendiente ${pendiente.id}: $e');
          if (esErrorDeConexion(e)) break;
          continue;
        }
        enviadas++;
        await _guardar([
          for (final p in pendientes.value)
            if (p.id != pendiente.id) p,
        ]);
        await _borrarFoto(pendiente.fotoLocal);
      }
    } finally {
      _enviando = false;
    }
    return enviadas;
  }

  /// Quita la publicación de la cola y borra su copia de la foto.
  static Future<void> descartar(PublicacionPendiente pendiente) async {
    await _guardar([
      for (final p in pendientes.value)
        if (p.id != pendiente.id) p,
    ]);
    await _borrarFoto(pendiente.fotoLocal);
  }

  static Future<void> _enviarUna(PublicacionPendiente pendiente, SolicitudesRepository repository) async {
    final generadorId = await repository.getGeneradorId();
    if (generadorId == null) throw StateError('No se encontró el perfil de generador.');

    final foto = pendiente.fotoLocal;
    String? subida;
    if (foto != null && await File(foto).exists()) subida = await repository.subirFoto(foto);

    try {
      await repository.crearSolicitud(
        pendiente.solicitud.copyWith(generadorId: generadorId, fotoUrl: subida ?? pendiente.solicitud.fotoUrl),
      );
    } catch (_) {
      if (subida != null) unawaited(repository.eliminarFoto(subida));
      rethrow;
    }
  }

  static Future<void> _guardar(List<PublicacionPendiente> lista) async {
    pendientes.value = List.unmodifiable(lista);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_clave, [for (final p in lista) jsonEncode(p.toJson())]);
  }

  static Future<void> _borrarFoto(String? ruta) async {
    if (ruta == null) return;
    try {
      await File(ruta).delete();
    } on FileSystemException catch (e) {
      debugPrint('No se pudo borrar la copia de la foto: ${e.message}');
    }
  }
}
