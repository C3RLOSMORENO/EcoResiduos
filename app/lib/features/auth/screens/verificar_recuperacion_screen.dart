import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/eco_theme.dart';
import '../repositories/auth_repository.dart';
import '../widgets/otp_input_field.dart';
import 'restablecer_password_screen.dart';

/// Recuperar contraseña, paso 2 (04b, 04c). Sin botón fijo: al escribir el
/// sexto dígito se verifica solo.
class VerificarRecuperacionScreen extends StatefulWidget {
  const VerificarRecuperacionScreen({super.key, required this.email, this.authRepository});

  final String email;
  final AuthRepository? authRepository;

  @override
  State<VerificarRecuperacionScreen> createState() => _VerificarRecuperacionScreenState();
}

class _VerificarRecuperacionScreenState extends State<VerificarRecuperacionScreen> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();
  final _codigo = TextEditingController();
  Timer? _timer;
  int _restante = 30;
  bool _verificando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciarEspera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  void _iniciarEspera() {
    _timer?.cancel();
    _restante = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _restante--);
      if (_restante <= 0) timer.cancel();
    });
  }

  Future<void> _verificar(String codigo) async {
    if (_verificando) return;
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      await _auth.verificarOtpRecuperacion(email: widget.email, token: codigo);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RestablecerPasswordScreen(authRepository: _auth)),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('No se pudo verificar el código: $e');
      setState(() => _error = 'No pudimos verificar el código. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _reenviar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.solicitarRecuperacionPassword(widget.email);
      _codigo.clear();
      setState(() => _error = null);
      _iniciarEspera();
      messenger.showSnackBar(const SnackBar(content: Text('Te enviamos un código nuevo.')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos reenviar el código. Inténtalo más tarde.')));
    }
  }

  static String _ocultarCorreo(String correo) {
    final partes = correo.split('@');
    if (partes.length != 2 || partes.first.isEmpty) return correo;
    return '${partes.first[0]}•••••@${partes.last}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Escribe el código')),
      body: ListView(
        padding: const EdgeInsets.all(EcoSpace.s16),
        children: [
          Text('Lo enviamos a ${_ocultarCorreo(widget.email)}. Vence en 10 minutos.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: EcoSpace.s24),
          OtpInputField(controller: _codigo, enabled: !_verificando, error: _error != null, onCompleted: _verificar),
          const SizedBox(height: EcoSpace.s16),
          if (_verificando) const LinearProgressIndicator(),
          if (_error != null)
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error, size: 20),
                const SizedBox(width: EcoSpace.s8),
                Expanded(
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                ),
              ],
            ),
          const SizedBox(height: EcoSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _restante > 0 ? null : _reenviar,
              icon: const Icon(Icons.refresh),
              label: Text(
                _restante > 0 ? 'Reenviar código en 0:${_restante.toString().padLeft(2, '0')}' : 'Reenviar código',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
