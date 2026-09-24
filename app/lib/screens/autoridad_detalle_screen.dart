import 'package:flutter/material.dart';

import '../models/autoridad_ambiental.dart';
import '../theme/eco_theme.dart';
import '../widgets/ficha_contacto.dart';

/// Ficha de autoridad ambiental (17): la plantilla de contacto del gestor,
/// sin materiales y con el banner en el tono secondary.
class AutoridadDetalleScreen extends StatelessWidget {
  const AutoridadDetalleScreen({super.key, required this.autoridad});

  final AutoridadAmbiental autoridad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FichaContacto(
      nombre: autoridad.nombre,
      subtitulo: ['Autoridad ambiental', ?autoridad.sigla].join(' · '),
      avatarTexto: autoridad.sigla,
      secundaria: true,
      direccion: autoridad.direccion,
      telefono: autoridad.telefono,
      correo: autoridad.email,
      horario: autoridad.horario,
      contenido: [
        if (autoridad.jurisdiccion.isNotEmpty) ...[
          Text('Jurisdicción', style: theme.textTheme.titleMedium),
          const SizedBox(height: EcoSpace.s4),
          Text(autoridad.jurisdiccion, style: theme.textTheme.bodyLarge),
          const SizedBox(height: EcoSpace.s8),
        ],
      ],
    );
  }
}
