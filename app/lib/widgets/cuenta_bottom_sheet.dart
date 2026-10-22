import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/auth/repositories/auth_repository.dart';
import '../features/auth/screens/restablecer_password_screen.dart';
import '../features/solicitudes/screens/mis_materiales_screen.dart';
import '../services/archivo_pdf.dart';
import '../services/foto_perfil_service.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/municipios.dart';
import '../utils/sesion.dart';
import 'gestor_card.dart';

/// Hoja de cuenta (05) que se abre desde el avatar. El municipio se edita en
/// la misma hoja (05b); la foto de perfil (y la portada del gestor) se cambia
/// con su opción; los demás datos son de lectura.
class CuentaBottomSheet extends StatefulWidget {
  const CuentaBottomSheet({super.key, this.authRepository, this.fotoPerfilService, this.sesion});

  final AuthRepository? authRepository;
  final FotoPerfilService? fotoPerfilService;

  /// Para pruebas; por defecto, la sesión actual.
  final SesionUsuario? sesion;

  /// Abre la hoja de la cuenta desde la parte inferior de la pantalla.
  static Future<void> show(BuildContext context, {AuthRepository? authRepository}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CuentaBottomSheet(authRepository: authRepository),
    );
  }

  @override
  State<CuentaBottomSheet> createState() => _CuentaBottomSheetState();
}

class _CuentaBottomSheetState extends State<CuentaBottomSheet> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();
  late final FotoPerfilService _fotos = widget.fotoPerfilService ?? FotoPerfilService();
  late SesionUsuario _sesion = widget.sesion ?? SesionUsuario.actual();

  String _nombre = '';
  String? _telefono;
  String? _municipio;
  String? _documento;
  String? _direccion;
  String? _emailContacto;
  String? _horario;

  _VistaActual _vista = _VistaActual.cuenta;
  String? _municipioNuevo;
  _CampoEditable? _campoActual;
  bool _guardando = false;

  // Un único controlador reutilizable para la sub-vista de editar un campo.
  final _ctrlCampo = TextEditingController();
  final _ctrlSolicitud = TextEditingController();

  /// Imagen que se está subiendo o quitando; null si ninguna.
  ImagenPerfil? _cambiandoImagen;

  @override
  void initState() {
    super.initState();
    _nombre = _sesion.nombre;
    _telefono = _sesion.telefono;
    _municipio = _sesion.municipio;
    _documento = _sesion.documento;
    _cargarPerfil();
  }

  @override
  void dispose() {
    _ctrlCampo.dispose();
    _ctrlSolicitud.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    try {
      if (_sesion.esGestor) {
        final perfil = await _auth.getPerfilGestor();
        if (perfil == null || !mounted) return;
        setState(() {
          _nombre = perfil.razonSocial;
          _telefono = perfil.telefonoContacto;
          _municipio = perfil.municipio;
          _documento = perfil.nit;
          _direccion = perfil.direccion;
          _emailContacto = perfil.emailContacto;
          _horario = perfil.horario;
        });
      } else {
        final perfil = await _auth.getPerfilGenerador();
        if (perfil == null || !mounted) return;
        setState(() {
          _nombre = perfil.nombreCompletoOEmpresa;
          _telefono = perfil.telefono;
          _municipio = perfil.municipio;
          _documento = perfil.documentoNit;
        });
      }
    } catch (e) {
      debugPrint('No se pudo cargar el perfil: $e');
    }
  }

  Future<void> _guardarMunicipio() async {
    final nuevo = _municipioNuevo;
    if (nuevo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      await _auth.actualizarMunicipio(nuevo);
      setState(() {
        _municipio = nuevo;
        _vista = _VistaActual.cuenta;
      });
    } catch (e) {
      debugPrint('No se pudo actualizar el municipio: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos guardar el municipio.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _abrirEditarCampo(_CampoEditable campo) {
    _ctrlCampo.text = switch (campo) {
      _CampoEditable.email => _emailContacto ?? '',
      _CampoEditable.telefono => _telefono ?? '',
      _CampoEditable.direccion => _direccion ?? '',
      _CampoEditable.horario => _horario ?? '',
    };
    setState(() {
      _campoActual = campo;
      _vista = _VistaActual.editarCampo;
    });
  }

  Future<void> _guardarCampo() async {
    final campo = _campoActual;
    if (campo == null) return;
    final nuevo = _ctrlCampo.text.trim();
    if (nuevo.isEmpty && campo != _CampoEditable.horario) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El campo no puede estar vacío.')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      if (campo == _CampoEditable.horario) {
        await _auth.actualizarHorario(nuevo.isEmpty ? null : nuevo);
      } else {
        await _auth.actualizarInfoContactoGestor(
          emailContacto: campo == _CampoEditable.email ? nuevo : (_emailContacto ?? ''),
          telefonoContacto: campo == _CampoEditable.telefono ? nuevo : (_telefono ?? ''),
          direccion: campo == _CampoEditable.direccion ? nuevo : (_direccion ?? ''),
        );
      }
      setState(() {
        switch (campo) {
          case _CampoEditable.email: _emailContacto = nuevo;
          case _CampoEditable.telefono: _telefono = nuevo;
          case _CampoEditable.direccion: _direccion = nuevo;
          case _CampoEditable.horario: _horario = nuevo.isEmpty ? null : nuevo;
        }
        _vista = _VistaActual.cuenta;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Guardado correctamente.')));
    } catch (e) {
      debugPrint('No se pudo actualizar: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos guardar los cambios. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _enviarSolicitud() async {
    final texto = _ctrlSolicitud.text.trim();
    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe qué necesitas cambiar.')));
      return;
    }
    final asunto = Uri.encodeComponent('Solicitud cambio datos · ${_documento ?? _nombre}');
    final cuerpo = Uri.encodeComponent('Empresa: $_nombre\nNIT: ${_documento ?? '—'}\n\n$texto');
    final uri = Uri.parse('mailto:$_adminEmail?subject=$asunto&body=$cuerpo');
    try {
      await launchUrl(uri);
      if (mounted) setState(() => _vista = _VistaActual.cuenta);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el correo. Contáctanos directamente.')),
        );
      }
    }
  }

  Future<void> _subirPermiso() async {
    final messenger = ScaffoldMessenger.of(context);
    ArchivoPdf? pdf;
    try {
      pdf = await elegirPdf();
    } on PdfInvalido catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
      return;
    }
    if (pdf == null || !mounted) return;
    setState(() => _guardando = true);
    try {
      await _auth.renovarPermisoAmbiental(pdf);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Permiso ambiental actualizado. El administrador lo revisará.')));
    } catch (e) {
      debugPrint('No se pudo subir el permiso: $e');
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('No pudimos subir el permiso. Revisa tu conexión.')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarImagen(ImagenPerfil imagen) async {
    final tieneImagen = (imagen == ImagenPerfil.foto ? _sesion.fotoPerfilPath : _sesion.portadaPath) != null;
    final opcion = await _OpcionesImagen.show(context, imagen: imagen, tieneImagen: tieneImagen);
    if (opcion == null || !mounted) return;

    String? rutaLocal;
    if (opcion != _OpcionImagen.quitar) {
      final camara = opcion == _OpcionImagen.camara;
      if (camara && !await _permisoCamara()) return;
      rutaLocal = await FotoPerfilService.elegir(camara ? ImageSource.camera : ImageSource.gallery, imagen);
      if (rutaLocal == null || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nombre = imagen == ImagenPerfil.foto ? 'Foto de perfil' : 'Portada';
    setState(() => _cambiandoImagen = imagen);
    try {
      String? ruta;
      if (rutaLocal == null) {
        await _fotos.quitar(imagen);
      } else {
        ruta = await _fotos.cambiar(rutaLocal, imagen);
      }
      if (!mounted) return;
      setState(
        () => _sesion = imagen == ImagenPerfil.foto
            ? _sesion.conImagenes(fotoPerfilPath: ruta, portadaPath: _sesion.portadaPath)
            : _sesion.conImagenes(fotoPerfilPath: _sesion.fotoPerfilPath, portadaPath: ruta),
      );
      messenger.showSnackBar(SnackBar(content: Text(rutaLocal == null ? '$nombre quitada.' : '$nombre actualizada.')));
    } catch (e) {
      debugPrint('No se pudo cambiar la imagen del perfil: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('No pudimos guardar la ${nombre.toLowerCase()}. Revisa tu conexión e inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cambiandoImagen = null);
    }
  }

  /// Pide el permiso de cámara del sistema. Si quedó negado para siempre,
  /// ofrece abrir los ajustes del teléfono.
  Future<bool> _permisoCamara() async {
    var estado = await Permission.camera.status;
    if (estado.isGranted) return true;
    if (!estado.isPermanentlyDenied) estado = await Permission.camera.request();
    if (estado.isGranted) return true;
    if (estado.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para tomar la foto, permite la cámara en los ajustes del teléfono.'),
          action: SnackBarAction(label: 'Abrir ajustes', onPressed: openAppSettings),
        ),
      );
    }
    return false;
  }

  Future<void> _cerrarSesion() async {
    final navigator = Navigator.of(context);
    await _auth.signOut();
    navigator.popUntil((ruta) => ruta.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: EcoMotion.duracion(context, EcoMotion.estado),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s16),
        child: switch (_vista) {
          _VistaActual.municipio => _vistaMunicipio(),
          _VistaActual.editarCampo => _vistaEditarCampo(),
          _VistaActual.solicitarCambio => _vistaSolicitarCambio(),
          _VistaActual.cuenta => _vistaCuenta(),
        },
      ),
    );
  }

  Widget _vistaCuenta() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AvatarEditable(
                nombre: _nombre,
                fotoUrl: FotoPerfilService.url(_sesion.fotoPerfilPath),
                tieneFoto: _sesion.fotoPerfilPath != null,
                esGestor: _sesion.esGestor,
                guardando: _cambiandoImagen == ImagenPerfil.foto,
                onTap: _cambiandoImagen == null ? () => _cambiarImagen(ImagenPerfil.foto) : null,
              ),
              const SizedBox(width: EcoSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nombre.isEmpty ? 'Tu cuenta' : _nombre, style: theme.textTheme.titleLarge),
                    Text(
                      _sesion.esGestor ? 'Gestor certificado' : 'Generador',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.s16),
          _Dato(etiqueta: 'Correo de acceso', valor: _sesion.correo),
          if (_sesion.esGestor)
            _Dato(
              etiqueta: 'Correo de contacto',
              valor: _emailContacto?.isNotEmpty == true ? _emailContacto! : 'Sin definir',
              accion: TextButton(
                onPressed: _guardando ? null : () => _abrirEditarCampo(_CampoEditable.email),
                child: const Text('Cambiar'),
              ),
            ),
          _Dato(
            etiqueta: 'Teléfono',
            valor: _telefono?.isNotEmpty == true ? _telefono! : 'Sin definir',
            accion: _sesion.esGestor
                ? TextButton(
                    onPressed: _guardando ? null : () => _abrirEditarCampo(_CampoEditable.telefono),
                    child: const Text('Cambiar'),
                  )
                : null,
          ),
          _Dato(
            etiqueta: 'Municipio',
            valor: municipioAdmitido(_municipio) ?? capitalizar(_municipio ?? 'Sin definir'),
            accion: TextButton(
              onPressed: () => setState(() {
                _municipioNuevo = municipioAdmitido(_municipio);
                _vista = _VistaActual.municipio;
              }),
              child: const Text('Cambiar'),
            ),
          ),
          if (_documento?.isNotEmpty ?? false)
            _Dato(etiqueta: _sesion.esGestor ? 'NIT' : 'Documento', valor: _documento!),
          if (_sesion.esGestor)
            _Dato(
              etiqueta: 'Dirección',
              valor: _direccion?.isNotEmpty == true ? _direccion! : 'Sin definir',
              accion: TextButton(
                onPressed: _guardando ? null : () => _abrirEditarCampo(_CampoEditable.direccion),
                child: const Text('Cambiar'),
              ),
            ),
          if (_sesion.esGestor)
            _Dato(
              etiqueta: 'Horario de atención',
              valor: _horario?.isNotEmpty == true ? _horario! : 'Sin definir',
              accion: TextButton(
                onPressed: _guardando ? null : () => _abrirEditarCampo(_CampoEditable.horario),
                child: const Text('Cambiar'),
              ),
            ),
          const Divider(height: EcoSpace.s24),
          if (_sesion.esGestor)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Solicitar cambio al administrador'),
              subtitle: const Text('NIT, razón social u otros datos de empresa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _guardando
                  ? null
                  : () => setState(() {
                        _ctrlSolicitud.clear();
                        _vista = _VistaActual.solicitarCambio;
                      }),
            ),
          if (_sesion.esGestor)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _guardando
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.upload_file_outlined),
              title: const Text('Actualizar permiso ambiental'),
              subtitle: const Text('PDF · máx. 10 MB'),
              trailing: _guardando ? null : const Icon(Icons.chevron_right),
              onTap: _guardando ? null : _subirPermiso,
            ),
          if (_sesion.esGestor)
            _OpcionImagenPerfil(
              icono: Icons.wallpaper_outlined,
              titulo: _sesion.portadaPath == null ? 'Agregar portada' : 'Cambiar portada',
              subtitulo: 'Se ve detrás de tu foto en el directorio',
              subiendo: _cambiandoImagen == ImagenPerfil.portada,
              onTap: _cambiandoImagen == null ? () => _cambiarImagen(ImagenPerfil.portada) : null,
            ),
          if (_sesion.esGestor)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.recycling),
              title: const Text('Materiales que recibo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const MisMaterialesScreen()));
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(builder: (_) => RestablecerPasswordScreen(authRepository: _auth, desdeCuenta: true)),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            iconColor: scheme.error,
            textColor: scheme.error,
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: _cerrarSesion,
          ),
        ],
      ),
    );
  }

  Widget _vistaMunicipio() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _vista = _VistaActual.cuenta),
            ),
            Text('Tu municipio', style: theme.textTheme.headlineSmall),
          ],
        ),
        RadioGroup<String>(
          groupValue: _municipioNuevo,
          onChanged: (valor) => setState(() => _municipioNuevo = valor),
          child: Column(
            children: [for (final m in municipiosAdmitidos) RadioListTile<String>(value: m, title: Text(m))],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s8),
          child: Text(
            'Cambia qué gestores y solicitudes ves «cerca». Solo los 6 municipios admitidos.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: EcoSpace.s16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _guardando || _municipioNuevo == null ? null : _guardarMunicipio,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _vistaEditarCampo() {
    final theme = Theme.of(context);
    final campo = _campoActual!;
    final (titulo, hint, tipo, multilinea) = switch (campo) {
      _CampoEditable.email => ('Correo de contacto', 'contacto@empresa.com', TextInputType.emailAddress, false),
      _CampoEditable.telefono => ('Teléfono', '3001234567', TextInputType.phone, false),
      _CampoEditable.direccion => ('Dirección', 'Calle 35 # 12-40', TextInputType.streetAddress, false),
      _CampoEditable.horario => ('Horario de atención', 'Lun a sáb 7:00–17:00', TextInputType.multiline, true),
    };
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: _guardando ? null : () => setState(() => _vista = _VistaActual.cuenta),
              ),
              Text('Cambiar $titulo', style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: EcoSpace.s16),
          TextField(
            controller: _ctrlCampo,
            decoration: InputDecoration(labelText: titulo, hintText: hint),
            keyboardType: tipo,
            textInputAction: multilinea ? TextInputAction.newline : TextInputAction.done,
            minLines: multilinea ? 2 : 1,
            maxLines: multilinea ? 4 : 1,
            enabled: !_guardando,
            autofocus: true,
            onSubmitted: multilinea ? null : (_) => _guardarCampo(),
          ),
          if (campo == _CampoEditable.horario) ...[
            const SizedBox(height: EcoSpace.s4),
            Text(
              'Se muestra en tu ficha del directorio. Deja en blanco para no mostrar horario.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: EcoSpace.s24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _guardando ? null : _guardarCampo,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _vistaSolicitarCambio() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vista = _VistaActual.cuenta),
              ),
              Text('Solicitar cambio', style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: EcoSpace.s8),
          Text(
            'Para cambiar el NIT, la razón social u otros datos de empresa que no puedes editar desde la app, escríbenos qué necesitas. El administrador lo revisará.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: EcoSpace.s16),
          TextField(
            controller: _ctrlSolicitud,
            minLines: 3,
            maxLines: 6,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '¿Qué necesitas cambiar?',
              hintText: 'Ej.: Actualizar el NIT porque hubo una corrección.',
            ),
          ),
          const SizedBox(height: EcoSpace.s16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _enviarSolicitud,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }
}

const _adminEmail = 'soporte@ecoresiduos.co';

enum _VistaActual { cuenta, municipio, editarCampo, solicitarCambio }

enum _CampoEditable { email, telefono, direccion, horario }

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor, this.accion});

  final String etiqueta;
  final String valor;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(etiqueta, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

/// Avatar de la hoja de cuenta: es el botón para cambiar la foto, con la
/// insignia de cámara que usan la mayoría de apps. Círculo para personas y
/// recuadro para el logo de una empresa.
class _AvatarEditable extends StatelessWidget {
  const _AvatarEditable({
    required this.nombre,
    required this.fotoUrl,
    required this.tieneFoto,
    required this.esGestor,
    required this.guardando,
    this.onTap,
  });

  static const _tamano = 72.0;

  final String nombre;
  final String? fotoUrl;
  final bool tieneFoto;
  final bool esGestor;
  final bool guardando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final forma = esGestor
        ? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.small)))
        : const CircleBorder();
    final accion = !tieneFoto ? 'Agregar foto de perfil' : 'Cambiar foto de perfil';
    // La insignia se recorta sobre el fondo de la hoja para separarse de la foto.
    final fondoHoja = Theme.of(context).bottomSheetTheme.backgroundColor ?? scheme.surfaceContainerLow;

    return Tooltip(
      message: guardando ? 'Guardando foto de perfil' : accion,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: SizedBox.square(
          dimension: _tamano,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarEntidad(
                nombre: nombre,
                size: _tamano,
                fotoUrl: fotoUrl,
                circular: !esGestor,
                ajuste: esGestor ? BoxFit.contain : BoxFit.cover,
              ),
              if (guardando)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(shape: forma, color: scheme.scrim.withValues(alpha: 0.4)),
                    child: const Center(
                      child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                    ),
                  ),
                ),
              Positioned(
                right: -4,
                bottom: -4,
                child: ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: fondoHoja, width: 2),
                    ),
                    child: Icon(Icons.photo_camera, size: 15, color: scheme.onPrimary),
                  ),
                ),
              ),
              // La capa de toque va encima: debajo de la foto el efecto no se vería.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  shape: forma,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onTap),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opción de la hoja para cambiar la portada.
class _OpcionImagenPerfil extends StatelessWidget {
  const _OpcionImagenPerfil({
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.subiendo = false,
    this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final bool subiendo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono),
      title: Text(titulo),
      subtitle: subtitulo == null ? null : Text(subtitulo!),
      trailing: subiendo
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3, semanticsLabel: 'Guardando'),
            )
          : null,
      onTap: onTap,
    );
  }
}

enum _OpcionImagen { galeria, camara, quitar }

/// Hoja con las formas de cambiar la imagen: galería, cámara o quitarla.
class _OpcionesImagen extends StatelessWidget {
  const _OpcionesImagen({required this.imagen, required this.tieneImagen});

  final ImagenPerfil imagen;
  final bool tieneImagen;

  static Future<_OpcionImagen?> show(BuildContext context, {required ImagenPerfil imagen, required bool tieneImagen}) {
    return showModalBottomSheet<_OpcionImagen>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _OpcionesImagen(imagen: imagen, tieneImagen: tieneImagen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final esFoto = imagen == ImagenPerfil.foto;
    return Padding(
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(esFoto ? 'Foto de perfil' : 'Portada', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: EcoSpace.s8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(context, _OpcionImagen.galeria),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, _OpcionImagen.camara),
          ),
          if (tieneImagen)
            ListTile(
              contentPadding: EdgeInsets.zero,
              iconColor: scheme.error,
              textColor: scheme.error,
              leading: const Icon(Icons.delete_outline),
              title: Text(esFoto ? 'Quitar foto' : 'Quitar portada'),
              onTap: () => Navigator.pop(context, _OpcionImagen.quitar),
            ),
        ],
      ),
    );
  }
}
