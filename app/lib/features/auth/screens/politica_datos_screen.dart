import 'package:flutter/material.dart';

import '../../../legal/politica_datos.dart';
import '../../../theme/eco_theme.dart';

/// Texto completo de la política de tratamiento de datos personales.
class PoliticaDatosScreen extends StatelessWidget {
  const PoliticaDatosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tratamiento de datos personales')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(EcoSpace.s20, EcoSpace.s16, EcoSpace.s20, EcoSpace.s40),
          children: [
            Text(
              'Política de tratamiento de datos personales de EcoResiduos, según la Ley 1581 de 2012. '
              'Versión $versionPoliticaDatos.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            for (final seccion in politicaDatos) ...[
              const SizedBox(height: EcoSpace.s24),
              Semantics(
                header: true,
                child: Text(seccion.titulo, style: theme.textTheme.titleMedium),
              ),
              for (final parrafo in seccion.parrafos)
                Padding(
                  padding: const EdgeInsets.only(top: EcoSpace.s8),
                  child: Text(parrafo, style: theme.textTheme.bodyLarge),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
