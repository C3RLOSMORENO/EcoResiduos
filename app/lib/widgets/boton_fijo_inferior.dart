import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Barra fija inferior con la acción principal (56 dp) y, en formularios, la
/// meta de avance «N de M campos» con lo que falta.
class BotonFijoInferior extends StatelessWidget {
  const BotonFijoInferior({
    super.key,
    required this.textoBoton,
    required this.onPressed,
    this.iconoBoton,
    this.isLoading = false,
    this.textoLoading,
    this.camposCompletados,
    this.totalCampos,
    this.mensajeCamposFaltantes,
    this.botonSecundario,
  });

  final String textoBoton;
  final VoidCallback? onPressed;
  final IconData? iconoBoton;
  final bool isLoading;
  final String? textoLoading;
  final int? camposCompletados;
  final int? totalCampos;
  final String? mensajeCamposFaltantes;
  final Widget? botonSecundario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tieneMeta = camposCompletados != null && totalCampos != null && totalCampos! > 0;

    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tieneMeta) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (mensajeCamposFaltantes != null && mensajeCamposFaltantes!.isNotEmpty)
                  Expanded(
                    child: Text(
                      mensajeCamposFaltantes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  '$camposCompletados de $totalCampos campos',
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.s8),
            Row(
              children: List.generate(totalCampos!, (index) {
                final isFilled = index < camposCompletados!;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == totalCampos! - 1 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: isFilled ? scheme.tertiary : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: EcoSpace.s12),
          ],

          Row(
            children: [
              if (botonSecundario != null) ...[Expanded(child: botonSecundario!), const SizedBox(width: EcoSpace.s12)],
              Expanded(
                flex: botonSecundario != null ? 2 : 1,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  onPressed: isLoading ? null : onPressed,
                  child: isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                textoLoading ?? 'Procesando…',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (iconoBoton != null) ...[Icon(iconoBoton, size: 20), const SizedBox(width: 8)],
                            Flexible(
                              child: Text(
                                textoBoton,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
