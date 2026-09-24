import 'package:flutter/material.dart';

import '../features/solicitudes/screens/publicar_residuo_screen.dart';
import '../theme/eco_theme.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/foto_capturada.dart';
import 'flujo_identificacion.dart';
import 'residuos_screen.dart';

/// Confianza bajo el umbral (23): tono tranquilo y tres salidas con pesos distintos.
class ResiduoNoIdentificadoScreen extends StatelessWidget {
  const ResiduoNoIdentificadoScreen({
    super.key,
    required this.imagePath,
    required this.confianza,
    this.sinResiduo = false,
  });

  final String imagePath;
  final int confianza;

  /// La IA reconoció que la foto no muestra un residuo.
  final bool sinResiduo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          FotoCapturada(ruta: imagePath),
          EmptyStateWidget(
            icon: Icons.help_outline,
            title: sinResiduo ? 'No vemos un residuo' : 'No pudimos identificarlo',
            description: sinResiduo
                ? 'La foto parece mostrar solo el fondo. Centra el residuo y acércate un poco más.'
                : 'La IA no está segura ($confianza %). Prueba con más luz y con el residuo solo en la foto.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () => abrirIdentificacion(context, reemplazarActual: true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tomar otra foto'),
                ),
                const SizedBox(height: EcoSpace.s8),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResiduosScreen())),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar por nombre'),
                ),
                const SizedBox(height: EcoSpace.s4),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => PublicarResiduoScreen(fotoInicial: imagePath)),
                  ),
                  child: const Text('Publicar sin clasificar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
