import 'package:flutter/material.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import 'categoria_chip.dart';
import 'estado_badge.dart';
import 'imagen_foto.dart';

/// Tarjeta de solicitud (26a, 29a, 31a): etiqueta con banda lateral del color
/// de la categoría, foto, material completo y cantidad con su propia unidad.
///
/// Con [mostrarCategoria] la cabecera lleva el chip de categoría y la
/// distancia (vista del gestor). El [pie] muestra estado u otra información;
/// si se omite, se muestra el estado de la solicitud.
class SolicitudCard extends StatelessWidget {
  const SolicitudCard({
    super.key,
    required this.solicitud,
    this.onTap,
    this.mostrarCategoria = false,
    this.distanciaKm,
    this.detalleUbicacion,
    this.pie,
  });

  final SolicitudRecoleccion solicitud;
  final VoidCallback? onTap;
  final bool mostrarCategoria;
  final double? distanciaKm;

  /// Texto tras el municipio, p. ej. «hace 2 h».
  final String? detalleUbicacion;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colores = theme.extension<EcoColores>() ?? ecoColoresLight;
    final categoria = categoriaFromString(solicitud.material?.categoria);
    final ubicacion = [
      if (solicitud.municipio.isNotEmpty) capitalizar(solicitud.municipio),
      if (detalleUbicacion != null && detalleUbicacion!.isNotEmpty) detalleUbicacion!,
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: EcoRadius.corte),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: colores.categoria(categoria).color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FotoResiduo(url: solicitud.fotoUrl, categoria: categoria, size: 72),
                      const SizedBox(width: EcoSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mostrarCategoria) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(child: CategoriaChip(categoria: categoria)),
                                  const Spacer(),
                                  if (distanciaKm != null)
                                    Text(
                                      'a ${formatoDistancia(distanciaKm!)}',
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontSize: 20,
                                        color: scheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              solicitud.material?.nombreComun ?? 'Residuo sin especificar',
                              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, height: 20 / 15),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: EcoSpace.s8,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                Text(
                                  formatoCantidad(solicitud.cantidadEstimada, solicitud.unidadMedida),
                                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22, height: 1),
                                ),
                                if (ubicacion.isNotEmpty)
                                  Text(
                                    ubicacion,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            if (pie != null || !mostrarCategoria) ...[
                              const SizedBox(height: 6),
                              pie ?? EstadoBadge.fromString(solicitud.estado),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado con un texto al lado («Publicado · 3 postulaciones»).
class FilaEstado extends StatelessWidget {
  const FilaEstado({super.key, required this.estado, this.texto, this.label});

  final String estado;
  final String? texto;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        EstadoBadge.fromString(estado, label: label),
        if (texto != null && texto!.isNotEmpty)
          Text(texto!, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Foto del residuo (URL o archivo local) con respaldo al pictograma de la categoría.
class FotoResiduo extends StatelessWidget {
  const FotoResiduo({
    super.key,
    required this.url,
    required this.categoria,
    this.size = 72,
    this.height,
    this.radio = EcoRadius.small,
  });

  final String? url;
  final Categoria categoria;

  /// Ancho; admite `double.infinity` junto con un [height] fijo.
  final double size;
  final double? height;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    final lado = height ?? size;
    final respaldo = Center(
      child: CategoriaIcon(categoria: categoria, size: (lado.isFinite ? lado : 72) * 0.42, color: color.onContainer),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: Container(
        width: size,
        height: height ?? size,
        color: color.container,
        child: ImagenFoto(ruta: url, respaldo: respaldo),
      ),
    );
  }
}
