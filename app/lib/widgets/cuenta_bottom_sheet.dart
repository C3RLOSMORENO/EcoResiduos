import 'package:flutter/material.dart';

import '../features/auth/repositories/auth_repository.dart';
import '../features/auth/screens/restablecer_password_screen.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import '../utils/municipios.dart';
import '../utils/sesion.dart';

/// Hoja de cuenta (05) que se abre desde el avatar. El municipio se edita en
/// la misma hoja (05b); los demás datos son de lectura.
class CuentaBottomSheet extends StatefulWidget {
  const CuentaBottomSheet({super.key, this.authRepository});

  final AuthRepository? authRepository;

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
  final _sesion = SesionUsuario.actual();

  String _nombre = '';
  String? _telefono;
  String? _municipio;
  String? _documento;
  bool _eligiendoMunicipio = false;
  String? _municipioNuevo;
  bool _guardando = false;

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
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: scheme.tertiaryContainer,
                  shape: const EtiquetaBorder(radius: EcoRadius.small, cut: 10),
                ),
                child: Text(
                  iniciales(_nombre),
                  style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onTertiaryContainer),
                ),
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
