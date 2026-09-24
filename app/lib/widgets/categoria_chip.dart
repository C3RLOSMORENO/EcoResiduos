import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Colores de caneca de la Res. 2184 de 2019 que se pintan bajo el contorno
/// del pictograma. Son fijos: no dependen del tema.
const _canecaVerde = Color(0xFF2F8A1F);
const _canecaNegra = Color(0xFF1A1C1A);

IconData iconoCategoria(Categoria categoria) {
  switch (categoria) {
    case Categoria.aprovechable:
      return Icons.restore_from_trash_outlined;
    case Categoria.peligroso:
      return Icons.science_outlined;
    case Categoria.raee:
      return Icons.devices_other_outlined;
    case Categoria.rcd:
      return Icons.construction_outlined;
    case Categoria.riesgoBiologico:
      return Icons.coronavirus_outlined;
    case Categoria.organico:
      return Icons.compost_outlined;
    case Categoria.ordinario:
      return Icons.delete_outline;
  }
}

/// Pictograma de la categoría. Las tres categorías con caneca normativa
/// (blanca, verde, negra) pintan el color de la caneca bajo el contorno.
class CategoriaIcon extends StatelessWidget {
  const CategoriaIcon({super.key, required this.categoria, this.size = 18, this.color});

  final Categoria categoria;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final contorno = color ?? colores.categoria(categoria).onContainer;
    final relleno = switch (categoria) {
      Categoria.aprovechable => (Icons.restore_from_trash, Colors.white),
      Categoria.organico => (Icons.compost, _canecaVerde),
      Categoria.ordinario => (Icons.delete, _canecaNegra),
      _ => null,
    };

    final icono = Icon(iconoCategoria(categoria), size: size, color: contorno);
    if (relleno == null) return icono;
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(relleno.$1, size: size, color: relleno.$2),
        icono,
      ],
    );
  }
}

/// Chip de categoría con forma de etiqueta colgante: color, pictograma y
/// nombre siempre juntos, para que se lea también sin distinguir colores.
class CategoriaChip extends StatelessWidget {
  const CategoriaChip({super.key, required this.categoria, this.label});

  factory CategoriaChip.fromString(String? raw, {Key? key, String? label}) =>
      CategoriaChip(key: key, categoria: categoriaFromString(raw), label: label);

  final Categoria categoria;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    final texto = label ?? etiquetaDeCategoria(categoria);

    return Semantics(
      label: 'Categoría $texto',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.fromLTRB(20, 4, 10, 4),
        decoration: ShapeDecoration(color: color.container, shape: const EtiquetaChipBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoriaIcon(categoria: categoria, size: 16, color: color.onContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color.onContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile cuadrado con el pictograma sobre el color tonal de la categoría,
/// usado al inicio de filas y resultados.
class CategoriaTile extends StatelessWidget {
  const CategoriaTile({super.key, required this.categoria, this.size = 40});

  final Categoria categoria;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: color.container,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.small))),
      ),
      alignment: Alignment.center,
      child: CategoriaIcon(categoria: categoria, size: size * 0.55, color: color.onContainer),
    );
  }
}

/// Banda de color de la categoría para cabeceras de fichas. En riesgo
/// biológico lleva franjas diagonales para no confundirse con un error.
class CategoriaBanner extends StatelessWidget {
  const CategoriaBanner({super.key, required this.categoria, this.height = 48, this.trailing});

  final Categoria categoria;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    final theme = Theme.of(context);

    return CustomPaint(
      painter: categoria == Categoria.riesgoBiologico
          ? FranjasAlertaPainter(fondo: color.color, franja: color.onColor)
          : null,
      child: Container(
        height: height,
        color: categoria == Categoria.riesgoBiologico ? null : color.color,
        padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
        child: Row(
          children: [
            CategoriaIcon(categoria: categoria, size: 22, color: color.onColor),
            const SizedBox(width: EcoSpace.s8),
            Expanded(
              child: Text(
                etiquetaDeCategoria(categoria).toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: theme.textTheme.headlineSmall?.fontFamily,
                  color: color.onColor,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Fondo rojo de riesgo biológico con franjas diagonales de alerta máxima.
class FranjasAlertaPainter extends CustomPainter {
  const FranjasAlertaPainter({required this.fondo, required this.franja});

  final Color fondo;
  final Color franja;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fondo);
    final paint = Paint()
      ..color = franja.withValues(alpha: 0.14)
      ..strokeWidth = 8;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FranjasAlertaPainter oldDelegate) => oldDelegate.fondo != fondo || oldDelegate.franja != franja;
}

/// Nombre legible de una categoría.
String etiquetaDeCategoria(Categoria categoria) => switch (categoria) {
  Categoria.aprovechable => 'Aprovechable',
  Categoria.peligroso => 'Peligroso (RESPEL)',
  Categoria.raee => 'RAEE',
  Categoria.rcd => 'Escombros (RCD)',
  Categoria.riesgoBiologico => 'Riesgo biológico',
  Categoria.organico => 'Orgánico',
  Categoria.ordinario => 'Ordinario',
};
