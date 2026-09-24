import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/eco_theme.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
import 'verificar_recuperacion_screen.dart';

/// Recuperar contraseña, paso 1 (04a): pedir el código al correo.
class SolicitarRecuperacionScreen extends StatefulWidget {
  const SolicitarRecuperacionScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<SolicitarRecuperacionScreen> createState() => _SolicitarRecuperacionScreenState();
}

class _SolicitarRecuperacionScreenState extends State<SolicitarRecuperacionScreen> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final correo = _correo.text.trim();
      await _auth.solicitarRecuperacionPassword(correo);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificarRecuperacionScreen(email: correo, authRepository: _auth),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('No se pudo pedir el código de recuperación: $e');
      setState(() => _error = 'No pudimos enviar el código. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recupera tu contraseña')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(EcoSpace.s16),
          children: [
            Text(
              'Te enviaremos un código de 6 dígitos al correo con el que te registraste.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: EcoSpace.s24),
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: validarCorreo,
              onFieldSubmitted: (_) => _enviar(),
              decoration: InputDecoration(labelText: 'Correo', errorText: _error, errorMaxLines: 3),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: BotonFijoInferior(
          textoBoton: 'Enviar código',
          isLoading: _enviando,
          textoLoading: 'Enviando…',
          onPressed: _enviar,
        ),
      ),
    );
  }
}
