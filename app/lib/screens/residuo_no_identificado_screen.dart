import 'package:flutter/material.dart';

import '../widgets/empty_state_screen.dart';

/// WF-12 — Residuo no identificado
class ResiduoNoIdentificadoScreen extends StatelessWidget {
  const ResiduoNoIdentificadoScreen({
    super.key,
    this.onReintentar,
    this.onCancelar,
  });

  final void Function(BuildContext)? onReintentar;
  final void Function(BuildContext)? onCancelar;

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      icon: Icons.question_mark_rounded,
      title: 'No pudimos identificar el residuo',
      subtitle:
          'Intenta con mejor iluminación o busca el residuo manualmente.',
      primaryLabel: 'REINTENTAR',
      onPrimary: onReintentar,
      secondaryLabel: 'CANCELAR',
      onSecondary: onCancelar,
    );
  }
}
