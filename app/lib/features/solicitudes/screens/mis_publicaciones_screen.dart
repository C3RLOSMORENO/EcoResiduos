import 'package:flutter/material.dart';

import '../../../models/historial_escaneo_ia.dart';
import '../../../screens/flujo_identificacion.dart';
import '../../../services/historial_service.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/formato.dart';
import '../../../widgets/categoria_chip.dart';
import '../../../widgets/eco_top_app_bar.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/skeleton_loading.dart';
import '../../../widgets/solicitud_card.dart';
import '../models/solicitud_recoleccion.dart';
import '../repositories/solicitudes_repository.dart';
import 'detalle_solicitud_screen.dart';
import 'publicar_residuo_screen.dart';

/// Actividad del generador (26): publicaciones y escaneos en pestañas.
class MisPublicacionesScreen extends StatefulWidget {
  const MisPublicacionesScreen({
    super.key,
    this.repository,
    this.publicacionesIniciales,
    this.cargarEscaneos = HistorialService.getHistorialUsuario,
  });

  final SolicitudesRepository? repository;
  final List<SolicitudRecoleccion>? publicacionesIniciales;
  final Future<List<HistorialEscaneoIa>> Function() cargarEscaneos;

  @override
  State<MisPublicacionesScreen> createState() => _MisPublicacionesScreenState();
}

class _MisPublicacionesScreenState extends State<MisPublicacionesScreen> with SingleTickerProviderStateMixin {
  late final SolicitudesRepository _repository;
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_alCambiarPestana);

  List<SolicitudRecoleccion>? _publicaciones;
  Map<int, ResumenPostulaciones> _postulaciones = const {};
  Object? _error;
  String? _filtro;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseSolicitudesRepository();
    if (widget.publicacionesIniciales != null) {
      _publicaciones = List.of(widget.publicacionesIniciales!);
    } else {
      _cargar();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _alCambiarPestana() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final publicaciones = await _repository.getMisPublicaciones();
      final ids = publicaciones.where((s) => s.id != null).map((s) => s.id!).toList();
      final postulaciones = await _repository.getResumenPostulaciones(ids);
      if (!mounted) return;
      setState(() {
        _publicaciones = publicaciones;
        _postulaciones = postulaciones;
      });
    } catch (e) {
      debugPrint('Error al cargar publicaciones: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _abrirDetalle(SolicitudRecoleccion solicitud) async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleSolicitudScreen(solicitud: solicitud, repository: _repository, rol: 'GENERADOR'),
      ),
    );
    if (cambio == true && mounted) _cargar();
  }

  Future<void> _publicar() async {
    final publicado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublicarResiduoScreen(repository: _repository)),
    );
    if (publicado == true && mounted) _cargar();
  }

  bool get _sinPublicaciones => _publicaciones != null && _publicaciones!.isEmpty;

  @override
  Widget build(BuildContext context) {
    final mostrarFab = _tabs.index == 1 || (!_sinPublicaciones && _error == null);
    return Scaffold(
      appBar: EcoTopAppBar(
        titulo: 'Actividad',
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Publicaciones'),
            Tab(text: 'Escaneos'),
          ],
        ),
      ),
      floatingActionButton: mostrarFab
          ? FloatingActionButton.extended(
              heroTag: 'publicar',
              onPressed: _publicar,
              icon: const Icon(Icons.add),
              label: const Text('Publicar'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _publicacionesView(),
          _EscaneosView(cargar: widget.cargarEscaneos, repository: _repository),
        ],
      ),
    );
  }

  Widget _publicacionesView() {
    if (_error != null) {
      return EstadoDesplazable(
        child: EmptyStateWidget.error(
          title: 'No pudimos cargar tus publicaciones',
          description: 'Tus datos están a salvo. Revisa tu conexión e inténtalo de nuevo.',
          onRetry: _cargar,
        ),
      );
    }
    final publicaciones = _publicaciones;
    if (publicaciones == null) return const SkeletonList();
    if (publicaciones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: EstadoDesplazable(
          child: EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'Aún no has publicado residuos',
            description: 'Cuando publiques uno, aquí verás qué gestores se postulan para recogerlo.',
            ctaText: 'Publicar residuo',
            ctaIcon: Icons.upload,
            onCtaPressed: _publicar,
            secondaryText: 'Identificar con foto',
            onSecondaryPressed: () => abrirIdentificacion(context),
          ),
        ),
      );
    }

    final filtradas = _filtro == null ? publicaciones : publicaciones.where((s) => s.estado == _filtro).toList();
    return RefreshIndicator(
      onRefresh: _cargar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _filtros()),
          if (filtradas.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.filter_alt_off_outlined,
                title: 'No tienes publicaciones en «${etiquetaEstado(_filtro)}»',
                ctaText: 'Ver todas',
                ctaIcon: Icons.list,
                onCtaPressed: () => setState(() => _filtro = null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, 96 + EcoSpace.s16),
              sliver: SliverList.separated(
                itemCount: filtradas.length,
                separatorBuilder: (_, _) => const SizedBox(height: EcoSpace.s12),
                itemBuilder: (_, i) {
                  final s = filtradas[i];
                  return SolicitudCard(
                    solicitud: s,
                    onTap: () => _abrirDetalle(s),
                    pie: FilaEstado(
                      estado: s.estado,
                      label: s.pendienteConfirmacion ? 'Recolectado · por confirmar' : null,
                      texto: _textoPostulaciones(s),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String? _textoPostulaciones(SolicitudRecoleccion s) {
    final resumen = _postulaciones[s.id];
    switch (s.estado) {
      case 'PUBLICADO':
        final n = resumen?.pendientes ?? 0;
        if (n == 0) return 'Sin postulaciones aún';
        return n == 1 ? '1 postulación' : '$n postulaciones';
      case 'EN_NEGOCIACION':
        return resumen?.gestorAceptado != null ? 'con ${resumen!.gestorAceptado}' : null;
      default:
        return null;
    }
  }

  Widget _filtros() {
    const opciones = [null, 'PUBLICADO', 'EN_NEGOCIACION', 'RECOLECTADO', 'CANCELADO'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 14, EcoSpace.s16, EcoSpace.s12),
      child: Row(
        children: [
          for (final opcion in opciones)
            Padding(
              padding: const EdgeInsets.only(right: EcoSpace.s8),
              child: FilterChip(
                label: Text(opcion == null ? 'Todas' : etiquetaEstado(opcion)),
                selected: _filtro == opcion,
                onSelected: (_) => setState(() => _filtro = opcion),
              ),
            ),
        ],
      ),
    );
  }
}

/// Escaneos recientes (26b). Orgánico, Ordinario y los no identificados no se
/// pueden publicar: ningún gestor de la app los recibe.
class _EscaneosView extends StatefulWidget {
  const _EscaneosView({required this.cargar, required this.repository});

  final Future<List<HistorialEscaneoIa>> Function() cargar;
  final SolicitudesRepository repository;

  @override
  State<_EscaneosView> createState() => _EscaneosViewState();
}

class _EscaneosViewState extends State<_EscaneosView> with AutomaticKeepAliveClientMixin {
  late Future<List<HistorialEscaneoIa>> _escaneos = widget.cargar();

  @override
  bool get wantKeepAlive => true;

  Future<void> _recargar() async {
    final futuro = widget.cargar();
    setState(() => _escaneos = futuro);
    await futuro;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<HistorialEscaneoIa>>(
      future: _escaneos,
      builder: (context, snapshot) {
        if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
          return EstadoDesplazable(
            child: EmptyStateWidget.error(title: 'No pudimos cargar tus escaneos', onRetry: _recargar),
          );
        }
        if (!snapshot.hasData) return const SkeletonList();
        final escaneos = snapshot.data!;
        if (escaneos.isEmpty) {
          return RefreshIndicator(
            onRefresh: _recargar,
            child: EstadoDesplazable(
              child: EmptyStateWidget(
                icon: Icons.photo_camera_outlined,
                title: 'Aún no has identificado residuos',
                description: 'Tómale una foto a un residuo y te decimos qué es y quién lo recibe.',
                ctaText: 'Identificar con foto',
                ctaIcon: Icons.photo_camera_outlined,
                onCtaPressed: () => abrirIdentificacion(context),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _recargar,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 14, EcoSpace.s16, 96 + EcoSpace.s16),
            itemCount: escaneos.length,
            separatorBuilder: (_, _) => const SizedBox(height: EcoSpace.s12),
            itemBuilder: (_, i) => _FilaEscaneo(escaneo: escaneos[i], repository: widget.repository),
          ),
        );
      },
    );
  }
}

class _FilaEscaneo extends StatelessWidget {
  const _FilaEscaneo({required this.escaneo, required this.repository});

  final HistorialEscaneoIa escaneo;
  final SolicitudesRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final raw = escaneo.categoriaDetectada.trim().toUpperCase();
    final identificado = catLabel.containsKey(raw);
    final categoria = categoriaFromString(raw);
    final publicable = identificado && categoria != Categoria.organico && categoria != Categoria.ordinario;
    final confianza = escaneo.nivelConfianza > 1 ? escaneo.nivelConfianza : escaneo.nivelConfianza * 100;

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
      child: Padding(
        padding: const EdgeInsets.all(EcoSpace.s12),
        child: Row(
          children: [
            FotoResiduo(url: escaneo.imagenPath, categoria: categoria, size: 64),
            const SizedBox(width: EcoSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (identificado)
                    CategoriaChip(categoria: categoria)
                  else
                    Text('No identificado', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    '${confianza.round()} % · ${tiempoRelativo(escaneo.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (publicable)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicarResiduoScreen(
                      repository: repository,
                      fotoInicial: escaneo.imagenPath.isEmpty ? null : escaneo.imagenPath,
                      categoriaSugerida: raw,
                    ),
                  ),
                ),
                child: const Text('Publicar'),
              ),
          ],
        ),
      ),
    );
  }
}
