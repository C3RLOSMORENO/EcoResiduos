import 'package:flutter/material.dart';

import '../features/solicitudes/models/solicitud_recoleccion.dart';
import '../features/solicitudes/repositories/solicitudes_repository.dart';
import '../features/solicitudes/screens/detalle_solicitud_screen.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/sesion.dart';
import '../widgets/categoria_chip.dart';
import '../widgets/eco_top_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/tarjeta_siguiente_paso.dart';
import 'navegacion_principal.dart';

/// Inicio del generador (06): el siguiente paso primero y el resumen después.
class InicioGeneradorView extends StatefulWidget {
  const InicioGeneradorView({super.key, required this.repository});

  final SolicitudesRepository repository;

  @override
  State<InicioGeneradorView> createState() => _InicioGeneradorViewState();
}

class _InicioGeneradorViewState extends State<InicioGeneradorView> {
  late Future<_Resumen> _resumen = _cargar();

  Future<_Resumen> _cargar() async {
    final publicaciones = await widget.repository.getMisPublicaciones();
    final ids = publicaciones.where((s) => s.id != null).map((s) => s.id!).toList();
    final postulaciones = await widget.repository.getResumenPostulaciones(ids);
    return _Resumen(publicaciones, postulaciones);
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() {
      _resumen = futuro;
    });
    await futuro;
  }

  Future<void> _abrirDetalle(SolicitudRecoleccion solicitud) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleSolicitudScreen(solicitud: solicitud, repository: widget.repository, rol: 'GENERADOR'),
      ),
    );
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = SesionUsuario.actual();
    return Scaffold(
      appBar: EcoTopAppBar(
        titulo: sesion.nombreSaludo.isEmpty ? 'Hola' : 'Hola, ${sesion.nombreSaludo}',
        subtitulo: sesion.municipio,
      ),
      body: FutureBuilder<_Resumen>(
        future: _resumen,
        builder: (context, snapshot) {
          if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
            return EstadoDesplazable(
              child: EmptyStateWidget.error(
                title: 'No pudimos cargar tu resumen',
                description:
                    'Revisa tu conexión. Mientras tanto puedes identificar residuos: la cámara funciona sin internet.',
                onRetry: _recargar,
              ),
            );
          }
          if (!snapshot.hasData) return const InicioSkeleton();
          return RefreshIndicator(onRefresh: _recargar, child: _contenido(snapshot.data!));
        },
      ),
    );
  }

  Widget _contenido(_Resumen resumen) {
    final colores = Theme.of(context).extension<EcoColores>() ?? ecoColoresLight;
    final pendientes = resumen.pendientes();
    final bloques = <Widget>[];

    if (resumen.publicaciones.isEmpty) {
      bloques.add(
        const TarjetaSiguientePaso(
          encabezado: 'PRIMER PASO',
          titulo: 'Empieza por tu primer residuo',
          detalle: 'Tómale una foto y te decimos qué es y qué gestor cercano lo recibe. Funciona sin internet.',
          nota: 'Usa «Identificar», abajo a la derecha',
        ),
      );
    } else {
      if (pendientes.isEmpty) {
        final publicados = resumen.contar('PUBLICADO');
        bloques.add(
          TarjetaSiguientePaso(
            encabezado: 'TODO AL DÍA',
            icono: Icons.task_alt,
            titulo: 'Todo al día',
            detalle: publicados > 0
                ? 'Tus $publicados publicaciones siguen visibles para los gestores certificados. '
                      'Te avisamos cuando alguien se postule.'
                : 'No tienes publicaciones activas. Cuando tengas otro residuo, identifícalo o publícalo.',
          ),
        );
      } else {
        final primero = pendientes.first;
        bloques.add(
          TarjetaSiguientePaso(
            contador: pendientes.length > 1 ? '1 DE ${pendientes.length}' : null,
            chip: CategoriaChip.fromString(primero.solicitud.material?.categoria),
            titulo: primero.titulo,
            detalle: primero.detalle,
            accion: primero.accion,
            onAccion: () => _abrirDetalle(primero.solicitud),
          ),
        );
        if (pendientes.length > 1) {
          final segundo = pendientes[1];
          final color = colores.estado(estadoFromString(segundo.solicitud.estado));
          bloques.add(
            FilaDespues(
              icono: segundo.icono,
              texto: segundo.titulo,
              fondoIcono: color.container,
              colorIcono: color.onContainer,
              onTap: () => _abrirDetalle(segundo.solicitud),
            ),
          );
        }
      }
      bloques.add(
        FranjaCifras(
          cifras: [
            Cifra(
              valor: resumen.contar('PUBLICADO'),
              etiqueta: 'Publicados',
              icono: Icons.campaign_outlined,
              color: colores.estado(EstadoSolicitud.publicado).color,
            ),
            Cifra(
              valor: resumen.contar('EN_NEGOCIACION'),
              etiqueta: 'En negociación',
              icono: Icons.handshake_outlined,
              color: colores.estado(EstadoSolicitud.enNegociacion).color,
            ),
            Cifra(
              valor: resumen.contar('RECOLECTADO'),
              etiqueta: 'Completados',
              icono: Icons.local_shipping_outlined,
              color: colores.estado(EstadoSolicitud.recolectado).color,
            ),
          ],
        ),
      );
      bloques.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => NavegacionPrincipal.of(context)?.irA(Pestana.actividad),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Ver toda mi actividad'),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, espacioFab),
      itemCount: bloques.length,
      separatorBuilder: (_, _) => const SizedBox(height: EcoSpace.s12),
      itemBuilder: (_, i) => bloques[i],
    );
  }
}

class _Resumen {
  _Resumen(this.publicaciones, this.postulaciones);

  final List<SolicitudRecoleccion> publicaciones;
  final Map<int, ResumenPostulaciones> postulaciones;

  int contar(String estado) => publicaciones.where((s) => s.estado == estado).length;

  /// Pendientes del generador, del más urgente al menos urgente: confirmar una
  /// recolección, revisar postulaciones y coordinar una recogida.
  List<_Pendiente> pendientes() {
    final lista = <_Pendiente>[];
    for (final s in publicaciones.where((s) => s.pendienteConfirmacion)) {
      final gestor = postulaciones[s.id]?.gestorAceptado;
      lista.add(
        _Pendiente(
          solicitud: s,
          titulo: 'Confirma la recolección de tu ${_material(s)}',
          detalle: '${gestor ?? 'El gestor'} la marcó como recolectada ${tiempoRelativo(s.recolectadoAt)}',
          accion: 'Confirmar recolección',
          icono: Icons.local_shipping_outlined,
        ),
      );
    }
    for (final s in publicaciones.where((s) => s.estado == 'PUBLICADO')) {
      final n = postulaciones[s.id]?.pendientes ?? 0;
      if (n == 0) continue;
      lista.add(
        _Pendiente(
          solicitud: s,
          titulo: n == 1
              ? '1 gestor quiere recoger tu ${_material(s)}'
              : '$n gestores quieren recoger tu ${_material(s)}',
          detalle: '${formatoCantidad(s.cantidadEstimada, s.unidadMedida)} · publicado ${tiempoRelativo(s.createdAt)}',
          accion: 'Revisar postulaciones',
          icono: Icons.campaign_outlined,
        ),
      );
    }
    for (final s in publicaciones.where((s) => s.estado == 'EN_NEGOCIACION')) {
      final gestor = postulaciones[s.id]?.gestorAceptado;
      lista.add(
        _Pendiente(
          solicitud: s,
          titulo: 'Coordina la recogida de tu ${_material(s)}${gestor != null ? ' con $gestor' : ''}',
          detalle: formatoCantidad(s.cantidadEstimada, s.unidadMedida),
          accion: 'Ver detalle',
          icono: Icons.handshake_outlined,
        ),
      );
    }
    return lista;
  }

  static String _material(SolicitudRecoleccion s) => minusculaInicial(s.material?.nombreComun ?? 'residuo');
}

class _Pendiente {
  const _Pendiente({
    required this.solicitud,
    required this.titulo,
    required this.detalle,
    required this.accion,
    required this.icono,
  });

  final SolicitudRecoleccion solicitud;
  final String titulo;
  final String detalle;
  final String accion;
  final IconData icono;
}
