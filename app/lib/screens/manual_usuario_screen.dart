import 'package:flutter/material.dart';

import '../data/manual_usuario.dart';
import '../legal/politica_datos.dart' show correoDatosPersonales;
import '../theme/eco_theme.dart';
import '../widgets/recorrido_bienvenida.dart' show reiniciarRecorridos;

/// Manual de uso (Apéndice E del libro) para el rol de la sesión. Se abre
/// desde la hoja de cuenta y funciona sin internet.
class ManualUsuarioScreen extends StatelessWidget {
  const ManualUsuarioScreen({super.key, required this.esGestor});

  final bool esGestor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secciones = esGestor ? manualGestor : manualGenerador;
    final preguntas = esGestor ? preguntasGestor : preguntasGenerador;

    return Scaffold(
      appBar: AppBar(title: const Text('Manual de uso')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(EcoSpace.s16, EcoSpace.s8, EcoSpace.s16, EcoSpace.s40),
        children: [
          Text(
            esGestor ? 'Guía para gestores certificados' : 'Guía para quienes tienen residuos',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: EcoSpace.s4),
          Text(
            'Actualizado el $manualActualizado',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: EcoSpace.s12),
          Text(
            'Toca cada tema para ver los pasos. Los nombres en negrita son los botones y pantallas de la app, y los pasos '
            'numerados se siguen en orden.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: EcoSpace.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.tour_outlined),
              label: const Text('Ver el recorrido en pantalla'),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await reiniciarRecorridos();
                navigator.pop();
              },
            ),
          ),
          const SizedBox(height: EcoSpace.s16),
          _Aviso(texto: esGestor ? avisoDatosGestor : avisoDatosGenerador),
          const SizedBox(height: EcoSpace.s16),
          for (final seccion in secciones) _TarjetaSeccion(seccion: seccion),
          const SizedBox(height: EcoSpace.s24),
          Text('Preguntas frecuentes', style: theme.textTheme.titleMedium),
          const SizedBox(height: EcoSpace.s8),
          for (final p in preguntas) _TarjetaPregunta(pregunta: p),
          const SizedBox(height: EcoSpace.s24),
          Text('Soporte', style: theme.textTheme.titleMedium),
          const SizedBox(height: EcoSpace.s8),
          Text(
            'Si algo no funciona como dice este manual, escribe a este correo con la pantalla en la que estabas, '
            'lo que intentabas hacer y el mensaje que apareció:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: EcoSpace.s4),
          SelectableText(
            correoDatosPersonales,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSeccion extends StatelessWidget {
  const _TarjetaSeccion({required this.seccion});

  final SeccionManual seccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: EcoSpace.s8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(seccion.icono, color: scheme.primary),
        title: Text(seccion.titulo, style: theme.textTheme.titleSmall),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (seccion.intro != null) TextoManual(seccion.intro!),
          for (var i = 0; i < seccion.pasos.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: EcoSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: EcoSpace.s12, top: 1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(label: 'Paso ${i + 1}', child: TextoManual(seccion.pasos[i])),
                  ),
                ],
              ),
            ),
          for (final nota in seccion.notas)
            Padding(padding: const EdgeInsets.only(top: EcoSpace.s12), child: TextoManual(nota)),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: 'Aviso sobre tus datos',
      child: Container(
        padding: const EdgeInsets.all(EcoSpace.s12),
        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(EcoRadius.small)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, color: scheme.onSecondaryContainer),
            const SizedBox(width: EcoSpace.s12),
            Expanded(
              child: Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPregunta extends StatelessWidget {
  const _TarjetaPregunta({required this.pregunta});

  final PreguntaManual pregunta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: EcoSpace.s8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(pregunta.pregunta, style: theme.textTheme.titleSmall),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(EcoSpace.s16, 0, EcoSpace.s16, EcoSpace.s16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [TextoManual(pregunta.respuesta)],
      ),
    );
  }
}

/// Muestra un texto del manual con lo que va entre `**` en negrita.
class TextoManual extends StatelessWidget {
  const TextoManual(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium;
    final partes = texto.split('**');
    return Text.rich(
      TextSpan(
        style: estilo,
        children: [
          for (var i = 0; i < partes.length; i++)
            if (partes[i].isNotEmpty)
              TextSpan(text: partes[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ],
      ),
    );
  }
}
