import 'package:flutter/material.dart';

import '../../../theme/eco_theme.dart';
import '../screens/politica_datos_screen.dart';

/// Casilla de autorización del tratamiento de datos personales. La Ley 1581
/// de 2012 exige que sea previa, expresa e informada: no viene marcada y
/// enlaza la política completa.
class CasillaAutorizacionDatos extends StatelessWidget {
  const CasillaAutorizacionDatos({
    super.key,
    required this.valor,
    required this.onChanged,
    this.conError = false,
  });

  final bool valor;
  final ValueChanged<bool> onChanged;
  final bool conError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: valor,
                isError: conError,
                onChanged: (nuevo) => onChanged(nuevo ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(!valor),
                  child: Padding(
                    padding: const EdgeInsets.only(top: EcoSpace.s12),
                    child: Text(
                      'Autorizo a EcoResiduos a tratar mis datos personales para las finalidades descritas en la '
                      'política de tratamiento de datos.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: EcoSpace.s40),
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PoliticaDatosScreen()),
            ),
            child: const Text('Leer la política de tratamiento de datos'),
          ),
        ),
        if (conError)
          Padding(
            padding: const EdgeInsets.only(left: EcoSpace.s12),
            child: Text(
              'Para crear la cuenta debes autorizar el tratamiento de tus datos.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
