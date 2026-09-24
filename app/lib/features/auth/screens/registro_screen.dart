import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/guia_categorias.dart';
import '../../../screens/gestores_asociados_screen.dart';
import '../../../theme/eco_theme.dart';
import '../../../utils/municipios.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../../../widgets/categoria_chip.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../solicitudes/models/material_residuo.dart';
import '../../solicitudes/repositories/solicitudes_repository.dart';
import '../models/gestor_padron.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
import 'revisa_correo_screen.dart';

enum _Paso { rol, generador, verificarGestor, gestorNoEncontrado, datosGestor, materiales }

/// Registro (03). Primero se elige el rol y después se ven solo los campos
/// de ese rol. El gestor se verifica en el padrón y declara sus materiales;
/// el administrador los verifica antes de que vea solicitudes.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.authRepository, this.cargarMateriales});

  final AuthRepository? authRepository;
  final Future<List<MaterialResiduo>> Function()? cargarMateriales;

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
  String? _municipio;

  GestorPadron? _padron;
  Future<List<MaterialResiduo>>? _catalogo;
  final _materialesElegidos = <int>{};

  @override
  void initState() {
    super.initState();
    for (final c in [_nombre, _documento, _telefono, _correo, _contrasena, _nit, _razonSocial, _direccion]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _documento, _telefono, _correo, _contrasena, _nit, _razonSocial, _direccion]) {
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
      case _Paso.materiales:
        _ir(_Paso.datosGestor);
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
    'razón social': _lleno(_razonSocial),
    'teléfono': _lleno(_telefono),
    'dirección': _lleno(_direccion),
    'municipio': _municipio != null,
    'contraseña': validarContrasena(_contrasena.text) == null,
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
    if (_nit.text.trim().isEmpty || validarCorreo(_correo.text) != null) {
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
      } else if ((padron.emailOficial ?? '').toLowerCase() != _correo.text.trim().toLowerCase()) {
        setState(
          () => _error =
              'Ese correo no es el que tiene la empresa en el padrón. Usa el correo oficial o comunícate '
              'con la autoridad ambiental para actualizarlo.',
        );
      } else {
        _padron = padron;
        _razonSocial.text = padron.razonSocial;
        _ir(_Paso.datosGestor);
      }
    } catch (e) {
      debugPrint('Falló la consulta al padrón: $e');
      if (mounted) setState(() => _error = 'No pudimos consultar el padrón. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _continuarAMateriales() {
    if (_camposGestor.containsValue(false)) {
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
    await _enviar(
      () => _auth.signUpGestor(
        email: _correo.text,
        password: _contrasena.text,
        padron: _padron!,
        razonSocial: _razonSocial.text,
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
          textoBoton: 'Verificar en el padrón',
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      textInputAction: TextInputAction.next,
      autofillHints: autofill,
      maxLines: maxLineas,
      textCapitalization: teclado == null ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(labelText: etiqueta, errorText: _mostrarErrores ? error : null),
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
                    'Verificamos tu NIT en el padrón oficial.',
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
        'Buscamos tu NIT en el padrón oficial de gestores autorizados. Si apareces, completamos tus datos.',
        style: theme.textTheme.bodyLarge,
      ),
      _campo(_nit, 'NIT', teclado: TextInputType.number, error: _lleno(_nit) ? null : 'Escribe el NIT de la empresa'),
      _campo(
        _correo,
        'Correo de la empresa',
        teclado: TextInputType.emailAddress,
        error: validarCorreo(_correo.text),
        autofill: const [AutofillHints.email],
      ),
    ]);
  }

  Widget _pasoNoEncontrado() {
    return EstadoDesplazable(
      child: EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No encontramos ese NIT en el padrón',
        description:
            'Revisa que esté bien escrito, sin dígito de verificación de más. Si tu licencia está vigente y no '
            'apareces, comunícate con la autoridad ambiental.',
        ctaText: 'Corregir NIT',
        ctaIcon: Icons.edit_outlined,
        onCtaPressed: () => _ir(_Paso.verificarGestor),
        secondaryText: 'Ver autoridades ambientales',
        onSecondaryPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GestoresAsociadosScreen(segmentoInicial: 1)),
        ),
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
                    '${padron.razonSocial} · NIT ${padron.nit} · registrada en el padrón de gestores autorizados.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _campo(
        _razonSocial,
        'Razón social',
        error: _lleno(_razonSocial) ? null : 'Escribe la razón social',
        maxLineas: null,
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
              'Elige lo que tu licencia te permite recibir. El administrador de EcoResiduos lo verifica antes de '
              'mostrarte solicitudes.',
              style: theme.textTheme.bodyLarge,
            ),
            if (_error != null) ...[const SizedBox(height: EcoSpace.s16), _MensajeError(texto: _error!)],
            const SizedBox(height: EcoSpace.s16),
            for (final categoria in categoriasPublicables.keys)
              _GrupoMateriales(
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

class _GrupoMateriales extends StatelessWidget {
  const _GrupoMateriales({
    required this.categoria,
    required this.materiales,
    required this.elegidos,
    required this.onCambio,
  });

  final String categoria;
  final List<MaterialResiduo> materiales;
  final Set<int> elegidos;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cantidad = materiales.where((m) => elegidos.contains(m.id)).length;
    final todos = materiales.isNotEmpty && cantidad == materiales.length;

    return Card(
      margin: const EdgeInsets.only(bottom: EcoSpace.s8),
      child: ExpansionTile(
        shape: const Border(),
        leading: CategoriaTile(categoria: categoriaFromString(categoria)),
        title: Text(etiquetaDeCategoria(categoriaFromString(categoria)), style: theme.textTheme.titleSmall),
        subtitle: Text(
          cantidad == 0
              ? 'Toca para elegir materiales'
              : (cantidad == 1 ? '1 material elegido' : '$cantidad materiales elegidos'),
        ),
        children: [
          if (materiales.isEmpty)
            const ListTile(title: Text('Aún no hay materiales en esta categoría.'))
          else ...[
            CheckboxListTile(
              value: todos,
              title: const Text('Todos los de esta categoría'),
              onChanged: (marcar) {
                for (final m in materiales) {
                  marcar == true ? elegidos.add(m.id) : elegidos.remove(m.id);
                }
                onCambio();
              },
            ),
            for (final m in materiales)
              CheckboxListTile(
                value: elegidos.contains(m.id),
                title: Text(m.nombreComun),
                subtitle: m.subcategoria?.trim().isNotEmpty ?? false ? Text(m.subcategoria!.trim()) : null,
                onChanged: (marcar) {
                  marcar == true ? elegidos.add(m.id) : elegidos.remove(m.id);
                  onCambio();
                },
              ),
          ],
        ],
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
