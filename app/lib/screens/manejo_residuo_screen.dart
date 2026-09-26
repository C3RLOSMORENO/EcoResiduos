import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../features/solicitudes/models/material_residuo.dart';
import '../features/solicitudes/screens/publicar_residuo_screen.dart';
import '../theme/eco_theme.dart';
import '../utils/sesion.dart';
import '../widgets/boton_fijo_inferior.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/contenido_guia.dart';
import 'guia_manejo_general_screen.dart';

/// Manejo seguro de un material (12): pasos numerados y lineamientos según
/// la normativa ambiental colombiana, con tipografía clara y signos formales.
class ManejoResiduoScreen extends StatelessWidget {
  const ManejoResiduoScreen({super.key, required this.material});

  final MaterialResiduo material;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoria = categoriaFromString(material.categoria);
    final guia = guiasPorCategoria[categoria]!;
    final pasos = material.pasosManejo.isNotEmpty ? material.pasosManejo : guia.hacer;
    final puedePublicar =
        !SesionUsuario.actual().esGestor && categoriasPublicables.containsKey(material.categoria.toUpperCase());

    return Scaffold(
      appBar: AppBar(title: const Text('Guía de manejo seguro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s12, EcoSpace.s16, EcoSpace.s32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CategoriaChip(categoria: categoria),
          ),
          const SizedBox(height: EcoSpace.s8),
          Text(
            material.nombreComun,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.2),
          ),
          if (material.subcategoria?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: EcoSpace.s4),
            Text(
              material.subcategoria!.trim(),
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: EcoSpace.s16),
          RecuadroNormativa(guia: guia),
          if (material.tieneAdvertencia) ...[
            const SizedBox(height: EcoSpace.s16),
            AvisoAdvertencia(texto: material.advertenciaManejo!),
          ],
          const SizedBox(height: EcoSpace.s24),
          SeccionGuia(
            titulo: '¿Cómo realizar el manejo seguro?',
            child: Column(
              children: [for (final (i, paso) in pasos.indexed) PasoNumerado(numero: i + 1, texto: paso)],
            ),
          ),
          SeccionGuia(
            titulo: '¿Qué no hacer según la norma?',
            colorTitulo: scheme.error,
            child: Column(
              children: [
                for (final restriccion in guia.noHacer)
                  ItemGuia(icono: Icons.cancel_outlined, color: scheme.error, texto: restriccion),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.medium)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GuiaManejoGeneralScreen(categoriaInicial: categoria)),
            ),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Ver marco normativo completo'),
          ),
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
