import 'package:flutter/material.dart';

import '../models/gestor.dart';
import '../services/foto_perfil_service.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/ficha_contacto.dart';

/// Ficha de gestor (15). Si se llega desde un residuo, confirma arriba que
/// el gestor lo recibe.
class GestorDetalleScreen extends StatelessWidget {
  const GestorDetalleScreen({super.key, required this.gestor, this.materialResaltado, this.categoriaResaltada});

  final Gestor gestor;
  final String? materialResaltado;
  final String? categoriaResaltada;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colores = theme.extension<EcoColores>() ?? ecoColoresLight;

    return FichaContacto(
      nombre: gestor.nombre,
      subtitulo: ['Gestor certificado', if (gestor.nit.isNotEmpty) 'NIT ${gestor.nit}'].join(' · '),
      coloresFranja: [for (final c in gestor.categorias) colores.categoria(categoriaFromString(c)).color],
      direccion: gestor.direccion,
      municipio: capitalizar(gestor.municipio),
      telefono: gestor.telefono,
      correo: gestor.correo,
      horario: gestor.horario,
      latitud: gestor.latitud,
      longitud: gestor.longitud,
      fotoUrl: FotoPerfilService.url(gestor.fotoPerfilPath),
      portadaUrl: FotoPerfilService.url(gestor.portadaPath),
      contenido: [
        if (materialResaltado != null && categoriaResaltada != null) ...[
          Container(
            padding: const EdgeInsets.all(EcoSpace.s12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(EcoRadius.medium),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: scheme.onPrimaryContainer),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recibe tu residuo',
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      Text(
                        '$materialResaltado · ${etiquetaCategoria(categoriaResaltada)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: EcoSpace.s16),
        ],
        if (gestor.categorias.isNotEmpty) ...[
          Text('Materiales que recibe', style: theme.textTheme.titleMedium),
          const SizedBox(height: EcoSpace.s8),
          Wrap(
            spacing: EcoSpace.s8,
            runSpacing: EcoSpace.s8,
            children: [for (final c in gestor.categorias) CategoriaChip.fromString(c)],
          ),
          const SizedBox(height: EcoSpace.s16),
        ],
      ],
    );
  }
}
