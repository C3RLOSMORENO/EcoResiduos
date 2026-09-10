import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/pasos_manejo_list.dart';

/// WF-17 — Guía de manejo general
///
/// A diferencia de WF-08 (que muestra el manejo de un residuo puntual ya
/// identificado), esta pantalla es una guía general por categoría, a la
/// que se llega desde Inicio sin haber escaneado nada.
class GuiaManejoGeneralScreen extends StatefulWidget {
  const GuiaManejoGeneralScreen({super.key});

  @override
  State<GuiaManejoGeneralScreen> createState() =>
      _GuiaManejoGeneralScreenState();
}

class _GuiaManejoGeneralScreenState extends State<GuiaManejoGeneralScreen> {
  static const _pasosPorCategoria = {
    'Peligroso': [
      'No lo mezcles con residuos comunes o reciclables.',
      'Guárdalo en su empaque original o uno hermético.',
      'Etiqueta claramente el contenedor para evitar accidentes.',
      'Entrégalo a un gestor certificado de residuos peligrosos.',
    ],
    'Industrial': [
      'Separa y clasifica según la normativa de tu sector.',
      'Almacena en áreas designadas y seguras lejos de sumideros.',
      'Evita derrames y contaminación cruzada.',
      'Contacta a un gestor autorizado para la recolección en volumen.',
    ],
    'RAEE': [
      'No desarmes los equipos electrónicos por tu cuenta.',
      'Cubre con cinta las baterías o cables expuestos.',
      'Llévalos a puntos de recolección autorizados (ej. centros comerciales).',
      'Borra tu información personal antes de desecharlos.',
    ],
    'Biosanitario': [
      'Usa elementos de protección personal al manipularlos.',
      'Deposítalos únicamente en bolsas rojas marcadas como Riesgo Biológico.',
      'No los comprimas ni los mezcles con ningún otro tipo de residuo.',
      'Requieren recolección especializada y desactivación por calor.',
    ],
  };

  static const _descripciones = {
    'Peligroso': 'Sustancias químicas, aceites, pinturas o materiales corrosivos que representan un riesgo para la salud o el medio ambiente.',
    'Industrial': 'Residuos generados en procesos de manufactura, construcción o minería.',
    'RAEE': 'Residuos de Aparatos Eléctricos y Electrónicos (cables, celulares, electrodomésticos).',
    'Biosanitario': 'Material que ha estado en contacto con fluidos corporales humanos o animales, con riesgo de infección.',
  };

  String _categoria = 'Peligroso';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Guía de manejo general'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final categoria in _pasosPorCategoria.keys) ...[
                      CategoriaChip(
                        label: categoria,
                        selected: categoria == _categoria,
                        onTap: () => setState(() => _categoria = categoria),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: EcoColors.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: EcoColors.primaryContainer),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: EcoColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _descripciones[_categoria]!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: EcoColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pasos recomendados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PasosManejoList(
                      pasos: _pasosPorCategoria[_categoria]!,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: EcoColors.background,
        border: Border(bottom: BorderSide(color: EcoColors.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: EcoColors.onSurface,
            onPressed: () => Navigator.maybePop(context),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.bold,
              color: EcoColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
