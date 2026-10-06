import 'package:flutter/material.dart';

import '../screens/notificaciones_screen.dart';
import '../services/contador_novedades.dart';
import '../services/foto_perfil_service.dart';
import '../theme/eco_theme.dart';
import '../utils/sesion.dart';
import 'cuenta_bottom_sheet.dart';
import 'gestor_card.dart';

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
            padding: const EdgeInsets.only(right: EcoSpace.s8),
            // Se vuelve a pintar cuando la persona cambia su foto.
            child: ValueListenableBuilder<int>(
              valueListenable: FotoPerfilService.cambios,
              builder: (context, _, _) => _AvatarCuenta(sesion: SesionUsuario.actual()),
            ),
          ),
        ],
      ],
    );
  }
}

/// Avatar de la barra: foto de perfil o iniciales. Abre la hoja de cuenta.
///
/// Es un IconButton: área táctil de 48 dp, tooltip que también es su nombre
/// para el lector de pantalla y efecto de toque visible alrededor de la foto.
class _AvatarCuenta extends StatelessWidget {
  const _AvatarCuenta({required this.sesion});

  final SesionUsuario sesion;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Tu cuenta',
      onPressed: () => CuentaBottomSheet.show(context),
      padding: const EdgeInsets.all(EcoSpace.s4),
      iconSize: 40,
      icon: AvatarEntidad(
        nombre: sesion.nombre,
        size: 40,
        fotoUrl: FotoPerfilService.url(sesion.fotoPerfilPath),
        // La persona en círculo; la empresa, su logo completo en recuadro.
        circular: !sesion.esGestor,
        ajuste: sesion.esGestor ? BoxFit.contain : BoxFit.cover,
      ),
    );
  }
}
