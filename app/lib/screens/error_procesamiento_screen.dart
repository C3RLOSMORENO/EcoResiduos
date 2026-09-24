import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/foto_capturada.dart';
import 'flujo_identificacion.dart';

/// Falló el análisis o tardó demasiado (24). La foto no se pierde.
class ErrorProcesamientoScreen extends StatelessWidget {
  const ErrorProcesamientoScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          FotoCapturada(ruta: imagePath),
          const EmptyStateWidget(
            icon: Icons.broken_image_outlined,
            tono: TonoEstado.error,
            title: 'No pudimos analizar la foto',
            description: 'Algo falló en el análisis. Tu foto sigue aquí; puedes intentarlo otra vez.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () => analizarFoto(context, imagePath),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: EcoSpace.s8),
                TextButton(
                  onPressed: () => identificarDesdeGaleria(context, reemplazar: true),
                  child: const Text('Elegir otra foto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
