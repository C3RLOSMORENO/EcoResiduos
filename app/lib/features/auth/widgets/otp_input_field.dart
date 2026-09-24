import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/eco_theme.dart';

/// Código de 6 dígitos en cajas (04b). Un solo campo invisible recibe el
/// texto, así que se puede pegar el código completo desde el portapapeles.
class OtpInputField extends StatefulWidget {
  const OtpInputField({super.key, required this.controller, this.onCompleted, this.enabled = true, this.error = false});

  final TextEditingController controller;

  /// Se llama al escribir el sexto dígito.
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool error;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final texto = widget.controller.text;

    return Semantics(
      label: 'Código de 6 dígitos',
      value: texto,
      textField: true,
      child: GestureDetector(
        onTap: () => _foco.requestFocus(),
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(width: EcoSpace.s8),
                  Expanded(
                    child: AnimatedContainer(
                      duration: EcoMotion.duracion(context, EcoMotion.estado),
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(EcoRadius.small),
                        border: Border.all(
                          width: 2,
                          color: widget.error
                              ? scheme.error
                              : (_foco.hasFocus && i == texto.length.clamp(0, 5) ? scheme.primary : Colors.transparent),
                        ),
                      ),
                      child: Text(
                        i < texto.length ? texto[i] : '',
                        style: theme.textTheme.displaySmall?.copyWith(fontSize: 30),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _foco,
                  enabled: widget.enabled,
                  autofocus: true,
                  showCursor: false,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  onChanged: (valor) {
                    setState(() {});
                    if (valor.length == 6) widget.onCompleted?.call(valor);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
