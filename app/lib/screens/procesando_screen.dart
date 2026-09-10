import 'package:flutter/material.dart';

import '../models/waste_item.dart';
import '../services/identificacion_service.dart';
import '../services/historial_service.dart';
import '../theme/eco_colors.dart';
import 'error_conexion_screen.dart';
import 'error_procesamiento_screen.dart';
import 'informacion_residuo_screen.dart';
import 'manejo_residuo_screen.dart';
import 'residuo_no_identificado_screen.dart';
import 'resultado_screen.dart';

/// WF-05 — Procesando
///
/// Dispara la identificación en cuanto se monta, y navega automáticamente
/// según el resultado: WF-06 (éxito), WF-12 (no identificado), WF-13
/// (error de procesamiento) o WF-14 (sin conexión). Esta pantalla es la
/// que conecta el flujo completo — el único cambio pendiente para cuando
/// llegue el modelo de IA real es lo que hay dentro de
/// [IdentificacionService.identificar].
class ProcesandoScreen extends StatefulWidget {
  const ProcesandoScreen({
    super.key,
    required this.imagePath,
    this.service,
  });

  final String imagePath;

  /// Inyectable para pruebas; si no se provee, usa una instancia nueva.
  final IdentificacionService? service;

  @override
  State<ProcesandoScreen> createState() => _ProcesandoScreenState();
}

class _ProcesandoScreenState extends State<ProcesandoScreen> {
  @override
  void initState() {
    super.initState();
    _procesar();
  }

  Future<void> _procesar() async {
    final service = widget.service ?? IdentificacionService();
    try {
      final WasteItem resultado = await service.identificar(
        imagePath: widget.imagePath,
      );
      
      // Guardar el escaneo en el historial (en segundo plano)
      HistorialService.guardarEscaneoEnSegundoPlano(resultado, widget.imagePath);

      _irA(
        ResultadoScreen(
          item: resultado,
          onReintentar: (resultContext) {
            Navigator.pushReplacement(
              resultContext,
              MaterialPageRoute(
                builder: (_) => ProcesandoScreen(imagePath: widget.imagePath, service: service),
              ),
            );
          },
          onVerInformacion: (resultContext) => Navigator.push(
            resultContext,
            MaterialPageRoute(
              builder: (ctx) => InformacionResiduoScreen(
                item: resultado,
                onVerManejo: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ManejoResiduoScreen(pasos: resultado.pasosManejo),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } on ResiduoNoIdentificadoException {
      _irA(ResiduoNoIdentificadoScreen(onReintentar: (resultContext) {
        Navigator.pushReplacement(
          resultContext,
          MaterialPageRoute(
            builder: (_) => ProcesandoScreen(imagePath: widget.imagePath, service: service),
          ),
        );
      }));
    } on SinConexionException {
      _irA(ErrorConexionScreen(onReintentar: (resultContext) {
        Navigator.pushReplacement(
          resultContext,
          MaterialPageRoute(
            builder: (_) => ProcesandoScreen(imagePath: widget.imagePath, service: service),
          ),
        );
      }));
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is ErrorProcesamientoException && e.message != null) {
          msg = e.message!;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg')),
        );
      }
      _irA(ErrorProcesamientoScreen(onReintentar: (resultContext) {
        Navigator.pushReplacement(
          resultContext,
          MaterialPageRoute(
            builder: (_) => ProcesandoScreen(imagePath: widget.imagePath, service: service),
          ),
        );
      }));
    }
  }

  void _irA(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: EcoColors.outline)),
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: EcoColors.primary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Analizando imagen...',
                      style: TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w500,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Esto puede tardar unos segundos',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: EcoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
