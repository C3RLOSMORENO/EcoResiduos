import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';

/// Lista de pasos numerados, reutilizada por WF-08 (Manejo del residuo)
/// y WF-17 (Guía de manejo general).
class PasosManejoList extends StatelessWidget {
  const PasosManejoList({super.key, required this.pasos});

  final List<String> pasos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: EcoColors.primaryContainer,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EcoColors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    pasos[i],
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: EcoColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
