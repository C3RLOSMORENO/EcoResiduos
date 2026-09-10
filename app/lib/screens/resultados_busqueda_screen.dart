import 'package:flutter/material.dart';

import '../models/waste_item.dart';
import '../services/busqueda_service.dart';
import '../theme/eco_colors.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/entidad_list_tile.dart';
import '../widgets/shimmer_loading.dart';
import 'informacion_residuo_screen.dart';
import 'manejo_residuo_screen.dart';

/// WF-16 — Resultados de búsqueda
class ResultadosBusquedaScreen extends StatefulWidget {
  const ResultadosBusquedaScreen({
    super.key,
    required this.query,
    this.service,
  });

  final String query;
  final BusquedaService? service;

  @override
  State<ResultadosBusquedaScreen> createState() =>
      _ResultadosBusquedaScreenState();
}

class _ResultadosBusquedaScreenState extends State<ResultadosBusquedaScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );
  late Future<List<WasteItem>> _resultados;
  late final BusquedaService _service = widget.service ?? BusquedaService();

  @override
  void initState() {
    super.initState();
    _resultados = _service.buscar(widget.query);
  }

  void _buscar(String query) {
    setState(() => _resultados = _service.buscar(query));
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
              child: FutureBuilder<List<WasteItem>>(
                future: _resultados,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList();
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: 'Sin resultados',
                      message: 'No encontramos residuos que coincidan con tu búsqueda.',
                    );
                  }
                  
                  final resultados = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Text(
                        '${resultados.length} resultados',
                        style: const TextStyle(
                          fontSize: 14,
                          color: EcoColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final residuo in resultados) ...[
                        EntidadListTile(
                          inicial: 'R',
                          titulo: residuo.nombre,
                          subtitulo: residuo.categoria,
                          onTap: () => _abrirInformacion(context, residuo),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirInformacion(BuildContext context, WasteItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InformacionResiduoScreen(
          item: item,
          onVerManejo: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManejoResiduoScreen(pasos: item.pasosManejo),
            ),
          ),
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
