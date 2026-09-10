import 'package:flutter/material.dart';

import '../widgets/empty_state_screen.dart';

/// WF-11 — Permiso rechazado
///
/// Se muestra cuando el usuario negó el permiso de cámara y necesita
/// activarlo manualmente desde los ajustes del sistema.
class PermisoRechazadoScreen extends StatelessWidget {
  const PermisoRechazadoScreen({
    super.key,
    this.onAbrirConfiguracion,
    this.onCancelar,
  });

  final void Function(BuildContext)? onAbrirConfiguracion;
  final void Function(BuildContext)? onCancelar;

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      icon: Icons.warning_amber_rounded,
      title: 'Permiso de cámara denegado',
      subtitle:
          'Actívalo desde los ajustes del sistema para poder identificar '
          'residuos.',
      primaryLabel: 'ABRIR CONFIGURACIÓN',
      onPrimary: onAbrirConfiguracion,
      secondaryLabel: 'CANCELAR',
      onSecondary: onCancelar,
    );
  }
}
