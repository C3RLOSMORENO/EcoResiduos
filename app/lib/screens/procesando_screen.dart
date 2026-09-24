import 'package:flutter/material.dart';

import '../services/historial_service.dart';
import '../services/identificacion_service.dart';
import '../theme/eco_theme.dart';
import '../widgets/foto_capturada.dart';
import 'error_procesamiento_screen.dart';
import 'residuo_no_identificado_screen.dart';
import 'resultado_screen.dart';

/// Análisis de la foto (21): la foto queda congelada y la etiqueta se
/// «imprime» mientras corre el modelo en el teléfono.
class ProcesandoScreen extends StatefulWidget {
  const ProcesandoScreen({super.key, required this.imagePath, this.service});

  final String imagePath;
  final IdentificacionService? service;

  @override
  State<ProcesandoScreen> createState() => _ProcesandoScreenState();
}

class _ProcesandoScreenState extends State<ProcesandoScreen> {
  /// Tiempo máximo antes de mostrar el error de análisis (24).
  static const _limite = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _procesar();
  }

  Future<void> _procesar() async {
    final service = widget.service ?? IdentificacionService();
    Widget siguiente;
    try {
      final resultado = await service.identificar(imagePath: widget.imagePath).timeout(_limite);
      HistorialService.guardarEscaneoEnSegundoPlano(resultado, widget.imagePath);
      siguiente = ResultadoScreen(item: resultado, imagePath: widget.imagePath);
    } on ResiduoNoIdentificadoException catch (e) {
      siguiente = ResiduoNoIdentificadoScreen(
        imagePath: widget.imagePath,
        confianza: e.confianza,
        sinResiduo: e.sinResiduo,
      );
    } catch (e) {
      debugPrint('Falló el análisis de la foto: $e');
      siguiente = ErrorProcesamientoScreen(imagePath: widget.imagePath);
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => siguiente));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reducir = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: colorVisorCamara,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FotoCapturada(ruta: widget.imagePath, alto: null),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40 + MediaQuery.paddingOf(context).bottom,
            child: Material(
              color: scheme.surfaceContainerLowest,
              shape: const EtiquetaBorder(radius: EcoRadius.medium, hole: 6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: reducir ? Duration.zero : const Duration(seconds: 3),
                      curve: Curves.easeOutCubic,
                      builder: (_, avance, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: avance,
                          heightFactor: 1,
                          child: ColoredBox(color: scheme.primary),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(EcoSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analizando tu residuo…', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: EcoSpace.s4),
                        Text(
                          'En tu teléfono, sin internet.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
