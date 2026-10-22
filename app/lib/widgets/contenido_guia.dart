import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../theme/eco_theme.dart';
import '../utils/enlaces.dart';

/// Piezas de lectura compartidas por la ficha del material, el manejo seguro
/// y la guía general, para que el texto tenga el mismo tamaño en todas.

/// Estilo de los párrafos de lectura.
TextStyle? estiloLectura(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface);
}

/// Título de una sección de la guía.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
    );
  }
}

/// Título y contenido con el espaciado de una sección de lectura.
class SeccionGuia extends StatelessWidget {
  const SeccionGuia({super.key, required this.titulo, required this.child, this.colorTitulo});

  final String titulo;
  final Widget child;
  final Color? colorTitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TituloSeccion(titulo, color: colorTitulo),
          const SizedBox(height: EcoSpace.s12),
          child,
        ],
      ),
    );
  }
}

/// Punto de una lista con su ícono (qué hacer, qué no hacer).
class ItemGuia extends StatelessWidget {
  const ItemGuia({super.key, required this.icono, required this.color, required this.texto});

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icono, size: 20, color: color),
          ),
          const SizedBox(width: EcoSpace.s12),
          Expanded(child: Text(texto, style: estiloLectura(context))),
        ],
      ),
    );
  }
}

/// Paso con su número en una etiqueta.
class PasoNumerado extends StatelessWidget {
  const PasoNumerado({super.key, required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: scheme.primaryContainer,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.small))),
            ),
            child: Text(
              '$numero',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: EcoSpace.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(texto, style: estiloLectura(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro con la norma que aplica, el color de la bolsa y, si se pide,
/// el artículo clave.
class RecuadroNormativa extends StatelessWidget {
  const RecuadroNormativa({super.key, required this.guia, this.conArticulo = false});

  final GuiaCategoria guia;
  final bool conArticulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(EcoSpace.s16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(EcoRadius.medium),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fila(
            icono: Icons.gavel_rounded,
            colorIcono: scheme.primary,
            child: Text(
              guia.normativa,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: EcoSpace.s8),
          _Fila(
            icono: Icons.inventory_2_outlined,
            colorIcono: scheme.onSurfaceVariant,
            child: Text(
              guia.codigoColor,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
            ),
          ),
          if (conArticulo) ...[
            const SizedBox(height: EcoSpace.s8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                guia.articuloClave,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (guia.urlNormativa != null) ...[
            const SizedBox(height: EcoSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: scheme.primary,
                ),
                onPressed: () => abrirDocumento(context, guia.urlNormativa!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver norma oficial'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.colorIcono, required this.child});

  final IconData icono;
  final Color colorIcono;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icono, size: 20, color: colorIcono),
        ),
        const SizedBox(width: EcoSpace.s8),
        Expanded(child: child),
      ],
    );
  }
}
