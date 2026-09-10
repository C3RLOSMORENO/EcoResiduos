import 'package:flutter/material.dart';

import '../models/autoridad_ambiental.dart';
import '../widgets/contacto_detalle_screen.dart';

/// WF-19 — Detalle de autoridad
class AutoridadDetalleScreen extends StatelessWidget {
  const AutoridadDetalleScreen({
    super.key,
    required this.autoridad,
    this.onLlamar,
    this.onComoLlegar,
  });

  final AutoridadAmbiental autoridad;
  final VoidCallback? onLlamar;
  final VoidCallback? onComoLlegar;

  @override
  Widget build(BuildContext context) {
    return ContactoDetalleScreen(
      inicial: 'A',
      nombre: autoridad.nombre,
      etiqueta: autoridad.descripcion,
      direccion: autoridad.direccion,
      telefono: autoridad.telefono,
      correo: autoridad.correo,
      horario: autoridad.sitioWeb,
      // TODO: usar url_launcher para tel:/geo: cuando se integre.
      onLlamar: onLlamar,
      onComoLlegar: onComoLlegar,
    );
  }
}
