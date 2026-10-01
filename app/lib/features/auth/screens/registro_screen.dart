import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/guia_categorias.dart';
import '../../../services/archivo_pdf.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/municipios.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/grupo_materiales.dart';
import '../../solicitudes/models/material_residuo.dart';
import '../../solicitudes/repositories/solicitudes_repository.dart';
import '../models/gestor_padron.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
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

  GestorPadron? _padron;

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
    'teléfono': _lleno(_telefono),
    'municipio': _municipio != null,
    'correo': validarCorreo(_correo.text) == null,
    'contraseña': validarContrasena(_contrasena.text) == null,
  };

  Map<String, bool> get _camposGestor => {
    'teléfono': _lleno(_telefono),
    'dirección': _lleno(_direccion),
    'municipio': _municipio != null,
    'contraseña': validarContrasena(_contrasena.text) == null,
  };

  bool get _nitValido => RegExp(r'^\d{8,15}$').hasMatch(normalizarNit(_nit.text));

  Map<String, bool> get _camposGestorNuevo => {
    'NIT': _nitValido,
    'razón social': _lleno(_razonSocial),
    'representante legal': _lleno(_representante),
    'teléfono': _lleno(_telefono),
    'dirección': _lleno(_direccion),
    'municipio': _municipio != null,
    'correo': validarCorreo(_correo.text) == null,
    'contraseña': validarContrasena(_contrasena.text) == null,
    'permiso en PDF': _permiso != null,
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
        telefono: _telefono.text,
        municipio: _municipio!,
      ),
    );
  }

  Future<void> _verificarPadron() async {
    if (_nit.text.trim().isEmpty) {
      setState(() => _mostrarErrores = true);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final padron = await _auth.buscarGestorEnPadron(_nit.text);
      if (!mounted) return;
      if (padron == null) {
        _ir(_Paso.gestorNoEncontrado);
      } else if (padron.tieneCuentaActiva) {
        setState(() => _error = 'Esta empresa ya tiene una cuenta. Inicia sesión con el correo de la empresa.');
      } else if (!padron.tieneCorreo) {
        setState(
          () => _error =
              'Tu empresa no tiene un correo registrado y lo necesitamos para activar la cuenta. Comunícate con '
              'el administrador de EcoResiduos para actualizarlo.',
        );
      } else {
        _llenarDesdePadron(padron);
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
  void _llenarDesdePadron(GestorPadron padron) {
    _padron = padron;
    _registroNuevo = false;
    _razonSocial.text = padron.razonSocial;
    _correo.text = padron.emailOficial!;
    _telefono.text = padron.telefono ?? '';
    _direccion.text = padron.direccion ?? '';
    _municipio = municipioAdmitido(padron.municipio);
    _materialesElegidos
      ..clear()
      ..addAll(padron.materialIds);
  }

  void _iniciarRegistroNuevo() {
    if (_padron != null) {
      _padron = null;
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
          telefono: _telefono.text,
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
        padron: _padron!,
        razonSocial: _padron!.razonSocial,
        telefono: _telefono.text,
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

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(
          leading: IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back), onPressed: _volver),
          title: Text(titulo),
        ),
        body: switch (_paso) {
          _Paso.rol => _pasoRol(),
          _Paso.generador => _pasoGenerador(),
          _Paso.verificarGestor => _pasoVerificar(),
          _Paso.gestorNoEncontrado => _pasoNoEncontrado(),
          _Paso.datosGestor => _pasoDatosGestor(),
          _Paso.registroNuevo => _pasoRegistroNuevo(),
          _Paso.materiales => _pasoMateriales(),
        },
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
          onPressed: _verificarPadron,
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
                texto:
                    'Empresa autorizada. Recibe solicitudes de los materiales que puedes gestionar. '
                    'Con tu NIT buscamos tu empresa; si no la encontramos, la registras con tu permiso ambiental.',
              ),
            ],
          ),
        ),
      ],
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
          error: _lleno(_telefono) ? null : 'Escribe tu teléfono',
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
          ayuda: 'Mínimo 8 caracteres y un número',
          autofillHints: const [AutofillHints.newPassword],
          validator: (_) => _mostrarErrores ? validarContrasena(_contrasena.text) : null,
        ),
        if (_mostrarErrores && validarContrasena(_contrasena.text) != null)
          _MensajeError(texto: validarContrasena(_contrasena.text)!),
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
    final padron = _padron!;
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
                    '${padron.razonSocial} · NIT ${padron.nit} · gestor autorizado.',
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
        error: _lleno(_telefono) ? null : 'Escribe el teléfono',
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
        ayuda: 'Mínimo 8 caracteres y un número',
        autofillHints: const [AutofillHints.newPassword],
      ),
      if (_mostrarErrores && validarContrasena(_contrasena.text) != null)
        _MensajeError(texto: validarContrasena(_contrasena.text)!),
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
        error: _nitValido ? null : 'El NIT debe tener entre 8 y 15 dígitos, sin dígito de verificación',
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
        error: _lleno(_telefono) ? null : 'Escribe el teléfono',
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
        ayuda: 'Mínimo 8 caracteres y un número',
        autofillHints: const [AutofillHints.newPassword],
      ),
      if (_mostrarErrores && validarContrasena(_contrasena.text) != null)
        _MensajeError(texto: validarContrasena(_contrasena.text)!),
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
              _padron?.materialIds.isNotEmpty ?? false
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

    return Material(
      color: elegido ? scheme.secondaryContainer : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(EcoRadius.medium)),
        side: BorderSide(color: elegido ? scheme.primary : scheme.outlineVariant, width: elegido ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => grupo?.onChanged(valor),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.all(EcoSpace.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, size: 28, color: scheme.primary),
                const SizedBox(width: EcoSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: theme.textTheme.titleMedium),
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
