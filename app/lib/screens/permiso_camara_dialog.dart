import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';

/// WF-03 — Permiso de cámara
///
/// Diálogo MD3 que explica por qué la app necesita acceso a la cámara,
/// antes de disparar el permiso real del sistema operativo.
///
/// Úsalo así:
/// ```dart
/// final permitido = await showPermisoCamaraDialog(context);
/// if (permitido == true) {
///   // dispara Permission.camera.request() del paquete permission_handler
/// }
/// ```
Future<bool?> showPermisoCamaraDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const PermisoCamaraDialog(),
  );
}

class PermisoCamaraDialog extends StatelessWidget {
  const PermisoCamaraDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EcoColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: EcoColors.primaryContainer,
              child: Icon(
                Icons.photo_camera_rounded,
                color: EcoColors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Permitir acceso a la cámara',
              style: TextStyle(
                fontSize: 20,
                height: 28 / 20,
                fontWeight: FontWeight.bold,
                color: EcoColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Necesitamos tu cámara para capturar la imagen del residuo '
              'y clasificarlo.',
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: EcoColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: EcoColors.primary,
                  ),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(fontSize: 14, letterSpacing: 0.4),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: EcoColors.primary,
                  ),
                  child: const Text(
                    'PERMITIR',
                    style: TextStyle(fontSize: 14, letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
