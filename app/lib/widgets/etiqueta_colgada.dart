import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Pantalla de éxito con la etiqueta que «cuelga» del ojal: gira de −8° a 0°
/// en 500 ms. Si el sistema pide reducir movimiento, es un fundido de 150 ms.
class ExitoEtiquetaScreen extends StatelessWidget {
  const ExitoEtiquetaScreen({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.accionPrincipal,
    required this.onAccionPrincipal,
    this.accionSecundaria,
    this.onAccionSecundaria,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String accionPrincipal;
  final VoidCallback onAccionPrincipal;
  final String? accionSecundaria;
  final VoidCallback? onAccionSecundaria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EcoSpace.s24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _EtiquetaAnimada(icono: icono),
                        const SizedBox(height: EcoSpace.s24),
                        Text(titulo, textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
                        const SizedBox(height: EcoSpace.s8),
                        Text(
                          descripcion,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: onAccionPrincipal,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text(accionPrincipal),
              ),
              if (accionSecundaria != null && onAccionSecundaria != null) ...[
                const SizedBox(height: EcoSpace.s8),
                TextButton(
                  onPressed: onAccionSecundaria,
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(accionSecundaria!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EtiquetaAnimada extends StatelessWidget {
  const _EtiquetaAnimada({required this.icono});

  final IconData icono;

  static const _ojal = Offset(40, 22);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reducir = MediaQuery.of(context).disableAnimations;

    final etiqueta = Container(
      width: 80,
      height: 100,
      decoration: ShapeDecoration(
        color: scheme.primaryContainer,
        shape: const EtiquetaBorder(radius: EcoRadius.medium, hole: 6, holeCenter: _ojal),
      ),
      alignment: const Alignment(0, 0.35),
      child: Icon(icono, size: 40, color: scheme.onPrimaryContainer),
    );

    if (reducir) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        builder: (_, valor, child) => Opacity(opacity: valor, child: child),
        child: etiqueta,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -8, end: 0),
      duration: EcoMotion.exito,
      curve: Curves.easeOutBack,
      builder: (_, grados, child) =>
          Transform.rotate(angle: grados * math.pi / 180, origin: _ojal - const Offset(40, 50), child: child),
      child: etiqueta,
    );
  }
}
