import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';
import '../utils/enlaces.dart';
import 'gestor_card.dart';

/// Plantilla de ficha de contacto (15, 17): banner con volver superpuesto,
/// avatar en etiqueta, filas de contacto tocables y «Llamar / Cómo llegar»
/// fijos abajo. Sin mapa embebido: «Cómo llegar» abre Google Maps.
class FichaContacto extends StatelessWidget {
  const FichaContacto({
    super.key,
    required this.nombre,
    required this.subtitulo,
    this.avatarTexto,
    this.secundaria = false,
    this.coloresFranja = const [],
    this.contenido = const [],
    this.direccion = '',
    this.municipio = '',
    this.telefono = '',
    this.correo = '',
    this.horario,
    this.latitud,
    this.longitud,
  });

  final String nombre;
  final String subtitulo;
  final String? avatarTexto;

  /// Autoridades: banner en el tono secondary y sin materiales.
  final bool secundaria;

  /// Un color por cada categoría que recibe el gestor.
  final List<Color> coloresFranja;

  /// Bloques entre la cabecera y los datos de contacto.
  final List<Widget> contenido;
  final String direccion;
  final String municipio;
  final String telefono;
  final String correo;
  final String? horario;
  final double? latitud;
  final double? longitud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fondoBanner = secundaria ? scheme.secondaryContainer : scheme.primaryContainer;
    final direccionCompleta = [direccion, municipio].where((p) => p.trim().isNotEmpty).join(', ');

    void irAlMapa() =>
        comoLlegar(context, latitud: latitud, longitud: longitud, direccion: direccion, municipio: municipio);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 148 + MediaQuery.paddingOf(context).top,
                  color: fondoBanner,
                  alignment: Alignment.bottomCenter,
                  child: coloresFranja.isEmpty
                      ? null
                      : SizedBox(
                          height: 10,
                          child: Row(
                            children: [for (final c in coloresFranja) Expanded(child: ColoredBox(color: c))],
                          ),
                        ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + EcoSpace.s8,
                  left: EcoSpace.s8,
                  child: IconButton.filled(
                    tooltip: 'Volver',
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned(
                  left: EcoSpace.s16,
                  bottom: -36,
                  child: AvatarEntidad(nombre: nombre, texto: avatarTexto, size: 72, secundario: secundaria),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 48, EcoSpace.s16, EcoSpace.s24),
            sliver: SliverList.list(
              children: [
                Text(nombre, style: theme.textTheme.headlineMedium),
                const SizedBox(height: EcoSpace.s4),
                Text(subtitulo, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: EcoSpace.s16),
                ...contenido,
                if (direccionCompleta.isNotEmpty)
                  _FilaContacto(
                    icono: Icons.location_on_outlined,
                    etiqueta: 'Dirección',
                    valor: direccionCompleta,
                    onTap: irAlMapa,
                  ),
                if (telefono.isNotEmpty)
                  _FilaContacto(
                    icono: Icons.call_outlined,
                    etiqueta: 'Teléfono',
                    valor: telefono,
                    onTap: () => llamar(context, telefono),
                  ),
                if (correo.isNotEmpty)
                  _FilaContacto(
                    icono: Icons.mail_outline,
                    etiqueta: 'Correo',
                    valor: correo,
                    onTap: () => escribirCorreo(context, correo),
                  ),
                if (horario?.isNotEmpty ?? false)
                  _FilaContacto(icono: Icons.schedule, etiqueta: 'Horario', valor: horario!),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: scheme.surfaceContainer,
        padding: EdgeInsets.fromLTRB(
          EcoSpace.s16,
          EcoSpace.s12,
          EcoSpace.s16,
          EcoSpace.s12 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Row(
          children: [
            if (telefono.isNotEmpty) ...[
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () => llamar(context, telefono),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Llamar'),
                ),
              ),
              const SizedBox(width: EcoSpace.s12),
            ],
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: direccionCompleta.isEmpty && latitud == null ? null : irAlMapa,
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Cómo llegar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaContacto extends StatelessWidget {
  const _FilaContacto({required this.icono, required this.etiqueta, required this.valor, this.onTap});

  final IconData icono;
  final String etiqueta;
  final String valor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono),
      title: Text(etiqueta, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: Text(valor, style: theme.textTheme.bodyLarge),
      onTap: onTap,
    );
  }
}
