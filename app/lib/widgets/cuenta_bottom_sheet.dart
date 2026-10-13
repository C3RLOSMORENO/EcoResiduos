import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/auth/repositories/auth_repository.dart';
import '../features/auth/screens/restablecer_password_screen.dart';
import '../features/solicitudes/screens/mis_materiales_screen.dart';
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
  bool _eligiendoMunicipio = false;
  String? _municipioNuevo;
  bool _guardando = false;

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
        _eligiendoMunicipio = false;
      });
    } catch (e) {
      debugPrint('No se pudo actualizar el municipio: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos guardar el municipio.')));
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
        child: _eligiendoMunicipio ? _vistaMunicipio() : _vistaCuenta(),
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
          _Dato(etiqueta: 'Correo', valor: _sesion.correo),
          if (_telefono?.isNotEmpty ?? false) _Dato(etiqueta: 'Teléfono', valor: _telefono!),
          _Dato(
            etiqueta: 'Municipio',
            valor: municipioAdmitido(_municipio) ?? capitalizar(_municipio ?? 'Sin definir'),
            accion: TextButton(
              onPressed: () => setState(() {
                _municipioNuevo = municipioAdmitido(_municipio);
                _eligiendoMunicipio = true;
              }),
              child: const Text('Cambiar'),
            ),
          ),
          if (_documento?.isNotEmpty ?? false)
            _Dato(etiqueta: _sesion.esGestor ? 'NIT' : 'Documento', valor: _documento!),
          const Divider(height: EcoSpace.s24),
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
              onPressed: () => setState(() => _eligiendoMunicipio = false),
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
}

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
