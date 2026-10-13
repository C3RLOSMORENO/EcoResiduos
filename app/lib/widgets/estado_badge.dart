import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Ícono de cada estado; el mismo que usa el panel de administración.
IconData iconoEstado(EstadoSolicitud estado) => switch (estado) {
  EstadoSolicitud.publicado => Icons.campaign_outlined,
  EstadoSolicitud.enNegociacion => Icons.handshake_outlined,
  EstadoSolicitud.recolectado => Icons.local_shipping_outlined,
  EstadoSolicitud.cancelado => Icons.block,
  EstadoSolicitud.propuesta => Icons.schedule,
  EstadoSolicitud.aceptada => Icons.check_circle_outline,
  EstadoSolicitud.rechazada => Icons.cancel_outlined,
  EstadoSolicitud.noSeleccionada => Icons.assignment_ind_outlined,
};

/// Nombre del estado para mostrar al usuario.
String etiquetaDeEstado(EstadoSolicitud estado) => switch (estado) {
  EstadoSolicitud.publicado => 'Publicado',
  EstadoSolicitud.enNegociacion => 'En negociación',
  EstadoSolicitud.recolectado => 'Recolectado',
  EstadoSolicitud.cancelado => 'Cancelado',
  EstadoSolicitud.propuesta => 'Propuesta enviada',
  EstadoSolicitud.aceptada => 'Aceptada',
  EstadoSolicitud.rechazada => 'Rechazada',
  EstadoSolicitud.noSeleccionada => 'Asignada a otro gestor',
};

/// Píldora de estado: color tonal, ícono y etiqueta humana (nunca el código).
class EstadoBadge extends StatelessWidget {
  const EstadoBadge({super.key, required this.estado, this.label});

  factory EstadoBadge.fromString(String? raw, {Key? key, String? label}) =>
      EstadoBadge(key: key, estado: estadoFromString(raw), label: label);

  final EstadoSolicitud estado;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.estado(estado);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(color: color.container, borderRadius: BorderRadius.circular(EcoRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstado(estado), size: 16, color: color.onContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label ?? etiquetaDeEstado(estado),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color.onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
