import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/contador_novedades.dart';
import '../../../services/ubicacion_service.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/formato.dart';
import '../../../utils/municipios.dart';
import '../../../widgets/chip_menu.dart';
import '../../../widgets/eco_top_app_bar.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/materiales_en_verificacion.dart';
import '../../../widgets/recorrido_bienvenida.dart';
import '../../../widgets/skeleton_loading.dart';
import '../../../widgets/solicitud_card.dart';
import '../models/solicitud_recoleccion.dart';
import '../repositories/solicitudes_repository.dart';
import 'detalle_solicitud_screen.dart';
import 'mis_materiales_screen.dart';

/// Solicitudes disponibles para el gestor (29): solo las PUBLICADO de los
/// materiales que el administrador le verificó, de la más cercana a la más lejana.
class SolicitudesDisponiblesScreen extends StatefulWidget {
  const SolicitudesDisponiblesScreen({
    super.key,
    this.repository,
    this.solicitudesIniciales,
    this.estadoMaterialesInicial,
  });

  final SolicitudesRepository? repository;
  final List<SolicitudRecoleccion>? solicitudesIniciales;
  final EstadoMaterialesGestor? estadoMaterialesInicial;

  @override
  State<SolicitudesDisponiblesScreen> createState() => _SolicitudesDisponiblesScreenState();
}

class _SolicitudesDisponiblesScreenState extends State<SolicitudesDisponiblesScreen> {
  late final SolicitudesRepository _repository = widget.repository ?? SupabaseSolicitudesRepository();

  EstadoMaterialesGestor? _materiales;
  List<SolicitudRecoleccion>? _solicitudes;
  Position? _posicion;
  Object? _error;

  String? _municipio;
  String? _categoria;
  double? _distanciaMaxima;
  final _keyFiltros = GlobalKey();
  final _keyLista = GlobalKey();
  bool _recorridoAgendado = false;

  @override
  void initState() {
    super.initState();
    if (widget.solicitudesIniciales != null) {
      _materiales =
          widget.estadoMaterialesInicial ?? const EstadoMaterialesGestor(totalDeclarados: 1, totalVerificados: 1);
      _solicitudes = widget.solicitudesIniciales;
    } else {
      _cargar();
    }
    // Una notificación (p. ej. la aprobación de sus materiales) puede cambiar
    // lo que el gestor ve: se vuelve a consultar sin que tenga que deslizar.
    ContadorNovedades.llegadas.addListener(_cargar);
  }

  @override
  void dispose() {
    ContadorNovedades.llegadas.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _editarMateriales() async {
    final guardo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MisMaterialesScreen(repository: _repository)),
    );
    if (guardo == true) await _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final materiales = await _repository.getEstadoMaterialesGestor();
      if (!materiales.verificado) {
        if (mounted) setState(() => _materiales = materiales);
        return;
      }
      final resultados = await Future.wait([_repository.getSolicitudesDisponibles(), UbicacionService.actual()]);
      if (!mounted) return;
      setState(() {
        _materiales = materiales;
        _solicitudes = resultados[0] as List<SolicitudRecoleccion>;
        _posicion = resultados[1] as Position?;
      });
    } catch (e) {
      debugPrint('Error al cargar solicitudes disponibles: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  double? _distancia(SolicitudRecoleccion s) => UbicacionService.distanciaKm(_posicion, s.latitud, s.longitud);

  List<SolicitudRecoleccion> get _visibles {
    final lista = (_solicitudes ?? const <SolicitudRecoleccion>[]).where((s) {
      if (_municipio != null && municipioAdmitido(s.municipio) != _municipio) return false;
      if (_categoria != null && s.material?.categoria.toUpperCase() != _categoria) return false;
      if (_distanciaMaxima != null) {
        final km = _distancia(s);
        if (km == null || km > _distanciaMaxima!) return false;
      }
      return true;
    }).toList();
    lista.sort((a, b) => (_distancia(a) ?? double.infinity).compareTo(_distancia(b) ?? double.infinity));
    return lista;
  }

  bool get _hayFiltros => _municipio != null || _categoria != null || _distanciaMaxima != null;

  Future<void> _abrir(SolicitudRecoleccion s) async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetalleSolicitudScreen(solicitud: s, repository: _repository, rol: 'GESTOR', distanciaKm: _distancia(s)),
      ),
    );
    if (cambio == true && mounted) _cargar();
  }

  Future<void> _elegirDistancia() async {
    var valor = _distanciaMaxima ?? 10;
    final elegido = await showModalBottomSheet<double?>(
      context: context,
      builder: (hoja) => StatefulBuilder(
        builder: (hoja, actualizar) => Padding(
          padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Distancia', style: Theme.of(hoja).textTheme.headlineSmall),
              const SizedBox(height: EcoSpace.s8),
              Text('Hasta ${valor.round()} km', style: Theme.of(hoja).textTheme.titleMedium),
              Slider(
                value: valor,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${valor.round()} km',
                onChanged: (v) => actualizar(() => valor = v),
              ),
              Row(
                children: [
                  TextButton(onPressed: () => Navigator.pop(hoja, -1.0), child: const Text('Sin límite')),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.pop(hoja, valor), child: const Text('Aplicar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido == null) return;
    setState(() => _distanciaMaxima = elegido < 0 ? null : elegido.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EcoTopAppBar(titulo: 'Solicitudes'),
      body: RefreshIndicator(onRefresh: _cargar, child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return EstadoDesplazable(
        child: EmptyStateWidget.error(title: 'No pudimos cargar las solicitudes', onRetry: _cargar),
      );
    }
    final materiales = _materiales;
    if (materiales == null) return const SkeletonList();
    if (!materiales.verificado) {
      return EstadoDesplazable(
        child: MaterialesEnVerificacion(estado: materiales, repository: _repository, onMaterialesCambiados: _cargar),
      );
    }
    if (_solicitudes == null) return const SkeletonList();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibles = _visibles;
    final categorias = {for (final s in _solicitudes!) ?s.material?.categoria.toUpperCase()}.toList();

    if (!_recorridoAgendado) {
      _recorridoAgendado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        mostrarRecorridoPantallaSiNecesario(context, 'solicitudes_gestor', [
          CoachMarkPaso(
            keyObjetivo: _keyFiltros,
            titulo: 'Filtra por lo que importa',
            descripcion:
                'Municipio: solo solicitudes de esa zona. '
                'Categoría: filtra por tipo de material. '
                'Distancia: radio en km desde tu ubicación. '
                'Los filtros se combinan entre sí.',
          ),
          CoachMarkPaso(
            keyObjetivo: _keyLista,
            titulo: 'Tu siguiente oportunidad',
            descripcion:
                'Cada tarjeta muestra residuo, municipio, distancia y fecha de publicación. '
                'Tócala para ver el detalle y enviar tu propuesta: precio, modalidad de entrega y mensaje al generador.',
            nota: 'Solo ves los materiales que declaraste.',
          ),
        ]);
      });
    }

    return ListView(
      key: _keyLista,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Solo ves los materiales que estás autorizado a recibir.',
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton(onPressed: _editarMateriales, child: const Text('Editar')),
          ],
        ),
        const SizedBox(height: EcoSpace.s12),
        SingleChildScrollView(
          key: _keyFiltros,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChipMenu(
                etiqueta: _municipio ?? 'Municipio',
                activo: _municipio != null,
                opciones: {for (final m in municipiosAdmitidos) m: m},
                onElegir: (v) => setState(() => _municipio = v),
              ),
              const SizedBox(width: EcoSpace.s8),
              ChipMenu(
                etiqueta: _categoria == null ? 'Categoría' : etiquetaCategoria(_categoria),
                activo: _categoria != null,
                opciones: {for (final c in categorias) c: etiquetaCategoria(c)},
                onElegir: (v) => setState(() => _categoria = v),
              ),
              if (_posicion != null) ...[
                const SizedBox(width: EcoSpace.s8),
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_distanciaMaxima == null ? 'Distancia' : 'Hasta ${_distanciaMaxima!.round()} km'),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                  selected: _distanciaMaxima != null,
                  onSelected: (_) => _elegirDistancia(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: EcoSpace.s12),
        if (visibles.isEmpty)
          EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: _hayFiltros ? 'No hay solicitudes con estos filtros' : 'No hay solicitudes de tus materiales',
            description: _hayFiltros ? null : 'Te avisamos cuando un generador publique uno. Jala para actualizar.',
            ctaText: _distanciaMaxima != null && _distanciaMaxima! < 25 ? 'Ampliar a 25 km' : null,
            ctaIcon: Icons.zoom_out_map,
            onCtaPressed: () => setState(() => _distanciaMaxima = 25),
            secondaryText: _hayFiltros ? 'Quitar filtros' : null,
            onSecondaryPressed: () => setState(() {
              _municipio = null;
              _categoria = null;
              _distanciaMaxima = null;
            }),
          )
        else ...[
          Text(
            '${visibles.length == 1 ? '1 solicitud' : '${visibles.length} solicitudes'}'
            '${_posicion != null ? ' · las más cercanas primero' : ''}',
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: EcoSpace.s8),
          for (final s in visibles)
            Padding(
              padding: const EdgeInsets.only(bottom: EcoSpace.s12),
              child: SolicitudCard(
                solicitud: s,
                mostrarCategoria: true,
                distanciaKm: _distancia(s),
                detalleUbicacion: tiempoRelativo(s.createdAt),
                onTap: () => _abrir(s),
              ),
            ),
        ],
      ],
    );
  }
}
