import 'package:flutter/material.dart';

import '../models/autoridad_ambiental.dart';
import '../services/directorio_service.dart';
import '../theme/eco_colors.dart';
import '../widgets/entidad_list_tile.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading.dart';
import 'autoridad_detalle_screen.dart';

/// WF-18 — Autoridades ambientales
class AutoridadesAmbientalesScreen extends StatelessWidget {
  const AutoridadesAmbientalesScreen({super.key, this.service});

  final DirectorioService? service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Autoridades ambientales'),
            Expanded(
              child: FutureBuilder<List<AutoridadAmbiental>>(
                future: (service ?? DirectorioService()).autoridades(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList();
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.account_balance_rounded,
                      title: 'Sin autoridades',
                      message: 'No hay autoridades ambientales registradas por el momento.',
                    );
                  }
                  
                  final autoridades = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      const Text(
                        'Entidades en Bucaramanga',
                        style: TextStyle(
                          fontSize: 14,
                          color: EcoColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final autoridad in autoridades) ...[
                        EntidadListTile(
                          inicial: 'A',
                          titulo: autoridad.nombre,
                          subtitulo: autoridad.descripcion,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AutoridadDetalleScreen(
                                autoridad: autoridad,
                              ),
                            ),
                          ),
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
