import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/eco_theme.dart';

/// Campo de contraseña con botón para mostrarla u ocultarla. [ayuda] dice la
/// regla antes de escribir; [errorText] la muestra en rojo en el mismo sitio
/// cuando no se cumple.
class CampoContrasena extends StatefulWidget {
  const CampoContrasena({
    super.key,
    required this.controller,
    this.etiqueta = 'Contraseña',
    this.ayuda,
    this.validator,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.fillColor,
  });

  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
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
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      inputFormatters: [LengthLimitingTextInputFormatter(largoContrasena)],
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        helperMaxLines: 2,
        errorText: widget.errorText,
        errorMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        filled: widget.fillColor != null,
        fillColor: widget.fillColor,
        border: widget.fillColor != null
            ? OutlineInputBorder(borderRadius: BorderRadius.circular(EcoRadius.medium), borderSide: BorderSide.none)
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

/// Reglas de contraseña: al menos 8 caracteres, con letras y números. Son las
/// mismas que se configuran en Supabase Auth (Minimum password length y
/// Password requirements), que las aplica aunque alguien no use la app.
String? validarContrasena(String? valor) {
  final texto = valor ?? '';
  if (texto.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
  if (texto.length > largoContrasena) return 'La contraseña puede tener máximo $largoContrasena caracteres';
  if (!texto.contains(RegExp(r'[0-9]'))) return 'La contraseña debe tener al menos un número';
  if (!texto.contains(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]'))) return 'La contraseña debe tener al menos una letra';
  return null;
}

/// Máximo que admite Supabase Auth (bcrypt solo usa los primeros 72 bytes).
const largoContrasena = 72;

/// Segunda escritura de la contraseña al registrarse.
String? validarConfirmacion(String contrasena, String? confirmacion) {
  if ((confirmacion ?? '').isEmpty) return 'Vuelve a escribir la contraseña';
  return confirmacion == contrasena ? null : 'Las contraseñas no coinciden';
}

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$');

/// Validador de [TextFormField] para el correo: devuelve el mensaje de error, o
/// null si el correo es válido.
String? validarCorreo(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu correo';
  if (!_correoValido.hasMatch(texto)) return 'Escribe un correo válido, por ejemplo ana@gmail.com';
  return null;
}
