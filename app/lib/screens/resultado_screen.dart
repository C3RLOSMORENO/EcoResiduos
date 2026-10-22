import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../features/solicitudes/screens/publicar_residuo_screen.dart';
import '../models/waste_item.dart';
import '../repositories/gestores_repository.dart';
import '../services/identificacion_service.dart';
import '../theme/eco_theme.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/foto_capturada.dart';
import 'flujo_identificacion.dart';
import 'guia_manejo_general_screen.dart';
import 'informacion_residuo_screen.dart';

/// Resultado de la IA (22). Orgánico y Ordinario solo los detecta el modelo:
/// ningún gestor de la app los recibe, así que no se ofrece publicarlos.
class ResultadoScreen extends StatelessWidget {
  const ResultadoScreen({super.key, required this.item, required this.imagePath, this.gestoresRepository});

  final WasteItem item;
  final String imagePath;
  final GestoresRepository? gestoresRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoria = categoriaFromString(item.categoria);
    final codigo = item.categoria.toUpperCase();
    final guia = guiasPorCategoria[categoria]!;
    final publicable = categoriasPublicables.containsKey(codigo);

    void verGuia() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GuiaManejoGeneralScreen(categoriaInicial: categoria)),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          FotoCapturada(ruta: imagePath),
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
              child: Material(
                color: scheme.surfaceContainerLowest,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
                clipBehavior: Clip.antiAlias,
                elevation: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CategoriaBanner(
                      categoria: categoria,
                      height: 56,
                      label: categoria == Categoria.raee ? 'Eléctricos y Electrónicos (RAEE)' : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(EcoSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Confianza(valor: item.confianza),
                          const SizedBox(height: EcoSpace.s16),
                          Text(
                            item.nombre,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: EcoSpace.s8),
                          Text(guia.consejoResultado, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: EcoSpace.s16),
                          _SubcategoriasSeccion(categoria: categoria),
                          if (item.confianza < IdentificacionService.confianzaAlta && item.alternativas.isNotEmpty) ...[
                            const SizedBox(height: EcoSpace.s16),
                            OpcionesIa(
                              titulo: '¿No es correcto? También podría ser:',
                              opciones: item.alternativas,
                              imagePath: imagePath,
                              descartada: Alternativa(categoria: item.categoria, confianza: item.confianza),
                              gestoresRepository: gestoresRepository,
                            ),
                          ],
                          if (categoria == Categoria.peligroso) ...[
                            const SizedBox(height: EcoSpace.s12),
                            const AvisoAdvertencia(
                              titulo: 'Guárdalo aparte',
                              texto: 'Mientras lo recogen, déjalo en un envase cerrado y lejos del calor.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s24),
            child: publicable
                ? GestoresCercanos(categoria: codigo, repository: gestoresRepository)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        onPressed: verGuia,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('¿Cómo separarlo correctamente?'),
                      ),
                      const SizedBox(height: EcoSpace.s8),
                      TextButton(
                        onPressed: () => abrirIdentificacion(context, reemplazarActual: true),
                        child: const Text('Identificar otro residuo'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: publicable
          ? Container(
              color: scheme.surfaceContainer,
              padding: EdgeInsets.fromLTRB(
                EcoSpace.s16,
                EcoSpace.s12,
                EcoSpace.s16,
                EcoSpace.s12 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicarResiduoScreen(fotoInicial: imagePath, categoriaSugerida: codigo),
                      ),
                    ),
                    icon: const Icon(Icons.upload),
                    label: const Text('Publicar para recolección'),
                  ),
                  TextButton(onPressed: verGuia, child: const Text('Ver información de la categoría')),
                ],
              ),
            )
          : null,
    );
  }
}

/// Confianza en número y en texto: «Muy probable» desde el 85 %, «Probable» por debajo.
class _Confianza extends StatelessWidget {
  const _Confianza({required this.valor});

  final int valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reducir = MediaQuery.of(context).disableAnimations;
    final texto = valor >= IdentificacionService.confianzaAlta ? 'Muy probable' : 'Probable';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.toDouble()),
      duration: reducir ? Duration.zero : EcoMotion.conteo,
      curve: Curves.easeOutCubic,
      builder: (_, actual, _) => Semantics(
        label: 'Confianza de la IA: $valor por ciento, $texto',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${actual.round()} %', style: theme.textTheme.displayMedium?.copyWith(height: 1)),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(texto, style: theme.textTheme.titleMedium),
                      Text(
                        'Confianza de la IA',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: actual / 100, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// Categorías que la IA también consideró. Al elegir una se abre su resultado,
/// y la categoría que se deja pasa a ser una opción más.
class OpcionesIa extends StatelessWidget {
  const OpcionesIa({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.imagePath,
    this.descartada,
    this.gestoresRepository,
  });

  final String titulo;
  final List<Alternativa> opciones;
  final String imagePath;
  final Alternativa? descartada;
  final GestoresRepository? gestoresRepository;

  void _elegir(BuildContext context, Alternativa opcion) {
    final restantes = [
      ?descartada,
      for (final otra in opciones)
        if (otra.categoria != opcion.categoria) otra,
    ]..sort((a, b) => b.confianza.compareTo(a.confianza));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadoScreen(
          item: WasteItem(
            nombre: IdentificacionService.nombreDe(opcion.categoria),
            categoria: opcion.categoria,
            confianza: opcion.confianza,
            imagenPath: imagePath,
            alternativas: restantes,
          ),
          imagePath: imagePath,
          gestoresRepository: gestoresRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: theme.textTheme.titleSmall),
        const SizedBox(height: EcoSpace.s8),
        for (final opcion in opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: EcoSpace.s8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.medium)),
              ),
              onPressed: () => _elegir(context, opcion),
              child: Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: CategoriaChip.fromString(opcion.categoria)),
                  ),
                  Text('${opcion.confianza} %', style: theme.textTheme.labelLarge),
                  const SizedBox(width: EcoSpace.s4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Muestra las subcategorías y ejemplos representativos que abarca la categoría identificada.
class _SubcategoriasSeccion extends StatelessWidget {
  const _SubcategoriasSeccion({required this.categoria});

  final Categoria categoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colores = theme.extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    final subcategorias = subcategoriasPorCategoria[categoria] ?? const [];

    if (subcategorias.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(EcoRadius.medium),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(EcoSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 20, color: color.color),
              const SizedBox(width: EcoSpace.s8),
              Expanded(
                child: Text(
                  'Subcategorías y qué incluye:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.s8),
          for (final sub in subcategorias)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: color.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      sub,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
