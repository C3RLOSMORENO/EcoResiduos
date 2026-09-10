import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import '../models/waste_item.dart';

class HistorialService {
  static final _supabase = Supabase.instance.client;

  /// Guarda el escaneo subiendo primero la foto a Storage y luego insertando el registro.
  /// Esto se hace en segundo plano para no congelar la pantalla del usuario.
  static Future<void> guardarEscaneoEnSegundoPlano(WasteItem item, String imagePath) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No hay usuario logueado. Saltando guardado de historial.');
      return;
    }

    try {
      final file = File(imagePath);
      final fileExtension = p.extension(imagePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      
      // Guardamos la imagen en una carpeta con el ID del usuario
      final storagePath = '$userId/$fileName';

      debugPrint('Subiendo imagen a Supabase Storage...');
      await _supabase.storage.from('escaneos_ia').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = _supabase.storage.from('escaneos_ia').getPublicUrl(storagePath);
      debugPrint('Imagen subida: $imageUrl');

      debugPrint('Insertando registro en historial_escaneos_ia...');
      await _supabase.from('historial_escaneos_ia').insert({
        'usuario_id': userId,
        'nombre_detectado': item.nombre,
        'categoria_detectada': item.categoria,
        'nivel_confianza': item.confianza,
        'imagen_path': imageUrl,
      });

      debugPrint('Historial guardado exitosamente.');
    } catch (e) {
      debugPrint('Error grave al guardar el historial: $e');
    }
  }
}
