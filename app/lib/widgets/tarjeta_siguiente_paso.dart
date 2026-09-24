import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';
import 'skeleton_loading.dart';

/// Tarjeta dominante de Inicio (06, 07): la etiqueta con ojal que dice qué
/// hacer ahora. Una sola por pantalla.
class TarjetaSiguientePaso extends StatelessWidget {
  const TarjetaSiguientePaso({
    super.key,
    required this.titulo,
    this.encabezado = 'SIGUIENTE PASO',
    this.contador,
    this.chip,
    this.detalle,
    this.accion,
    this.onAccion,
    this.icono,
    this.nota,
  });

  final String titulo;
  final String encabezado;

  /// «1 DE 2» cuando hay más de un pendiente.
  final String? contador;
  final Widget? chip;
  final String? detalle;
  final String? accion;
  final VoidCallback? onAccion;

  /// Ícono grande para los estados sin acción («Todo al día»).
  final IconData? icono;

  /// Indicación final que señala otro control, p. ej. el FAB.
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suave = scheme.onPrimary.withValues(alpha: 0.78);

    return Container(
      decoration: ShapeDecoration(
        color: scheme.primary,
        shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: 24, hole: 7),
      ),
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  encabezado,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: theme.textTheme.headlineSmall?.fontFamily,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: scheme.brightness == Brightness.light
                        ? ecoDarkColorScheme.tertiary
                        : ecoLightColorScheme.tertiary,
                  ),
                ),
              ),
              if (contador != null)
                Text(
                  contador!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: theme.textTheme.headlineSmall?.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: suave,
                  ),
                ),
            ],
          ),
          if (chip != null) ...[const SizedBox(height: EcoSpace.s12), chip!],
          const SizedBox(height: EcoSpace.s12),
          if (icono != null) ...[Icon(icono, color: scheme.onPrimary, size: 32), const SizedBox(height: EcoSpace.s8)],
          Text(titulo, style: theme.textTheme.headlineMedium?.copyWith(color: scheme.onPrimary)),
          if (detalle != null) ...[
            const SizedBox(height: 6),
            Text(detalle!, style: theme.textTheme.bodyMedium?.copyWith(color: suave)),
          ],
          if (nota != null) ...[
            const SizedBox(height: EcoSpace.s16),
            Row(
              children: [
                Flexible(
                  child: Text(nota!, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimary)),
                ),
                const SizedBox(width: EcoSpace.s8),
                Icon(Icons.south_east, color: scheme.onPrimary, size: 20),
              ],
            ),
          ],
          if (accion != null && onAccion != null) ...[
            const SizedBox(height: EcoSpace.s16),
            FilledButton(
              onPressed: onAccion,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                textStyle: theme.textTheme.titleMedium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(accion!, textAlign: TextAlign.center)),
                  const SizedBox(width: EcoSpace.s8),
                  const Icon(Icons.arrow_forward, size: 22),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila «Después»: el segundo pendiente, más discreto que la tarjeta.
class FilaDespues extends StatelessWidget {
  const FilaDespues({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.fondoIcono,
    this.colorIcono,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color? fondoIcono;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fondoIcono ?? scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(EcoRadius.small),
                  ),
                  child: Icon(icono, size: 22, color: colorIcono ?? scheme.onSecondaryContainer),
                ),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Después', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(texto, style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Cifra {
  const Cifra({required this.valor, required this.etiqueta, this.icono, this.color});

  final int valor;
  final String etiqueta;
  final IconData? icono;
  final Color? color;
}

/// Franja de conteos por estado. Con texto grande pasa a una fila por cifra.
class FranjaCifras extends StatelessWidget {
  const FranjaCifras({super.key, required this.cifras});

  final List<Cifra> cifras;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textoGrande = MediaQuery.textScalerOf(context).scale(1) > 1.5;

    final celdas = [
      for (var i = 0; i < cifras.length; i++)
        _CeldaCifra(cifra: cifras[i], separador: !textoGrande && i < cifras.length - 1),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(EcoRadius.medium),
      ),
      child: textoGrande
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: celdas)
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final celda in celdas) Expanded(child: celda)],
              ),
            ),
    );
  }
}

class _CeldaCifra extends StatelessWidget {
  const _CeldaCifra({required this.cifra, required this.separador});

  final Cifra cifra;
  final bool separador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: '${cifra.valor} ${cifra.etiqueta}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.all(EcoSpace.s12),
        decoration: separador
            ? BoxDecoration(
                border: Border(right: BorderSide(color: scheme.outlineVariant)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cifra.valor}', style: theme.textTheme.displaySmall?.copyWith(height: 1)),
            const SizedBox(height: EcoSpace.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cifra.icono != null) ...[
                  Icon(cifra.icono, size: 16, color: cifra.color ?? scheme.onSurfaceVariant),
                  const SizedBox(width: EcoSpace.s4),
                ],
                Expanded(
                  child: Text(
                    cifra.etiqueta,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
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

/// Esqueleto de Inicio con la forma exacta de la tarjeta y la franja.
class InicioSkeleton extends StatelessWidget {
  const InicioSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: 248,
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh,
            shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: 24, hole: 7),
          ),
        ),
        const SizedBox(height: EcoSpace.s12),
        const ShimmerLoading(height: 64, radius: EcoRadius.medium),
        const SizedBox(height: EcoSpace.s12),
        const ShimmerLoading(height: 88, radius: EcoRadius.medium),
      ],
    );
  }
}
