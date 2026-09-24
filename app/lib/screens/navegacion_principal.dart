import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Pestañas de la barra inferior, según el rol.
abstract final class Pestana {
  static const inicio = 0;

  static const residuos = 1;
  static const gestores = 2;
  static const actividad = 3;

  static const solicitudes = 1;
  static const postulaciones = 2;
  static const directorio = 3;
}

/// Permite a una pestaña pedir que se muestre otra.
class NavegacionPrincipal extends InheritedWidget {
  const NavegacionPrincipal({super.key, required this.irA, required super.child});

  final ValueChanged<int> irA;

  static NavegacionPrincipal? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavegacionPrincipal>();

  @override
  bool updateShouldNotify(NavegacionPrincipal oldWidget) => irA != oldWidget.irA;
}

/// Espacio al final de las listas para que el FAB no tape el último elemento.
const double espacioFab = 96 + EcoSpace.s16;
