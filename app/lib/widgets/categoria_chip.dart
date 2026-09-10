import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';

/// Chip de categoría (Reciclable / Orgánico / Peligroso), usado en WF-15
/// y WF-17. Cuando [selected] es true se muestra relleno; si no,
/// solo con borde.
class CategoriaChip extends StatelessWidget {
  const CategoriaChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? EcoColors.primaryContainer : EcoColors.background,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: const Color(0xFF73796D), width: 1.4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
            color: selected
                ? EcoColors.onPrimaryContainer
                : EcoColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
