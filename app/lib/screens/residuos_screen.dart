import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/guia_categorias.dart';
import '../features/solicitudes/models/material_residuo.dart';
import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../theme/eco_theme.dart';
import '../widgets/contenido_guia.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/eco_top_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/recorrido_bienvenida.dart';
import '../widgets/skeleton_loading.dart';
import 'flujo_identificacion.dart';
import 'guia_manejo_general_screen.dart';
import 'informacion_residuo_screen.dart';

/// Pestaña Residuos (08). La búsqueda (09, 10) es un estado de esta vista:
/// la barra se expande sobre ella y no existe una pantalla de búsqueda aparte.
class ResiduosScreen extends StatelessWidget {
  const ResiduosScreen({super.key, this.repository});

  final SolicitudesRepository? repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EcoTopAppBar(titulo: 'Residuos'),
      body: CatalogoResiduos(repository: repository),
    );
  }
}

/// Barra de búsqueda y cuadrícula de categorías. El gestor la ve dentro del
/// segmento «Residuos» del Directorio.
class CatalogoResiduos extends StatefulWidget {
  const CatalogoResiduos({super.key, this.repository});

  final SolicitudesRepository? repository;

  @override
  State<CatalogoResiduos> createState() => _CatalogoResiduosState();
}

class _CatalogoResiduosState extends State<CatalogoResiduos> {
  late final SolicitudesRepository _repository = widget.repository ?? SupabaseSolicitudesRepository();
  late Future<List<MaterialResiduo>> _catalogo = _repository.getMateriales();
  List<String> _recientes = const [];
  final _keyBuscar = GlobalKey();
  final _keyGuia = GlobalKey();
  bool _recorridoAgendado = false;

  static const _claveRecientes = 'busquedas_recientes';

  @override
  void initState() {
    super.initState();
    _cargarRecientes();
  }

  Future<void> _cargarRecientes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _recientes = prefs.getStringList(_claveRecientes) ?? const []);
  }

  Future<void> _guardarReciente(String termino) async {
    final limpio = termino.trim();
    if (limpio.length < 2) return;
    final lista = [limpio, ..._recientes.where((r) => r.toLowerCase() != limpio.toLowerCase())].take(5).toList();
    setState(() => _recientes = lista);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_claveRecientes, lista);
  }

  Future<void> _borrarRecientes() async {
    setState(() => _recientes = const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveRecientes);
  }

  void _reintentar() {
    setState(() {
      _catalogo = _repository.getMateriales();
    });
  }

  void _abrirMaterial(MaterialResiduo material) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InformacionResiduoScreen(material: material, repository: _repository),
      ),
    );
  }

  void _abrirCategoria(List<MaterialResiduo> catalogo, String categoria) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialesCategoriaScreen(
          categoria: categoria,
          materiales: catalogo.where((m) => m.categoria.toUpperCase() == categoria).toList(),
          onAbrir: _abrirMaterial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MaterialResiduo>>(
      future: _catalogo,
      builder: (context, snapshot) {
        final catalogo = snapshot.data;
        if (catalogo != null && !_recorridoAgendado) {
          _recorridoAgendado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            mostrarRecorridoPantallaSiNecesario(context, 'residuos', [
              CoachMarkPaso(
                keyObjetivo: _keyBuscar,
                titulo: 'Busca cualquier residuo',
                descripcion:
                    'Escribe "pilas", "cartón" o "plástico". '
                    'Obtienes la ficha del material: instrucciones de separación, normativa vigente y gestores que lo reciben.',
                nota: 'Funciona sin conexión a internet.',
              ),
              CoachMarkPaso(
                keyObjetivo: _keyGuia,
                titulo: 'Normativa y guías',
                descripcion:
                    'Resolución 2184/2019, Decreto 1076/2015, Ley RAEE y más. '
                    'Consulta las normas que definen cómo separar y qué gestor debe recibir cada material.',
              ),
            ]);
          });
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, 96 + EcoSpace.s16),
          children: [
            _barraBusqueda(catalogo ?? const []),
            const SizedBox(height: EcoSpace.s16),
            InkWell(
              key: _keyGuia,
              borderRadius: BorderRadius.circular(EcoRadius.medium),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuiaManejoGeneralScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16, vertical: EcoSpace.s12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(EcoRadius.medium),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(EcoSpace.s8),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                      child: Icon(Icons.gavel_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                    ),
                    const SizedBox(width: EcoSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Normativa Nacional de Separación',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Res. 2184/2019, Dec. 1076/2015, Ley RAEE y RCD',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: EcoSpace.s20),
            const TituloSeccion('Categorías de residuos'),
            const SizedBox(height: EcoSpace.s12),
            if (snapshot.hasError && snapshot.connectionState == ConnectionState.done)
              EmptyStateWidget.error(
                title: 'No pudimos cargar las categorías',
                description: 'Revisa tu conexión. Puedes identificar un residuo con la cámara sin internet.',
                onRetry: _reintentar,
              )
            else if (catalogo == null)
              const _CuadriculaSkeleton()
            else
              _cuadricula(catalogo),
          ],
        );
      },
    );
  }

  Widget _barraBusqueda(List<MaterialResiduo> catalogo) {
    return KeyedSubtree(
      key: _keyBuscar,
      child: SearchAnchor.bar(
      barHintText: 'Busca un residuo: pilas, cartón…',
      barElevation: const WidgetStatePropertyAll(0),
      barBackgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
      viewHintText: 'Busca un residuo',
      isFullScreen: true,
      onSubmitted: _guardarReciente,
      suggestionsBuilder: (context, controller) {
        final texto = controller.text.trim();
        if (texto.length < 2) return _sugerenciasIniciales(controller);
        return _resultados(catalogo, texto, controller);
      },
    ),
    );
  }

  List<Widget> _sugerenciasIniciales(SearchController controller) {
    final theme = Theme.of(context);
    return [
      if (_recientes.isEmpty)
        Padding(
          padding: const EdgeInsets.all(EcoSpace.s16),
          child: Text(
            'Escribe el nombre del residuo o una palabra clave, por ejemplo «batería» o «tapas».',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        )
      else ...[
        ListTile(
          title: Text('Recientes', style: theme.textTheme.titleSmall),
          trailing: TextButton(
            onPressed: () {
              _borrarRecientes();
              controller.text = '';
            },
            child: const Text('Borrar'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
          child: Wrap(
            spacing: EcoSpace.s8,
            runSpacing: EcoSpace.s8,
            children: [
              for (final termino in _recientes)
                ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(termino),
                  onPressed: () => controller.text = termino,
                ),
            ],
          ),
        ),
      ],
      ListTile(title: Text('Busca por categoría', style: theme.textTheme.titleSmall)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
        child: Wrap(
          spacing: EcoSpace.s8,
          runSpacing: EcoSpace.s8,
          children: [
            for (final categoria in categoriasPublicables.keys)
              InkWell(
                onTap: () => controller.text = etiquetaDeCategoria(categoriaFromString(categoria)),
                child: CategoriaChip.fromString(categoria),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _resultados(List<MaterialResiduo> catalogo, String texto, SearchController controller) {
    final buscado = _normalizar(texto);
    final categoriaBuscada = categoriasPublicables.keys.where(
      (c) => _normalizar(etiquetaDeCategoria(categoriaFromString(c))).startsWith(buscado),
    );
    final resultados = catalogo.where((m) {
      return _normalizar(m.nombreComun).contains(buscado) ||
          _normalizar(m.subcategoria ?? '').contains(buscado) ||
          categoriaBuscada.contains(m.categoria.toUpperCase());
    }).toList();

    if (resultados.isEmpty) {
      return [
        EmptyStateWidget(
          icon: Icons.search_off,
          title: 'No encontramos «$texto»',
          description: 'Prueba con otra palabra o tómale una foto: la cámara te dice de qué categoría es.',
          ctaText: 'Identificar con foto',
          ctaIcon: Icons.photo_camera_outlined,
          onCtaPressed: () {
            controller.closeView('');
            abrirIdentificacion(context);
          },
          secondaryText: 'Ver la guía general',
          onSecondaryPressed: () {
            controller.closeView('');
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GuiaManejoGeneralScreen()));
          },
        ),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s16, EcoSpace.s4),
        child: Text(
          resultados.length == 1 ? '1 resultado para «$texto»' : '${resultados.length} resultados para «$texto»',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
      for (final material in resultados)
        FilaMaterial(
          material: material,
          onTap: () {
            _guardarReciente(texto);
            controller.closeView(texto);
            _abrirMaterial(material);
          },
        ),
    ];
  }

  Widget _cuadricula(List<MaterialResiduo> catalogo) {
    final textoGrande = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final celdas = [
      for (final entrada in categoriasPublicables.entries)
        _CeldaCategoria(
          categoria: categoriaFromString(entrada.key),
          ejemplos: entrada.value,
          onTap: () => _abrirCategoria(catalogo, entrada.key),
        ),
      _CeldaGuia(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuiaManejoGeneralScreen())),
      ),
    ];
    final columnas = textoGrande ? 1 : 2;
    return Column(
      children: [
        for (var i = 0; i < celdas.length; i += columnas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columnas; j++) ...[
                    if (j > i) const SizedBox(width: 10),
                    Expanded(child: j < celdas.length ? celdas[j] : const SizedBox()),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

class _CeldaCategoria extends StatelessWidget {
  const _CeldaCategoria({required this.categoria, required this.ejemplos, required this.onTap});

  final Categoria categoria;
  final String ejemplos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colores = theme.extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    return Material(
      color: color.container,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 124),
          padding: const EdgeInsets.all(EcoSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoriaIcon(categoria: categoria, size: 28, color: color.onContainer),
              const SizedBox(height: EcoSpace.s24),
              Text(
                etiquetaDeCategoria(categoria),
                style: theme.textTheme.titleSmall?.copyWith(color: color.onContainer),
              ),
              const SizedBox(height: 2),
              Text(ejemplos, style: theme.textTheme.bodySmall?.copyWith(color: color.onContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CeldaGuia extends StatelessWidget {
  const _CeldaGuia({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 124),
          padding: const EdgeInsets.all(EcoSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.menu_book_outlined, size: 28, color: scheme.primary),
              const SizedBox(height: EcoSpace.s24),
              Text('Guía de manejo general', style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                'Qué hacer con cada categoría',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuadriculaSkeleton extends StatelessWidget {
  const _CuadriculaSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: List.generate(6, (_) => const ShimmerLoading(radius: EcoRadius.medium, height: double.infinity)),
    );
  }
}

/// Fila de material: tile de categoría, nombre completo y «categoría · subcategoría».
class FilaMaterial extends StatelessWidget {
  const FilaMaterial({super.key, required this.material, required this.onTap});

  final MaterialResiduo material;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoria = categoriaFromString(material.categoria);
    final detalle = [
      etiquetaDeCategoria(categoria),
      if (material.subcategoria?.trim().isNotEmpty ?? false) material.subcategoria!.trim(),
    ].join(' · ');
    return ListTile(
      minTileHeight: 68,
      leading: CategoriaTile(categoria: categoria),
      title: Text(material.nombreComun, style: theme.textTheme.titleSmall),
      subtitle: Text(detalle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Materiales de una categoría, agrupados por subcategoría.
class MaterialesCategoriaScreen extends StatelessWidget {
  const MaterialesCategoriaScreen({
    super.key,
    required this.categoria,
    required this.materiales,
    required this.onAbrir,
  });

  final String categoria;
  final List<MaterialResiduo> materiales;
  final ValueChanged<MaterialResiduo> onAbrir;

  @override
  Widget build(BuildContext context) {
    final categoriaEnum = categoriaFromString(categoria);
    final ordenados = [...materiales]
      ..sort(
        (a, b) => (a.subcategoria ?? '').compareTo(b.subcategoria ?? '') != 0
            ? (a.subcategoria ?? '').compareTo(b.subcategoria ?? '')
            : a.nombreComun.compareTo(b.nombreComun),
      );

    return Scaffold(
      appBar: AppBar(title: Text(etiquetaDeCategoria(categoriaEnum))),
      body: ordenados.isEmpty
          ? const EstadoDesplazable(
              child: EmptyStateWidget(
                icon: Icons.inventory_2_outlined,
                title: 'Aún no hay materiales en esta categoría',
              ),
            )
          : ListView(
              children: [
                CategoriaBanner(categoria: categoriaEnum),
                for (final material in ordenados) FilaMaterial(material: material, onTap: () => onAbrir(material)),
              ],
            ),
    );
  }
}
