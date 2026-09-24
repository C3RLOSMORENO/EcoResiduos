import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/eco_theme.dart';
import '../../../widgets/eco_logo.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
import 'registro_screen.dart';
import 'solicitar_recuperacion_screen.dart';

/// Login (02). Sin barra superior; «Entrar» queda fijo abajo y sube con el teclado.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AvisoLogin { ninguno, credenciales, sinActivar, otro }

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _cargando = false;
  _AvisoLogin _aviso = _AvisoLogin.ninguno;
  String _mensajeOtro = '';

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _aviso = _AvisoLogin.ninguno;
    });
    try {
      await _auth.signIn(email: _correo.text, password: _contrasena.text);
    } on AuthException catch (e) {
      setState(() {
        if (e.code == 'email_not_confirmed') {
          _aviso = _AvisoLogin.sinActivar;
        } else if (e.code == 'invalid_credentials' || e.message.contains('no coinciden')) {
          _aviso = _AvisoLogin.credenciales;
        } else {
          _aviso = _AvisoLogin.otro;
          _mensajeOtro = e.message;
        }
      });
    } catch (e) {
      debugPrint('Fallo al iniciar sesión: $e');
      setState(() {
        _aviso = _AvisoLogin.otro;
        _mensajeOtro = 'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviarEnlace() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.reenviarConfirmacion(_correo.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Enviamos un enlace nuevo. Revisa también la carpeta de spam.')),
      );
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos reenviar el enlace. Inténtalo en un minuto.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s24, EcoSpace.s16, EcoSpace.s24),
              children: [
                Row(
                  children: [
                    const EcoLogo(width: 40),
                    const SizedBox(width: EcoSpace.s12),
                    Text('EcoResiduos', style: theme.textTheme.headlineMedium?.copyWith(color: scheme.primary)),
                  ],
                ),
                const SizedBox(height: EcoSpace.s32),
                Text('Entra a tu cuenta', style: theme.textTheme.displaySmall),
                const SizedBox(height: EcoSpace.s24),
                if (_aviso != _AvisoLogin.ninguno) ...[_banner(), const SizedBox(height: EcoSpace.s16)],
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: validarCorreo,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: EcoSpace.s16),
                CampoContrasena(
                  controller: _contrasena,
                  validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                  onSubmitted: (_) => _entrar(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SolicitarRecuperacionScreen(authRepository: _auth)),
                    ),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _cargando ? null : _entrar,
              child: Text(_cargando ? 'Entrando…' : 'Entrar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroScreen(authRepository: _auth))),
              child: const Text('¿No tienes cuenta? Regístrate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icono, titulo, texto) = switch (_aviso) {
      _AvisoLogin.credenciales => (
        Icons.warning_amber_rounded,
        'El correo o la contraseña no coinciden',
        'Revísalos o recupera tu contraseña.',
      ),
      _AvisoLogin.sinActivar => (
        Icons.mark_email_unread_outlined,
        'Aún no has activado tu cuenta',
        'Abre el enlace que te enviamos a tu correo.',
      ),
      _ => (Icons.error_outline, 'No pudimos iniciar sesión', _mensajeOtro),
    };
    final sinActivar = _aviso == _AvisoLogin.sinActivar;

    return Container(
      padding: const EdgeInsets.all(EcoSpace.s16),
      decoration: BoxDecoration(
        color: sinActivar ? scheme.secondaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(EcoRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: sinActivar ? scheme.onSecondaryContainer : scheme.onErrorContainer),
              const SizedBox(width: EcoSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: theme.textTheme.titleSmall),
                    if (texto.isNotEmpty) Text(texto, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (sinActivar)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reenviarEnlace,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Reenviar enlace'),
              ),
            ),
        ],
      ),
    );
  }
}
