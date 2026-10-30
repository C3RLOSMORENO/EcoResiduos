import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/autorizacion_datos_service.dart';
import '../../../theme/eco_theme.dart';
import '../widgets/casilla_autorizacion_datos.dart';
import 'politica_datos_screen.dart';

/// Antes de entrar a la app: si el usuario no ha aceptado la versión vigente
/// de la política de datos (cuentas creadas antes de pedirla, o una política
/// nueva), se la pide; sin autorización no se pueden tratar sus datos.
class PuertaAutorizacionDatos extends StatefulWidget {
  const PuertaAutorizacionDatos({
    super.key,
    required this.usuarioId,
    required this.child,
    this.servicio,
  });

  final String usuarioId;
  final Widget child;
  final AutorizacionDatosService? servicio;

  @override
  State<PuertaAutorizacionDatos> createState() => _PuertaAutorizacionDatosState();
}

class _PuertaAutorizacionDatosState extends State<PuertaAutorizacionDatos> {
  late final AutorizacionDatosService _servicio = widget.servicio ?? AutorizacionDatosService();
  late final Future<bool> _vigente = _servicio.vigente(widget.usuarioId);
  bool _aceptada = false;

  @override
  Widget build(BuildContext context) {
    if (_aceptada) return widget.child;
    return FutureBuilder<bool>(
      future: _vigente,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data!) return widget.child;
        return AutorizacionDatosScreen(
          onAceptar: () async {
            await _servicio.aceptar(widget.usuarioId);
            if (mounted) setState(() => _aceptada = true);
          },
          onRechazar: () => Supabase.instance.client.auth.signOut(),
        );
      },
    );
  }
}

/// Pide la autorización del tratamiento de datos a quien ya tiene cuenta.
class AutorizacionDatosScreen extends StatefulWidget {
  const AutorizacionDatosScreen({super.key, required this.onAceptar, required this.onRechazar});

  final Future<void> Function() onAceptar;
  final VoidCallback onRechazar;

  @override
  State<AutorizacionDatosScreen> createState() => _AutorizacionDatosScreenState();
}

class _AutorizacionDatosScreenState extends State<AutorizacionDatosScreen> {
  bool _autoriza = false;
  bool _mostrarError = false;
  bool _enviando = false;

  Future<void> _continuar() async {
    if (!_autoriza) {
      setState(() => _mostrarError = true);
      return;
    }
    setState(() => _enviando = true);
    await widget.onAceptar();
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tus datos personales'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(EcoSpace.s20),
          children: [
            Text('Antes de continuar', style: theme.textTheme.headlineSmall),
            const SizedBox(height: EcoSpace.s12),
            Text(
              'Para usar EcoResiduos necesitamos tu autorización para tratar tus datos personales, como lo exige '
              'la Ley 1581 de 2012. Usamos tus datos para publicar y coordinar las recolecciones; nunca los vendemos.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: EcoSpace.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PoliticaDatosScreen()),
                ),
                child: const Text('Leer la política completa'),
              ),
            ),
            const SizedBox(height: EcoSpace.s8),
            CasillaAutorizacionDatos(
              valor: _autoriza,
              conError: _mostrarError && !_autoriza,
              onChanged: (valor) => setState(() => _autoriza = valor),
            ),
            const SizedBox(height: EcoSpace.s24),
            FilledButton(
              onPressed: _enviando ? null : _continuar,
              child: Text(_enviando ? 'Guardando…' : 'Aceptar y continuar'),
            ),
            const SizedBox(height: EcoSpace.s8),
            TextButton(
              onPressed: _enviando ? null : widget.onRechazar,
              child: const Text('No autorizo y cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
