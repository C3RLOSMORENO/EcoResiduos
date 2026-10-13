import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Estado vacío, de error o de espera: etiqueta con ícono, título, texto
/// y hasta dos salidas (una rellena y otra de texto).
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.ctaText,
    this.ctaIcon,
    this.onCtaPressed,
    this.secondaryText,
    this.onSecondaryPressed,
    this.tono = TonoEstado.neutro,
    this.child,
  });

  /// Estado de error de carga con «Reintentar».
  const EmptyStateWidget.error({
    super.key,
    required this.title,
    this.description = 'Revisa tu conexión e inténtalo de nuevo.',
    required VoidCallback onRetry,
    this.secondaryText,
    this.onSecondaryPressed,
  }) : icon = Icons.sync_problem,
       ctaText = 'Reintentar',
       ctaIcon = Icons.refresh,
       onCtaPressed = onRetry,
       tono = TonoEstado.error,
       child = null;

  final IconData icon;
  final String title;
  final String? description;
  final String? ctaText;
  final IconData? ctaIcon;
  final VoidCallback? onCtaPressed;
  final String? secondaryText;
  final VoidCallback? onSecondaryPressed;
  final TonoEstado tono;

  /// Contenido extra bajo la descripción (p. ej. los materiales declarados).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fondo, frente) = switch (tono) {
      TonoEstado.neutro => (scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
      TonoEstado.error => (scheme.errorContainer, scheme.onErrorContainer),
      TonoEstado.exito => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s24, vertical: EcoSpace.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 100,
            decoration: ShapeDecoration(
              color: fondo,
              shape: const EtiquetaBorder(radius: EcoRadius.medium, hole: 6, holeCenter: Offset(40, 18)),
            ),
            alignment: const Alignment(0, 0.3),
            child: Icon(icon, size: 36, color: frente),
          ),
          const SizedBox(height: EcoSpace.s20),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: EcoSpace.s8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (child != null) ...[const SizedBox(height: EcoSpace.s16), child!],
          if (ctaText != null && onCtaPressed != null) ...[
            const SizedBox(height: EcoSpace.s24),
            FilledButton.icon(
              onPressed: onCtaPressed,
              icon: Icon(ctaIcon ?? Icons.arrow_forward, size: 20),
              label: Text(ctaText!),
            ),
          ],
          if (secondaryText != null && onSecondaryPressed != null) ...[
            const SizedBox(height: EcoSpace.s8),
            TextButton(onPressed: onSecondaryPressed, child: Text(secondaryText!)),
          ],
        ],
      ),
    );
  }
}

/// Color del ícono de un estado vacío: neutro, de error o de éxito.
enum TonoEstado { neutro, error, exito }

/// Envuelve un estado para que se pueda «jalar para refrescar» y quede
/// centrado en el alto disponible.
class EstadoDesplazable extends StatelessWidget {
  const EstadoDesplazable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
