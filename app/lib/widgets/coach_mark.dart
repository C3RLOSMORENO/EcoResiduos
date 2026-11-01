import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Un paso del recorrido. Con [keyObjetivo] ilumina ese elemento de la
/// pantalla; con [CoachMarkPaso.bienvenida] es una tarjeta centrada, sin
/// elemento, para presentar la app antes de señalar nada.
class CoachMarkPaso {
  const CoachMarkPaso({
    required GlobalKey this.keyObjetivo,
    required this.titulo,
    required this.descripcion,
    this.nota,
    this.forma = FormaSpotlight.redondeo,
  }) : puntos = const [];

  const CoachMarkPaso.bienvenida({
    required this.titulo,
    required this.descripcion,
    this.puntos = const [],
    this.nota,
  })  : keyObjetivo = null,
        forma = FormaSpotlight.redondeo;

  final GlobalKey? keyObjetivo;
  final String titulo;
  final String descripcion;

  /// Lista numerada bajo la descripción (por ejemplo, los pasos del proceso).
  final List<String> puntos;
  final String? nota;
  final FormaSpotlight forma;
}

enum FormaSpotlight { redondeo, circulo }

/// Muestra el recorrido sobre la pantalla actual. Es una ruta transparente,
/// no una capa suelta: el botón Atrás del sistema lo cierra (como «Saltar») en
/// lugar de navegar por debajo, y TalkBack lo anuncia como pantalla.
///
/// Los pasos cuyo elemento no está en pantalla se omiten. Devuelve true si se
/// mostró (y se terminó o se saltó), false si no había nada que mostrar.
Future<bool> mostrarCoachMarks(BuildContext context, List<CoachMarkPaso> pasos) async {
  final visibles = pasos.where((p) => p.keyObjetivo == null || _limites(p.keyObjetivo!) != null).toList();
  if (visibles.isEmpty) return false;

  final duracion = EcoMotion.duracion(context, EcoMotion.estado);
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: duracion,
      reverseTransitionDuration: duracion,
      pageBuilder: (_, _, _) => _Recorrido(pasos: visibles),
      transitionsBuilder: (_, animacion, _, hijo) => FadeTransition(opacity: animacion, child: hijo),
    ),
  );
  return true;
}

/// Rectángulo del elemento en coordenadas de pantalla, o null si no está montado.
Rect? _limites(GlobalKey key) {
  final objeto = key.currentContext?.findRenderObject();
  if (objeto is! RenderBox || !objeto.attached || !objeto.hasSize) return null;
  return objeto.localToGlobal(Offset.zero) & objeto.size;
}

// ─── Recorrido ────────────────────────────────────────────────────────────────

class _Recorrido extends StatefulWidget {
  const _Recorrido({required this.pasos});

  final List<CoachMarkPaso> pasos;

  @override
  State<_Recorrido> createState() => _RecorridoState();
}

class _RecorridoState extends State<_Recorrido> with SingleTickerProviderStateMixin {
  int _indice = 0;

  // El hueco se desliza de un elemento al siguiente: [_desde] es donde estaba
  // y [_hasta] donde termina; null es «sin hueco» (la tarjeta de bienvenida).
  late final AnimationController _movimiento = AnimationController(vsync: this);
  Rect? _desde;
  Rect? _hasta;

  CoachMarkPaso get _paso => widget.pasos[_indice];
  bool get _esUltimo => _indice == widget.pasos.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _irA(0));
  }

  @override
  void dispose() {
    _movimiento.dispose();
    super.dispose();
  }

  Future<void> _irA(int indice) async {
    final paso = widget.pasos[indice];
    final contexto = paso.keyObjetivo?.currentContext;
    final duracion = EcoMotion.duracion(context, EcoMotion.pantalla);
    // Si el elemento está fuera de la vista (más abajo en una lista), se
    // desplaza hasta él antes de iluminarlo.
    if (contexto != null) {
      await Scrollable.ensureVisible(contexto, alignment: 0.4, duration: duracion);
    }
    if (!mounted) return;
    final destino = paso.keyObjetivo == null ? null : _limites(paso.keyObjetivo!);
    setState(() {
      _desde = _huecoActual;
      _hasta = destino;
      _indice = indice;
    });
    _movimiento.duration = duracion;
    await _movimiento.forward(from: 0);
  }

  /// Hueco a mitad de la animación entre el paso anterior y el actual.
  Rect? get _huecoActual {
    final t = Curves.easeInOutCubic.transform(_movimiento.value);
    final desde = _desde ?? (_hasta == null ? null : Rect.fromCenter(center: _hasta!.center, width: 0, height: 0));
    final hasta = _hasta ?? (_desde == null ? null : Rect.fromCenter(center: _desde!.center, width: 0, height: 0));
    if (desde == null || hasta == null) return null;
    return Rect.lerp(desde, hasta, t);
  }

  void _siguiente() => _esUltimo ? Navigator.of(context).pop() : _irA(_indice + 1);
  void _anterior() => _irA(_indice - 1);
  void _saltar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final relleno = MediaQuery.paddingOf(context);
    return AnimatedBuilder(
      animation: _movimiento,
      builder: (context, _) {
        // Sin animación en curso se mide de nuevo: si la pantalla giró o la
        // lista se movió, el hueco sigue al elemento.
        final medido = _paso.keyObjetivo == null ? null : _limites(_paso.keyObjetivo!);
        final hueco = _movimiento.isAnimating ? _huecoActual : medido;
        return Stack(
          children: [
            // La máscara no avanza al tocarla: avanzar por accidente hacía
            // perder pasos. Se avanza con los botones.
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: _PinturaMascara(hueco: hueco, circulo: _paso.forma == FormaSpotlight.circulo),
                  ),
                ),
              ),
            ),
            CustomSingleChildLayout(
              delegate: _PosicionTarjeta(objetivo: hueco, relleno: relleno),
              child: _Tarjeta(
                key: ValueKey(_indice),
                paso: _paso,
                indice: _indice,
                total: widget.pasos.length,
                onAnterior: _indice > 0 ? _anterior : null,
                onSiguiente: _siguiente,
                onSaltar: _esUltimo ? null : _saltar,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Posición de la tarjeta ───────────────────────────────────────────────────

/// Debajo del elemento si cabe, si no encima, y si no en el borde con más
/// espacio; siempre dentro de la pantalla y sin tapar la barra del sistema.
/// Usa la altura real de la tarjeta, no una estimada.
class _PosicionTarjeta extends SingleChildLayoutDelegate {
  const _PosicionTarjeta({required this.objetivo, required this.relleno});

  final Rect? objetivo;
  final EdgeInsets relleno;

  static const _margen = 16.0;
  static const _separacion = 18.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final ancho = (constraints.maxWidth - 2 * _margen).clamp(0.0, 380.0);
    return BoxConstraints(maxWidth: ancho, minWidth: ancho, maxHeight: constraints.maxHeight - relleno.vertical - 2 * _margen);
  }

  @override
  Offset getPositionForChild(Size pantalla, Size tarjeta) {
    final arriba = relleno.top + _margen;
    final abajo = pantalla.height - relleno.bottom - _margen;
    final objetivo = this.objetivo;
    if (objetivo == null || objetivo.isEmpty) {
      return Offset((pantalla.width - tarjeta.width) / 2, (pantalla.height - tarjeta.height) / 2);
    }
    final x = (objetivo.center.dx - tarjeta.width / 2).clamp(_margen, pantalla.width - tarjeta.width - _margen);
    final debajo = objetivo.bottom + _separacion;
    final encima = objetivo.top - _separacion - tarjeta.height;
    final double y;
    if (debajo + tarjeta.height <= abajo) {
      y = debajo;
    } else if (encima >= arriba) {
      y = encima;
    } else {
      // El elemento es muy alto: la tarjeta va al borde con más espacio libre.
      y = (objetivo.top - arriba > abajo - objetivo.bottom) ? arriba : abajo - tarjeta.height;
    }
    return Offset(x, y.clamp(arriba, (abajo - tarjeta.height).clamp(arriba, double.infinity)));
  }

  @override
  bool shouldRelayout(_PosicionTarjeta old) => old.objetivo != objetivo || old.relleno != relleno;
}

// ─── Tarjeta ──────────────────────────────────────────────────────────────────

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    super.key,
    required this.paso,
    required this.indice,
    required this.total,
    required this.onSiguiente,
    this.onAnterior,
    this.onSaltar,
  });

  final CoachMarkPaso paso;
  final int indice;
  final int total;
  final VoidCallback onSiguiente;
  final VoidCallback? onAnterior;
  final VoidCallback? onSaltar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colores = theme.colorScheme;
    final texto = theme.textTheme;
    final esUltimo = indice == total - 1;
    final esBienvenida = paso.keyObjetivo == null;

    return Semantics(
      container: true,
      liveRegion: true,
      explicitChildNodes: true,
      label: 'Recorrido, paso ${indice + 1} de $total',
      child: Material(
        color: colores.surface,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(EcoRadius.extraLarge),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(EcoSpace.s20, EcoSpace.s12, EcoSpace.s12, EcoSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Paso ${indice + 1} de $total',
                      style: texto.labelMedium?.copyWith(color: colores.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (onSaltar != null)
                    TextButton(onPressed: onSaltar, child: const Text('Saltar recorrido')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: EcoSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (esBienvenida) ...[
                      Icon(Icons.recycling, size: 40, color: colores.primary),
                      const SizedBox(height: EcoSpace.s8),
                    ],
                    Semantics(
                      header: true,
                      child: Text(paso.titulo, style: esBienvenida ? texto.headlineSmall : texto.titleLarge),
                    ),
                    const SizedBox(height: EcoSpace.s8),
                    Text(paso.descripcion, style: texto.bodyLarge?.copyWith(height: 1.4)),
                    for (final (i, punto) in paso.puntos.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: EcoSpace.s12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: colores.primaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: texto.labelMedium?.copyWith(color: colores.onPrimaryContainer),
                              ),
                            ),
                            const SizedBox(width: EcoSpace.s12),
                            Expanded(child: Text(punto, style: texto.bodyMedium)),
                          ],
                        ),
                      ),
                    if (paso.nota != null) ...[
                      const SizedBox(height: EcoSpace.s12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 18, color: colores.primary),
                          const SizedBox(width: EcoSpace.s8),
                          Expanded(
                            child: Text(paso.nota!, style: texto.bodySmall?.copyWith(color: colores.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: EcoSpace.s16),
                    _Progreso(indice: indice, total: total),
                    const SizedBox(height: EcoSpace.s12),
                    Row(
                      children: [
                        if (onAnterior != null) TextButton(onPressed: onAnterior, child: const Text('Anterior')),
                        const Spacer(),
                        FilledButton(
                          autofocus: true,
                          onPressed: onSiguiente,
                          child: Text(esUltimo ? 'Listo' : (esBienvenida && indice == 0 ? 'Empezar' : 'Siguiente')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puntos de progreso: el actual es más largo. Solo visual; el texto «Paso
/// N de M» ya lo dice para los lectores de pantalla.
class _Progreso extends StatelessWidget {
  const _Progreso({required this.indice, required this.total});

  final int indice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final duracion = EcoMotion.duracion(context, EcoMotion.estado);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: duracion,
              margin: const EdgeInsets.only(right: 6),
              width: i == indice ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= indice ? colores.primary : colores.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Máscara ──────────────────────────────────────────────────────────────────

/// Oscurece la pantalla menos el hueco del elemento, con un borde claro
/// alrededor. Sin hueco (bienvenida) oscurece todo.
class _PinturaMascara extends CustomPainter {
  const _PinturaMascara({required this.hueco, required this.circulo});

  final Rect? hueco;
  final bool circulo;

  static const _holgura = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final ruta = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final hueco = this.hueco;
    if (hueco == null || hueco.isEmpty) {
      canvas.drawPath(ruta, fondo);
      return;
    }

    final objetivo = hueco.inflate(_holgura);
    final forma = circulo
        ? RRect.fromRectAndRadius(objetivo, Radius.circular(objetivo.shortestSide / 2))
        : RRect.fromRectAndRadius(objetivo, const Radius.circular(16));
    ruta.addRRect(forma);
    canvas.drawPath(ruta, fondo);
    canvas.drawRRect(
      forma,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PinturaMascara old) => old.hueco != hueco || old.circulo != circulo;
}
