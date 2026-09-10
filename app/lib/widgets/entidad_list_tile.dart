import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';

/// Fila de lista con avatar (inicial o ícono), título y subtítulo —
/// usada por WF-09, WF-15, WF-16 y WF-18.
class EntidadListTile extends StatelessWidget {
  const EntidadListTile({
    super.key,
    this.inicial,
    this.icono,
    required this.titulo,
    required this.subtitulo,
    this.onTap,
  }) : assert(
         inicial != null || icono != null,
         'Provee inicial o icono',
       );

  final String? inicial;
  final IconData? icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EcoColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EcoColors.outline, width: 1.4),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: EcoColors.primaryContainer,
                child: icono != null
                    ? Icon(
                        icono,
                        size: 18,
                        color: EcoColors.onPrimaryContainer,
                      )
                    : Text(
                        inicial!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: EcoColors.onPrimaryContainer,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w500,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: EcoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: EcoColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
