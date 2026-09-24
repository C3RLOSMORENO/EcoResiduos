import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/historial_escaneo_ia.dart';
import '../models/waste_item.dart';
import 'fotos_service.dart';

/// Historial de escaneos con IA (tabla `historial_escaneos_ia`).
class HistorialService {
  /// Escaneos más recientes que se muestran; el resto sigue en la base de datos.
  static const _limiteHistorial = 50;

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Sube la foto y registra el escaneo. No se espera su resultado: si falla,
  /// el usuario igual ve su resultado.
  static Future<void> guardarEscaneoEnSegundoPlano(WasteItem item, String imagePath) async {
    final client = _supabase;
    if (client == null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final fotos = FotosService(client: client);
    String? imageUrl;
    try {
      imageUrl = await fotos.subir(imagePath, CarpetaFoto.escaneos);
      await client.from('historial_escaneos_ia').insert({
        'usuario_id': userId,
        'nombre_detectado': item.nombre,
        'categoria_detectada': item.categoria,
        'nivel_confianza': item.confianza,
        'imagen_path': imageUrl,
      });
    } catch (e) {
      debugPrint('No se pudo guardar el escaneo en el historial: $e');
      await fotos.eliminar(imageUrl);
    }
  }

  /// Consulta y mapea el historial de escaneos para un usuario determinado.
  static Future<List<HistorialEscaneoIa>> getHistorialUsuario([String? targetUserId]) async {
    final client = _supabase;
    if (client == null) return [];

    final userId = targetUserId ?? client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final List<dynamic> data = await client
          .from('historial_escaneos_ia')
          .select()
          .eq('usuario_id', userId)
          .order('created_at', ascending: false)
          .limit(_limiteHistorial);

      return data.map((map) => HistorialEscaneoIa.fromMap(map as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error al consultar historial_escaneos_ia: $e');
      return [];
    }
  }
}
