import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../features/solicitudes/models/material_residuo.dart';
import '../features/solicitudes/screens/publicar_residuo_screen.dart';
import '../theme/eco_theme.dart';
import '../utils/sesion.dart';
import '../widgets/boton_fijo_inferior.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/empty_state_widget.dart';
import 'guia_manejo_general_screen.dart';

/// Manejo seguro de un material (12): pasos numerados en etiquetas, en
/// texto grande para leerlo con el residuo en la mano.
class ManejoResiduoScreen extends StatelessWidget {
  const ManejoResiduoScreen({super.key, required this.material});

  final MaterialResiduo material;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoria = categoriaFromString(material.categoria);
    final pasos = material.pasosManejo;
    final puedePublicar =
        !SesionUsuario.actual().esGestor && categoriasPublicables.containsKey(material.categoria.toUpperCase());

    return Scaffold(
      appBar: AppBar(title: const Text('Manejo seguro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CategoriaChip(categoria: categoria),
          ),
          const SizedBox(height: EcoSpace.s8),
          Text(material.nombreComun, style: theme.textTheme.headlineSmall),
          if (material.tieneAdvertencia) ...[
            const SizedBox(height: EcoSpace.s16),
            AvisoAdvertencia(texto: material.advertenciaManejo!),
          ],
          const SizedBox(height: EcoSpace.s24),
          if (pasos.isEmpty)
            EmptyStateWidget(
              icon: Icons.list_alt,
              title: 'Aún no hay pasos para este material',
              description: 'Mientras tanto, sigue la guía general de ${etiquetaDeCategoria(categoria)}.',
              ctaText: 'Ver guía de ${etiquetaDeCategoria(categoria)}',
              ctaIcon: Icons.menu_book_outlined,
              onCtaPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GuiaManejoGeneralScreen(categoriaInicial: categoria)),
              ),
            )
          else
            for (final (i, paso) in pasos.indexed) PasoNumerado(numero: i + 1, texto: paso),
        ],
      ),
      bottomNavigationBar: puedePublicar
          ? BotonFijoInferior(
              textoBoton: 'Publicar para recolección',
              iconoBoton: Icons.upload,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PublicarResiduoScreen(categoriaSugerida: material.categoria)),
              ),
            )
          : null,
    );
  }
}

/// Paso con su número dentro de una etiqueta pequeña.
class PasoNumerado extends StatelessWidget {
  const PasoNumerado({super.key, required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 52,
            alignment: const Alignment(0, 0.3),
            decoration: ShapeDecoration(
              color: scheme.primaryContainer,
              shape: const EtiquetaBorder(radius: EcoRadius.small, cut: 10),
            ),
            child: Text('$numero', style: theme.textTheme.headlineMedium?.copyWith(color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: EcoSpace.s16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: EcoSpace.s12),
              child: Text(texto, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}
