import 'package:flutter/material.dart';

import '../screens/notificaciones_screen.dart';
import '../services/contador_novedades.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/sesion.dart';
import 'cuenta_bottom_sheet.dart';

/// Cabecera única de las vistas principales: título grande, campana y avatar.
///
/// El avatar abre la hoja de cuenta (05) y la campana, las novedades (5b).
/// Si la vista se abrió encima de otra, muestra «volver» a la izquierda.
class EcoTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EcoTopAppBar({super.key, required this.titulo, this.subtitulo, this.mostrarCuenta = true, this.bottom});

  final String titulo;
  final String? subtitulo;
  final bool mostrarCuenta;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sesion = SesionUsuario.actual();

    return AppBar(
      toolbarHeight: 64,
      bottom: bottom,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitulo != null && subtitulo!.isNotEmpty)
            Text(
              subtitulo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
        ],
      ),
      actions: [
        if (mostrarCuenta) ...[
          ValueListenableBuilder<int>(
            valueListenable: ContadorNovedades.noLeidas,
            builder: (context, noLeidas, _) => IconButton(
              tooltip: noLeidas > 0 ? 'Novedades, $noLeidas sin leer' : 'Novedades',
              onPressed: () => NotificacionesScreen.show(context),
              icon: Badge.count(
                count: noLeidas,
                isLabelVisible: noLeidas > 0,
                backgroundColor: scheme.tertiary,
                textColor: scheme.onTertiary,
                child: Icon(noLeidas > 0 ? Icons.notifications : Icons.notifications_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: EcoSpace.s4, right: EcoSpace.s12),
            child: Semantics(
              button: true,
              label: 'Tu cuenta',
              child: Material(
                color: scheme.tertiaryContainer,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.small))),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => CuentaBottomSheet.show(context),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Text(
                        iniciales(sesion.nombre),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
