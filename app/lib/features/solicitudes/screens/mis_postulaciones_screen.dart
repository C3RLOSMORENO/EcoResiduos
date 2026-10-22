import 'package:flutter/material.dart';

import '../../../models/postulacion_recoleccion.dart';
import '../../../screens/navegacion_principal.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/enlaces.dart';
import '../../../utils/formato.dart';
import '../../../widgets/eco_top_app_bar.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/recorrido_bienvenida.dart';
import '../../../widgets/skeleton_loading.dart';
import '../../../widgets/solicitud_card.dart';
import '../repositories/solicitudes_repository.dart';
import 'detalle_solicitud_screen.dart';

/// Postulaciones del gestor (31), una pestaña por estado. «Asignada a otro
/// gestor» aparece sola cuando el generador acepta a otro; «Rechazada», solo
/// cuando descarta esa propuesta.
class MisPostulacionesScreen extends StatefulWidget {
  const MisPostulacionesScreen({super.key, this.repository, this.postulacionesIniciales});

  final SolicitudesRepository? repository;
  final List<PostulacionRecoleccion>? postulacionesIniciales;

  @override
  State<MisPostulacionesScreen> createState() => _MisPostulacionesScreenState();
}

class _MisPostulacionesScreenState extends State<MisPostulacionesScreen> {
  late final SolicitudesRepository _repository = widget.repository ?? SupabaseSolicitudesRepository();
  List<PostulacionRecoleccion>? _postulaciones;
  Object? _error;
  bool _ocupado = false;
  final _keyPestanas = GlobalKey();
  bool _recorridoAgendado = false;

  static const _pestanas = [
    ('Enviadas', 'PROPUESTA'),
    ('Aceptadas', 'ACEPTADA'),
    ('Asignadas a otro gestor', 'NO_SELECCIONADA'),
    ('Rechazadas', 'RECHAZADA'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.postulacionesIniciales != null) {
      _postulaciones = widget.postulacionesIniciales;
    } else {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final lista = await _repository.getMisPostulaciones();
      if (mounted) setState(() => _postulaciones = lista);
    } catch (e) {
      debugPrint('Error al cargar postulaciones: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _abrir(PostulacionRecoleccion p) async {
    final solicitud = p.solicitud;
    if (solicitud == null) return;
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetalleSolicitudScreen(solicitud: solicitud, repository: _repository, rol: 'GESTOR', postulacion: p),
      ),
    );
    if (cambio == true && mounted) _cargar();
  }

  Future<void> _marcarRecolectado(PostulacionRecoleccion p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.local_shipping_outlined),
        title: const Text('¿Ya recogiste este residuo?'),
        content: const Text(
          'Le pediremos al generador que lo confirme. Si no responde en 72 h, la recolección se confirma automáticamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Sí, lo recogí')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);
    try {
      await _repository.marcarRecolectado(solicitudId: p.solicitudId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Marcaste la recolección. Esperamos la confirmación del generador.')),
      );
      await _cargar();
    } catch (e) {
      debugPrint('No se pudo marcar como recolectado: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo marcar como recolectado. Inténtalo de nuevo.')));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postulaciones = _postulaciones ?? const <PostulacionRecoleccion>[];
    int contar(String estado) => postulaciones.where((p) => p.estado == estado).length;

    if (_postulaciones != null && !_recorridoAgendado) {
      _recorridoAgendado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        mostrarRecorridoPantallaSiNecesario(context, 'postulaciones_gestor', [
          CoachMarkPaso(
            keyObjetivo: _keyPestanas,
            titulo: 'Cuatro estados de tus propuestas',
            descripcion:
                'Enviadas: esperando respuesta del generador. '
                'Aceptadas: coordina la recogida y súbela cuando la completes. '
                'Asignada a otro: el generador eligió a otro gestor. '
                'Rechazadas: propuestas descartadas.',
          ),
        ]);
      });
    }

    return DefaultTabController(
      length: _pestanas.length,
      child: Scaffold(
        appBar: EcoTopAppBar(
          titulo: 'Postulaciones',
          bottom: TabBar(
            key: _keyPestanas,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final (titulo, estado) in _pestanas)
                Tab(text: _postulaciones == null ? titulo : '$titulo · ${contar(estado)}'),
            ],
          ),
        ),
        body: _cuerpo(postulaciones),
      ),
    );
  }

  Widget _cuerpo(List<PostulacionRecoleccion> postulaciones) {
    if (_error != null) {
      return EstadoDesplazable(
        child: EmptyStateWidget.error(title: 'No pudimos cargar tus postulaciones', onRetry: _cargar),
      );
    }
    if (_postulaciones == null) return const SkeletonList();
    if (postulaciones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: EstadoDesplazable(
          child: EmptyStateWidget(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Aún no te has postulado',
            description: 'Revisa las solicitudes de tus materiales y envía tu propuesta.',
            ctaText: 'Ver solicitudes',
            ctaIcon: Icons.inventory_2_outlined,
            onCtaPressed: () => NavegacionPrincipal.of(context)?.irA(Pestana.solicitudes),
          ),
        ),
      );
    }

    return TabBarView(
      children: [
        for (final (titulo, estado) in _pestanas)
          RefreshIndicator(
            onRefresh: _cargar,
            child: _lista(postulaciones.where((p) => p.estado == estado && p.solicitud != null).toList(), titulo),
          ),
      ],
    );
  }

  Widget _lista(List<PostulacionRecoleccion> lista, String titulo) {
    if (lista.isEmpty) {
      return EstadoDesplazable(
        child: EmptyStateWidget(icon: Icons.inbox_outlined, title: 'Sin postulaciones en «$titulo»'),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(EcoSpace.s16),
      itemCount: lista.length,
      separatorBuilder: (_, _) => const SizedBox(height: EcoSpace.s12),
      itemBuilder: (_, i) {
        final p = lista[i];
        return SolicitudCard(solicitud: p.solicitud!, mostrarCategoria: true, onTap: () => _abrir(p), pie: _pie(p));
      },
    );
  }

  Widget _pie(PostulacionRecoleccion p) {
    final solicitud = p.solicitud!;
    if (solicitud.estado == 'CANCELADO') {
      return const FilaEstado(estado: 'CANCELADO', texto: 'El generador canceló la publicación');
    }
    if (p.esAceptada && solicitud.estado == 'RECOLECTADO') {
      return FilaEstado(
        estado: 'RECOLECTADO',
        label: solicitud.estaConfirmado ? 'Recolección confirmada' : 'Recolectado · por confirmar',
        texto: !solicitud.tieneCertificado
            ? 'Falta cargar el certificado'
            : (solicitud.estaConfirmado ? null : 'Esperando confirmación del generador'),
      );
    }
    if (p.esAceptada) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaEstado(estado: p.estado, texto: solicitud.telefono.isNotEmpty ? solicitud.telefono : null),
          const SizedBox(height: EcoSpace.s8),
          Wrap(
            spacing: EcoSpace.s8,
            runSpacing: EcoSpace.s8,
            children: [
              if (solicitud.telefono.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => llamar(context, solicitud.telefono),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Llamar'),
                ),
              FilledButton.icon(
                onPressed: _ocupado ? null : () => _marcarRecolectado(p),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Marcar recolectado'),
              ),
            ],
          ),
        ],
      );
    }
    final texto = switch (p.estado) {
      'PROPUESTA' => tiempoRelativo(p.createdAt),
      'NO_SELECCIONADA' => 'El generador eligió a otro gestor',
      'RECHAZADA' => 'El generador descartó tu propuesta',
      _ => null,
    };
    return FilaEstado(estado: p.estado, texto: texto);
  }
}
