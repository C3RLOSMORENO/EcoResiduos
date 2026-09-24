import 'package:flutter/material.dart';

import '../../../models/postulacion_recoleccion.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/enlaces.dart';
import '../../../utils/formato.dart';
import '../../../widgets/categoria_chip.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/estado_badge.dart';
import '../../../widgets/linea_tiempo_estado.dart';
import '../../../widgets/solicitud_card.dart';
import '../models/solicitud_recoleccion.dart';
import '../repositories/solicitudes_repository.dart';
import 'publicar_residuo_screen.dart';

/// Detalle de una solicitud. El generador (28) ve la línea de tiempo y decide
/// sobre las postulaciones; el gestor (30) ve los datos y envía su propuesta.
///
/// Devuelve `true` al cerrar si algo cambió, para que la lista se recargue.
class DetalleSolicitudScreen extends StatefulWidget {
  const DetalleSolicitudScreen({
    super.key,
    required this.solicitud,
    this.repository,
    this.rol,
    this.postulacion,
    this.distanciaKm,
  });

  final SolicitudRecoleccion solicitud;
  final SolicitudesRepository? repository;

  /// 'GENERADOR' o 'GESTOR'; si se omite, se consulta.
  final String? rol;

  /// Postulación del gestor ya conocida (desde Mis postulaciones).
  final PostulacionRecoleccion? postulacion;
  final double? distanciaKm;

  @override
  State<DetalleSolicitudScreen> createState() => _DetalleSolicitudScreenState();
}

class _DetalleSolicitudScreenState extends State<DetalleSolicitudScreen> {
  late final SolicitudesRepository _repository;
  late SolicitudRecoleccion _solicitud = widget.solicitud;
  String? _rol;
  bool _cambio = false;
  bool _ocupado = false;

  List<PostulacionRecoleccion>? _postulaciones;
  bool _errorPostulaciones = false;

  PostulacionRecoleccion? _miPostulacion;
  bool _cargandoMiPostulacion = true;
  final _propuesta = TextEditingController();

  bool get _esGestor => _rol == 'GESTOR';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseSolicitudesRepository();
    _miPostulacion = widget.postulacion;
    _rol = widget.rol?.toUpperCase();
    _iniciar();
  }

  @override
  void dispose() {
    _propuesta.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (_rol == null) {
      final rol = await _repository.getRolUsuario().catchError((_) => 'GENERADOR');
      if (!mounted) return;
      setState(() => _rol = rol.toUpperCase());
    }
    _cargarRelacionados();
  }

  Future<void> _cargarRelacionados() async {
    final id = _solicitud.id;
    if (id == null) {
      setState(() => _cargandoMiPostulacion = false);
      return;
    }
    if (_esGestor) {
      try {
        final postulacion = await _repository.getMiPostulacion(id);
        if (mounted) setState(() => _miPostulacion = postulacion ?? _miPostulacion);
      } catch (e) {
        debugPrint('No se pudo consultar la postulación: $e');
      } finally {
        if (mounted) setState(() => _cargandoMiPostulacion = false);
      }
    } else {
      try {
        final postulaciones = await _repository.getPostulacionesDeSolicitud(id);
        if (mounted) {
          setState(() {
            _postulaciones = postulaciones;
            _errorPostulaciones = false;
          });
        }
      } catch (e) {
        debugPrint('No se pudieron cargar las postulaciones: $e');
        if (mounted) setState(() => _errorPostulaciones = true);
      }
    }
  }

  Future<void> _recargarSolicitud() async {
    final id = _solicitud.id;
    if (id == null) return;
    final actual = await _repository.getSolicitud(id);
    if (actual != null && mounted) setState(() => _solicitud = actual);
    await _cargarRelacionados();
  }

  /// Ejecuta una acción que cambia la solicitud, avisa el resultado y recarga.
  Future<void> _ejecutar(Future<void> Function() accion, {required String exito}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);
    try {
      await accion();
      _cambio = true;
      messenger.showSnackBar(SnackBar(content: Text(exito)));
      await _recargarSolicitud();
    } catch (e) {
      debugPrint('Acción sobre la solicitud fallida: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo completar. Inténtalo de nuevo.')));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aceptar(PostulacionRecoleccion p) async {
    final otros = (_postulaciones ?? []).where((o) => o.esPropuesta && o.id != p.id).length;
    final nombre = p.gestorRazonSocial ?? 'este gestor';
    final confirmado = await _confirmar(
      icono: Icons.handshake_outlined,
      titulo: '¿Aceptar a $nombre?',
      texto:
          'Le compartiremos tu teléfono y la dirección para coordinar la recogida.'
          '${otros > 0 ? ' A ${otros == 1 ? 'el otro gestor' : 'los otros $otros gestores'} les avisaremos que la solicitud se asignó a otro gestor.' : ''}',
      accion: 'Aceptar',
    );
    if (!confirmado) return;
    await _ejecutar(
      () => _repository.aceptarPostulacion(solicitudId: _solicitud.id!, postulacionId: p.id!, gestorId: p.gestorId),
      exito: 'Aceptaste a $nombre.',
    );
  }

  Future<void> _rechazar(PostulacionRecoleccion p) async {
    final confirmado = await _confirmar(
      icono: Icons.cancel_outlined,
      titulo: '¿Rechazar esta propuesta?',
      texto: 'Le avisaremos a ${p.gestorRazonSocial ?? 'el gestor'} que descartaste su propuesta.',
      accion: 'Rechazar',
    );
    if (!confirmado) return;
    await _ejecutar(() => _repository.rechazarPostulacion(postulacionId: p.id!), exito: 'Rechazaste la propuesta.');
  }

  Future<void> _cancelar() async {
    final pendientes = (_postulaciones ?? []).where((p) => p.esPropuesta).length;
    final confirmado = await _confirmar(
      icono: Icons.delete_forever_outlined,
      titulo: '¿Cancelar esta publicación?',
      texto: pendientes > 0
          ? 'Los $pendientes gestores que se postularon verán que ya no está disponible. '
                'Puedes volver a publicarla cuando quieras.'
          : 'Los gestores dejarán de verla. Puedes volver a publicarla cuando quieras.',
      accion: 'Cancelar publicación',
      destructiva: true,
    );
    if (!confirmado || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final anterior = _solicitud;
    setState(() => _ocupado = true);
    try {
      await _repository.cancelarSolicitud(anterior.id!);
      _cambio = true;
      setState(() => _solicitud = anterior.copyWith(estado: 'CANCELADO', updatedAt: DateTime.now()));
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Publicación cancelada.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              await _repository.actualizarSolicitud(anterior);
              if (mounted) setState(() => _solicitud = anterior);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo cancelar la solicitud: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo cancelar. Inténtalo de nuevo.')));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PublicarResiduoScreen(solicitudAEditar: _solicitud, repository: _repository),
      ),
    );
    if (guardado == true) {
      _cambio = true;
      await _recargarSolicitud();
    }
  }

  Future<void> _publicarDeNuevo() async {
    final publicado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PublicarResiduoScreen(plantilla: _solicitud, repository: _repository),
      ),
    );
    if (publicado == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmarRecoleccion() => _ejecutar(
    () => _repository.confirmarRecoleccion(solicitudId: _solicitud.id!),
    exito: 'Confirmaste la recolección. ¡Gracias por separar bien tu residuo!',
  );

  Future<void> _reportarProblema() async {
    final detalle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HojaReportarProblema(),
    );
    if (detalle == null) return;
    await _ejecutar(
      () => _repository.reportarProblemaRecoleccion(solicitudId: _solicitud.id!, detalle: detalle),
      exito: 'Enviamos tu reporte. Lo revisaremos con el gestor.',
    );
  }

  Future<void> _postularme() async {
    final texto = _propuesta.text.trim();
    await _ejecutar(
      () => _repository.postularASolicitud(solicitudId: _solicitud.id!, propuesta: texto.isEmpty ? null : texto),
      exito: 'Te postulaste. Te avisamos si te eligen.',
    );
  }

  Future<void> _marcarRecolectado() async {
    final confirmado = await _confirmar(
      icono: Icons.local_shipping_outlined,
      titulo: '¿Ya recogiste este residuo?',
      texto:
          'Le pediremos al generador que lo confirme. Si no responde en 72 h, la recolección se confirma automáticamente.',
      accion: 'Sí, lo recogí',
    );
    if (!confirmado) return;
    await _ejecutar(
      () => _repository.marcarRecolectado(solicitudId: _solicitud.id!),
      exito: 'Marcaste la recolección. Esperamos la confirmación del generador.',
    );
  }

  Future<bool> _confirmar({
    required IconData icono,
    required String titulo,
    required String texto,
    required String accion,
    bool destructiva = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: Icon(icono),
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Volver')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            style: destructiva
                ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                : null,
            child: Text(accion),
          ),
        ],
      ),
    );
    return respuesta == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_rol == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambio);
      },
      child: _esGestor ? _vistaGestor() : _vistaGenerador(),
    );
  }

  Widget _vistaGenerador() {
    final s = _solicitud;
    final puedeEditar = s.estado == 'PUBLICADO';
    final puedeCancelar = s.estado == 'PUBLICADO' || s.estado == 'EN_NEGOCIACION';

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (puedeEditar || puedeCancelar)
            MenuAnchor(
              builder: (_, controller, _) => IconButton(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert),
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              ),
              menuChildren: [
                if (puedeEditar)
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit_outlined),
                    onPressed: _editar,
                    child: const Text('Editar publicación'),
                  ),
                if (puedeCancelar)
                  MenuItemButton(
                    leadingIcon: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
                    onPressed: _cancelar,
                    child: Text('Cancelar publicación', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _recargarSolicitud,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s32),
          children: [
            EstadoBadge.fromString(
              s.estado,
              label: s.pendienteConfirmacion
                  ? 'Recolectado · por confirmar'
                  : (s.tieneProblema ? 'Recolectado · con problema reportado' : null),
            ),
            const SizedBox(height: EcoSpace.s16),
            LineaTiempoEstado(solicitud: s),
            const SizedBox(height: EcoSpace.s24),
            _Resumen(solicitud: s),
            const SizedBox(height: EcoSpace.s24),
            ..._seccionGenerador(),
          ],
        ),
      ),
      bottomNavigationBar: _barraGenerador(),
    );
  }

  List<Widget> _seccionGenerador() {
    final s = _solicitud;
    final theme = Theme.of(context);

    switch (s.estado) {
      case 'CANCELADO':
        return const [
          _Aviso(
            icono: Icons.block,
            titulo: 'Cancelaste esta publicación',
            texto: 'Los gestores ya no la ven. Puedes publicarla de nuevo con los mismos datos.',
          ),
        ];
      case 'RECOLECTADO':
        final gestor = _aceptada?.gestorRazonSocial ?? 'El gestor';
        if (s.tieneProblema) {
          return [
            _Aviso(
              icono: Icons.report_problem_outlined,
              titulo: 'Reportaste un problema',
              texto: '${s.problemaDetalle ?? ''}\nLo estamos revisando con $gestor.'.trim(),
              tono: TonoEstado.error,
            ),
          ];
        }
        if (s.estaConfirmado) {
          return [
            _Aviso(
              icono: Icons.task_alt,
              titulo: 'Recolección confirmada',
              texto:
                  '$gestor la marcó ${s.recolectadoAt != null ? 'el ${fechaCorta(s.recolectadoAt!)}' : ''} '
                  'y quedó confirmada. Gracias por separar bien tu residuo.',
              tono: TonoEstado.exito,
            ),
          ];
        }
        return [
          _Aviso(
            icono: Icons.local_shipping_outlined,
            titulo: '$gestor marcó tu residuo como recolectado',
            texto: '${tiempoRelativo(s.recolectadoAt)}. ¿Lo recogieron?',
          ),
        ];
      case 'EN_NEGOCIACION':
        final aceptada = _aceptada;
        final otros = (_postulaciones ?? []).where((p) => p.esNoSeleccionada).length;
        return [
          Text('Gestor elegido', style: theme.textTheme.titleMedium),
          const SizedBox(height: EcoSpace.s12),
          if (aceptada != null)
            _TarjetaPostulacion(
              postulacion: aceptada,
              pie: Wrap(
                spacing: EcoSpace.s8,
                children: [
                  if (aceptada.gestorTelefono?.isNotEmpty ?? false)
                    FilledButton.tonalIcon(
                      onPressed: () => llamar(context, aceptada.gestorTelefono!),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Llamar'),
                    ),
                ],
              ),
            )
          else if (_postulaciones == null)
            const LinearProgressIndicator(),
          if (otros > 0) ...[
            const SizedBox(height: EcoSpace.s12),
            Text(
              otros == 1
                  ? '1 gestor notificado: asignada a otro gestor'
                  : '$otros gestores notificados: asignada a otro gestor',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ];
      default:
        return _listaPostulaciones();
    }
  }

  PostulacionRecoleccion? get _aceptada {
    for (final p in _postulaciones ?? const <PostulacionRecoleccion>[]) {
      if (p.esAceptada) return p;
    }
    return null;
  }

  List<Widget> _listaPostulaciones() {
    final theme = Theme.of(context);
    if (_errorPostulaciones) {
      return [EmptyStateWidget.error(title: 'No pudimos cargar las postulaciones', onRetry: _cargarRelacionados)];
    }
    final postulaciones = _postulaciones;
    if (postulaciones == null) return const [LinearProgressIndicator()];

    final propuestas = postulaciones.where((p) => p.esPropuesta).toList();
    if (propuestas.isEmpty) {
      return const [
        _Aviso(
          icono: Icons.hourglass_empty,
          titulo: 'Aún no hay postulaciones',
          texto: 'Les avisamos a los gestores certificados que reciben este material. Aquí verás sus propuestas.',
        ),
      ];
    }
    return [
      Text('Postulaciones · ${propuestas.length}', style: theme.textTheme.titleMedium),
      const SizedBox(height: EcoSpace.s12),
      for (final p in propuestas)
        Padding(
          padding: const EdgeInsets.only(bottom: EcoSpace.s12),
          child: _TarjetaPostulacion(
            postulacion: p,
            pie: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _ocupado ? null : () => _rechazar(p), child: const Text('Rechazar')),
                const SizedBox(width: EcoSpace.s8),
                FilledButton.icon(
                  onPressed: _ocupado ? null : () => _aceptar(p),
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar'),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget? _barraGenerador() {
    final s = _solicitud;
    if (s.estado == 'CANCELADO') {
      return _BarraInferior(
        children: [
          FilledButton.icon(
            onPressed: _publicarDeNuevo,
            icon: const Icon(Icons.replay),
            label: const Text('Publicar de nuevo'),
          ),
        ],
      );
    }
    if (s.pendienteConfirmacion) {
      return _BarraInferior(
        nota: 'Si no respondes en 72 h, la confirmamos automáticamente.',
        children: [
          FilledButton.icon(
            onPressed: _ocupado ? null : _confirmarRecoleccion,
            icon: const Icon(Icons.task_alt),
            label: const Text('Sí, confirmar recolección'),
          ),
          TextButton(onPressed: _ocupado ? null : _reportarProblema, child: const Text('Reportar un problema')),
        ],
      );
    }
    return null;
  }

  Widget _vistaGestor() {
    final s = _solicitud;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoria = categoriaFromString(s.material?.categoria);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(EcoSpace.s4),
              child: IconButton.filled(
                tooltip: 'Volver',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: FotoResiduo(
                url: s.fotoUrl,
                categoria: categoria,
                size: double.infinity,
                height: 220,
                radio: 0,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s16, EcoSpace.s16, EcoSpace.s32),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Flexible(child: CategoriaChip(categoria: categoria)),
                    const Spacer(),
                    if (widget.distanciaKm != null)
                      Text(
                        'a ${formatoDistancia(widget.distanciaKm!)}',
                        style: theme.textTheme.headlineSmall?.copyWith(color: scheme.primary),
                      ),
                  ],
                ),
                const SizedBox(height: EcoSpace.s12),
                Text(s.material?.nombreComun ?? 'Residuo', style: theme.textTheme.headlineMedium),
                const SizedBox(height: EcoSpace.s4),
                Text(formatoCantidad(s.cantidadEstimada, s.unidadMedida), style: theme.textTheme.displaySmall),
                const SizedBox(height: EcoSpace.s16),
                _FilaDato(
                  icono: Icons.location_on_outlined,
                  etiqueta: 'Dirección de recolección',
                  valor: [s.direccionRecoleccion, s.municipio].where((p) => p.isNotEmpty).join(', '),
                  accion: TextButton(
                    onPressed: () => comoLlegar(
                      context,
                      latitud: s.latitud,
                      longitud: s.longitud,
                      direccion: s.direccionRecoleccion,
                      municipio: s.municipio,
                    ),
                    child: const Text('Cómo llegar'),
                  ),
                ),
                if (s.descripcion?.trim().isNotEmpty ?? false)
                  _FilaDato(icono: Icons.notes, etiqueta: 'Descripción', valor: s.descripcion!.trim()),
                if (s.createdAt != null)
                  _FilaDato(
                    icono: Icons.schedule,
                    etiqueta: 'Publicado',
                    valor: mayusculaInicial(tiempoRelativo(s.createdAt)),
                  ),
                if (s.material?.tieneAdvertencia ?? false) ...[
                  const SizedBox(height: EcoSpace.s8),
                  AvisoAdvertencia(texto: s.material!.advertenciaManejo ?? ''),
                ],
                const SizedBox(height: EcoSpace.s24),
                ..._seccionGestor(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _barraGestor(),
    );
  }

  List<Widget> _seccionGestor() {
    final theme = Theme.of(context);
    final p = _miPostulacion;
    if (_cargandoMiPostulacion && p == null) return const [LinearProgressIndicator()];

    if (p == null) {
      if (_solicitud.estado != 'PUBLICADO') {
        return const [
          _Aviso(
            icono: Icons.lock_clock_outlined,
            titulo: 'Esta solicitud ya no recibe postulaciones',
            texto: 'El generador ya eligió un gestor o la canceló.',
          ),
        ];
      }
      return [
        Text('Tu propuesta', style: theme.textTheme.titleMedium),
        const SizedBox(height: EcoSpace.s8),
        TextField(
          controller: _propuesta,
          minLines: 4,
          maxLines: 8,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Cuéntale cuándo puedes pasar y cómo lo recoges.',
            helperText: 'El generador la verá al elegir un gestor.',
          ),
        ),
      ];
    }

    if (_solicitud.estado == 'CANCELADO') {
      return const [
        _Aviso(
          icono: Icons.cancel_outlined,
          titulo: 'Publicación cancelada',
          texto: 'El generador canceló esta publicación.',
        ),
      ];
    }

    if (p.esAceptada) {
      final recolectado = _solicitud.estado == 'RECOLECTADO';
      return [
        _Aviso(
          icono: recolectado ? Icons.local_shipping_outlined : Icons.check_circle_outline,
          titulo: recolectado
              ? (_solicitud.estaConfirmado ? 'Recolección confirmada' : 'Recolectado · por confirmar')
              : 'Te eligieron para esta recolección',
          texto: recolectado
              ? (_solicitud.estaConfirmado
                    ? 'El generador confirmó la recolección.'
                    : 'Le pedimos al generador que confirme. Si reporta un problema, te avisaremos para resolverlo.')
              : 'Coordina la recogida con el generador.',
          tono: TonoEstado.exito,
        ),
        if (!recolectado && _solicitud.telefono.isNotEmpty)
          _FilaDato(icono: Icons.call_outlined, etiqueta: 'Teléfono del generador', valor: _solicitud.telefono),
      ];
    }

    if (p.esPropuesta) {
      return [
        Text('Tu propuesta', style: theme.textTheme.titleMedium),
        const SizedBox(height: EcoSpace.s8),
        _Aviso(
          icono: Icons.schedule,
          titulo: 'Propuesta enviada',
          texto: p.propuesta?.trim().isNotEmpty ?? false ? p.propuesta!.trim() : 'Sin mensaje.',
        ),
      ];
    }

    return [
      _Aviso(
        icono: p.esNoSeleccionada ? Icons.assignment_ind_outlined : Icons.cancel_outlined,
        titulo: p.esNoSeleccionada ? 'Asignada a otro gestor' : 'Rechazada',
        texto: p.esNoSeleccionada ? 'El generador eligió a otro gestor.' : 'El generador descartó tu propuesta.',
      ),
    ];
  }

  Widget? _barraGestor() {
    final p = _miPostulacion;
    if (_cargandoMiPostulacion && p == null) return null;

    if (p == null && _solicitud.estado == 'PUBLICADO') {
      return _BarraInferior(
        children: [
          FilledButton.icon(
            onPressed: _ocupado ? null : _postularme,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Postularme para recolección'),
          ),
        ],
      );
    }
    if (p != null && p.esPropuesta) {
      return const _BarraInferior(children: [FilledButton(onPressed: null, child: Text('Ya te postulaste'))]);
    }
    if (p != null && p.esAceptada && _solicitud.estado == 'EN_NEGOCIACION') {
      return _BarraInferior(
        children: [
          FilledButton.icon(
            onPressed: _ocupado ? null : _marcarRecolectado,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Marcar recolectado'),
          ),
          if (_solicitud.telefono.isNotEmpty)
            TextButton.icon(
              onPressed: () => llamar(context, _solicitud.telefono),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Llamar al generador'),
            ),
        ],
      );
    }
    return null;
  }
}

/// Foto, categoría, material, cantidad y datos de la solicitud (vista del generador).
class _Resumen extends StatelessWidget {
  const _Resumen({required this.solicitud});

  final SolicitudRecoleccion solicitud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = solicitud;
    final categoria = categoriaFromString(s.material?.categoria);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FotoResiduo(url: s.fotoUrl, categoria: categoria, size: double.infinity, height: 180, radio: EcoRadius.medium),
        const SizedBox(height: EcoSpace.s16),
        CategoriaChip(categoria: categoria),
        const SizedBox(height: EcoSpace.s8),
        Text(s.material?.nombreComun ?? 'Residuo', style: theme.textTheme.headlineMedium),
        const SizedBox(height: EcoSpace.s4),
        Text(formatoCantidad(s.cantidadEstimada, s.unidadMedida), style: theme.textTheme.displaySmall),
        const SizedBox(height: EcoSpace.s16),
        _FilaDato(
          icono: Icons.location_on_outlined,
          etiqueta: 'Dirección de recolección',
          valor: [s.direccionRecoleccion, s.municipio].where((p) => p.isNotEmpty).join(', '),
        ),
        if (s.descripcion?.trim().isNotEmpty ?? false)
          _FilaDato(icono: Icons.notes, etiqueta: 'Descripción', valor: s.descripcion!.trim()),
        if (s.material?.tieneAdvertencia ?? false) ...[
          const SizedBox(height: EcoSpace.s8),
          AvisoAdvertencia(texto: s.material!.advertenciaManejo ?? ''),
        ],
      ],
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.etiqueta, required this.valor, this.accion});

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EcoSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: scheme.onSurfaceVariant),
          const SizedBox(width: EcoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(valor, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

class _TarjetaPostulacion extends StatelessWidget {
  const _TarjetaPostulacion({required this.postulacion, required this.pie});

  final PostulacionRecoleccion postulacion;
  final Widget pie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = postulacion;
    final detalle = [
      if (p.gestorMunicipio?.isNotEmpty ?? false) p.gestorMunicipio!,
      if (p.createdAt != null) tiempoRelativo(p.createdAt),
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: 14),
      child: Padding(
        padding: const EdgeInsets.all(EcoSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(EcoRadius.small),
                  ),
                  child: Text(
                    iniciales(p.gestorRazonSocial),
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.gestorRazonSocial ?? 'Gestor certificado', style: theme.textTheme.titleSmall),
                      if (detalle.isNotEmpty)
                        Text(detalle, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (p.esAceptada) EstadoBadge.fromString(p.estado),
              ],
            ),
            if (p.propuesta?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: EcoSpace.s12),
              Text('«${p.propuesta!.trim()}»', style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: EcoSpace.s8),
            pie,
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.texto, this.tono = TonoEstado.neutro});

  final IconData icono;
  final String titulo;
  final String texto;
  final TonoEstado tono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fondo, frente) = switch (tono) {
      TonoEstado.neutro => (scheme.surfaceContainerLow, scheme.onSurface),
      TonoEstado.error => (scheme.errorContainer, scheme.onErrorContainer),
      TonoEstado.exito => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.all(EcoSpace.s16),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(EcoRadius.medium)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: frente),
          const SizedBox(width: EcoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.titleSmall?.copyWith(color: frente)),
                if (texto.isNotEmpty) ...[
                  const SizedBox(height: EcoSpace.s4),
                  Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: frente)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.children, this.nota});

  final List<Widget> children;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.surfaceContainer,
      padding: EdgeInsets.fromLTRB(
        EcoSpace.s16,
        EcoSpace.s12,
        EcoSpace.s16,
        EcoSpace.s12 + MediaQuery.viewPaddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, hijo) in children.indexed) ...[
            if (i > 0) const SizedBox(height: EcoSpace.s4),
            i == 0 ? SizedBox(height: 56, child: hijo) : hijo,
          ],
          if (nota != null) ...[
            const SizedBox(height: EcoSpace.s4),
            Text(
              nota!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _HojaReportarProblema extends StatefulWidget {
  const _HojaReportarProblema();

  @override
  State<_HojaReportarProblema> createState() => _HojaReportarProblemaState();
}

class _HojaReportarProblemaState extends State<_HojaReportarProblema> {
  static const _motivos = ['No vinieron a recoger', 'Recogieron solo una parte', 'Otro problema'];
  String? _motivo;
  final _detalle = TextEditingController();

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EcoSpace.s16,
        0,
        EcoSpace.s16,
        EcoSpace.s16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Qué pasó con la recolección?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: EcoSpace.s8),
            RadioGroup<String>(
              groupValue: _motivo,
              onChanged: (valor) => setState(() => _motivo = valor),
              child: Column(
                children: [
                  for (final motivo in _motivos)
                    RadioListTile<String>(value: motivo, title: Text(motivo), contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            TextField(
              controller: _detalle,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Cuéntanos más (opcional)',
                hintText: 'Ej.: Llegaron, pero no tenían espacio en el camión.',
              ),
            ),
            const SizedBox(height: EcoSpace.s16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _motivo == null
                  ? null
                  : () {
                      final extra = _detalle.text.trim();
                      Navigator.pop(context, extra.isEmpty ? _motivo : '$_motivo. $extra');
                    },
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );
  }
}
