import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Resultado de enviar un formulario: credenciales que no coinciden, cuenta
/// sin activar, sin conexión… Lo que falla en un campo concreto no va aquí:
/// va como errorText debajo de ese campo.
///
/// Se pone justo encima del botón que envía, que es donde la persona está
/// mirando al tocarlo. El lector de pantalla lo anuncia apenas aparece
/// (liveRegion), sin mover el foco.
class AvisoFormulario extends StatelessWidget {
  const AvisoFormulario({super.key, required this.texto, this.titulo, this.informativo = false, this.accion});

  final String texto;
  final String? titulo;

  /// true para un estado que no es un error de la persona (por ejemplo, la
  /// cuenta aún sin activar): se pinta con el color secundario, no el rojo.
  final bool informativo;

  /// Botón opcional para resolverlo ahí mismo, como «Reenviar enlace».
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fondo = informativo ? scheme.secondaryContainer : scheme.errorContainer;
    final color = informativo ? scheme.onSecondaryContainer : scheme.onErrorContainer;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(EcoSpace.s12),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(EcoRadius.medium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(informativo ? Icons.info_outline : Icons.error_outline, color: color, size: 20),
                const SizedBox(width: EcoSpace.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titulo != null) Text(titulo!, style: theme.textTheme.titleSmall?.copyWith(color: color)),
                      Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
                    ],
                  ),
                ),
              ],
            ),
            if (accion != null) Align(alignment: Alignment.centerRight, child: accion),
          ],
        ),
      ),
    );
  }
}
