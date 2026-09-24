import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/guia_categorias.dart';
import '../../../screens/camara_screen.dart';
import '../../../services/fotos_service.dart';
import '../../../services/identificacion_service.dart';
import '../../../services/ubicacion_service.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/formato.dart';
import '../../../utils/municipios.dart';
import '../../../utils/sesion.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../../../widgets/categoria_chip.dart';
import '../../../widgets/etiqueta_colgada.dart';
import '../../../widgets/imagen_foto.dart';
import '../../../widgets/selector_cascada_sheet.dart';
import '../models/material_residuo.dart';
import '../models/solicitud_recoleccion.dart';
import '../models/unidad_medida.dart';
import '../repositories/solicitudes_repository.dart';
import 'detalle_solicitud_screen.dart';

/// Sugerencia de la IA sobre la foto: categoría detectada y confianza en %.
typedef SugerenciaIa = ({String categoria, int confianza});

/// Formulario para publicar un residuo (27) o editar una publicación (28i).
///
/// Gradiente de meta: muestra cuántos de los 5 campos obligatorios faltan
/// mientras se llena, en vez de errores sorpresa al final.
class PublicarResiduoScreen extends StatefulWidget {
  const PublicarResiduoScreen({
    super.key,
    this.solicitudAEditar,
    this.plantilla,
    this.repository,
    this.materialesIniciales,
    this.fotoInicial,
    this.categoriaSugerida,
    this.analizarFoto,
    this.subidorFoto,
  });

  /// Publicación existente cuando se edita.
  final SolicitudRecoleccion? solicitudAEditar;

  /// Publicación cuyos datos se copian en una nueva («Publicar de nuevo»).
  final SolicitudRecoleccion? plantilla;
  final SolicitudesRepository? repository;
  final List<MaterialResiduo>? materialesIniciales;

  /// Foto ya tomada (desde el resultado de la IA o un escaneo).
  final String? fotoInicial;

  /// Categoría ya detectada: se ofrece como sugerencia sin volver a analizar.
  final String? categoriaSugerida;

  /// Analiza la foto con el modelo; inyectable para pruebas.
  final Future<SugerenciaIa?> Function(String rutaFoto)? analizarFoto;

  /// Sube la foto y devuelve su URL; inyectable para pruebas.
  final Future<String> Function(String rutaLocal)? subidorFoto;

  @override
  State<PublicarResiduoScreen> createState() => _PublicarResiduoScreenState();
}

class _PublicarResiduoScreenState extends State<PublicarResiduoScreen> {
  late final SolicitudesRepository _repository;
  final _cantidad = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _descripcion = TextEditingController();

  final _claveFoto = GlobalKey();
  final _claveMaterial = GlobalKey();
  final _claveCantidad = GlobalKey();
  final _claveDireccion = GlobalKey();

  List<MaterialResiduo> _materiales = const [];
  MaterialResiduo? _material;
  String _unidad = 'KG';
  String? _municipio;
  String? _fotoLocal;
  String? _fotoRemota;
  bool _pedirTelefono = true;

  bool _analizando = false;
  SugerenciaIa? _sugerencia;
  bool _mostrarErrores = false;
  bool _guardando = false;

  bool get _esEdicion => widget.solicitudAEditar != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseSolicitudesRepository();
    for (final c in [_cantidad, _direccion, _telefono]) {
      c.addListener(() => setState(() {}));
    }

    final sesion = SesionUsuario.actual();
    final edicion = widget.solicitudAEditar ?? widget.plantilla;
    if (edicion != null) {
      _cantidad.text = formatoNumero(edicion.cantidadEstimada).replaceAll(',', '.');
      _direccion.text = edicion.direccionRecoleccion;
      _telefono.text = edicion.telefono;
      _descripcion.text = edicion.descripcion ?? '';
      _unidad = edicion.unidadMedida;
      _municipio = municipioAdmitido(edicion.municipio);
      _fotoRemota = edicion.fotoUrl;
      _material = edicion.material;
    } else {
      _municipio = municipioAdmitido(sesion.municipio);
      _telefono.text = sesion.telefono ?? '';
    }
    _pedirTelefono = _telefono.text.trim().isEmpty;

    if (widget.materialesIniciales != null) {
      _materiales = widget.materialesIniciales!;
      _vincularMaterial();
    } else {
      _cargarMateriales();
    }

    final fotoInicial = widget.fotoInicial;
    if (fotoInicial != null && fotoInicial.startsWith('http')) {
      // Foto de un escaneo ya subida: se reutiliza sin volver a subirla.
      _fotoRemota = fotoInicial;
      if (widget.categoriaSugerida != null) {
        _sugerencia = (categoria: widget.categoriaSugerida!.toUpperCase(), confianza: 0);
      }
    } else if (fotoInicial != null) {
      _fotoLocal = fotoInicial;
      final categoria = widget.categoriaSugerida;
      if (categoria != null) {
        _sugerencia = (categoria: categoria.toUpperCase(), confianza: 0);
      } else {
        _analizar(fotoInicial);
      }
    } else if (widget.categoriaSugerida != null) {
      _sugerencia = (categoria: widget.categoriaSugerida!.toUpperCase(), confianza: 0);
    }
  }

  @override
  void dispose() {
    for (final c in [_cantidad, _direccion, _telefono, _descripcion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarMateriales() async {
    try {
      final materiales = await _repository.getMateriales();
      if (!mounted) return;
      setState(() {
        _materiales = materiales;
        _vincularMaterial();
      });
    } catch (e) {
      debugPrint('No se pudo cargar el catálogo de materiales: $e');
    }
  }

  /// En edición, reemplaza el material por la versión completa del catálogo.
  void _vincularMaterial() {
    final id = (widget.solicitudAEditar ?? widget.plantilla)?.materialId;
    if (id == null) return;
    for (final m in _materiales) {
      if (m.id == id) _material = m;
    }
  }

  // Campos obligatorios de la meta.
  bool get _tieneFoto => _fotoLocal != null || (_fotoRemota?.isNotEmpty ?? false);
  bool get _tieneCantidad => (double.tryParse(_cantidad.text.trim().replaceAll(',', '.')) ?? 0) > 0;
  bool get _tieneDireccion => _direccion.text.trim().isNotEmpty;
  bool get _tieneTelefono => _telefono.text.trim().isNotEmpty;

  List<String> get _faltantes => [
    if (!_tieneFoto) 'foto',
    if (_material == null) 'material',
    if (!_tieneCantidad) 'cantidad',
    if (!_tieneDireccion) 'dirección',
    if (_municipio == null) 'municipio',
    if (!_tieneTelefono) 'teléfono',
  ];

  int get _totalCampos => _pedirTelefono ? 6 : 5;

  String get _mensajeMeta {
    final faltan = _faltantes;
    if (faltan.isEmpty) return 'Todo listo. Revisa y publica.';
    final lista = faltan.length == 1
        ? faltan.first
        : '${faltan.sublist(0, faltan.length - 1).join(', ')} y ${faltan.last}';
    return faltan.length == 1 ? 'Te falta: $lista' : 'Te faltan: $lista';
  }

  Future<void> _tomarFoto() async {
    final ruta = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (camara) => CamaraScreen(onCapturar: (ruta) => Navigator.pop(camara, ruta))),
    );
    if (ruta != null) _usarFoto(ruta);
  }

  Future<void> _elegirDeGaleria() async {
    final ruta = await FotosService.elegirDeGaleria();
    if (ruta != null) _usarFoto(ruta);
  }

  void _usarFoto(String ruta) {
    setState(() {
      _fotoLocal = ruta;
      _sugerencia = null;
    });
    _analizar(ruta);
  }

  Future<void> _analizar(String ruta) async {
    setState(() => _analizando = true);
    try {
      final resultado = await (widget.analizarFoto ?? _analizarConModelo)(ruta);
      if (!mounted) return;
      final publicable = resultado != null && categoriasPublicables.containsKey(resultado.categoria);
      setState(() => _sugerencia = publicable ? resultado : null);
    } catch (e) {
      debugPrint('La IA no pudo sugerir una categoría: $e');
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  static Future<SugerenciaIa?> _analizarConModelo(String ruta) async {
    try {
      final item = await IdentificacionService().identificar(imagePath: ruta);
      return (categoria: item.categoria.toUpperCase(), confianza: item.confianza);
    } on ResiduoNoIdentificadoException {
      return null;
    }
  }

  Future<void> _elegirMaterial({String? categoria}) async {
    final elegido = await SelectorCascadaSheet.show(
      context,
      materiales: _materiales,
      categoriaInicial: categoria,
      categoriaSugerida: _sugerencia?.categoria,
    );
    if (elegido != null && mounted) {
      setState(() {
        _material = elegido;
        _sugerencia = null;
      });
    }
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (_faltantes.isNotEmpty) {
      setState(() => _mostrarErrores = true);
      final primera = [
        if (!_tieneFoto) _claveFoto,
        if (_material == null) _claveMaterial,
        if (!_tieneCantidad) _claveCantidad,
        if (!_tieneDireccion || _municipio == null || !_tieneTelefono) _claveDireccion,
      ].firstOrNull;
      final destino = primera?.currentContext;
      if (destino != null) {
        Scrollable.ensureVisible(destino, duration: EcoMotion.duracion(context, EcoMotion.pantalla), alignment: 0.1);
      }
      return;
    }

    if (!_esEdicion && !await _confirmar()) return;
    await _guardar();
  }

  Future<bool> _confirmar() async {
    final theme = Theme.of(context);
    final cantidad = formatoCantidad(_cantidadNumerica, _unidad);
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.campaign_outlined),
        title: const Text('¿Publicar tu residuo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_material!.nombreComun} · $cantidad', style: theme.textTheme.titleSmall),
            const SizedBox(height: EcoSpace.s4),
            Text('${_direccion.text.trim()}, $_municipio'),
            const SizedBox(height: EcoSpace.s12),
            const Text('Se notificará a los gestores certificados para este material.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Revisar')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Publicar')),
        ],
      ),
    );
    return respuesta == true;
  }

  double get _cantidadNumerica => double.parse(_cantidad.text.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    String? fotoSubida;
    try {
      var fotoUrl = _fotoRemota;
      if (_fotoLocal != null) {
        fotoSubida = await (widget.subidorFoto ?? _repository.subirFoto)(_fotoLocal!);
        fotoUrl = fotoSubida;
      }

      final base = widget.solicitudAEditar;
      if (base != null) {
        await _repository.actualizarSolicitud(_completar(base, fotoUrl));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardamos los cambios.')));
        Navigator.pop(context, true);
        return;
      }

      final generadorId = await _repository.getGeneradorId();
      if (generadorId == null) throw StateError('No se encontró el perfil de generador.');
      // Quien publica suele estar donde está el residuo: su ubicación permite
      // que los gestores vean a qué distancia queda la recogida.
      final posicion = await UbicacionService.actual();
      final creada = await _repository.crearSolicitud(
        _completar(
          SolicitudRecoleccion(
            generadorId: generadorId,
            materialId: _material!.id,
            cantidadEstimada: 0,
            unidadMedida: _unidad,
            direccionRecoleccion: '',
            municipio: '',
            telefono: '',
            latitud: posicion?.latitude,
            longitud: posicion?.longitude,
          ),
          fotoUrl,
        ),
      );
      if (mounted) _mostrarExito(creada);
    } catch (e) {
      debugPrint('No se pudo guardar la publicación: $e');
      // Ninguna publicación quedó apuntando a la foto recién subida.
      if (fotoSubida != null) unawaited(_repository.eliminarFoto(fotoSubida));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion ? 'No se pudieron guardar los cambios.' : 'No se pudo publicar. Tus datos siguen aquí.',
          ),
          action: SnackBarAction(label: 'Reintentar', onPressed: _guardar),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  SolicitudRecoleccion _completar(SolicitudRecoleccion base, String? fotoUrl) => base.copyWith(
    materialId: _material!.id,
    cantidadEstimada: _cantidadNumerica,
    unidadMedida: _unidad,
    descripcion: _descripcion.text.trim(),
    direccionRecoleccion: _direccion.text.trim(),
    municipio: _municipio!.toUpperCase(),
    telefono: _telefono.text.trim(),
    fotoUrl: fotoUrl,
  );

  void _mostrarExito(SolicitudRecoleccion creada) {
    final material = minusculaInicial(_material!.nombreComun);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<bool>(
        builder: (exito) => ExitoEtiquetaScreen(
          icono: Icons.check_circle_outline,
          titulo: 'Residuo publicado',
          descripcion:
              'Avisamos a los gestores certificados que reciben $material. Te contamos cuando alguien se postule.',
          accionPrincipal: 'Ver mi publicación',
          onAccionPrincipal: () => Navigator.pushReplacement(
            exito,
            MaterialPageRoute(
              builder: (_) => DetalleSolicitudScreen(solicitud: creada, repository: _repository, rol: 'GENERADOR'),
            ),
          ),
          accionSecundaria: 'Volver al inicio',
          onAccionSecundaria: () => Navigator.pop(exito, true),
        ),
      ),
      result: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(_esEdicion ? 'Editar publicación' : 'Publicar residuo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
        children: [
          _Campo(
            key: _claveFoto,
            etiqueta: 'Foto del residuo',
            error: _mostrarErrores && !_tieneFoto
                ? 'La foto es obligatoria: ayuda al gestor a saber qué va a recoger.'
                : null,
            child: _SlotFoto(
              fotoLocal: _fotoLocal,
              fotoRemota: _fotoRemota,
              analizando: _analizando,
              onCamara: _tomarFoto,
              onGaleria: _elegirDeGaleria,
            ),
          ),
          if (_sugerencia != null) ...[
            const SizedBox(height: EcoSpace.s12),
            _SugerenciaIa(
              sugerencia: _sugerencia!,
              onAplicar: () => _elegirMaterial(categoria: _sugerencia!.categoria),
              onIgnorar: () => setState(() => _sugerencia = null),
            ),
          ],
          const SizedBox(height: EcoSpace.s20),
          _Campo(
            key: _claveMaterial,
            etiqueta: 'Material',
            error: _mostrarErrores && _material == null ? 'Elige qué material vas a publicar.' : null,
            child: _SelectorMaterial(material: _material, onTap: _elegirMaterial),
          ),
          if (_material?.tieneAdvertencia ?? false) ...[
            const SizedBox(height: EcoSpace.s12),
            AvisoAdvertencia(texto: _material!.advertenciaManejo ?? ''),
          ],
          const SizedBox(height: EcoSpace.s20),
          Row(
            key: _claveCantidad,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _cantidad,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textInputAction: TextInputAction.next,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26),
                  decoration: InputDecoration(
                    labelText: 'Cantidad estimada',
                    errorText: _mostrarErrores && !_tieneCantidad ? 'Escribe cuánto hay, aunque sea aproximado.' : null,
                    errorMaxLines: 3,
                  ),
                ),
              ),
              const SizedBox(width: EcoSpace.s12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _unidad,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unidad'),
                  items: [
                    for (final u in unidadesMedidaDisponibles)
                      DropdownMenuItem(value: u.codigo, child: Text(unidadCorta(u.codigo))),
                  ],
                  onChanged: (valor) => setState(() => _unidad = valor ?? _unidad),
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.s16),
          TextField(
            key: _claveDireccion,
            controller: _direccion,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Dirección de recolección',
              hintText: 'Ej.: Cra 27 # 45-12, Cabecera',
              errorText: _mostrarErrores && !_tieneDireccion
                  ? 'Escribe la dirección donde el gestor recogerá el residuo.'
                  : null,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: EcoSpace.s16),
          DropdownButtonFormField<String>(
            initialValue: _municipio,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Municipio',
              errorText: _mostrarErrores && _municipio == null ? 'Elige el municipio.' : null,
            ),
            items: [for (final m in municipiosAdmitidos) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (valor) => setState(() => _municipio = valor),
          ),
          if (_pedirTelefono) ...[
            const SizedBox(height: EcoSpace.s16),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Teléfono de contacto',
                hintText: 'Para que el gestor coordine la recogida',
                errorText: _mostrarErrores && !_tieneTelefono ? 'Escribe un teléfono de contacto.' : null,
              ),
            ),
          ],
          const SizedBox(height: EcoSpace.s16),
          TextField(
            controller: _descripcion,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              hintText: 'Ej.: Cajas dobladas y amarradas, en el garaje.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: BotonFijoInferior(
          textoBoton: _esEdicion ? 'Guardar cambios' : 'Publicar residuo',
          iconoBoton: _esEdicion ? Icons.save_outlined : Icons.upload,
          onPressed: _enviar,
          isLoading: _guardando,
          textoLoading: _esEdicion ? 'Guardando…' : 'Publicando…',
          camposCompletados: _esEdicion || tecladoAbierto ? null : _totalCampos - _faltantes.length,
          totalCampos: _esEdicion || tecladoAbierto ? null : _totalCampos,
          mensajeCamposFaltantes: _mensajeMeta,
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({super.key, required this.etiqueta, required this.child, this.error});

  final String etiqueta;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: theme.textTheme.titleSmall),
        const SizedBox(height: EcoSpace.s8),
        child,
        if (error != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SlotFoto extends StatelessWidget {
  const _SlotFoto({
    required this.fotoLocal,
    required this.fotoRemota,
    required this.analizando,
    required this.onCamara,
    required this.onGaleria,
  });

  final String? fotoLocal;
  final String? fotoRemota;
  final bool analizando;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remota = fotoRemota;
    final ruta = fotoLocal ?? (remota != null && remota.startsWith('http') ? remota : null);
    final imagen = ruta == null ? null : ImagenFoto(ruta: ruta, respaldo: const SizedBox());

    return Container(
      height: 176,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: const EtiquetaBorder(radius: EcoRadius.medium, cut: 20),
      ),
      child: imagen == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 36, color: scheme.onSurfaceVariant),
                const SizedBox(height: EcoSpace.s12),
                Wrap(
                  spacing: EcoSpace.s8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onCamara,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onGaleria,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ],
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                imagen,
                if (analizando)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: scheme.inverseSurface.withValues(alpha: 0.85),
                      padding: const EdgeInsets.all(EcoSpace.s12),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onInverseSurface),
                          ),
                          const SizedBox(width: EcoSpace.s8),
                          Text(
                            'Analizando tu foto…',
                            style: theme.textTheme.labelLarge?.copyWith(color: scheme.onInverseSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: EcoSpace.s8,
                  top: EcoSpace.s8,
                  child: FilledButton.tonalIcon(
                    onPressed: onCamara,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Cambiar'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SugerenciaIa extends StatelessWidget {
  const _SugerenciaIa({required this.sugerencia, required this.onAplicar, required this.onIgnorar});

  final SugerenciaIa sugerencia;
  final VoidCallback onAplicar;
  final VoidCallback onIgnorar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoria = etiquetaCategoria(sugerencia.categoria);
    final texto = sugerencia.confianza > 0
        ? 'La IA sugiere: $categoria · ${sugerencia.confianza} %'
        : 'La IA sugiere: $categoria';

    return Container(
      padding: const EdgeInsets.fromLTRB(EcoSpace.s12, EcoSpace.s8, EcoSpace.s4, EcoSpace.s8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(EcoRadius.medium),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: EcoSpace.s8),
          Expanded(
            child: Text(texto, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer)),
          ),
          TextButton(onPressed: onAplicar, child: const Text('Aplicar')),
          TextButton(onPressed: onIgnorar, child: const Text('Ignorar')),
        ],
      ),
    );
  }
}

class _SelectorMaterial extends StatelessWidget {
  const _SelectorMaterial({required this.material, required this.onTap});

  final MaterialResiduo? material;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elegido = material;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(EcoRadius.small),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcoRadius.small),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16, vertical: EcoSpace.s12),
            child: Row(
              children: [
                Expanded(
                  child: elegido == null
                      ? Text('Elige qué es', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CategoriaChip.fromString(
                              elegido.categoria,
                              label: [
                                etiquetaCategoria(elegido.categoria),
                                if (elegido.subcategoria?.trim().isNotEmpty ?? false) elegido.subcategoria!.trim(),
                              ].join(' · '),
                            ),
                            const SizedBox(height: 6),
                            Text(elegido.nombreComun, style: theme.textTheme.bodyLarge),
                          ],
                        ),
                ),
                const SizedBox(width: EcoSpace.s8),
                elegido == null
                    ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
                    : Text('Cambiar', style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Advertencia técnica de manejo de un material. Usa el color de error
/// porque es una alerta, nunca el terracota de la marca.
class AvisoAdvertencia extends StatelessWidget {
  const AvisoAdvertencia({super.key, required this.texto, this.titulo = 'Advertencia técnica'});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(EcoSpace.s12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(EcoRadius.medium)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: EcoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer)),
                const SizedBox(height: 2),
                Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
