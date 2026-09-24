import 'package:flutter/material.dart';

import '../data/guia_categorias.dart';
import '../features/solicitudes/models/material_residuo.dart';
import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../features/solicitudes/screens/publicar_residuo_screen.dart';
import '../models/gestor.dart';
import '../repositories/gestores_repository.dart';
import '../theme/eco_theme.dart';
import '../utils/sesion.dart';
import '../widgets/boton_fijo_inferior.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/gestor_card.dart';
import 'gestor_detalle_screen.dart';
import 'gestores_asociados_screen.dart';
import 'manejo_residuo_screen.dart';

/// Ficha de un material (11): qué es, su riesgo, quién lo recibe cerca y
/// la acción principal fija abajo.
class InformacionResiduoScreen extends StatelessWidget {
  const InformacionResiduoScreen({super.key, required this.material, this.repository, this.gestoresRepository});

  final MaterialResiduo material;
  final SolicitudesRepository? repository;
  final GestoresRepository? gestoresRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoria = categoriaFromString(material.categoria);
    final colores = theme.extension<EcoColores>() ?? ecoColoresLight;
    final color = colores.categoria(categoria);
    final guia = guiasPorCategoria[categoria]!;
    final puedePublicar = !SesionUsuario.actual().esGestor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(pinned: true, backgroundColor: color.color, foregroundColor: color.onColor),
          SliverToBoxAdapter(
            child: CustomPaint(
              painter: categoria == Categoria.riesgoBiologico
                  ? FranjasAlertaPainter(fondo: color.color, franja: color.onColor)
                  : null,
              child: Container(
                color: categoria == Categoria.riesgoBiologico ? null : color.color,
                padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s4, EcoSpace.s16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoriaIcon(categoria: categoria, size: 20, color: color.onColor),
                        const SizedBox(width: EcoSpace.s8),
                        Flexible(
                          child: Text(
                            etiquetaDeCategoria(categoria),
                            style: theme.textTheme.labelLarge?.copyWith(color: color.onColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: EcoSpace.s8),
                    Text(material.nombreComun, style: theme.textTheme.headlineLarge?.copyWith(color: color.onColor)),
                    if (material.subcategoria?.trim().isNotEmpty ?? false)
                      Text(
                        material.subcategoria!.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(color: color.onColor),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s16, EcoSpace.s16, EcoSpace.s24),
            sliver: SliverList.list(
              children: [
                if (material.tieneAdvertencia) ...[
                  AvisoAdvertencia(texto: material.advertenciaManejo!),
                  const SizedBox(height: EcoSpace.s16),
                ],
                Text('Qué es', style: theme.textTheme.titleMedium),
                const SizedBox(height: EcoSpace.s4),
                Text(
                  material.descripcion?.trim().isNotEmpty ?? false ? material.descripcion!.trim() : guia.queEs,
                  style: theme.textTheme.bodyLarge,
                ),
                if (material.descripcion?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: EcoSpace.s8),
                  Text(guia.queEs, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                const SizedBox(height: EcoSpace.s16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ManejoResiduoScreen(material: material)),
                  ),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Ver manejo seguro'),
                ),
                const SizedBox(height: EcoSpace.s24),
                GestoresCercanos(
                  categoria: material.categoria,
                  materialResaltado: material.nombreComun,
                  repository: gestoresRepository,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: puedePublicar && categoriasPublicables.containsKey(material.categoria.toUpperCase())
          ? BotonFijoInferior(
              textoBoton: 'Publicar para recolección',
              iconoBoton: Icons.upload,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicarResiduoScreen(repository: repository, categoriaSugerida: material.categoria),
                ),
              ),
            )
          : null,
    );
  }
}

/// Carrusel «Quién lo recibe cerca» (11, 22): hasta 10 gestores de la
/// categoría, del más cercano al más lejano.
class GestoresCercanos extends StatefulWidget {
  const GestoresCercanos({super.key, required this.categoria, this.materialResaltado, this.repository});

  final String categoria;
  final String? materialResaltado;
  final GestoresRepository? repository;

  @override
  State<GestoresCercanos> createState() => _GestoresCercanosState();
}

class _GestoresCercanosState extends State<GestoresCercanos> {
  late final GestoresRepository _repository = widget.repository ?? SupabaseGestoresRepository();
  late Future<List<Gestor>> _gestores = _repository.getGestoresPorCategoria(widget.categoria);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Gestor>>(
      future: _gestores,
      builder: (context, snapshot) {
        final gestores = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Quién lo recibe cerca', style: theme.textTheme.titleMedium)),
                if (gestores != null && gestores.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GestoresAsociadosScreen())),
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            const SizedBox(height: EcoSpace.s8),
            if (snapshot.hasError)
              _MensajeCarrusel(
                texto: 'No pudimos cargar los gestores. Revisa tu conexión.',
                accion: 'Reintentar',
                onAccion: () => setState(() {
                  _gestores = _repository.getGestoresPorCategoria(widget.categoria);
                }),
              )
            else if (gestores == null)
              const LinearProgressIndicator()
            else if (gestores.isEmpty)
              _MensajeCarrusel(
                texto: 'Aún no hay gestores certificados en la app que reciban este material.',
                accion: 'Ver autoridades',
                onAccion: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GestoresAsociadosScreen(segmentoInicial: 1)),
                ),
              )
            else
              SizedBox(
                height: alturaCarruselGestores(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gestores.length,
                  separatorBuilder: (_, _) => const SizedBox(width: EcoSpace.s12),
                  itemBuilder: (_, i) => SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 280 : 232,
                    child: GestorCard(
                      gestor: gestores[i],
                      compacta: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GestorDetalleScreen(
                            gestor: gestores[i],
                            materialResaltado: widget.materialResaltado,
                            categoriaResaltada: widget.categoria,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MensajeCarrusel extends StatelessWidget {
  const _MensajeCarrusel({required this.texto, required this.accion, required this.onAccion});

  final String texto;
  final String accion;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(EcoSpace.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(EcoRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: theme.textTheme.bodyMedium),
          TextButton(onPressed: onAccion, child: Text(accion)),
        ],
      ),
    );
  }
}
