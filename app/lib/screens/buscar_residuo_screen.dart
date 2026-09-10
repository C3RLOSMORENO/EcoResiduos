import 'package:flutter/material.dart';

import '../services/busqueda_service.dart';
import '../theme/eco_colors.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/entidad_list_tile.dart';
import 'resultados_busqueda_screen.dart';

/// WF-15 — Buscar residuo
class BuscarResiduoScreen extends StatefulWidget {
  const BuscarResiduoScreen({super.key, this.service});

  final BusquedaService? service;

  @override
  State<BuscarResiduoScreen> createState() => _BuscarResiduoScreenState();
}

class _BuscarResiduoScreenState extends State<BuscarResiduoScreen> {
  final _controller = TextEditingController();
  late final BusquedaService _service = widget.service ?? BusquedaService();

  // Mapeo de etiqueta visual a valor exacto en la BD
  static const _categorias = {
    'Peligroso': 'PELIGROSO',
    'Industrial': 'INDUSTRIAL',
    'RAEE': 'RAEE',
    'Biosanitario': 'BIOSANITARIO',
  };

  void _buscar(String query) {
    if (query.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosBusquedaScreen(
          query: query,
          service: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Buscar residuo'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _controller,
                onSubmitted: _buscar,
                decoration: InputDecoration(
                  hintText: 'Buscar residuo...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: EcoColors.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  const Text(
                    'Categorías',
                    style: TextStyle(
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w500,
                      color: EcoColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in _categorias.entries) ...[
                          CategoriaChip(
                            label: entry.key,
                            selected: false,
                            onTap: () => _buscar(entry.value),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Búsquedas recientes',
                    style: TextStyle(
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w500,
                      color: EcoColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<String>>(
                    future: _service.busquedasRecientes(),
                    builder: (context, snapshot) {
                      final recientes = snapshot.data ?? const [];
                      return Column(
                        children: [
                          for (final termino in recientes) ...[
                            EntidadListTile(
                              icono: Icons.history_rounded,
                              titulo: termino,
                              subtitulo: 'Buscado recientemente',
                              onTap: () => _buscar(termino),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                ],
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
