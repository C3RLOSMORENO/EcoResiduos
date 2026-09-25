import 'package:flutter/material.dart';

import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../services/cola_publicaciones.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';

/// Aviso en Actividad con las publicaciones guardadas sin conexión.
class PublicacionesPendientes extends StatefulWidget {
  const PublicacionesPendientes({super.key, required this.repository});

  final SolicitudesRepository repository;

  @override
  State<PublicacionesPendientes> createState() => _PublicacionesPendientesState();
}

class _PublicacionesPendientesState extends State<PublicacionesPendientes> {
  bool _enviando = false;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final enviadas = await ColaPublicaciones.enviar(widget.repository);
    if (!mounted) return;
    setState(() => _enviando = false);
    final quedan = ColaPublicaciones.pendientes.value.length;
    final mensaje = enviadas > 0
        ? (enviadas == 1 ? 'Publicamos 1 residuo pendiente.' : 'Publicamos $enviadas residuos pendientes.')
        : 'Aún no hay conexión. Lo intentamos de nuevo más tarde.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(quedan > 0 && enviadas > 0 ? '$mensaje Faltan $quedan.' : mensaje)));
  }

  Future<void> _descartar(PublicacionPendiente pendiente) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Descartar esta publicación?'),
        content: Text('La publicación de ${minusculaInicial(pendiente.nombreMaterial)} no se enviará.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Conservar')),
          TextButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmado == true) await ColaPublicaciones.descartar(pendiente);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<List<PublicacionPendiente>>(
      valueListenable: ColaPublicaciones.pendientes,
      builder: (context, pendientes, _) {
        if (pendientes.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s16, 0),
          padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s8, EcoSpace.s8),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(EcoRadius.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_send_outlined, color: scheme.onTertiaryContainer),
                  const SizedBox(width: EcoSpace.s12),
                  Expanded(
                    child: Text(
                      pendientes.length == 1
                          ? '1 publicación sin enviar'
                          : '${pendientes.length} publicaciones sin enviar',
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Enviar ahora'),
                  ),
                ],
              ),
              for (final pendiente in pendientes)
                Row(
                  children: [
                    const SizedBox(width: 36),
                    Expanded(
                      child: Text(
                        '${pendiente.nombreMaterial} · ${tiempoRelativo(pendiente.creada)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Descartar',
                      visualDensity: VisualDensity.compact,
                      onPressed: _enviando ? null : () => _descartar(pendiente),
                      icon: Icon(Icons.close, size: 18, color: scheme.onTertiaryContainer),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
