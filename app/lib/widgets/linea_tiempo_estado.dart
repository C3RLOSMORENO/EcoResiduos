import 'package:flutter/material.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../utils/formato.dart';

/// Línea de tiempo de 3 nodos del detalle de solicitud (28): Publicado →
/// En negociación → Recolectado, o Publicado → Cancelado.
///
/// La fecha de «En negociación» se pierde al pasar a Recolectado porque la
/// base no guarda un historial de estados; en ese caso se muestra «—».
class LineaTiempoEstado extends StatelessWidget {
  const LineaTiempoEstado({super.key, required this.solicitud});

  final SolicitudRecoleccion solicitud;

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final nodos = s.estado == 'CANCELADO'
        ? [
            _Nodo('Publicado', _fecha(s.createdAt), true),
            _Nodo('Cancelado', _fecha(s.updatedAt), true, cancelado: true),
          ]
        : [
            _Nodo('Publicado', _fecha(s.createdAt), true),
            _Nodo(
              'En negociación',
              s.estado == 'EN_NEGOCIACION' ? _fecha(s.updatedAt) : (s.estado == 'RECOLECTADO' ? '—' : null),
              s.estado == 'EN_NEGOCIACION' || s.estado == 'RECOLECTADO',
            ),
            _Nodo('Recolectado', _fecha(s.recolectadoAt), s.estado == 'RECOLECTADO'),
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < nodos.length; i++)
          Expanded(
            child: _VistaNodo(
              nodo: nodos[i],
              lineaAntes: i > 0,
              lineaDespues: i < nodos.length - 1,
              lineaActiva: i < nodos.length - 1 && nodos[i + 1].hecho,
            ),
          ),
      ],
    );
  }

  static String? _fecha(DateTime? fecha) {
    if (fecha == null) return null;
    final hoy = DateTime.now();
    final local = fecha.toLocal();
    if (local.year == hoy.year && local.month == hoy.month && local.day == hoy.day) return 'hoy';
    return fechaCorta(fecha);
  }
}

class _Nodo {
  const _Nodo(this.etiqueta, this.fecha, this.hecho, {this.cancelado = false});

  final String etiqueta;
  final String? fecha;
  final bool hecho;
  final bool cancelado;
}

class _VistaNodo extends StatelessWidget {
  const _VistaNodo({
    required this.nodo,
    required this.lineaAntes,
    required this.lineaDespues,
    required this.lineaActiva,
  });

  final _Nodo nodo;
  final bool lineaAntes;
  final bool lineaDespues;
  final bool lineaActiva;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colorNodo = nodo.cancelado ? scheme.outline : (nodo.hecho ? scheme.primary : scheme.surfaceContainerHighest);
    final colorIcono = nodo.hecho ? scheme.onPrimary : scheme.onSurfaceVariant;
    final linea = lineaActiva ? scheme.primary : scheme.outlineVariant;

    return Semantics(
      label: '${nodo.etiqueta}${nodo.fecha != null ? ', ${nodo.fecha}' : ''}${nodo.hecho ? '' : ', pendiente'}',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(child: lineaAntes ? Container(height: 3, color: scheme.primary) : const SizedBox()),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: colorNodo, shape: BoxShape.circle),
                  child: nodo.hecho
                      ? Icon(nodo.cancelado ? Icons.block : Icons.check, size: 16, color: colorIcono)
                      : null,
                ),
                Expanded(child: lineaDespues ? Container(height: 3, color: linea) : const SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nodo.etiqueta,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: nodo.hecho ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
          if (nodo.fecha != null)
            Text(
              nodo.fecha!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
