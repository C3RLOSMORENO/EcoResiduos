import 'package:flutter/material.dart';
import '../../../theme/eco_theme.dart';

/// Campo de contraseña con botón para mostrarla u ocultarla.
class CampoContrasena extends StatefulWidget {
  const CampoContrasena({
    super.key,
    required this.controller,
    this.etiqueta = 'Contraseña',
    this.ayuda,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.fillColor,
  });

  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;
  final Color? fillColor;

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculta,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: widget.etiqueta,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        filled: widget.fillColor != null,
        fillColor: widget.fillColor,
        border: widget.fillColor != null 
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(EcoRadius.medium),
              borderSide: BorderSide.none,
            )
          : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        suffixIcon: IconButton(
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    );
  }
}

/// Reglas de contraseña: al menos 8 caracteres y un número.
String? validarContrasena(String? valor) {
  final texto = valor ?? '';
  if (texto.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
  if (!texto.contains(RegExp(r'[0-9]'))) return 'La contraseña debe tener al menos un número';
  return null;
}

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validarCorreo(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu correo';
  if (!_correoValido.hasMatch(texto)) return 'Ingresa un correo electrónico válido';
  return null;
}
