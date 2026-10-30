import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/guia_categorias.dart';
import '../../../services/archivo_pdf.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/municipios.dart';
import '../../../utils/validacion.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/grupo_materiales.dart';
import '../../solicitudes/models/material_residuo.dart';
import '../../solicitudes/repositories/solicitudes_repository.dart';
import '../models/gestor_directorio.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
import '../widgets/casilla_autorizacion_datos.dart';
import 'revisa_correo_screen.dart';

enum _Paso { rol, generador, verificarGestor, gestorNoEncontrado, datosGestor, registroNuevo, materiales }

/// Registro (03). Primero se elige el rol y después se ven solo los campos
/// de ese rol. El gestor escribe su NIT: si ya está registrado, sus datos y
/// materiales se llenan solos; si no, registra la empresa con su permiso
/// ambiental en PDF. En ambos casos el administrador verifica antes de que
/// vea solicitudes.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.authRepository, this.cargarMateriales, this.elegirPermiso});

  final AuthRepository? authRepository;
  final Future<List<MaterialResiduo>> Function()? cargarMateriales;

  /// Selector del PDF del permiso; por defecto, el explorador de archivos.
  final Future<ArchivoPdf?> Function()? elegirPermiso;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();

  _Paso _paso = _Paso.rol;
  bool _esGestor = false;
  bool _enviando = false;
  bool _mostrarErrores = false;
  bool _autorizaDatos = false;
  String? _error;

  final _nombre = TextEditingController();
  final _documento = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _nit = TextEditingController();
  final _razonSocial = TextEditingController();
  final _direccion = TextEditingController();
  final _representante = TextEditingController();
  final _horario = TextEditingController();
  String? _municipio;

  GestorDirectorio? _gestorDirectorio;

  /// La empresa no está registrada y se registra con su permiso.
  bool _registroNuevo = false;
  ArchivoPdf? _permiso;
  Future<List<MaterialResiduo>>? _catalogo;
  final _materialesElegidos = <int>{};

  late final _controladores = [
    _nombre,
    _documento,
    _telefono,
    _correo,
    _contrasena,
    _nit,
    _razonSocial,
    _direccion,
    _representante,
    _horario,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _controladores) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  void _ir(_Paso paso) => setState(() {
    _paso = paso;
    _error = null;
    _mostrarErrores = false;
  });

  void _volver() {
    switch (_paso) {
      case _Paso.rol:
        Navigator.maybePop(context);
      case _Paso.generador || _Paso.verificarGestor:
        _ir(_Paso.rol);
      case _Paso.gestorNoEncontrado || _Paso.datosGestor:
        _ir(_Paso.verificarGestor);
      case _Paso.registroNuevo:
        _ir(_Paso.gestorNoEncontrado);
      case _Paso.materiales:
        _ir(_registroNuevo ? _Paso.registroNuevo : _Paso.datosGestor);
    }
  }

  bool _lleno(TextEditingController c) => c.text.trim().isNotEmpty;

  Map<String, bool> get _camposGenerador => {
    'nombre': _lleno(_nombre),
    'documento': _lleno(_documento),
    'teléfono': validarTelefono(_telefono.text) == null,
    'municipio': _municipio != null,
    'correo': validarCorreo(_correo.text) == null,
    'contraseña': validarContrasena(_contrasena.text) == null,
    'autorización de datos personales': _autorizaDatos,
  };

  Map<String, bool> get _camposGestor => {
    'teléfono': validarTelefono(_telefono.text) == null,
    'dirección': _lleno(_direccion),
    'municipio': _municipio != null,
    'contraseña': validarContrasena(_contrasena.text) == null,
    'autorización de datos personales': _autorizaDatos,
  };

  bool get _nitValido => validarNit(_nit.text) == null;

  Map<String, bool> get _camposGestorNuevo => {
    'NIT': _nitValido,
    'razón social': _lleno(_razonSocial),
    'representante legal': _lleno(_representante),
    'teléfono': validarTelefono(_telefono.text) == null,
    'dirección': _lleno(_direccion),
    'municipio': _municipio != null,
    'correo': validarCorreo(_correo.text) == null,
    'contraseña': validarContrasena(_contrasena.text) == null,
    'permiso en PDF': _permiso != null,
    'autorización de datos personales': _autorizaDatos,
  };

  String _mensajeFaltantes(Map<String, bool> campos) {
    final faltan = campos.entries.where((e) => !e.value).map((e) => e.key).toList();
    if (faltan.isEmpty) return 'Todo listo';
    final lista = faltan.length == 1
        ? faltan.first
        : '${faltan.sublist(0, faltan.length - 1).join(', ')} y ${faltan.last}';
    return faltan.length == 1 ? 'Te falta: $lista' : 'Te faltan: $lista';
  }

  Future<void> _crearCuentaGenerador() async {
    if (_camposGenerador.containsValue(false)) {
      setState(() => _mostrarErrores = true);
      return;
    }
    await _enviar(
      () => _auth.signUpGenerador(
        email: _correo.text,
        password: _contrasena.text,
        nombre: _nombre.text,
        documento: _documento.text,
        telefono: normalizarTelefono(_telefono.text) ?? _telefono.text.trim(),
        municipio: _municipio!,
      ),
    );
  }

  Future<void> _verificarDirectorio() async {
    if (_nit.text.trim().isEmpty) {
      setState(() => _mostrarErrores = true);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final gestor = await _auth.buscarGestorEnDirectorio(_nit.text);
      if (!mounted) return;
      if (gestor == null) {
        _ir(_Paso.gestorNoEncontrado);
      } else if (gestor.tieneCuentaActiva) {
        setState(() => _error = 'Esta empresa ya tiene una cuenta. Inicia sesión con el correo de la empresa.');
      } else if (!gestor.tieneCorreo) {
        setState(
          () => _error =
              'Tu empresa no tiene un correo registrado y lo necesitamos para activar la cuenta. Comunícate con '
              'el administrador de EcoResiduos para actualizarlo.',
        );
      } else {
        _llenarDesdeDirectorio(gestor);
        _ir(_Paso.datosGestor);
      }
    } catch (e) {
      debugPrint('Falló la búsqueda del NIT: $e');
      if (mounted) setState(() => _error = 'No pudimos buscar tu empresa. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Con el NIT basta: los datos y materiales registrados quedan llenos y el
  /// gestor solo corrige lo que haya cambiado.
  void _llenarDesdeDirectorio(GestorDirectorio gestor) {
    _gestorDirectorio = gestor;
    _registroNuevo = false;
    _razonSocial.text = gestor.razonSocial;
    _correo.text = gestor.emailOficial!;
    _telefono.text = gestor.telefono ?? '';
    _direccion.text = gestor.direccion ?? '';
    _municipio = municipioAdmitido(gestor.municipio);
    _materialesElegidos
      ..clear()
      ..addAll(gestor.materialIds);
  }

  void _iniciarRegistroNuevo() {
    if (_gestorDirectorio != null) {
      _gestorDirectorio = null;
      for (final c in [_razonSocial, _correo, _telefono, _direccion]) {
        c.clear();
      }
      _municipio = null;
      _materialesElegidos.clear();
    }
    _registroNuevo = true;
    _ir(_Paso.registroNuevo);
  }

  Future<void> _elegirPermiso() async {
    try {
      final pdf = await (widget.elegirPermiso ?? elegirPdf)();
      if (pdf != null && mounted) {
        setState(() {
          _permiso = pdf;
          _error = null;
        });
      }
    } on PdfInvalido catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      debugPrint('No se pudo leer el permiso: $e');
      if (mounted) setState(() => _error = 'No pudimos abrir ese archivo. Elige otro PDF.');
    }
  }

  void _continuarAMateriales() {
    final campos = _registroNuevo ? _camposGestorNuevo : _camposGestor;
    if (campos.containsValue(false)) {
      setState(() => _mostrarErrores = true);
      return;
    }
    _catalogo ??= (widget.cargarMateriales ?? SupabaseSolicitudesRepository().getMateriales)();
    _ir(_Paso.materiales);
  }

  Future<void> _crearCuentaGestor() async {
    if (_materialesElegidos.isEmpty) {
      setState(() => _error = 'Elige al menos un material que tu licencia te permita recibir.');
      return;
    }
    if (_registroNuevo) {
      await _enviar(() async {
        final permisoPath = await _auth.subirPermisoAmbiental(_permiso!);
        return _auth.signUpGestorNuevo(
          email: _correo.text,
          password: _contrasena.text,
          nit: _nit.text,
          razonSocial: _razonSocial.text,
          representanteLegal: _representante.text,
          telefono: normalizarTelefono(_telefono.text) ?? _telefono.text.trim(),
          direccion: _direccion.text,
          municipio: _municipio!,
          horario: _horario.text,
          permisoPath: permisoPath,
          materialesDeclarados: _materialesElegidos.toList(),
        );
      });
      return;
    }
    await _enviar(
      () => _auth.signUpGestor(
        email: _correo.text,
        password: _contrasena.text,
        gestorDirectorio: _gestorDirectorio!,
        razonSocial: _gestorDirectorio!.razonSocial,
        telefono: normalizarTelefono(_telefono.text) ?? _telefono.text.trim(),
        direccion: _direccion.text,
        municipio: _municipio!,
        materialesDeclarados: _materialesElegidos.toList(),
      ),
    );
  }

  Future<void> _enviar(Future<AuthResponse> Function() registro) async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await registro();
      if (!mounted) return;
      final correo = _correo.text.trim();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RevisaCorreoScreen(email: correo, onReenviar: () => _auth.reenviarConfirmacion(correo)),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on StorageException catch (e) {
      // Falla al subir el permiso: la cuenta aún no se creó.
      debugPrint('Falló la subida del permiso: ${e.statusCode} ${e.message}');
      if (mounted) {
        setState(
          () => _error = 'No pudimos subir tu permiso ambiental, así que aún no creamos la cuenta. Inténtalo de nuevo.',
        );
      }
    } catch (e) {
      debugPrint('Falló el registro: $e');
      if (mounted) setState(() => _error = 'No pudimos crear la cuenta. Revisa tu conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _buildHeader(String titulo) {
    final theme = Theme.of(context);
    final isRol = _paso == _Paso.rol;

    return ClipPath(
      clipper: _HeaderWaveClipper(isRol: isRol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        color: theme.colorScheme.primary,
        padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 16, 24, isRol ? 40 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _volver,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                Expanded(
                  child: Text(
                    isRol ? 'EcoResiduos' : titulo,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (isRol) ...[
              const SizedBox(height: 16),
              Text(
                'Únete al\ncambio',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
              const SizedBox(height: 8),
              Text(
                'Elige cómo quieres participar en la red de reciclaje.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titulo = switch (_paso) {
      _Paso.rol => '',
      _Paso.generador => 'Tus datos',
      _Paso.verificarGestor || _Paso.gestorNoEncontrado || _Paso.datosGestor => 'Verifica tu empresa',
      _Paso.registroNuevo => 'Registra tu empresa',
      _Paso.materiales => 'Materiales que recibes',
    };
    return PopScope(
      canPop: _paso == _Paso.rol,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volver();
      },
      child: Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.colorScheme.surface : const Color(0xFFF8F6EE),
        extendBodyBehindAppBar: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(titulo),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_paso),
                  child: switch (_paso) {
                    _Paso.rol => _pasoRol(),
                    _Paso.generador => _pasoGenerador(),
                    _Paso.verificarGestor => _pasoVerificar(),
                    _Paso.gestorNoEncontrado => _pasoNoEncontrado(),
                    _Paso.datosGestor => _pasoDatosGestor(),
                    _Paso.registroNuevo => _pasoRegistroNuevo(),
                    _Paso.materiales => _pasoMateriales(),
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _barra(),
      ),
    );
  }

  Widget? _barra() {
    return switch (_paso) {
      _Paso.rol => BotonFijoInferior(
        textoBoton: 'Continuar',
        onPressed: () => _ir(_esGestor ? _Paso.verificarGestor : _Paso.generador),
      ),
      _Paso.generador => _conTeclado(
        BotonFijoInferior(
          textoBoton: 'Crear cuenta',
          isLoading: _enviando,
          textoLoading: 'Creando cuenta…',
          onPressed: _crearCuentaGenerador,
          camposCompletados: _camposGenerador.values.where((v) => v).length,
          totalCampos: _camposGenerador.length,
          mensajeCamposFaltantes: _mensajeFaltantes(_camposGenerador),
        ),
      ),
      _Paso.verificarGestor => _conTeclado(
        BotonFijoInferior(
          textoBoton: 'Verificar',
          iconoBoton: Icons.verified_outlined,
          isLoading: _enviando,
          textoLoading: 'Buscando…',
          onPressed: _verificarDirectorio,
        ),
      ),
      _Paso.datosGestor => _conTeclado(
        BotonFijoInferior(
          textoBoton: 'Continuar',
          onPressed: _continuarAMateriales,
          camposCompletados: _camposGestor.values.where((v) => v).length,
          totalCampos: _camposGestor.length,
          mensajeCamposFaltantes: _mensajeFaltantes(_camposGestor),
        ),
      ),
      _Paso.registroNuevo => _conTeclado(
        BotonFijoInferior(
          textoBoton: 'Continuar',
          onPressed: _continuarAMateriales,
          camposCompletados: _camposGestorNuevo.values.where((v) => v).length,
          totalCampos: _camposGestorNuevo.length,
          mensajeCamposFaltantes: _mensajeFaltantes(_camposGestorNuevo),
        ),
      ),
      _Paso.materiales => BotonFijoInferior(
        textoBoton: 'Enviar para verificación',
        iconoBoton: Icons.verified_outlined,
        isLoading: _enviando,
        textoLoading: 'Creando cuenta…',
        onPressed: _crearCuentaGestor,
      ),
      _Paso.gestorNoEncontrado => null,
    };
  }

  Widget _conTeclado(Widget barra) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: barra,
  );

  Widget _formulario(List<Widget> campos) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
      children: [
        if (_error != null) ...[_MensajeError(texto: _error!), const SizedBox(height: EcoSpace.s16)],
        for (final (i, campo) in campos.indexed) ...[if (i > 0) const SizedBox(height: EcoSpace.s16), campo],
      ],
    );
  }

  Widget _campo(
    TextEditingController controller,
    String etiqueta, {
    TextInputType? teclado,
    String? error,
    Iterable<String>? autofill,
    int? maxLineas = 1,
    String? ayuda,
    int? maxLargo,
    bool soloLectura = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      textInputAction: TextInputAction.next,
      autofillHints: autofill,
      maxLines: maxLineas,
      maxLength: maxLargo,
      readOnly: soloLectura,
      textCapitalization: teclado == null ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        helperMaxLines: 2,
        errorText: _mostrarErrores ? error : null,
        suffixIcon: soloLectura ? const Icon(Icons.lock_outline) : null,
      ),
    );
  }

  Widget _selectorMunicipio() {
    return DropdownButtonFormField<String>(
      initialValue: _municipio,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Municipio',
        errorText: _mostrarErrores && _municipio == null ? 'Elige tu municipio' : null,
      ),
      items: [for (final m in municipiosAdmitidos) DropdownMenuItem(value: m, child: Text(m))],
      onChanged: (valor) => setState(() => _municipio = valor),
    );
  }

  Widget _pasoRol() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(EcoSpace.s16),
      children: AnimateList(
        interval: 100.ms,
        effects: [
          FadeEffect(duration: 400.ms),
          SlideEffect(begin: const Offset(0, 0.1), duration: 400.ms, curve: Curves.easeOutCubic),
        ],
        children: [
          Text('¿Cómo vas a usar EcoResiduos?', style: theme.textTheme.displaySmall),
          const SizedBox(height: EcoSpace.s24),
          RadioGroup<bool>(
            groupValue: _esGestor,
            onChanged: (valor) => setState(() => _esGestor = valor ?? false),
            child: const Column(
              children: [
                _TarjetaRol(
                  valor: false,
                  icono: Icons.home_work_outlined,
                  titulo: 'Tengo residuos',
                  texto: 'Hogar, negocio o persona. Identifica tus residuos, publícalos y encuentra quién los recibe.',
                ),
                SizedBox(height: EcoSpace.s12),
                _TarjetaRol(
                  valor: true,
                  icono: Icons.local_shipping_outlined,
                  titulo: 'Soy gestor certificado',
                  texto: 'Empresa autorizada. Recibe solicitudes de los materiales que puedes gestionar.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasoGenerador() {
    return AutofillGroup(
      child: _formulario([
        _campo(
          _nombre,
          'Nombre completo',
          error: _lleno(_nombre) ? null : 'Escribe tu nombre',
          autofill: const [AutofillHints.name],
        ),
        _campo(
          _documento,
          'Documento / NIT',
          teclado: TextInputType.number,
          error: _lleno(_documento) ? null : 'Escribe tu documento',
        ),
        _campo(
          _telefono,
          'Teléfono',
          teclado: TextInputType.phone,
          error: validarTelefono(_telefono.text),
          autofill: const [AutofillHints.telephoneNumber],
        ),
        _selectorMunicipio(),
        _campo(
          _correo,
          'Correo',
          teclado: TextInputType.emailAddress,
          error: validarCorreo(_correo.text),
          autofill: const [AutofillHints.email],
        ),
        CampoContrasena(
          controller: _contrasena,
          ayuda: 'Mínimo 8 caracteres, con letras y números',
          autofillHints: const [AutofillHints.newPassword],
          validator: (_) => _mostrarErrores ? validarContrasena(_contrasena.text) : null,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : const Color(0xFFE6E3DB),
        ),
        if (_mostrarErrores && validarContrasena(_contrasena.text) != null)
          _MensajeError(texto: validarContrasena(_contrasena.text)!),
          CasillaAutorizacionDatos(
            valor: _autorizaDatos,
            onChanged: (valor) => setState(() => _autorizaDatos = valor),
            conError: _mostrarErrores && !_autorizaDatos,
          ),
      ]),
    );
  }

  Widget _pasoVerificar() {
    final theme = Theme.of(context);
    return _formulario([
      Text(
        'Escribe el NIT de tu empresa. Si ya está registrada como gestor autorizado, llenamos tus datos.',
        style: theme.textTheme.bodyLarge,
      ),
      _campo(
        _nit,
        'NIT',
        teclado: TextInputType.number,
        error: _lleno(_nit) ? null : 'Escribe el NIT de la empresa',
        ayuda: 'Sin dígito de verificación. Ej.: 900456789',
      ),
    ]);
  }

  Widget _pasoNoEncontrado() {
    return EstadoDesplazable(
      child: EmptyStateWidget(
        icon: Icons.domain_add_outlined,
        title: 'No encontramos tu empresa',
        description:
            'No hay un gestor registrado con ese NIT. Revisa que esté bien escrito o registra tu empresa: llena '
            'sus datos y adjunta en PDF tu licencia o permiso ambiental. '
            'Lo revisamos antes de que recibas solicitudes.',
        ctaText: 'Registrar mi empresa',
        ctaIcon: Icons.app_registration,
        onCtaPressed: _iniciarRegistroNuevo,
        secondaryText: 'Corregir NIT',
        onSecondaryPressed: () => _ir(_Paso.verificarGestor),
      ),
    );
  }

  Widget _pasoDatosGestor() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gestor = _gestorDirectorio!;
    return _formulario([
      Container(
        padding: const EdgeInsets.all(EcoSpace.s16),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(EcoRadius.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified, color: scheme.onPrimaryContainer),
            const SizedBox(width: EcoSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encontramos tu empresa',
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  Text(
                    '${gestor.razonSocial} · NIT ${gestor.nit} · gestor autorizado.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _campo(
        _correo,
        'Correo de la empresa',
        teclado: TextInputType.emailAddress,
        soloLectura: true,
        ayuda: 'Es el correo registrado de tu empresa. Ahí te llega el enlace para activar la cuenta.',
      ),
      _campo(
        _telefono,
        'Teléfono',
        teclado: TextInputType.phone,
        error: validarTelefono(_telefono.text),
      ),
      _campo(
        _direccion,
        'Dirección',
        teclado: TextInputType.streetAddress,
        error: _lleno(_direccion) ? null : 'Escribe la dirección',
        maxLineas: null,
      ),
      _selectorMunicipio(),
      CampoContrasena(
        controller: _contrasena,
        ayuda: 'Mínimo 8 caracteres, con letras y números',
        autofillHints: const [AutofillHints.newPassword],
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : const Color(0xFFE6E3DB),
      ),
      if (_mostrarErrores && validarContrasena(_contrasena.text) != null)
        _MensajeError(texto: validarContrasena(_contrasena.text)!),
        CasillaAutorizacionDatos(
          valor: _autorizaDatos,
          onChanged: (valor) => setState(() => _autorizaDatos = valor),
          conError: _mostrarErrores && !_autorizaDatos,
        ),
    ]);
  }

  Widget _pasoRegistroNuevo() {
    final theme = Theme.of(context);
    return _formulario([
      Text(
        'Escribe los datos como aparecen en tu licencia o permiso ambiental. El administrador los revisa antes de '
        'que recibas solicitudes.',
        style: theme.textTheme.bodyLarge,
      ),
      _campo(
        _nit,
        'NIT',
        teclado: TextInputType.number,
        error: validarNit(_nit.text),
      ),
      _campo(
        _razonSocial,
        'Razón social',
        error: _lleno(_razonSocial) ? null : 'Escribe la razón social',
        maxLineas: null,
      ),
      _campo(
        _representante,
        'Representante legal',
        error: _lleno(_representante) ? null : 'Escribe el nombre del representante legal',
      ),
      _campo(
        _telefono,
        'Teléfono',
        teclado: TextInputType.phone,
        error: validarTelefono(_telefono.text),
      ),
      _campo(
        _direccion,
        'Dirección',
        teclado: TextInputType.streetAddress,
        error: _lleno(_direccion) ? null : 'Escribe la dirección',
        maxLineas: null,
      ),
      _selectorMunicipio(),
      _campo(
        _correo,
        'Correo de la empresa',
        teclado: TextInputType.emailAddress,
        error: validarCorreo(_correo.text),
        autofill: const [AutofillHints.email],
        ayuda: 'Ahí te llega el enlace para activar la cuenta.',
      ),
      _campo(
        _horario,
        'Horario de atención (opcional)',
        teclado: TextInputType.text,
        maxLargo: 120,
        ayuda: 'Ej.: Lun a vie 7:30 a 17:00 · Sáb 8:00 a 12:00',
      ),
      CampoContrasena(
        controller: _contrasena,
        ayuda: 'Mínimo 8 caracteres, con letras y números',
        autofillHints: const [AutofillHints.newPassword],
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : const Color(0xFFE6E3DB),
      ),
      if (_mostrarErrores && validarContrasena(_contrasena.text) != null)
        _MensajeError(texto: validarContrasena(_contrasena.text)!),
        CasillaAutorizacionDatos(
          valor: _autorizaDatos,
          onChanged: (valor) => setState(() => _autorizaDatos = valor),
          conError: _mostrarErrores && !_autorizaDatos,
        ),
      _SelectorPermiso(
        archivo: _permiso,
        onElegir: _enviando ? null : _elegirPermiso,
        conError: _mostrarErrores && _permiso == null,
      ),
    ]);
  }

  Widget _pasoMateriales() {
    final theme = Theme.of(context);
    return FutureBuilder<List<MaterialResiduo>>(
      future: _catalogo,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyStateWidget.error(
            title: 'No pudimos cargar los materiales',
            onRetry: () => setState(
              () => _catalogo = (widget.cargarMateriales ?? SupabaseSolicitudesRepository().getMateriales)(),
            ),
          );
        }
        final catalogo = snapshot.data;
        if (catalogo == null) return const Center(child: CircularProgressIndicator());

        return ListView(
          padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s24),
          children: [
            Text(
              _gestorDirectorio?.materialIds.isNotEmpty ?? false
                  ? 'Marcamos los que tu empresa ya tiene registrados. Agrega o quita lo que haga falta: el '
                        'administrador de EcoResiduos lo verifica antes de mostrarte solicitudes.'
                  : 'Elige lo que tu licencia te permite recibir. El administrador de EcoResiduos lo verifica antes '
                        'de mostrarte solicitudes.',
              style: theme.textTheme.bodyLarge,
            ),
            if (_error != null) ...[const SizedBox(height: EcoSpace.s16), _MensajeError(texto: _error!)],
            const SizedBox(height: EcoSpace.s16),
            for (final categoria in categoriasPublicables.keys)
              GrupoMateriales(
                categoria: categoria,
                materiales: catalogo.where((m) => m.categoria.toUpperCase() == categoria).toList(),
                elegidos: _materialesElegidos,
                onCambio: () => setState(() => _error = null),
              ),
          ],
        );
      },
    );
  }
}

/// Licencia o permiso ambiental en PDF, obligatorio para registrar una empresa.
class _SelectorPermiso extends StatelessWidget {
  const _SelectorPermiso({required this.archivo, required this.onElegir, required this.conError});

  final ArchivoPdf? archivo;
  final VoidCallback? onElegir;
  final bool conError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elegido = archivo != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: elegido ? scheme.secondaryContainer : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(EcoRadius.medium)),
            side: BorderSide(color: conError ? scheme.error : scheme.outlineVariant, width: conError ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(EcoSpace.s16),
            child: Row(
              children: [
                Icon(
                  elegido ? Icons.picture_as_pdf : Icons.upload_file,
                  size: 28,
                  color: conError ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Licencia o permiso ambiental', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        archivo?.nombre ?? 'PDF de máximo 10 MB expedido por la autoridad ambiental (CDMB, AMB o CAS).',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: EcoSpace.s8),
                elegido
                    ? TextButton(onPressed: onElegir, child: const Text('Cambiar'))
                    : FilledButton.tonal(onPressed: onElegir, child: const Text('Elegir PDF')),
              ],
            ),
          ),
        ),
        if (conError) ...[
          const SizedBox(height: EcoSpace.s4),
          Text('Adjunta el permiso en PDF', style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
        ],
      ],
    );
  }
}

class _TarjetaRol extends StatelessWidget {
  const _TarjetaRol({required this.valor, required this.icono, required this.titulo, required this.texto});

  final bool valor;
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grupo = RadioGroup.maybeOf<bool>(context);
    final elegido = grupo?.groupValue == valor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: elegido ? scheme.secondaryContainer : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(EcoRadius.medium),
        border: Border.all(
          color: elegido ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.5),
          width: elegido ? 2 : 1,
        ),
        boxShadow: elegido
            ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => grupo?.onChanged(valor),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(EcoSpace.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: elegido ? scheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, size: 28, color: scheme.primary),
                  ),
                  const SizedBox(width: EcoSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: elegido ? FontWeight.bold : FontWeight.normal,
                            color: elegido ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: EcoSpace.s4),
                        Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Radio<bool>(value: valor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(EcoSpace.s12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(EcoRadius.small)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: EcoSpace.s8),
          Expanded(
            child: Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
  const _HeaderWaveClipper({this.isRol = false});
  final bool isRol;

  @override
  Path getClip(Size size) {
    final path = Path();
    final curveDepth = isRol ? 25.0 : 15.0;

    path.lineTo(0, size.height - curveDepth);
    path.quadraticBezierTo(size.width * 0.35, size.height, size.width * 0.65, size.height - (curveDepth * 0.6));
    path.quadraticBezierTo(size.width * 0.85, size.height - curveDepth, size.width, size.height - (curveDepth * 0.4));

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _HeaderWaveClipper oldClipper) => oldClipper.isRol != isRol;
}
