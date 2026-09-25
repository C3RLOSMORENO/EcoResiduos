import 'package:flutter/material.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../utils/formato.dart';

/// Línea de tiempo de 3 nodos del detalle de solicitud (28): Publicado →
/// En negociación → Recolectado, o Publicado → Cancelado.
///
/// Las fechas salen del historial de estados ([fechas]); mientras carga, o
/// en solicitudes anteriores al historial, se usan las columnas de la
/// solicitud. Si no hay forma de saber una fecha se muestra «—».
class LineaTiempoEstado extends StatelessWidget {
  const LineaTiempoEstado({super.key, required this.solicitud, this.fechas = const {}});

  final SolicitudRecoleccion solicitud;
  final Map<String, DateTime> fechas;

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final publicado = _fecha(fechas['PUBLICADO'] ?? s.createdAt);
    final nodos = s.estado == 'CANCELADO'
        ? [
            _Nodo('Publicado', publicado, true),
            _Nodo('Cancelado', _fecha(fechas['CANCELADO'] ?? s.updatedAt), true, cancelado: true),
          ]
        : [
            _Nodo('Publicado', publicado, true),
            _Nodo(
              'En negociación',
              _fecha(fechas['EN_NEGOCIACION'] ?? (s.estado == 'EN_NEGOCIACION' ? s.updatedAt : null)) ??
                  (s.estado == 'RECOLECTADO' ? '—' : null),
              s.estado == 'EN_NEGOCIACION' || s.estado == 'RECOLECTADO',
            ),
            _Nodo('Recolectado', _fecha(s.recolectadoAt ?? fechas['RECOLECTADO']), s.estado == 'RECOLECTADO'),
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
