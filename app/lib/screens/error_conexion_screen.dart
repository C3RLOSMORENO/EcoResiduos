import 'package:flutter/material.dart';

import '../widgets/empty_state_screen.dart';

/// WF-14 — Error de conexión
class ErrorConexionScreen extends StatelessWidget {
  const ErrorConexionScreen({
    super.key,
    this.onReintentar,
    this.onCancelar,
  });

  final void Function(BuildContext)? onReintentar;
  final void Function(BuildContext)? onCancelar;

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      icon: Icons.wifi_off_rounded,
      title: 'Sin conexión a internet',
      subtitle: 'Verifica tu conexión e intenta nuevamente.',
      primaryLabel: 'REINTENTAR',
      onPrimary: onReintentar,
      secondaryLabel: 'CANCELAR',
      onSecondary: onCancelar,
    );
  }
}
