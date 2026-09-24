import 'package:flutter/material.dart';

import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../features/solicitudes/screens/mis_postulaciones_screen.dart';
import '../features/solicitudes/screens/mis_publicaciones_screen.dart';
import '../features/solicitudes/screens/solicitudes_disponibles_screen.dart';
import 'flujo_identificacion.dart';
import 'gestores_asociados_screen.dart';
import 'inicio_generador_view.dart';
import 'inicio_gestor_view.dart';
import 'navegacion_principal.dart';
import 'residuos_screen.dart';
import 'splash_screen.dart';

/// Estructura principal tras iniciar sesión.
///
/// Generador: Inicio · Residuos · Gestores · Actividad, con «Identificar»
/// como FAB en Inicio y Residuos. Gestor: Inicio · Solicitudes ·
/// Postulaciones · Directorio, sin FAB.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, this.rol, this.repository});

  /// Rol conocido de antemano ('GENERADOR' o 'GESTOR'); si se omite, se consulta.
  final String? rol;
  final SolicitudesRepository? repository;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  late final SolicitudesRepository _repository;
  String? _rol;
  int _indice = Pestana.inicio;

  /// Solo se construye la pestaña activa, y cada visita la crea de nuevo para
  /// que muestre datos al día (p. ej. tras publicar o aceptar una postulación).
  final _visitas = List<int>.filled(4, 0);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseSolicitudesRepository();
    _rol = widget.rol?.toUpperCase();
    if (_rol == null) _cargarRol();
  }

  Future<void> _cargarRol() async {
    String rol;
    try {
      rol = await _repository.getRolUsuario();
    } catch (e) {
      debugPrint('No se pudo determinar el rol: $e');
      rol = 'GENERADOR';
    }
    if (mounted) setState(() => _rol = rol.toUpperCase());
  }

  void _irA(int indice) {
    setState(() {
      if (indice != _indice) _visitas[indice]++;
      _indice = indice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rol = _rol;
    if (rol == null) return const SplashScreen();

    final esGestor = rol == 'GESTOR';
    final pestanas = esGestor ? _pestanasGestor() : _pestanasGenerador();
    final conIdentificar = !esGestor && (_indice == Pestana.inicio || _indice == Pestana.residuos);

    return NavegacionPrincipal(
      irA: _irA,
      child: Scaffold(
        body: KeyedSubtree(key: ValueKey('$_indice-${_visitas[_indice]}'), child: pestanas[_indice]),
        floatingActionButton: conIdentificar
            ? FloatingActionButton.extended(
                heroTag: 'identificar',
                onPressed: () => abrirIdentificacion(context),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Identificar'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: _irA,
          destinations: esGestor ? _destinosGestor : _destinosGenerador,
        ),
      ),
    );
  }

  List<Widget> _pestanasGenerador() => [
    InicioGeneradorView(repository: _repository),
    ResiduosScreen(repository: _repository),
    const GestoresAsociadosScreen(),
    MisPublicacionesScreen(repository: _repository),
  ];

  List<Widget> _pestanasGestor() => [
    InicioGestorView(repository: _repository),
    SolicitudesDisponiblesScreen(repository: _repository),
    MisPostulacionesScreen(repository: _repository),
    const GestoresAsociadosScreen(incluirResiduos: true),
  ];

  static const _destinosGenerador = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
    NavigationDestination(icon: Icon(Icons.manage_search), label: 'Residuos'),
    NavigationDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: 'Gestores'),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Actividad',
    ),
  ];

  static const _destinosGestor = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Solicitudes',
    ),
    NavigationDestination(
      icon: Icon(Icons.assignment_turned_in_outlined),
      selectedIcon: Icon(Icons.assignment_turned_in),
      label: 'Postulaciones',
    ),
    NavigationDestination(
      icon: Icon(Icons.import_contacts_outlined),
      selectedIcon: Icon(Icons.import_contacts),
      label: 'Directorio',
    ),
  ];
}
