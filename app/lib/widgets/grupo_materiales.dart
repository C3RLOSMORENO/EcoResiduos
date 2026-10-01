import 'package:flutter/material.dart';

import '../features/solicitudes/models/material_residuo.dart';
import '../theme/eco_theme.dart';
import 'categoria_chip.dart';

/// Materiales de una categoría para marcar los que recibe un gestor. Lo usan el
/// registro y la pantalla «Materiales que recibo».
class GrupoMateriales extends StatelessWidget {
  const GrupoMateriales({
    super.key,
    required this.categoria,
    required this.materiales,
    required this.elegidos,
    required this.onCambio,
    this.verificados = const {},
  });

  final String categoria;
  final List<MaterialResiduo> materiales;
  final Set<int> elegidos;
  final VoidCallback onCambio;

  /// Estado de los materiales que el gestor ya tiene guardados: true si el
  /// administrador lo verificó. Los demás no muestran estado.
  final Map<int, bool> verificados;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cantidad = materiales.where((m) => elegidos.contains(m.id)).length;
    final todos = materiales.isNotEmpty && cantidad == materiales.length;

    return Card(
      margin: const EdgeInsets.only(bottom: EcoSpace.s8),
      child: ExpansionTile(
        shape: const Border(),
        leading: CategoriaTile(categoria: categoriaFromString(categoria)),
        title: Text(etiquetaDeCategoria(categoriaFromString(categoria)), style: theme.textTheme.titleSmall),
        subtitle: Text(
          cantidad == 0
              ? 'Toca para elegir materiales'
              : (cantidad == 1 ? '1 material elegido' : '$cantidad materiales elegidos'),
        ),
        children: [
          if (materiales.isEmpty)
            const ListTile(title: Text('Aún no hay materiales en esta categoría.'))
          else ...[
            CheckboxListTile(
              value: todos,
              title: const Text('Todos los de esta categoría'),
              onChanged: (marcar) {
                for (final m in materiales) {
                  marcar == true ? elegidos.add(m.id) : elegidos.remove(m.id);
                }
                onCambio();
              },
            ),
            for (final m in materiales)
              CheckboxListTile(
                value: elegidos.contains(m.id),
                title: Text(m.nombreComun),
                subtitle: _subtitulo(m),
                onChanged: (marcar) {
                  marcar == true ? elegidos.add(m.id) : elegidos.remove(m.id);
                  onCambio();
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget? _subtitulo(MaterialResiduo m) {
    final partes = [
      if (m.subcategoria?.trim().isNotEmpty ?? false) m.subcategoria!.trim(),
      if (verificados.containsKey(m.id)) verificados[m.id]! ? 'Verificado' : 'En verificación',
    ];
    return partes.isEmpty ? null : Text(partes.join(' · '));
  }
}
