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
                    CategoriaBanner(categoria: categoria, height: 56),
                    Padding(
                      padding: const EdgeInsets.all(EcoSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Confianza(valor: item.confianza),
                          const SizedBox(height: EcoSpace.s16),
                          Text(guia.consejoResultado, style: theme.textTheme.bodyLarge),
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
