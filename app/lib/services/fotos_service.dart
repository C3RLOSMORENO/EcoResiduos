import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Carpetas dentro de `<uid>/` en el bucket.
enum CarpetaFoto {
  solicitudes('solicitudes'),
  escaneos('escaneos');

  const CarpetaFoto(this.nombre);
  final String nombre;
}

/// Captura, subida y borrado de fotos en Supabase Storage.
///
/// Todas las fotos van al bucket público `escaneos_ia` con la ruta
/// `<uid>/<carpeta>/<marca de tiempo>.<ext>`: la política del bucket solo deja
/// escribir y borrar dentro de la carpeta del propio usuario.
class FotosService {
  FotosService({this.client});

  static const bucket = 'escaneos_ia';

  /// Lado mayor al que se reduce la foto antes de subirla. Suficiente para que
  /// el gestor reconozca el residuo, y la foto queda en unos 200–400 KB.
  static const ladoMaximo = 1600.0;
  static const calidadJpeg = 80;

  /// Los nombres no se reutilizan, así que la foto se puede guardar en caché un año.
  static const _cacheControl = '31536000';

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Abre la galería y devuelve la ruta de la foto ya reducida, o null si el
  /// usuario cancela. El recorte y la compresión los hace el sistema operativo.
  static Future<String?> elegirDeGaleria() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: ladoMaximo,
      maxHeight: ladoMaximo,
      imageQuality: calidadJpeg,
    );
    return foto?.path;
  }

  /// Sube la foto local y devuelve su URL pública.
  Future<String> subir(String rutaLocal, CarpetaFoto carpeta) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('Inicia sesión para subir la foto.');

    final archivo = File(rutaLocal);
    if (!await archivo.exists()) throw StateError('La foto ya no está en el teléfono.');

    final extension = _extension(rutaLocal);
    final ruta = '$uid/${carpeta.nombre}/${DateTime.now().microsecondsSinceEpoch}$extension';

    await _supabase.storage
        .from(bucket)
        .upload(
          ruta,
          archivo,
          fileOptions: FileOptions(cacheControl: _cacheControl, contentType: _tipoContenido(extension)),
        );
    return _supabase.storage.from(bucket).getPublicUrl(ruta);
  }

  /// Borra una foto subida antes. No falla si ya no existe o no es de este bucket.
  Future<void> eliminar(String? url) async {
    final ruta = rutaEnBucket(url);
    if (ruta == null) return;
    try {
      await _supabase.storage.from(bucket).remove([ruta]);
    } on StorageException catch (e) {
      debugPrint('No se pudo borrar la foto $ruta: ${e.message}');
    }
  }

  /// Ruta dentro del bucket a partir de la URL pública, o null si la URL es de otro sitio.
  static String? rutaEnBucket(String? url) {
    if (url == null) return null;
    const marca = '/storage/v1/object/public/$bucket/';
    final inicio = url.indexOf(marca);
    if (inicio < 0) return null;
    final ruta = Uri.decodeFull(url.substring(inicio + marca.length).split('?').first);
    return ruta.isEmpty ? null : ruta;
  }

  static String _extension(String ruta) {
    final extension = p.extension(ruta).toLowerCase();
    return const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension) ? extension : '.jpg';
  }

  static String _tipoContenido(String extension) => switch (extension) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
