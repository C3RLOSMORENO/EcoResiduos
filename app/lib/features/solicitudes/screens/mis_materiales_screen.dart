import 'package:flutter/material.dart';

import '../../../data/guia_categorias.dart';
import '../../../theme/eco_theme.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/grupo_materiales.dart';
import '../models/material_residuo.dart';
import '../repositories/solicitudes_repository.dart';

/// El gestor elige qué materiales recibe. Los que agrega quedan en verificación
/// hasta que el administrador los aprueba; los que quita dejan de mostrarle
/// solicitudes de inmediato.
///
/// Devuelve `true` al cerrar si guardó cambios.
class MisMaterialesScreen extends StatefulWidget {
  const MisMaterialesScreen({super.key, this.repository});

  final SolicitudesRepository? repository;

  @override
  State<MisMaterialesScreen> createState() => _MisMaterialesScreenState();
}

class _MisMaterialesScreenState extends State<MisMaterialesScreen> {
  late final SolicitudesRepository _repository = widget.repository ?? SupabaseSolicitudesRepository();
  late Future<List<MaterialResiduo>> _catalogo = _cargar();

  Map<int, bool> _guardados = const {};
  final _elegidos = <int>{};
  bool _guardando = false;
  String? _error;

  Future<List<MaterialResiduo>> _cargar() async {
    final resultados = await Future.wait([_repository.getMateriales(), _repository.getMisMateriales()]);
    _guardados = resultados[1] as Map<int, bool>;
    _elegidos
      ..clear()
      ..addAll(_guardados.keys);
    return resultados[0] as List<MaterialResiduo>;
  }

  bool get _hayCambios => _elegidos.length != _guardados.length || !_elegidos.every(_guardados.containsKey);

  Future<void> _guardar() async {
    if (_elegidos.isEmpty) {
      setState(() => _error = 'Elige al menos un material que tu licencia te permita recibir.');
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final nuevos = await _repository.guardarMisMateriales(_elegidos.toList());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nuevos == 0
                ? 'Guardamos tus materiales.'
                : 'Guardamos tus materiales. Los nuevos quedan en verificación hasta que el administrador los apruebe.',
          ),
        ),
      );
      navigator.pop(true);
    } catch (e) {
      debugPrint('No se pudieron guardar los materiales: $e');
      if (mounted) setState(() => _error = 'No pudimos guardar tus materiales. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Materiales que recibo')),
      body: FutureBuilder<List<MaterialResiduo>>(
        future: _catalogo,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyStateWidget.error(
              title: 'No pudimos cargar los materiales',
              onRetry: () => setState(() => _catalogo = _cargar()),
            );
          }
          final catalogo = snapshot.data;
          if (catalogo == null) return const Center(child: CircularProgressIndicator());

          return ListView(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
            children: [
              Text(
                'Marca los materiales que tu licencia te permite recibir. Los nuevos los verifica el administrador '
                'de EcoResiduos antes de mostrarte solicitudes.',
                style: theme.textTheme.bodyLarge,
              ),
              if (_error != null) ...[
                const SizedBox(height: EcoSpace.s16),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: EcoSpace.s16),
              for (final categoria in categoriasPublicables.keys)
                GrupoMateriales(
                  categoria: categoria,
                  materiales: catalogo.where((m) => m.categoria.toUpperCase() == categoria).toList(),
                  elegidos: _elegidos,
                  verificados: _guardados,
                  onCambio: () => setState(() => _error = null),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: BotonFijoInferior(
        textoBoton: 'Guardar materiales',
        iconoBoton: Icons.save_outlined,
        isLoading: _guardando,
        textoLoading: 'Guardando…',
        onPressed: _hayCambios ? _guardar : null,
      ),
    );
  }
}
