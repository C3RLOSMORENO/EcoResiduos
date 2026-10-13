import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../features/solicitudes/models/material_residuo.dart';
import '../theme/eco_theme.dart';
import 'categoria_chip.dart';

const _sinSubcategoria = 'General';

String _subcategoriaDe(MaterialResiduo m) {
  final sub = m.subcategoria?.trim();
  return sub == null || sub.isEmpty ? _sinSubcategoria : sub;
}

/// Selector de material en 3 niveles (27c–27e): categoría → subcategoría →
/// material, en una hoja al 88 % del alto. Devuelve el material elegido.
class SelectorCascadaSheet extends StatefulWidget {
  const SelectorCascadaSheet({super.key, required this.materiales, this.categoriaInicial, this.categoriaSugerida});

  final List<MaterialResiduo> materiales;

  /// Abre directamente en esta categoría (p. ej. al aplicar la sugerencia de la IA).
  final String? categoriaInicial;

  /// Categoría marcada como «Sugerida» en el primer nivel.
  final String? categoriaSugerida;

  /// Abre el selector y devuelve el material elegido, o null si se cerró sin elegir.
  static Future<MaterialResiduo?> show(
    BuildContext context, {
    required List<MaterialResiduo> materiales,
    String? categoriaInicial,
    String? categoriaSugerida,
  }) {
    return showModalBottomSheet<MaterialResiduo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => SelectorCascadaSheet(
        materiales: materiales,
        categoriaInicial: categoriaInicial,
        categoriaSugerida: categoriaSugerida,
      ),
    );
  }

  @override
  State<SelectorCascadaSheet> createState() => _SelectorCascadaSheetState();
}

class _SelectorCascadaSheetState extends State<SelectorCascadaSheet> {
  String? _categoria;
  String? _subcategoria;
  String _filtro = '';

  int get _nivel => _categoria == null ? 1 : (_subcategoria == null ? 2 : 3);

  @override
  void initState() {
    super.initState();
    final inicial = widget.categoriaInicial?.toUpperCase();
    if (inicial != null && categoriasPublicables.containsKey(inicial)) _elegirCategoria(inicial);
  }

  List<String> _subcategorias(String categoria) {
    final subs =
        widget.materiales.where((m) => m.categoria.toUpperCase() == categoria).map(_subcategoriaDe).toSet().toList()
          ..sort();
    return subs;
  }

  List<MaterialResiduo> _materialesDe(String categoria, String subcategoria) => widget.materiales
      .where((m) => m.categoria.toUpperCase() == categoria && _subcategoriaDe(m) == subcategoria)
      .toList();

  void _elegirCategoria(String categoria) {
    final subs = _subcategorias(categoria);
    _categoria = categoria;
    _subcategoria = subs.length == 1 ? subs.first : null;
    _filtro = '';
  }

  void _volver() {
    setState(() {
      _filtro = '';
      if (_nivel == 3 && _subcategorias(_categoria!).length > 1) {
        _subcategoria = null;
      } else {
        _categoria = null;
        _subcategoria = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titulo = switch (_nivel) {
      1 => '¿Qué tipo de residuo es?',
      2 => 'Subcategoría',
      _ => 'Material',
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: EcoSpace.s12),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s8, EcoSpace.s8, EcoSpace.s16, EcoSpace.s8),
            child: Row(
              children: [
                if (_nivel > 1)
                  IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back), onPressed: _volver)
                else
                  const SizedBox(width: EcoSpace.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_categoria != null)
                        Text(
                          [etiquetaDeCategoria(categoriaFromString(_categoria)), ?_subcategoria].join(' › '),
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
                        ),
                      Text(titulo, style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
                Text(
                  '$_nivel DE 3',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: theme.textTheme.headlineSmall?.fontFamily,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_nivel) {
              1 => _categorias(scroll),
              2 => _subcategoriasView(scroll),
              _ => _materialesView(scroll),
            },
          ),
        ],
      ),
    );
  }

  Widget _categorias(ScrollController scroll) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sugerida = widget.categoriaSugerida?.toUpperCase();
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
      children: [
        for (final entrada in categoriasPublicables.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: EcoSpace.s8),
            child: _Opcion(
              leading: CategoriaTile(categoria: categoriaFromString(entrada.key), size: 44),
              titulo: etiquetaDeCategoria(categoriaFromString(entrada.key)),
              subtitulo: entrada.value,
              trailing: entrada.key == sugerida
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(EcoRadius.full),
                      ),
                      child: Text(
                        'Sugerida',
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    )
                  : null,
              onTap: () => setState(() => _elegirCategoria(entrada.key)),
            ),
          ),
      ],
    );
  }

  Widget _subcategoriasView(ScrollController scroll) {
    final subs = _subcategorias(_categoria!);
    if (subs.isEmpty) return _sinMateriales();
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
      children: [
        for (final sub in subs)
          Padding(
            padding: const EdgeInsets.only(bottom: EcoSpace.s8),
            child: _Opcion(
              titulo: sub,
              subtitulo: _conteo(_materialesDe(_categoria!, sub).length),
              onTap: () => setState(() => _subcategoria = sub),
            ),
          ),
      ],
    );
  }

  Widget _materialesView(ScrollController scroll) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final todos = _materialesDe(_categoria!, _subcategoria!);
    final visibles = _filtro.isEmpty
        ? todos
        : todos.where((m) => m.nombreComun.toLowerCase().contains(_filtro.toLowerCase())).toList();

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
      children: [
        if (todos.length > 5)
          Padding(
            padding: const EdgeInsets.only(bottom: EcoSpace.s12),
            child: TextField(
              onChanged: (texto) => setState(() => _filtro = texto.trim()),
              decoration: InputDecoration(
                hintText: 'Filtra entre ${todos.length} materiales',
                prefixIcon: const Icon(Icons.filter_list),
              ),
            ),
          ),
        if (todos.isEmpty) _sinMateriales(),
        for (final material in visibles)
          Padding(
            padding: const EdgeInsets.only(bottom: EcoSpace.s8),
            child: _Opcion(
              titulo: material.nombreComun,
              subtitulo: material.descripcion,
              aviso: material.tieneAdvertencia
                  ? Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                        const SizedBox(width: EcoSpace.s4),
                        Flexible(
                          child: Text(
                            'Tiene advertencia técnica',
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.error),
                          ),
                        ),
                      ],
                    )
                  : null,
              onTap: () => Navigator.pop(context, material),
            ),
          ),
      ],
    );
  }

  Widget _sinMateriales() => Padding(
    padding: const EdgeInsets.all(EcoSpace.s24),
    child: Text(
      'Aún no hay materiales registrados en esta categoría.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );

  static String _conteo(int n) => n == 1 ? '1 material' : '$n materiales';
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.titulo, required this.onTap, this.subtitulo, this.leading, this.trailing, this.aviso});

  final String titulo;
  final String? subtitulo;
  final Widget? leading;
  final Widget? trailing;
  final Widget? aviso;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(EcoSpace.s12),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: EcoSpace.s12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: theme.textTheme.titleSmall),
                      if (subtitulo != null && subtitulo!.isNotEmpty)
                        Text(subtitulo!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      if (aviso != null) ...[const SizedBox(height: EcoSpace.s4), aviso!],
                    ],
                  ),
                ),
                const SizedBox(width: EcoSpace.s8),
                trailing ?? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
