import 'package:flutter/material.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../features/solicitudes/screens/detalle_solicitud_screen.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/sesion.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loading.dart';

/// Novedades (5b, versión mínima): se calculan con los datos existentes de
/// los últimos 7 días. Leído/no leído, descartar y push requieren una tabla
/// de notificaciones que aún no existe.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.repository});

  final SolicitudesRepository? repository;

  static Future<void> show(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _Novedad {
  const _Novedad({required this.icono, required this.titulo, required this.fecha, required this.solicitud});

  final IconData icono;
  final String titulo;
  final DateTime fecha;
  final SolicitudRecoleccion solicitud;
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final SolicitudesRepository _repository = widget.repository ?? SupabaseSolicitudesRepository();
  late final bool _esGestor = SesionUsuario.actual().esGestor;
  late Future<List<_Novedad>> _novedades = _cargar();

  static const _ventana = Duration(days: 7);

  Future<List<_Novedad>> _cargar() async {
    final desde = DateTime.now().subtract(_ventana);
    final novedades = _esGestor ? await _novedadesGestor(desde) : await _novedadesGenerador(desde);
    novedades.sort((a, b) => b.fecha.compareTo(a.fecha));
    return novedades;
  }

  Future<List<_Novedad>> _novedadesGenerador(DateTime desde) async {
    final resultados = await Future.wait([
      _repository.getPostulacionesRecibidas(desde: desde),
      _repository.getMisPublicaciones(),
    ]);
    final postulaciones = resultados[0] as List;
    final publicaciones = resultados[1] as List<SolicitudRecoleccion>;
    return [
      for (final p in postulaciones)
        if (p.solicitud != null && p.createdAt != null)
          _Novedad(
            icono: Icons.handshake_outlined,
            titulo:
                '${p.gestorRazonSocial ?? 'Un gestor'} se postuló a tu ${minusculaInicial(p.solicitud!.material?.nombreComun ?? 'residuo')}',
            fecha: p.createdAt!,
            solicitud: p.solicitud!,
          ),
      for (final s in publicaciones)
        if (s.estado == 'RECOLECTADO' && s.recolectadoAt != null && s.recolectadoAt!.isAfter(desde))
          _Novedad(
            icono: Icons.local_shipping_outlined,
            titulo: 'Tu solicitud de ${minusculaInicial(s.material?.nombreComun ?? 'residuo')} quedó como recolectada',
            fecha: s.recolectadoAt!,
            solicitud: s,
          ),
    ];
  }

  Future<List<_Novedad>> _novedadesGestor(DateTime desde) async {
    final resultados = await Future.wait([_repository.getMisPostulaciones(), _repository.getSolicitudesDisponibles()]);
    final postulaciones = resultados[0] as List;
    final disponibles = resultados[1] as List<SolicitudRecoleccion>;
    final novedades = <_Novedad>[];
    for (final p in postulaciones) {
      final s = p.solicitud as SolicitudRecoleccion?;
      final fecha = s?.updatedAt;
      if (s == null || fecha == null || fecha.isBefore(desde)) continue;
      final material = minusculaInicial(s.material?.nombreComun ?? 'residuo');
      if (p.esAceptada) {
        novedades.add(
          _Novedad(
            icono: Icons.check_circle_outline,
            titulo: 'Te aceptaron la recolección de $material',
            fecha: fecha,
            solicitud: s,
          ),
        );
      } else if (p.esNoSeleccionada) {
        novedades.add(
          _Novedad(
            icono: Icons.assignment_ind_outlined,
            titulo: 'Esta solicitud fue asignada a otro gestor: $material',
            fecha: fecha,
            solicitud: s,
          ),
        );
      }
    }
    for (final s in disponibles) {
      if (s.createdAt == null || s.createdAt!.isBefore(desde)) continue;
      novedades.add(
        _Novedad(
          icono: Icons.inventory_2_outlined,
          titulo:
              'Nueva solicitud de ${minusculaInicial(s.material?.nombreComun ?? 'residuo')} en ${capitalizar(s.municipio)}',
          fecha: s.createdAt!,
          solicitud: s,
        ),
      );
    }
    return novedades;
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() => _novedades = futuro);
    await futuro;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Novedades')),
      body: FutureBuilder<List<_Novedad>>(
        future: _novedades,
        builder: (context, snapshot) {
          if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
            return EstadoDesplazable(
              child: EmptyStateWidget.error(title: 'No pudimos cargar tus novedades', onRetry: _recargar),
            );
          }
          final novedades = snapshot.data;
          if (novedades == null) return const SkeletonList(itemHeight: 64);
          if (novedades.isEmpty) {
            return RefreshIndicator(
              onRefresh: _recargar,
              child: EstadoDesplazable(
                child: EmptyStateWidget(
                  icon: Icons.notifications_none,
                  title: 'Sin novedades',
                  description: _esGestor
                      ? 'Te avisamos aquí cuando haya solicitudes nuevas de tus materiales o te acepten una recolección.'
                      : 'Te avisamos aquí cuando un gestor se postule a tus residuos o cambie el estado de una solicitud.',
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              children: [
                Container(
                  margin: const EdgeInsets.all(EcoSpace.s16),
                  padding: const EdgeInsets.all(EcoSpace.s12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(EcoRadius.medium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                      const SizedBox(width: EcoSpace.s12),
                      Expanded(
                        child: Text(
                          'Se calcula con tus datos. Muestra los cambios de los últimos 7 días.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final n in novedades)
                  ListTile(
                    minTileHeight: 64,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(EcoRadius.small),
                      ),
                      child: Icon(n.icono, color: scheme.onSecondaryContainer),
                    ),
                    title: Text(n.titulo, maxLines: 3),
                    subtitle: Text(mayusculaInicial(tiempoRelativo(n.fecha))),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleSolicitudScreen(
                          solicitud: n.solicitud,
                          repository: _repository,
                          rol: _esGestor ? 'GESTOR' : 'GENERADOR',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
