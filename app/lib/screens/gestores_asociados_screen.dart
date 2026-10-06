import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../models/autoridad_ambiental.dart';
import '../models/gestor.dart';
import '../repositories/gestores_repository.dart';
import '../services/ubicacion_service.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/municipios.dart';
import '../widgets/chip_menu.dart';
import '../widgets/eco_top_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/gestor_card.dart';
import '../widgets/avatar_entidad.dart';
import '../widgets/skeleton_loading.dart';
import 'autoridad_detalle_screen.dart';
import 'gestor_detalle_screen.dart';
import 'residuos_screen.dart';

/// Directorio (14, 16): gestores certificados y autoridades ambientales.
/// El gestor lo ve como «Directorio» con un tercer segmento, Residuos (14g).
class GestoresAsociadosScreen extends StatefulWidget {
  const GestoresAsociadosScreen({super.key, this.incluirResiduos = false, this.segmentoInicial = 0, this.repository});

  final bool incluirResiduos;

  /// 0 = Gestores, 1 = Autoridades.
  final int segmentoInicial;
  final GestoresRepository? repository;

  @override
  State<GestoresAsociadosScreen> createState() => _GestoresAsociadosScreenState();
}

enum _Segmento { residuos, gestores, autoridades }

class _GestoresAsociadosScreenState extends State<GestoresAsociadosScreen> {
  late final GestoresRepository _repository = widget.repository ?? SupabaseGestoresRepository();
  late _Segmento _segmento = widget.segmentoInicial == 1 ? _Segmento.autoridades : _Segmento.gestores;

  @override
  Widget build(BuildContext context) {
    final segmentos = [if (widget.incluirResiduos) _Segmento.residuos, _Segmento.gestores, _Segmento.autoridades];
    return Scaffold(
      appBar: EcoTopAppBar(titulo: widget.incluirResiduos ? 'Directorio' : 'Gestores'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Segmento>(
                segments: [
                  for (final s in segmentos)
                    ButtonSegment(
                      value: s,
                      label: Text(switch (s) {
                        _Segmento.residuos => 'Residuos',
                        _Segmento.gestores => 'Gestores',
                        _Segmento.autoridades => 'Autoridades',
                      }),
                    ),
                ],
                selected: {_segmento},
                onSelectionChanged: (seleccion) => setState(() => _segmento = seleccion.first),
              ),
            ),
          ),
          Expanded(
            child: switch (_segmento) {
              _Segmento.residuos => const CatalogoResiduos(),
              _Segmento.gestores => _ListaGestores(repository: _repository),
              _Segmento.autoridades => _ListaAutoridades(repository: _repository),
            },
          ),
        ],
      ),
    );
  }
}

class _ListaGestores extends StatefulWidget {
  const _ListaGestores({required this.repository});

  final GestoresRepository repository;

  @override
  State<_ListaGestores> createState() => _ListaGestoresState();
}

class _ListaGestoresState extends State<_ListaGestores> {
  /// «Ahora no» se respeta durante toda la sesión.
  static bool _ubicacionRechazadaEnSesion = false;

  static const _radioCercania = 10.0;

  late Future<List<Gestor>> _gestores = widget.repository.getDirectorio();
  PermisoUbicacion? _permiso;
  String _busqueda = '';
  String? _municipio;
  String? _categoria;

  @override
  void initState() {
    super.initState();
    _revisarPermiso();
  }

  Future<void> _revisarPermiso() async {
    final permiso = await UbicacionService.permiso();
    if (mounted) setState(() => _permiso = permiso);
  }

  void _recargar() {
    setState(() {
      _gestores = widget.repository.getDirectorio();
    });
  }

  Future<void> _activarUbicacion() async {
    final permiso = _permiso;
    if (permiso == PermisoUbicacion.denegadoSiempre || permiso == PermisoUbicacion.gpsApagado) {
      await UbicacionService.abrirAjustes(permiso!);
    } else {
      await UbicacionService.actual(pedirPermiso: true);
    }
    await _revisarPermiso();
    _recargar();
  }

  bool _coincide(Gestor g) {
    if (_municipio != null && municipioAdmitido(g.municipio) != _municipio) return false;
    if (_categoria != null && !g.categorias.contains(_categoria)) return false;
    if (_busqueda.isEmpty) return true;
    final texto = _busqueda.toLowerCase();
    return g.nombre.toLowerCase().contains(texto) ||
        g.municipio.toLowerCase().contains(texto) ||
        g.categorias.any((c) => etiquetaCategoria(c).toLowerCase().contains(texto));
  }

  void _abrir(Gestor gestor) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => GestorDetalleScreen(gestor: gestor)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Gestor>>(
      future: _gestores,
      builder: (context, snapshot) {
        final encabezado = <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
            child: SearchBar(
              hintText: 'Nombre, municipio o material',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest),
              onChanged: (texto) => setState(() => _busqueda = texto.trim()),
            ),
          ),
          _filtros(),
          ?_avisoUbicacion(),
        ];

        if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
          return ListView(
            children: [
              ...encabezado,
              EmptyStateWidget.error(title: 'No pudimos cargar los gestores', onRetry: _recargar),
            ],
          );
        }
        final todos = snapshot.data;
        if (todos == null) {
          return Column(
            children: [
              ...encabezado,
              const Expanded(child: SkeletonList(itemHeight: 88)),
            ],
          );
        }

        final filtrados = todos.where(_coincide).toList();
        final cercanos = filtrados.where((g) => (g.distanciaKm ?? double.infinity) <= _radioCercania).take(10).toList();
        final hayFiltros = _busqueda.isNotEmpty || _municipio != null || _categoria != null;

        return RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96 + EcoSpace.s16),
            children: [
              ...encabezado,
              if (filtrados.isEmpty)
                EmptyStateWidget(
                  icon: Icons.search_off,
                  title: hayFiltros
                      ? (_busqueda.isNotEmpty
                            ? 'Ningún gestor coincide con «$_busqueda»'
                            : 'Ningún gestor con estos filtros')
                      : 'Aún no hay gestores certificados',
                  description: hayFiltros
                      ? 'Busca por el nombre de la empresa, el municipio o el material, por ejemplo «cartón».'
                      : null,
                  ctaText: hayFiltros ? 'Quitar filtros' : null,
                  ctaIcon: Icons.filter_alt_off_outlined,
                  onCtaPressed: hayFiltros
                      ? () => setState(() {
                          _municipio = null;
                          _categoria = null;
                        })
                      : null,
                )
              else ...[
                if (cercanos.isNotEmpty && !hayFiltros) ...[
                  _titulo('Cerca de ti', 'a menos de ${_radioCercania.round()} km'),
                  SizedBox(
                    height: alturaCarruselGestores(context),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
                      itemCount: cercanos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: EcoSpace.s12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 232,
                        child: GestorCard(gestor: cercanos[i], compacta: true, onTap: () => _abrir(cercanos[i])),
                      ),
                    ),
                  ),
                ],
                _titulo('Todos · ${filtrados.length}', null),
                for (final gestor in filtrados)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s12),
                    child: GestorCard(gestor: gestor, onTap: () => _abrir(gestor)),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _titulo(String texto, String? detalle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s16, EcoSpace.s16, EcoSpace.s8),
      child: Wrap(
        spacing: EcoSpace.s8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(texto, style: theme.textTheme.titleMedium),
          if (detalle != null)
            Text(detalle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _filtros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s16, 0),
      child: Row(
        children: [
          ChipMenu(
            etiqueta: _municipio ?? 'Municipio',
            activo: _municipio != null,
            opciones: {for (final m in municipiosAdmitidos) m: m},
            onElegir: (valor) => setState(() => _municipio = valor),
          ),
          const SizedBox(width: EcoSpace.s8),
          ChipMenu(
            etiqueta: _categoria == null ? 'Categoría' : etiquetaCategoria(_categoria),
            activo: _categoria != null,
            opciones: {for (final c in categoriasPublicables.keys) c: etiquetaCategoria(c)},
            onElegir: (valor) => setState(() => _categoria = valor),
          ),
        ],
      ),
    );
  }

  Widget? _avisoUbicacion() {
    final permiso = _permiso;
    if (permiso == null || permiso == PermisoUbicacion.concedido) return null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final preguntar = permiso == PermisoUbicacion.sinDecidir && !_ubicacionRechazadaEnSesion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s16, 0),
      child: Container(
        padding: const EdgeInsets.all(EcoSpace.s16),
        decoration: BoxDecoration(
          color: preguntar ? scheme.secondaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(EcoRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(preguntar ? Icons.location_on_outlined : Icons.location_off_outlined),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preguntar
                            ? '¿Te mostramos los gestores más cercanos?'
                            : 'Sin tu ubicación no podemos ordenar por cercanía',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: EcoSpace.s4),
                      Text(
                        preguntar
                            ? 'Usamos tu ubicación solo para calcular a cuántos kilómetros está cada gestor.'
                            : 'Te mostramos los gestores por nombre.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: EcoSpace.s8,
                children: [
                  if (preguntar)
                    TextButton(
                      onPressed: () => setState(() => _ubicacionRechazadaEnSesion = true),
                      child: const Text('Ahora no'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _activarUbicacion,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      preguntar
                          ? 'Continuar'
                          : (permiso == PermisoUbicacion.denegadoSiempre ? 'Abrir ajustes' : 'Activar ubicación'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaAutoridades extends StatefulWidget {
  const _ListaAutoridades({required this.repository});

  final GestoresRepository repository;

  @override
  State<_ListaAutoridades> createState() => _ListaAutoridadesState();
}

class _ListaAutoridadesState extends State<_ListaAutoridades> {
  late Future<List<AutoridadAmbiental>> _autoridades = widget.repository.getAutoridades();
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<AutoridadAmbiental>>(
      future: _autoridades,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyStateWidget.error(
            title: 'No pudimos cargar las autoridades',
            onRetry: () => setState(() {
              _autoridades = widget.repository.getAutoridades();
            }),
          );
        }
        final autoridades = snapshot.data;
        if (autoridades == null) return const SkeletonList(itemHeight: 72);

        final texto = _busqueda.toLowerCase();
        final visibles = autoridades
            .where(
              (a) =>
                  texto.isEmpty || '${a.nombreCompleto} ${a.direccion} ${a.jurisdiccion}'.toLowerCase().contains(texto),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 96 + EcoSpace.s16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s8),
              child: SearchBar(
                hintText: 'Nombre o municipio',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest),
                onChanged: (valor) => setState(() => _busqueda = valor.trim()),
              ),
            ),
            if (visibles.isEmpty)
              EmptyStateWidget(icon: Icons.search_off, title: 'Ninguna autoridad coincide con «$_busqueda»'),
            for (final autoridad in visibles)
              ListTile(
                minTileHeight: 68,
                leading: AvatarEntidad(nombre: autoridad.nombre, texto: autoridad.sigla, secundario: true),
                title: Text(autoridad.nombreCompleto, style: theme.textTheme.titleSmall),
                subtitle: Text([autoridad.direccion.split(',').last.trim(), ?autoridad.horario].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AutoridadDetalleScreen(autoridad: autoridad)),
                ),
              ),
          ],
        );
      },
    );
  }
}
