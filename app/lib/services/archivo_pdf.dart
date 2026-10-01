import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// PDF elegido en el teléfono, listo para subir.
class ArchivoPdf {
  const ArchivoPdf({required this.nombre, required this.bytes});

  final String nombre;
  final Uint8List bytes;
}

/// El archivo elegido no sirve; [mensaje] se muestra tal cual.
class PdfInvalido implements Exception {
  const PdfInvalido(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Límite de los buckets de certificados y permisos (10 MB).
const tamanoMaximoPdf = 10 * 1024 * 1024;

/// Abre el explorador de archivos filtrando PDF. Devuelve null si el usuario
/// cancela. En Android el archivo puede venir de Drive, así que se leen los
/// bytes en lugar de una ruta local.
Future<ArchivoPdf?> elegirPdf() async {
  final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
  if (archivo == null) return null;

  if (archivo.extension?.toLowerCase() != 'pdf') {
    throw const PdfInvalido('Elige un archivo PDF.');
  }
  final tamano = archivo.lengthSync() ?? await archivo.length();
  if (tamano != null && tamano > tamanoMaximoPdf) {
    throw const PdfInvalido('El PDF pesa más de 10 MB.');
  }
  return ArchivoPdf(nombre: archivo.name, bytes: await archivo.readAsBytes());
}
