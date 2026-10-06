import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/sesion.dart';

/// Imágenes del perfil: la foto (todos) y la portada (solo gestores, se ve
/// detrás de su foto en la ficha del directorio).
enum ImagenPerfil {
  foto(carpeta: 'perfil', columna: 'foto_perfil_path', ladoMaximo: 512),
  portada(carpeta: 'portada', columna: 'portada_path', ladoMaximo: 1600);

  const ImagenPerfil({required this.carpeta, required this.columna, required this.ladoMaximo});

  /// Carpeta dentro de `<uid>/` en el bucket.
  final String carpeta;

  /// Columna del perfil y clave de `user_metadata` donde se guarda la ruta.
  final String columna;

  /// Lado mayor al que se reduce antes de subirla.
  final double ladoMaximo;
}

/// Elige, sube, guarda y quita la foto de perfil y la portada.
///
/// Las fotos van al bucket público `fotos_perfil` con la ruta
/// `<uid>/<carpeta>/<marca de tiempo>.<ext>`. La tabla del perfil guarda la
/// ruta (la migración 20261006000000 exige que sea de la carpeta del dueño) y
/// `user_metadata` una copia, para que la barra superior la muestre sin
/// consultar la base.
class FotoPerfilService {
  FotoPerfilService({this.client});

  static const bucket = 'fotos_perfil';
  static const calidadJpeg = 85;

  /// Cada foto nueva lleva un nombre nuevo, así que se puede guardar en caché un año.
  static const _cacheControl = '31536000';

  /// Avisa a la barra superior y a la hoja de cuenta que la foto cambió.
  static final ValueNotifier<int> cambios = ValueNotifier(0);

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Abre la galería o la cámara y devuelve la ruta de la foto ya reducida, o
  /// null si la persona cancela. La compresión la hace el sistema operativo.
  static Future<String?> elegir(ImageSource origen, ImagenPerfil imagen) async {
    final foto = await ImagePicker().pickImage(
      source: origen,
      maxWidth: imagen.ladoMaximo,
      maxHeight: imagen.ladoMaximo,
      imageQuality: calidadJpeg,
      preferredCameraDevice: imagen == ImagenPerfil.foto ? CameraDevice.front : CameraDevice.rear,
    );
    return foto?.path;
  }

  /// URL pública de una ruta del bucket, o null si no hay ruta o Supabase no
  /// está inicializado (pruebas de widgets).
  static String? url(String? ruta) {
    if (ruta == null || ruta.isEmpty) return null;
    try {
      return Supabase.instance.client.storage.from(bucket).getPublicUrl(ruta);
    } catch (_) {
      return null;
    }
  }

  /// Ruta nueva dentro de la carpeta del usuario. Debe cumplir la restricción
  /// de la base: `<uid>/<carpeta>/<dígitos>.(jpg|jpeg|png|webp)`.
  static String rutaNueva(String uid, ImagenPerfil imagen, String rutaLocal, DateTime ahora) {
    return '$uid/${imagen.carpeta}/${ahora.microsecondsSinceEpoch}${_extension(rutaLocal)}';
  }

  /// Sube la foto local, la deja como [imagen] del perfil, borra la anterior y
  /// devuelve la ruta nueva.
  Future<String> cambiar(String rutaLocal, ImagenPerfil imagen) async {
    final uid = _uid();
    final archivo = File(rutaLocal);
    if (!await archivo.exists()) throw StateError('La foto ya no está en el teléfono.');

    final anterior = _rutaActual(imagen);
    final ruta = rutaNueva(uid, imagen, rutaLocal, DateTime.now());
    await _supabase.storage
        .from(bucket)
        .upload(
          ruta,
          archivo,
          fileOptions: FileOptions(cacheControl: _cacheControl, contentType: _tipoContenido(_extension(rutaLocal))),
        );
    try {
      await _guardar(uid, imagen, ruta);
    } catch (_) {
      // Sin guardar en el perfil la foto subida queda huérfana: se borra.
      await _borrar(ruta);
      rethrow;
    }
    await _borrar(anterior);
    cambios.value++;
    return ruta;
  }

  /// Quita [imagen] del perfil y borra el archivo.
  Future<void> quitar(ImagenPerfil imagen) async {
    final uid = _uid();
    final anterior = _rutaActual(imagen);
    await _guardar(uid, imagen, null);
    await _borrar(anterior);
    cambios.value++;
  }

  String _uid() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('Inicia sesión para cambiar tu foto.');
    return uid;
  }

  String? _rutaActual(ImagenPerfil imagen) => _supabase.auth.currentUser?.userMetadata?[imagen.columna]?.toString();

  Future<void> _guardar(String uid, ImagenPerfil imagen, String? ruta) async {
    final tabla = await consultarRol(_supabase) == 'GESTOR' ? 'perfiles_gestor' : 'perfiles_generador';
    final filas = await _supabase.from(tabla).update({imagen.columna: ruta}).eq('usuario_id', uid).select('id');
    if (filas.isEmpty) throw StateError('No encontramos tu perfil.');
    await _supabase.auth.updateUser(UserAttributes(data: {imagen.columna: ruta}));
  }

  /// Borra un archivo del bucket. No falla si ya no existe.
  Future<void> _borrar(String? ruta) async {
    if (ruta == null || ruta.isEmpty) return;
    try {
      await _supabase.storage.from(bucket).remove([ruta]);
    } on StorageException catch (e) {
      debugPrint('No se pudo borrar la foto $ruta: ${e.message}');
    }
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
