import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/fotos_service.dart';
import 'camara_screen.dart';
import 'permiso_camara_dialog.dart';
import 'permiso_rechazado_screen.dart';
import 'procesando_screen.dart';

/// Punto de entrada único de «Identificar» (FAB de Inicio y Residuos).
///
/// Explica el permiso antes del diálogo del sistema (18), abre la cámara (20)
/// y, si el permiso se niega, ofrece las salidas alternativas (19).
///
/// Con [reemplazarActual] la cámara ocupa el lugar de la pantalla actual
/// (p. ej. «Tomar otra foto» desde un resultado).
Future<void> abrirIdentificacion(BuildContext context, {bool reemplazarActual = false}) async {
  final estado = await Permission.camera.status;
  if (!context.mounted) return;

  if (estado.isGranted) {
    _abrirCamara(context, reemplazarActual);
    return;
  }

  if (!estado.isPermanentlyDenied) {
    final aceptoExplicacion = await showPermisoCamaraDialog(context);
    if (aceptoExplicacion != true || !context.mounted) return;

    final nuevoEstado = await Permission.camera.request();
    if (!context.mounted) return;
    if (nuevoEstado.isGranted) {
      _abrirCamara(context, reemplazarActual);
      return;
    }
  }

  _abrir(context, MaterialPageRoute(builder: (_) => const PermisoRechazadoScreen()), reemplazarActual);
}

/// Elige una foto de la galería y la analiza. No requiere permiso de cámara.
Future<void> identificarDesdeGaleria(BuildContext context, {bool reemplazar = false}) async {
  final ruta = await FotosService.elegirDeGaleria();
  if (ruta == null || !context.mounted) return;
  analizarFoto(context, ruta, reemplazar: reemplazar);
}

/// Abre la pantalla de análisis (21) para una foto ya tomada.
void analizarFoto(BuildContext context, String rutaFoto, {bool reemplazar = true}) {
  final ruta = MaterialPageRoute<void>(builder: (_) => ProcesandoScreen(imagePath: rutaFoto));
  if (reemplazar) {
    Navigator.pushReplacement(context, ruta);
  } else {
    Navigator.push(context, ruta);
  }
}

void _abrirCamara(BuildContext context, bool reemplazarActual) {
  _abrir(
    context,
    MaterialPageRoute(
      builder: (camaraContext) => CamaraScreen(onCapturar: (rutaFoto) => analizarFoto(camaraContext, rutaFoto)),
    ),
    reemplazarActual,
  );
}

void _abrir(BuildContext context, Route<void> ruta, bool reemplazar) {
  if (reemplazar) {
    Navigator.pushReplacement(context, ruta);
  } else {
    Navigator.push(context, ruta);
  }
}
