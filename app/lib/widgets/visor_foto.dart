import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';
import 'imagen_foto.dart';

/// Abre la foto a pantalla completa con zoom por pellizco o doble toque.
Future<void> abrirVisorFoto(BuildContext context, String ruta) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => VisorFoto(ruta: ruta),
      transitionsBuilder: (_, animacion, _, hijo) => FadeTransition(opacity: animacion, child: hijo),
    ),
  );
}

class VisorFoto extends StatefulWidget {
  const VisorFoto({super.key, required this.ruta});

  final String ruta;

  @override
  State<VisorFoto> createState() => _VisorFotoState();
}

class _VisorFotoState extends State<VisorFoto> {
  static const _zoomDobleToque = 2.5;

  final _transformacion = TransformationController();
  TapDownDetails? _ultimoToque;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _alternarZoom() {
    if (_transformacion.value.getMaxScaleOnAxis() > 1) {
      _transformacion.value = Matrix4.identity();
      return;
    }
    final punto = _ultimoToque?.localPosition ?? Offset.zero;
    _transformacion.value = Matrix4.identity()
      ..translateByDouble(-punto.dx * (_zoomDobleToque - 1), -punto.dy * (_zoomDobleToque - 1), 0, 1)
      ..scaleByDouble(_zoomDobleToque, _zoomDobleToque, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (detalles) => _ultimoToque = detalles,
            onDoubleTap: _alternarZoom,
            child: InteractiveViewer(
              transformationController: _transformacion,
              maxScale: 5,
              child: Hero(
                tag: widget.ruta,
                child: ImagenFoto(
                  ruta: widget.ruta,
                  fit: BoxFit.contain,
                  respaldo: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(EcoSpace.s8),
                child: IconButton.filled(
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
