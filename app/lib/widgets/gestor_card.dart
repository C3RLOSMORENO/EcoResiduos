import 'package:flutter/material.dart';

import '../models/gestor.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import 'categoria_chip.dart';

/// Tarjeta de gestor. En [compacta] es la del carrusel «Cerca de ti» (232 dp);
/// si no, es la fila de la lista completa con la distancia a la derecha.
class GestorCard extends StatelessWidget {
  const GestorCard({super.key, required this.gestor, this.onTap, this.compacta = false});

  final Gestor gestor;
  final VoidCallback? onTap;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detalle = [
      if (gestor.municipio.isNotEmpty) capitalizar(gestor.municipio),
      if (gestor.horario?.isNotEmpty ?? false) gestor.horario!,
    ].join(' · ');

    // En el carrusel el alto es fijo; la lista completa muestra el nombre entero.
    final nombre = Text(
      gestor.nombre,
      style: theme.textTheme.titleSmall,
      maxLines: compacta ? 3 : null,
      overflow: compacta ? TextOverflow.ellipsis : null,
    );
    final subtitulo = detalle.isEmpty
        ? null
        : Text(detalle, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant));
    final categorias = ChipsCategorias(categorias: gestor.categorias);

    final contenido = compacta
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarEntidad(nombre: gestor.nombre),
                  const SizedBox(width: EcoSpace.s8),
                  if (gestor.distanciaKm != null)
                    Expanded(
                      child: Text(
                        '${formatoDistancia(gestor.distanciaKm!)} de ti',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: EcoSpace.s12),
              nombre,
              ?subtitulo,
              const SizedBox(height: EcoSpace.s8),
              categorias,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarEntidad(nombre: gestor.nombre),
              const SizedBox(width: EcoSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    nombre,
                    ?subtitulo,
                    if (gestor.categorias.isNotEmpty) ...[const SizedBox(height: EcoSpace.s8), categorias],
                  ],
                ),
              ),
              const SizedBox(width: EcoSpace.s8),
              if (gestor.distanciaKm != null)
                Text(
                  formatoDistancia(gestor.distanciaKm!),
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18, color: scheme.primary),
                )
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          );

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(padding: const EdgeInsets.all(EcoSpace.s12), child: contenido),
        ),
      ),
    );
  }
}

/// Alto del carrusel «Cerca de ti», que crece con el tamaño de texto del sistema.
double alturaCarruselGestores(BuildContext context) => 200 + MediaQuery.textScalerOf(context).scale(76);

/// Máximo 2 chips de categoría y luego «y N más».
class ChipsCategorias extends StatelessWidget {
  const ChipsCategorias({super.key, required this.categorias, this.maximo = 2});

  final List<String> categorias;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibles = categorias.take(maximo);
    final resto = categorias.length - visibles.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in visibles) CategoriaChip.fromString(c),
        if (resto > 0)
          Text('y $resto más', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Iniciales en un recuadro terracota (gestores) o secundario (autoridades).
class AvatarEntidad extends StatelessWidget {
  const AvatarEntidad({super.key, required this.nombre, this.size = 40, this.secundario = false, this.texto});

  final String nombre;
  final double size;
  final bool secundario;

  /// Texto a mostrar en lugar de las iniciales (p. ej. la sigla).
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fondo = secundario ? scheme.secondaryContainer : scheme.tertiaryContainer;
    final frente = secundario ? scheme.onSecondaryContainer : scheme.onTertiaryContainer;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: fondo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.small))),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            texto ?? iniciales(nombre),
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: size * 0.4, color: frente),
          ),
        ),
      ),
    );
  }
}
