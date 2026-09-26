import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../theme/eco_theme.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/contenido_guia.dart';

/// Guía de manejo y marco normativo oficial colombiano por categoría (13).
/// Diseñada con proporciones armónicas, tipografía legible y jerarquía visual clara.
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
      appBar: AppBar(title: const Text('Guía técnica y normativa')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: EcoSpace.s40),
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16, vertical: 4),
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
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s16, EcoSpace.s16),
            child: Material(
              color: scheme.surfaceContainerLowest,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CategoriaBanner(categoria: _actual),
                  Padding(
                    padding: const EdgeInsets.all(EcoSpace.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RecuadroNormativa(guia: guia, conArticulo: true),
                        const SizedBox(height: EcoSpace.s24),
                        SeccionGuia(
                          titulo: 'Definición técnica',
                          child: Text(guia.queEs, style: estiloLectura(context)),
                        ),
                        SeccionGuia(
                          titulo: '¿Cómo reconocerlo?',
                          child: Text(guia.reconocer, style: estiloLectura(context)),
                        ),
                        SeccionGuia(
                          titulo: '¿Qué hacer?',
                          child: Column(
                            children: [
                              for (final item in guia.hacer)
                                ItemGuia(icono: Icons.check_circle_outline, color: scheme.primary, texto: item),
                            ],
                          ),
                        ),
                        SeccionGuia(
                          titulo: '¿Qué no hacer?',
                          child: Column(
                            children: [
                              for (final item in guia.noHacer)
                                ItemGuia(icono: Icons.cancel_outlined, color: scheme.error, texto: item),
                            ],
                          ),
                        ),
                        SeccionGuia(
                          titulo: '¿Dónde entregarlo?',
                          child: Text(guia.entregar, style: estiloLectura(context)),
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
