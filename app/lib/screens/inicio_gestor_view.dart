import 'package:flutter/material.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../models/postulacion_recoleccion.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/sesion.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/eco_top_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/materiales_en_verificacion.dart';
import '../widgets/tarjeta_siguiente_paso.dart';
import 'navegacion_principal.dart';

/// Inicio del gestor (07). Sin FAB: su acción siempre es sobre una solicitud.
class InicioGestorView extends StatefulWidget {
  const InicioGestorView({super.key, required this.repository});

  final SolicitudesRepository repository;

  @override
  State<InicioGestorView> createState() => _InicioGestorViewState();
}

class _InicioGestorViewState extends State<InicioGestorView> {
  late Future<_ResumenGestor> _resumen = _cargar();

  Future<_ResumenGestor> _cargar() async {
    final materiales = await widget.repository.getEstadoMaterialesGestor();
    if (!materiales.verificado) return _ResumenGestor(materiales, const [], const []);

    final resultados = await Future.wait([
      widget.repository.getSolicitudesDisponibles(),
      widget.repository.getMisPostulaciones(),
    ]);
    return _ResumenGestor(
      materiales,
      resultados[0] as List<SolicitudRecoleccion>,
      resultados[1] as List<PostulacionRecoleccion>,
    );
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() => _resumen = futuro);
    await futuro;
  }

  void _irA(int pestana) => NavegacionPrincipal.of(context)?.irA(pestana);

  @override
  Widget build(BuildContext context) {
    final sesion = SesionUsuario.actual();
    return Scaffold(
      appBar: EcoTopAppBar(
        titulo: sesion.nombreSaludo.isEmpty ? 'Hola' : 'Hola, ${sesion.nombreSaludo}',
        subtitulo: [if (sesion.municipio != null) sesion.municipio!, 'Gestor certificado'].join(' · '),
      ),
      body: FutureBuilder<_ResumenGestor>(
        future: _resumen,
        builder: (context, snapshot) {
          if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
            return EstadoDesplazable(
              child: EmptyStateWidget.error(title: 'No pudimos cargar tu resumen', onRetry: _recargar),
            );
          }
          if (!snapshot.hasData) return const InicioSkeleton();
          final resumen = snapshot.data!;
          if (!resumen.materiales.verificado) {
            return RefreshIndicator(
              onRefresh: _recargar,
              child: EstadoDesplazable(child: MaterialesEnVerificacion(estado: resumen.materiales)),
            );
          }
          return RefreshIndicator(onRefresh: _recargar, child: _contenido(resumen));
        },
      ),
    );
  }

  Widget _contenido(_ResumenGestor resumen) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final aceptada = resumen.aceptadaPorCoordinar;
    final disponibles = resumen.disponibles.length;
    final bloques = <Widget>[];
    final totalPendientes = (aceptada != null ? 1 : 0) + (disponibles > 0 ? 1 : 0);

    if (aceptada != null) {
      final s = aceptada.solicitud!;
      bloques.add(
        TarjetaSiguientePaso(
          contador: totalPendientes > 1 ? '1 DE $totalPendientes' : null,
          chip: CategoriaChip.fromString(s.material?.categoria),
          titulo: 'Te aceptaron la recolección de ${_material(s)}',
          detalle: [
            formatoCantidad(s.cantidadEstimada, s.unidadMedida),
            if (s.municipio.isNotEmpty) s.municipio,
            if (s.updatedAt != null) 'aceptada ${tiempoRelativo(s.updatedAt)}',
          ].join(' · '),
          accion: 'Coordinar recolección',
          onAccion: () => _irA(Pestana.postulaciones),
        ),
      );
      if (disponibles > 0) {
        bloques.add(
          FilaDespues(
            icono: Icons.inventory_2_outlined,
            texto: disponibles == 1
                ? '1 solicitud nueva de materiales que recibes'
                : '$disponibles solicitudes nuevas de materiales que recibes',
            onTap: () => _irA(Pestana.solicitudes),
          ),
        );
      }
    } else if (disponibles > 0) {
      bloques.add(
        TarjetaSiguientePaso(
          titulo: disponibles == 1
              ? 'Hay 1 solicitud de tus materiales'
              : 'Hay $disponibles solicitudes de tus materiales',
          detalle: resumen.materiales.categoriasDeclaradas.map(etiquetaCategoria).join(', '),
          accion: 'Ver solicitudes',
          onAccion: () => _irA(Pestana.solicitudes),
        ),
      );
    } else {
      bloques.add(
        const TarjetaSiguientePaso(
          encabezado: 'TODO AL DÍA',
          icono: Icons.task_alt,
          titulo: 'Todo al día',
          detalle: 'No hay solicitudes nuevas de tus materiales. Te avisamos cuando se publique una.',
        ),
      );
    }

    bloques.add(
      FranjaCifras(
        cifras: [
          Cifra(
            valor: disponibles,
            etiqueta: 'Disponibles',
            icono: Icons.inventory_2_outlined,
            color: colores.estado(EstadoSolicitud.publicado).color,
          ),
          Cifra(
            valor: resumen.postulaciones.where((p) => p.esPropuesta).length,
            etiqueta: 'Postuladas',
            icono: Icons.schedule,
            color: colores.estado(EstadoSolicitud.propuesta).color,
          ),
          Cifra(
            valor: resumen.completadas,
            etiqueta: 'Completadas',
            icono: Icons.local_shipping_outlined,
            color: colores.estado(EstadoSolicitud.recolectado).color,
          ),
        ],
      ),
    );

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
      itemCount: bloques.length,
      separatorBuilder: (_, _) => const SizedBox(height: EcoSpace.s12),
      itemBuilder: (_, i) => bloques[i],
    );
  }

  static String _material(SolicitudRecoleccion s) => minusculaInicial(s.material?.nombreComun ?? 'un residuo');
}

class _ResumenGestor {
  const _ResumenGestor(this.materiales, this.disponibles, this.postulaciones);

  final EstadoMaterialesGestor materiales;
  final List<SolicitudRecoleccion> disponibles;
  final List<PostulacionRecoleccion> postulaciones;

  /// La aceptación más reciente que el gestor todavía no marca como recolectada.
  PostulacionRecoleccion? get aceptadaPorCoordinar {
    for (final p in postulaciones) {
      if (p.esAceptada && p.solicitud?.estado == 'EN_NEGOCIACION') return p;
    }
    return null;
  }

  int get completadas => postulaciones.where((p) => p.esAceptada && p.solicitud?.estado == 'RECOLECTADO').length;
}
