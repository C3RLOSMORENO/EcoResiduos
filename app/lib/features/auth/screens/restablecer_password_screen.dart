import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/eco_theme.dart';
import '../../../widgets/boton_fijo_inferior.dart';
import '../../../widgets/etiqueta_colgada.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';

/// Nueva contraseña (04d) con la lista de reglas a la vista. Tras recuperar
/// la contraseña se cierra la sesión y se muestra el éxito (04e); desde la
/// hoja de cuenta ([desdeCuenta]) solo se confirma y se vuelve.
class RestablecerPasswordScreen extends StatefulWidget {
  const RestablecerPasswordScreen({super.key, this.authRepository, this.desdeCuenta = false});

  final AuthRepository? authRepository;
  final bool desdeCuenta;

  @override
  State<RestablecerPasswordScreen> createState() => _RestablecerPasswordScreenState();
}

class _RestablecerPasswordScreenState extends State<RestablecerPasswordScreen> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nueva.addListener(() => setState(() {}));
    _confirmacion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _largoOk => _nueva.text.length >= 8;
  bool get _numeroOk => _nueva.text.contains(RegExp(r'[0-9]'));
  bool get _coinciden => _nueva.text.isNotEmpty && _nueva.text == _confirmacion.text;

  Future<void> _guardar() async {
    if (!_largoOk || !_numeroOk || !_coinciden) {
      setState(() => _error = 'Cumple las tres reglas para continuar.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _auth.actualizarPassword(_nueva.text);
      if (!mounted) return;
      if (widget.desdeCuenta) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualizamos tu contraseña.')));
        Navigator.pop(context);
        return;
      }
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (exito) => ExitoEtiquetaScreen(
            icono: Icons.lock_reset,
            titulo: 'Contraseña actualizada',
            descripcion: 'Ya puedes entrar con tu contraseña nueva.',
            accionPrincipal: 'Entrar',
            onAccionPrincipal: () => Navigator.popUntil(exito, (ruta) => ruta.isFirst),
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('No se pudo actualizar la contraseña: $e');
      setState(() => _error = 'No pudimos guardar la contraseña. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crea una contraseña nueva')),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(EcoSpace.s16),
          children: [
            CampoContrasena(
              controller: _nueva,
              etiqueta: 'Nueva contraseña',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: EcoSpace.s16),
            CampoContrasena(
              controller: _confirmacion,
              etiqueta: 'Confírmala',
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: EcoSpace.s16),
            _Regla(cumplida: _largoOk, texto: 'Al menos 8 caracteres'),
            _Regla(cumplida: _numeroOk, texto: 'Al menos un número'),
            _Regla(cumplida: _coinciden, texto: 'Las dos coinciden'),
            if (_error != null) ...[
              const SizedBox(height: EcoSpace.s12),
              Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: BotonFijoInferior(
          textoBoton: 'Guardar contraseña',
          isLoading: _guardando,
          textoLoading: 'Guardando…',
          onPressed: _guardar,
        ),
      ),
    );
  }
}

class _Regla extends StatelessWidget {
  const _Regla({required this.cumplida, required this.texto});

  final bool cumplida;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$texto: ${cumplida ? 'cumplida' : 'pendiente'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EcoSpace.s4),
        child: Row(
          children: [
            Icon(
              cumplida ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: cumplida ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: EcoSpace.s8),
            Text(texto),
          ],
        ),
      ),
    );
  }
}
