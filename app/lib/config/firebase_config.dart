import 'package:firebase_core/firebase_core.dart';

/// Datos del proyecto de Firebase que envía las notificaciones al teléfono.
///
/// Salen de la consola de Firebase: Configuración del proyecto → General →
/// la app Android `co.edu.udes.ecoresiduos` (o del google-services.json
/// descargado). Como la llave publicable de Supabase, pueden ir en la app: no
/// dan permiso para enviar notificaciones, eso requiere la cuenta de servicio
/// que solo tiene la Edge Function `enviar-push`.
///
/// Mientras estén vacíos la app no pide el permiso ni registra el teléfono, y
/// los avisos se ven solo dentro de la app.
abstract final class FirebaseConfig {
  /// `client[0].api_key[0].current_key` en google-services.json.
  static const apiKey = '';

  /// `client[0].client_info.mobilesdk_app_id`.
  static const appId = '';

  /// `project_info.project_number`.
  static const messagingSenderId = '';

  /// `project_info.project_id`.
  static const projectId = '';

  static bool get configurado =>
      apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;

  static const opciones = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
  );
}
