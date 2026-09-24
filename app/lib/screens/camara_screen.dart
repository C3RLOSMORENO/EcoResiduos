import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/fotos_service.dart';
import '../theme/eco_theme.dart';

/// Visor de cámara (20). Siempre oscuro; la guía de encuadre tiene la forma
/// de la etiqueta y el disparador de 80 dp queda en la zona del pulgar.
class CamaraScreen extends StatefulWidget {
  const CamaraScreen({super.key, required this.onCapturar});

  /// Recibe la ruta de la foto tomada o elegida de la galería.
  final ValueChanged<String> onCapturar;

  @override
  State<CamaraScreen> createState() => _CamaraScreenState();
}

class _CamaraScreenState extends State<CamaraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _flash = false;
  bool _capturando = false;
  bool _sinCamara = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _iniciar();
    }
  }

  Future<void> _iniciar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        if (mounted) setState(() => _sinCamara = true);
        return;
      }
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controller = CameraController(trasera, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      debugPrint('No se pudo iniciar la cámara: $e');
      if (mounted) setState(() => _sinCamara = true);
    }
  }

  Future<void> _alternarFlash() async {
    final controller = _controller;
    if (controller == null) return;
    HapticFeedback.selectionClick();
    try {
      await controller.setFlashMode(_flash ? FlashMode.off : FlashMode.torch);
      setState(() => _flash = !_flash);
    } catch (e) {
      debugPrint('No se pudo cambiar el flash: $e');
    }
  }

  Future<void> _tomarFoto() async {
    final controller = _controller;
    if (controller == null || _capturando) return;
    HapticFeedback.mediumImpact();
    setState(() => _capturando = true);
    try {
      final foto = await controller.takePicture();
      if (_flash) await controller.setFlashMode(FlashMode.off);
      widget.onCapturar(foto.path);
    } catch (e) {
      debugPrint('No se pudo tomar la foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo tomar la foto.')));
      }
    } finally {
      if (mounted) setState(() => _capturando = false);
    }
  }

  Future<void> _galeria() async {
    final ruta = await FotosService.elegirDeGaleria();
    if (ruta != null) widget.onCapturar(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colorVisorCamara,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? 1,
                  height: controller.value.previewSize?.width ?? 1,
                  child: CameraPreview(controller),
                ),
              )
            else if (_sinCamara)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(EcoSpace.s32),
                  child: Text(
                    'No pudimos abrir la cámara. Puedes elegir una foto de la galería.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            const IgnorePointer(child: CustomPaint(painter: _GuiaEtiquetaPainter())),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(EcoSpace.s8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BotonCircular(icono: Icons.close, tooltip: 'Cerrar', onTap: () => Navigator.maybePop(context)),
                        if (controller != null)
                          _BotonCircular(
                            icono: _flash ? Icons.flash_on : Icons.flash_off,
                            tooltip: _flash ? 'Apagar flash' : 'Encender flash',
                            onTap: _alternarFlash,
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s24),
                    child: Text(
                      'Centra el residuo dentro de la etiqueta',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: _BotonCircular(
                              icono: Icons.photo_library_outlined,
                              tooltip: 'Galería',
                              onTap: _galeria,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Tomar foto',
                          child: GestureDetector(
                            onTap: _tomarFoto,
                            child: Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _capturando ? Colors.white54 : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oscurece el visor fuera de la guía y dibuja el contorno de la etiqueta
/// (inset 40, arriba 140, alto 340) con su ojal.
class _GuiaEtiquetaPainter extends CustomPainter {
  const _GuiaEtiquetaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final alto = (size.height - 140 - 230).clamp(200.0, 340.0);
    final guia = Rect.fromLTWH(40, 140, size.width - 80, alto);
    const forma = EtiquetaBorder(radius: EcoRadius.medium, hole: 8, holeCenter: Offset(30, 30));
    final contorno = forma.getOuterPath(guia);

    final velo = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), contorno);
    canvas.drawPath(velo, Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawPath(
      contorno,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_GuiaEtiquetaPainter oldDelegate) => false;
}

class _BotonCircular extends StatelessWidget {
  const _BotonCircular({required this.icono, required this.tooltip, required this.onTap});

  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icono),
    );
  }
}
