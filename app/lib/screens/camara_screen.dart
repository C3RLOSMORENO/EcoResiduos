import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/eco_colors.dart';

/// WF-04 — Cámara
///
/// Vista de captura en vivo utilizando el paquete `camera`.
class CamaraScreen extends StatefulWidget {
  const CamaraScreen({
    super.key,
    this.onCerrar,
    this.onCapturar,
  });

  final VoidCallback? onCerrar;
  /// Callback llamado al tomar la foto, pasando la ruta del archivo.
  final ValueChanged<String>? onCapturar;

  @override
  State<CamaraScreen> createState() => _CamaraScreenState();
}

class _CamaraScreenState extends State<CamaraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        await _controller!.setFlashMode(_flashMode);
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error inicializando la cámara: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    HapticFeedback.lightImpact();
    FlashMode nextMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      debugPrint('Error cambiando el flash: $e');
    }
  }

  Future<void> _tomarFoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    HapticFeedback.mediumImpact();

    try {
      final image = await _controller!.takePicture();
      widget.onCapturar?.call(image.path);
    } catch (e) {
      debugPrint('Error capturando foto: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.cameraBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    onTap: widget.onCerrar ?? () => Navigator.maybePop(context),
                  ),
                  _CircleIconButton(
                    icon: _flashMode != FlashMode.off
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  width: 310,
                  height: 384,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14), // un poco menos por el borde
                    child: _isInitialized && _controller != null
                        ? AspectRatio(
                            aspectRatio: 310 / 384,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize?.height ?? 1,
                                height: _controller!.value.previewSize?.width ?? 1,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Centra el residuo dentro del marco',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: _tomarFoto,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 4),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
