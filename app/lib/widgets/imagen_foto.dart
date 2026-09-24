import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Foto que puede ser una URL de Storage o un archivo del teléfono.
///
/// Las remotas quedan en la caché de disco, así que no se descargan de nuevo
/// al volver a abrir la app. Ambas se decodifican cerca del tamaño en pantalla
/// en lugar de a resolución completa, que es lo que llena la memoria en listas.
class ImagenFoto extends StatelessWidget {
  const ImagenFoto({super.key, required this.ruta, required this.respaldo, this.fit = BoxFit.cover});

  final String? ruta;

  /// Se muestra mientras carga, si falla o si no hay foto.
  final Widget respaldo;
  final BoxFit fit;

  /// Tope del ancho decodificado: coincide con el lado mayor de las fotos subidas.
  static const _anchoMaximo = 1600;

  @override
  Widget build(BuildContext context) {
    final ruta = this.ruta;
    if (ruta == null || ruta.isEmpty) return respaldo;

    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = _anchoDecodificado(restricciones, MediaQuery.devicePixelRatioOf(context));
        if (ruta.startsWith('http')) {
          return CachedNetworkImage(
            imageUrl: ruta,
            fit: fit,
            memCacheWidth: ancho,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => respaldo,
            errorWidget: (_, _, _) => respaldo,
          );
        }
        return Image.file(File(ruta), fit: fit, cacheWidth: ancho, errorBuilder: (_, _, _) => respaldo);
      },
    );
  }

  /// Con `BoxFit.cover` una foto horizontal en un cuadro llena el alto, no el
  /// ancho: decodificar al doble del lado mayor del cuadro evita que se vea borrosa.
  static int? _anchoDecodificado(BoxConstraints restricciones, double densidad) {
    final lados = [restricciones.maxWidth, restricciones.maxHeight].where((l) => l.isFinite);
    if (lados.isEmpty) return null;
    return math.min(_anchoMaximo, (lados.reduce(math.max) * densidad * 2).round());
  }
}
