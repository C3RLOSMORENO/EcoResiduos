import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/firebase_config.dart';

/// Notificaciones en el teléfono (Firebase Cloud Messaging).
///
/// Cada novedad que la base guarda en `notificaciones` la envía la Edge
/// Function `enviar-push` a los teléfonos registrados del usuario. Con la app
/// cerrada o en segundo plano, Android la muestra en la barra de
/// notificaciones; con la app abierta no se muestra nada extra, porque la
/// campana ya se actualiza en tiempo real.
abstract final class PushService {
  static bool _iniciado = false;
  static StreamSubscription<String>? _renovacion;
  static StreamSubscription<RemoteMessage>? _aperturas;

  /// Se llama cuando alguien toca una notificación del teléfono. La pone
  /// InicioScreen para abrir la pantalla de novedades.
  static void Function()? alAbrirNotificacion;

  /// Inicia Firebase. Se llama una vez en `main`. Si no hay configuración o
  /// falla, la app sigue sin notificaciones en el teléfono.
  static Future<void> iniciar() async {
    if (!FirebaseConfig.configurado || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.opciones);
      _iniciado = true;
    } catch (e) {
      debugPrint('No se pudo iniciar Firebase: $e');
    }
  }

  /// Pide el permiso (Android 13 en adelante) y registra este teléfono para
  /// la cuenta de la sesión. Se llama al entrar a la app con sesión.
  static Future<void> registrar() async {
    if (!_iniciado) return;
    final messaging = FirebaseMessaging.instance;
    try {
      final permiso = await messaging.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) return;

      // getToken y onTokenRefresh están marcados como obsoletos desde
      // firebase_messaging 17 en favor de register()/onRegistered, que entregan
      // el ID de instalación (FID) para otro modo de envío. enviar-push usa el
      // token de registro con la API HTTP v1, que sigue funcionando; cambiar a
      // FID implica cambiar también la Edge Function.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _guardar(token);
      await _renovacion?.cancel();
      // ignore: deprecated_member_use
      _renovacion = messaging.onTokenRefresh.listen(_guardar);

      await _aperturas?.cancel();
      _aperturas = FirebaseMessaging.onMessageOpenedApp.listen((_) => alAbrirNotificacion?.call());
      // La app estaba cerrada y se abrió tocando la notificación.
      if (await messaging.getInitialMessage() != null) alAbrirNotificacion?.call();
    } catch (e) {
      debugPrint('No se pudo registrar el teléfono para notificaciones: $e');
    }
  }

  /// Borra el registro de este teléfono para que la cuenta que cierra sesión
  /// no le siga mandando avisos. Se llama antes de cerrar sesión, porque la
  /// base pide la sesión para borrarlo.
  static Future<void> desregistrar() async {
    if (!_iniciado) return;
    await _renovacion?.cancel();
    _renovacion = null;
    await _aperturas?.cancel();
    _aperturas = null;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client.rpc('quitar_dispositivo_push', params: {'p_token': token});
      }
    } catch (e) {
      debugPrint('No se pudo quitar el teléfono de las notificaciones: $e');
    }
  }

  static Future<void> _guardar(String token) async {
    try {
      await Supabase.instance.client.rpc('registrar_dispositivo_push', params: {'p_token': token});
    } catch (e) {
      debugPrint('No se pudo guardar el token de notificaciones: $e');
    }
  }
}
