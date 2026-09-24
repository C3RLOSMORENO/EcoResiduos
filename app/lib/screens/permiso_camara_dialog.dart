import 'package:flutter/material.dart';

/// Explicación previa al diálogo de permiso del sistema (18). Devuelve
/// `true` si la persona decide continuar.
Future<bool?> showPermisoCamaraDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      icon: const Icon(Icons.photo_camera_outlined),
      title: const Text('Para identificar tu residuo usamos la cámara'),
      content: const SingleChildScrollView(
        child: Text('La foto se analiza en tu teléfono, sin internet. Solo se sube si decides publicarla.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Permitir cámara')),
      ],
    ),
  );
}
