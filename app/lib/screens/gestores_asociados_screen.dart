import 'package:flutter/material.dart';

import '../models/gestor.dart';
import '../services/directorio_service.dart';
import '../theme/eco_colors.dart';
import '../widgets/entidad_list_tile.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading.dart';
import 'gestor_detalle_screen.dart';

/// WF-09 — Gestores asociados
class GestoresAsociadosScreen extends StatelessWidget {
  const GestoresAsociadosScreen({super.key, this.service});

  final DirectorioService? service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Gestores asociados'),
            Expanded(
              child: FutureBuilder<List<Gestor>>(
                future: (service ?? DirectorioService()).gestores(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList();
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.store_mall_directory_rounded,
                      title: 'Sin gestores cercanos',
                      message: 'No encontramos gestores de residuos en tu zona. ¡Vuelve a intentarlo más tarde!',
                    );
                  }
          
          final gestores = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                '${gestores.length} gestores cerca de ti',
                style: const TextStyle(
                  fontSize: 14,
                  color: EcoColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final gestor in gestores) ...[
                EntidadListTile(
                  inicial: 'M',
                  titulo: gestor.nombre,
                  subtitulo:
                      'A ${gestor.distanciaKm} km — ${gestor.categoria}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GestorDetalleScreen(gestor: gestor),
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
