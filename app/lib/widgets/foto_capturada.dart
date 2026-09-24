import 'package:flutter/material.dart';

import 'imagen_foto.dart';

/// Foto recién tomada, de borde a borde, con «cerrar» superpuesto (21–24).
class FotoCapturada extends StatelessWidget {
  const FotoCapturada({super.key, required this.ruta, this.alto = 280, this.onCerrar});

  final String ruta;

  /// Alto fijo; null para ocupar todo el espacio disponible.
  final double? alto;
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context) {
    final foto = SizedBox(
      width: double.infinity,
      height: alto,
      child: ImagenFoto(
        ruta: ruta,
        respaldo: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
      ),
    );
    return Stack(
      fit: alto == null ? StackFit.expand : StackFit.loose,
      children: [
        foto,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          child: IconButton.filled(
            tooltip: 'Cerrar',
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
            ),
            onPressed: onCerrar ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
