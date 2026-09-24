import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/eco_theme.dart';
import '../widgets/empty_state_widget.dart';
import 'flujo_identificacion.dart';
import 'residuos_screen.dart';

/// Cámara desactivada (19): abrir ajustes, usar la galería (no necesita
/// permiso de cámara) o buscar por nombre. Nunca queda sin salida.
class PermisoRechazadoScreen extends StatefulWidget {
  const PermisoRechazadoScreen({super.key});

  @override
  State<PermisoRechazadoScreen> createState() => _PermisoRechazadoScreenState();
}

class _PermisoRechazadoScreenState extends State<PermisoRechazadoScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes se revisa el permiso otra vez.
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    if (await Permission.camera.isGranted && mounted) {
      abrirIdentificacion(context, reemplazarActual: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: EstadoDesplazable(
        child: Column(
          children: [
            const EmptyStateWidget(
              icon: Icons.no_photography_outlined,
              title: 'La cámara está desactivada',
              description: 'Para identificar con foto, permite el acceso a la cámara en los ajustes del teléfono.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Abrir ajustes'),
                  ),
                  const SizedBox(height: EcoSpace.s8),
                  OutlinedButton.icon(
                    onPressed: () => identificarDesdeGaleria(context, reemplazar: true),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Elegir de la galería'),
                  ),
                  const SizedBox(height: EcoSpace.s4),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResiduosScreen())),
                    child: const Text('Buscar por nombre'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
