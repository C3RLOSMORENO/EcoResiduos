import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Logo de EcoResiduos: la etiqueta blanca con la banda de las 7 categorías.
/// Sus colores son fijos para que la marca se vea igual en claro y oscuro.
class EcoLogo extends StatelessWidget {
  const EcoLogo({super.key, this.width = 134});

  final double width;

  @override
  Widget build(BuildContext context) {
    final alto = width * 1.25;
    return Semantics(
      label: 'EcoResiduos',
      image: true,
      child: Container(
        width: width,
        height: alto,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: EtiquetaBorder(
            radius: width * 0.107,
            cut: width * 0.196,
            hole: width * 0.071,
            holeCenter: Offset(width * 0.214, alto * 0.414),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: width * 0.321,
              child: Row(
                children: [
                  for (final categoria in Categoria.values)
                    Expanded(child: ColoredBox(color: ecoColoresLight.categoria(categoria).color)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(width * 0.125),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'eco',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: width * 0.232,
                      height: 1,
                      color: ecoLightColorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
