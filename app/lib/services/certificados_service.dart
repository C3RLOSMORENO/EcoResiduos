import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'archivo_pdf.dart';

/// Subida y borrado de los certificados PDF de los gestores.
///
/// Van al bucket público `certificados` con la ruta
/// `<uid>/<id solicitud>/<marca de tiempo>.pdf`: la política del bucket solo
/// deja escribir y borrar dentro de la carpeta del propio usuario.
class CertificadosService {
  CertificadosService({this.client});

  static const bucket = 'certificados';

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Sube el PDF y devuelve su URL pública.
  Future<String> subir(ArchivoPdf pdf, {required int solicitudId}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('Inicia sesión para subir el certificado.');

    final ruta = '$uid/$solicitudId/${DateTime.now().microsecondsSinceEpoch}.pdf';
    await _supabase.storage
        .from(bucket)
        .uploadBinary(ruta, pdf.bytes, fileOptions: const FileOptions(contentType: 'application/pdf'));
    return _supabase.storage.from(bucket).getPublicUrl(ruta);
  }

  /// Borra un certificado subido antes. No falla si ya no existe o no es de este bucket.
  Future<void> eliminar(String? url) async {
    final ruta = rutaEnBucket(url);
    if (ruta == null) return;
    try {
      await _supabase.storage.from(bucket).remove([ruta]);
    } on StorageException catch (e) {
      debugPrint('No se pudo borrar el certificado $ruta: ${e.message}');
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
}
