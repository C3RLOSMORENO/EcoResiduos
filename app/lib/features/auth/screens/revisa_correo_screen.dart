import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/eco_theme.dart';
import '../../../widgets/empty_state_widget.dart';

/// Revisa tu correo (03f). La activación es por enlace; el reenvío se
/// habilita a los 60 s y «Cambiar correo» vuelve al formulario.
class RevisaCorreoScreen extends StatefulWidget {
  const RevisaCorreoScreen({super.key, required this.email, required this.onReenviar});

  final String email;
  final Future<void> Function() onReenviar;

  @override
  State<RevisaCorreoScreen> createState() => _RevisaCorreoScreenState();
}

class _RevisaCorreoScreenState extends State<RevisaCorreoScreen> {
  static const _espera = 60;

  Timer? _timer;
  int _restante = _espera;
  bool _reenviando = false;

  @override
  void initState() {
    super.initState();
    _iniciarEspera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarEspera() {
    _timer?.cancel();
    setState(() => _restante = _espera);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _restante--);
      if (_restante <= 0) timer.cancel();
    });
  }

  Future<void> _reenviar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reenviando = true);
    try {
      await widget.onReenviar();
      _iniciarEspera();
      messenger.showSnackBar(
        const SnackBar(content: Text('Enviamos un enlace nuevo. Revisa también la carpeta de spam.')),
      );
    } catch (e) {
      debugPrint('No se pudo reenviar el enlace: $e');
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos reenviar el enlace. Inténtalo más tarde.')));
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutos = _restante ~/ 60;
    final segundos = (_restante % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(),
      body: EstadoDesplazable(
        child: Column(
          children: [
            EmptyStateWidget(
              icon: Icons.mark_email_unread_outlined,
              tono: TonoEstado.exito,
              title: 'Revisa tu correo',
              description:
                  'Te enviamos un enlace a ${widget.email}. Ábrelo desde este teléfono para activar tu cuenta.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => launchUrl(Uri(scheme: 'mailto'), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir app de correo'),
                  ),
                  const SizedBox(height: EcoSpace.s8),
                  OutlinedButton(
                    onPressed: _restante > 0 || _reenviando ? null : _reenviar,
                    child: Text(_restante > 0 ? 'Reenviar enlace en $minutos:$segundos' : 'Reenviar enlace'),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cambiar correo')),
                  TextButton(
                    onPressed: () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
                    child: Text('Ya la activé, iniciar sesión', style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
