import 'package:flutter/material.dart';

/// Chip de filtro que abre un menú de opciones; «Todos» quita el filtro.
class ChipMenu extends StatelessWidget {
  const ChipMenu({
    super.key,
    required this.etiqueta,
    required this.activo,
    required this.opciones,
    required this.onElegir,
  });

  final String etiqueta;
  final bool activo;

  /// Valor → texto visible.
  final Map<String, String> opciones;
  final ValueChanged<String?> onElegir;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (_, controller, _) => FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(etiqueta), const Icon(Icons.arrow_drop_down, size: 18)],
        ),
        selected: activo,
        onSelected: (_) => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        if (activo) MenuItemButton(onPressed: () => onElegir(null), child: const Text('Todos')),
        for (final e in opciones.entries) MenuItemButton(onPressed: () => onElegir(e.key), child: Text(e.value)),
      ],
    );
  }
}
