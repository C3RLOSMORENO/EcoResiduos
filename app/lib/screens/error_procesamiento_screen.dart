import 'package:flutter/material.dart';

import '../widgets/empty_state_screen.dart';

/// WF-13 — Error de procesamiento
class ErrorProcesamientoScreen extends StatelessWidget {
  const ErrorProcesamientoScreen({
    super.key,
    this.onReintentar,
    this.onCancelar,
  });

  final void Function(BuildContext)? onReintentar;
  final void Function(BuildContext)? onCancelar;

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      icon: Icons.warning_amber_rounded,
      title: 'Error al procesar la imagen',
      subtitle: 'Ocurrió un problema al analizar la foto. Intenta de nuevo.',
      primaryLabel: 'REINTENTAR',
      onPrimary: onReintentar,
      secondaryLabel: 'CANCELAR',
      onSecondary: onCancelar,
    );
  }
}
