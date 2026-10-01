import 'package:flutter/material.dart';

import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../features/solicitudes/screens/mis_materiales_screen.dart';
import '../theme/eco_theme.dart';
import 'categoria_chip.dart';
import 'empty_state_widget.dart';

/// Estado 07d / 29f: el gestor declaró materiales que el administrador aún no
/// aprueba, así que todavía no ve solicitudes.
class MaterialesEnVerificacion extends StatelessWidget {
  const MaterialesEnVerificacion({super.key, required this.estado, this.onMaterialesCambiados, this.repository});

  final EstadoMaterialesGestor estado;

  /// Se llama al volver de «Materiales que recibo» si el gestor guardó cambios.
  final VoidCallback? onMaterialesCambiados;
  final SolicitudesRepository? repository;

  Future<void> _editar(BuildContext context) async {
    final guardo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MisMaterialesScreen(repository: repository)),
    );
    if (guardo == true) onMaterialesCambiados?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (estado.sinDeclarar) {
      return EmptyStateWidget(
        icon: Icons.inventory_2_outlined,
        title: 'Aún no tienes materiales registrados',
        description:
            'Elige los materiales que tu licencia te permite recibir. Cuando el administrador los apruebe, aquí '
            'verás las solicitudes.',
        ctaText: 'Elegir materiales',
        ctaIcon: Icons.recycling,
        onCtaPressed: () => _editar(context),
      );
    }
    return EmptyStateWidget(
      icon: Icons.hourglass_top,
      title: 'Tus materiales están en verificación',
      description:
          'El administrador de EcoResiduos está revisando los materiales que declaraste. '
          'Cuando los apruebe, aquí verás las solicitudes de esos materiales.',
      ctaText: 'Editar materiales',
      ctaIcon: Icons.edit_outlined,
      onCtaPressed: () => _editar(context),
      child: Column(
        children: [
          Text('Declaraste', style: theme.textTheme.labelMedium),
          const SizedBox(height: EcoSpace.s8),
          Wrap(
            spacing: EcoSpace.s8,
            runSpacing: EcoSpace.s8,
            alignment: WrapAlignment.center,
            children: [for (final c in estado.categoriasDeclaradas) CategoriaChip.fromString(c)],
          ),
          const SizedBox(height: EcoSpace.s16),
          Text(
            'Te avisaremos con una notificación.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
