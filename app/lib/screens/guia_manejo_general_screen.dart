import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../theme/eco_theme.dart';
import '../widgets/categoria_chip.dart';

/// Guía de manejo por categoría (13). La pestaña activa muestra el chip
/// completo de su categoría y las demás solo el ícono.
class GuiaManejoGeneralScreen extends StatefulWidget {
  const GuiaManejoGeneralScreen({super.key, this.categoriaInicial});

  final Categoria? categoriaInicial;

  @override
  State<GuiaManejoGeneralScreen> createState() => _GuiaManejoGeneralScreenState();
}

class _GuiaManejoGeneralScreenState extends State<GuiaManejoGeneralScreen> {
  late final List<Categoria> _categorias = [
    for (final c in categoriasPublicables.keys) categoriaFromString(c),
    if (widget.categoriaInicial == Categoria.organico || widget.categoriaInicial == Categoria.ordinario)
      widget.categoriaInicial!,
  ];
  late Categoria _actual = widget.categoriaInicial ?? _categorias.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final guia = guiasPorCategoria[_actual]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Guía de manejo')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: EcoSpace.s32),
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16, vertical: 6),
              itemCount: _categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: EcoSpace.s8),
              itemBuilder: (_, i) {
                final categoria = _categorias[i];
                final activa = categoria == _actual;
                return Semantics(
                  selected: activa,
                  button: true,
                  label: etiquetaDeCategoria(categoria),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => _actual = categoria),
                    borderRadius: BorderRadius.circular(EcoRadius.small),
                    child: activa
                        ? Center(child: CategoriaChip(categoria: categoria))
                        : SizedBox(
                            width: 44,
                            child: Center(child: CategoriaTile(categoria: categoria)),
                          ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(EcoSpace.s16),
            child: Material(
              color: scheme.surfaceContainerLowest,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CategoriaBanner(categoria: _actual),
                  Padding(
                    padding: const EdgeInsets.all(EcoSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Seccion(
                          titulo: 'Cómo reconocerlo',
                          child: Text(guia.reconocer, style: theme.textTheme.bodyLarge),
                        ),
                        _Seccion(
                          titulo: 'Qué hacer',
                          child: Column(
                            children: [
                              for (final item in guia.hacer)
                                _Item(icono: Icons.check_circle, color: scheme.primary, texto: item),
                            ],
                          ),
                        ),
                        _Seccion(
                          titulo: 'Qué no hacer',
                          child: Column(
                            children: [
                              for (final item in guia.noHacer)
                                _Item(icono: Icons.block, color: scheme.error, texto: item),
                            ],
                          ),
                        ),
                        _Seccion(
                          titulo: 'Dónde entregarlo',
                          child: Text(guia.entregar, style: theme.textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EcoSpace.s8),
          child,
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icono, required this.color, required this.texto});

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: EcoSpace.s8),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
