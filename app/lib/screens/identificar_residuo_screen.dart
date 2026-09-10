import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';

/// WF-02 — Identificar residuo
///
/// Pantalla que invita al usuario a tomar una foto del residuo para que
/// la IA lo identifique y sugiera recomendaciones de manejo.
class IdentificarResiduoScreen extends StatelessWidget {
  const IdentificarResiduoScreen({
    super.key,
    this.onAbrirCamara,
    this.onCancelar,
  });

  final VoidCallback? onAbrirCamara;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Identificar residuo'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  children: [
                    const _FotoPreview(),
                    const SizedBox(height: 24),
                    const Text(
                      'Toma una foto del residuo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        height: 28 / 20,
                        fontWeight: FontWeight.bold,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Usaremos IA para identificar el tipo de residuo y '
                      'darte recomendaciones de manejo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: EcoColors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: onAbrirCamara,
                        style: FilledButton.styleFrom(
                          backgroundColor: EcoColors.primary,
                          foregroundColor: EcoColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'ABRIR CÁMARA',
                          style: TextStyle(fontSize: 14, letterSpacing: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed:
                            onCancelar ?? () => Navigator.maybePop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: EcoColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(fontSize: 14, letterSpacing: 0.4),
                        ),
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

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: EcoColors.background,
        border: Border(bottom: BorderSide(color: EcoColors.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: EcoColors.onSurface,
            onPressed: () => Navigator.maybePop(context),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.bold,
              color: EcoColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro grande con el ícono de cámara, tal como en el wireframe.
/// Cuando conectes la cámara real, este widget es el lugar natural para
/// mostrar el preview en vivo o la miniatura de la foto tomada.
class _FotoPreview extends StatelessWidget {
  const _FotoPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: EcoColors.accentSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 34,
          backgroundColor: EcoColors.primary,
          child: const Icon(
            Icons.photo_camera_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
