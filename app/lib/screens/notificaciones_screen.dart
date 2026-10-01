import 'package:flutter/material.dart';

import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../features/solicitudes/screens/detalle_solicitud_screen.dart';
import '../models/notificacion.dart';
import '../repositories/notificaciones_repository.dart';
import '../services/contador_novedades.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/sesion.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_loading.dart';

/// Novedades (5b): avisos que crea el servidor cuando cambian las solicitudes
/// o postulaciones del usuario. Se marcan como leídas al abrirlas y se
/// descartan deslizando.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.repository, this.solicitudes});

  final NotificacionesRepository? repository;
  final SolicitudesRepository? solicitudes;

  static Future<void> show(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final NotificacionesRepository _repository = widget.repository ?? SupabaseNotificacionesRepository();
  late final SolicitudesRepository _solicitudes = widget.solicitudes ?? SupabaseSolicitudesRepository();
  late final bool _esGestor = SesionUsuario.actual().esGestor;

  List<Notificacion>? _avisos;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final avisos = await _repository.listar();
      if (!mounted) return;
      setState(() {
        _avisos = avisos;
        _error = false;
      });
    } catch (e) {
      debugPrint('No se pudieron cargar las novedades: $e');
      if (mounted) setState(() => _error = true);
    }
    ContadorNovedades.actualizar();
  }

  Future<void> _reintentar() async {
    setState(() {
      _avisos = null;
      _error = false;
    });
    await _cargar();
  }

  Future<void> _abrir(Notificacion aviso) async {
    if (!aviso.leida) {
      setState(() => _avisos = [for (final a in _avisos!) a.id == aviso.id ? a.marcadaComoLeida() : a]);
      _repository.marcarLeida(aviso.id).then((_) => ContadorNovedades.actualizar()).catchError((Object e) {
        debugPrint('No se pudo marcar la novedad como leída: $e');
      });
    }
    final id = aviso.solicitudId;
    if (id == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final solicitud = await _solicitudes.getSolicitud(id);
      if (!mounted) return;
      if (solicitud == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Esta solicitud ya no está disponible.')));
        return;
      }
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => DetalleSolicitudScreen(
            solicitud: solicitud,
            repository: _solicitudes,
            rol: _esGestor ? 'GESTOR' : 'GENERADOR',
          ),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo abrir la solicitud $id: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos abrir la solicitud. Revisa tu conexión.')));
    }
  }

  Future<void> _descartar(Notificacion aviso) async {
    final anteriores = _avisos!;
    setState(
      () => _avisos = [
        for (final a in anteriores)
          if (a.id != aviso.id) a,
      ],
    );
    try {
      await _repository.descartar(aviso.id);
    } catch (e) {
      debugPrint('No se pudo descartar la novedad: $e');
      if (!mounted) return;
      setState(() => _avisos = anteriores);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pudimos descartarla. Revisa tu conexión.')));
    }
    ContadorNovedades.actualizar();
  }

  Future<void> _marcarTodas() async {
    final anteriores = _avisos!;
    setState(() => _avisos = [for (final a in anteriores) a.marcadaComoLeida()]);
    try {
      await _repository.marcarTodasLeidas();
    } catch (e) {
      debugPrint('No se pudieron marcar las novedades: $e');
      if (mounted) setState(() => _avisos = anteriores);
    }
    ContadorNovedades.actualizar();
  }

  @override
  Widget build(BuildContext context) {
    final avisos = _avisos;
    final hayNoLeidas = avisos?.any((a) => !a.leida) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novedades'),
        actions: [
          if (hayNoLeidas)
            IconButton(tooltip: 'Marcar todo como leído', onPressed: _marcarTodas, icon: const Icon(Icons.done_all)),
        ],
      ),
      body: _cuerpo(avisos),
    );
  }

  Widget _cuerpo(List<Notificacion>? avisos) {
    if (_error) {
      return EstadoDesplazable(
        child: EmptyStateWidget.error(title: 'No pudimos cargar tus novedades', onRetry: _reintentar),
      );
    }
    if (avisos == null) return const SkeletonList(itemHeight: 64);
    if (avisos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
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
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: EcoSpace.s8),
        itemCount: avisos.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          final aviso = avisos[i];
          return Dismissible(
            key: ValueKey(aviso.id),
            direction: DismissDirection.endToStart,
            background: const _FondoDescartar(),
            onDismissed: (_) => _descartar(aviso),
            child: _TileAviso(aviso: aviso, onTap: () => _abrir(aviso)),
          );
        },
      ),
    );
  }
}

class _TileAviso extends StatelessWidget {
  const _TileAviso({required this.aviso, required this.onTap});

  final Notificacion aviso;
  final VoidCallback onTap;

  static IconData _icono(String tipo) => switch (tipo) {
    'POSTULACION_NUEVA' => Icons.handshake_outlined,
    'POSTULACION_ACEPTADA' => Icons.check_circle_outline,
    'POSTULACION_NO_SELECCIONADA' => Icons.assignment_ind_outlined,
    'POSTULACION_RECHAZADA' => Icons.do_not_disturb_on_outlined,
    'SOLICITUD_NUEVA' => Icons.inventory_2_outlined,
    'SOLICITUD_CANCELADA' => Icons.block,
    'RECOLECCION_MARCADA' => Icons.local_shipping_outlined,
    'RECOLECCION_CONFIRMADA' => Icons.verified_outlined,
    'PROBLEMA_REPORTADO' => Icons.report_problem_outlined,
    'CERTIFICADO_CARGADO' => Icons.picture_as_pdf_outlined,
    'GESTOR_APROBADO' => Icons.verified_user_outlined,
    'GESTOR_RECHAZADO' => Icons.gpp_bad_outlined,
    'GESTOR_SUSPENDIDO' => Icons.pause_circle_outline,
    'MATERIALES_VERIFICADOS' => Icons.recycling,
    'PROBLEMA_RESUELTO' => Icons.assignment_turned_in_outlined,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nueva = !aviso.leida;

    return Semantics(
      label: nueva ? 'Sin leer' : null,
      child: ListTile(
        minTileHeight: 72,
        tileColor: nueva ? scheme.secondaryContainer.withValues(alpha: 0.35) : null,
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: nueva ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(EcoRadius.small),
          ),
          child: Icon(_icono(aviso.tipo), color: nueva ? scheme.onSecondaryContainer : scheme.onSurfaceVariant),
        ),
        title: Text(
          aviso.titulo,
          maxLines: 3,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: nueva ? FontWeight.w600 : FontWeight.w400),
        ),
        subtitle: Text(mayusculaInicial(tiempoRelativo(aviso.createdAt))),
        trailing: nueva
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
              )
            : (aviso.solicitudId != null ? const Icon(Icons.chevron_right) : null),
      ),
    );
  }
}

class _FondoDescartar extends StatelessWidget {
  const _FondoDescartar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.errorContainer,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: EcoSpace.s24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Descartar',
                style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: EcoSpace.s8),
              Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
