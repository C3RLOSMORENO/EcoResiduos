import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';

/// Un paso del recorrido: apunta a un widget por [GlobalKey] y lleva título y texto.
class CoachMarkPaso {
  const CoachMarkPaso({
    required this.keyObjetivo,
    required this.titulo,
    required this.descripcion,
    this.nota,
    this.forma = FormaSpotlight.redondeo,
  });

  final GlobalKey keyObjetivo;
  final String titulo;
  final String descripcion;
  final String? nota;
  final FormaSpotlight forma;
}

enum FormaSpotlight { redondeo, circulo }

/// Muestra el recorrido de coach marks sobre la pantalla actual.
/// Los pasos cuyo objetivo no esté en el árbol se omiten silenciosamente.
void mostrarCoachMarks(BuildContext context, List<CoachMarkPaso> pasos) {
  final visibles = pasos.where((p) => _bounds(p.keyObjetivo) != null).toList();
  if (visibles.isEmpty) return;

  late OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _RecorridoOverlay(
      pasos: visibles,
      onFin: () => entrada.remove(),
    ),
  );
  Overlay.of(context).insert(entrada);
}

Rect? _bounds(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final obj = ctx.findRenderObject();
  if (obj == null || !obj.attached) return null;
  final box = obj as RenderBox;
  if (!box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

// ─── Overlay principal ────────────────────────────────────────────────────────

class _RecorridoOverlay extends StatefulWidget {
  const _RecorridoOverlay({required this.pasos, required this.onFin});
  final List<CoachMarkPaso> pasos;
  final VoidCallback onFin;

  @override
  State<_RecorridoOverlay> createState() => _RecorridoOverlayState();
}

class _RecorridoOverlayState extends State<_RecorridoOverlay>
    with SingleTickerProviderStateMixin {
  int _indice = 0;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  CoachMarkPaso get _paso => widget.pasos[_indice];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _avanzar() {
    if (_indice < widget.pasos.length - 1) {
      _ctrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _indice++);
        _ctrl.forward();
      });
    } else {
      _ctrl.reverse().then((_) => widget.onFin());
    }
  }

  void _saltar() {
    _ctrl.reverse().then((_) => widget.onFin());
  }

  @override
  Widget build(BuildContext context) {
    final target = _bounds(_paso.keyObjetivo);
    if (target == null) {
      _avanzar();
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    final enCimaMitad = target.center.dy < size.height / 2;
    final esUltimo = _indice == widget.pasos.length - 1;
    final numero = '${_indice + 1} de ${widget.pasos.length}';

    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        return Stack(
          children: [
            // Máscara con hueco iluminado
            Positioned.fill(
              child: GestureDetector(
                onTap: _avanzar,
                child: CustomPaint(
                  painter: _PinturaMascara(
                    hueco: target,
                    radio: _paso.forma == FormaSpotlight.circulo
                        ? target.shortestSide / 2 + 12
                        : 16,
                    circulo: _paso.forma == FormaSpotlight.circulo,
                    opacidad: 0.78 * _anim.value,
                  ),
                ),
              ),
            ),
            // Globo de texto
            _Globo(
              paso: _paso,
              target: target,
              enCimaMitad: enCimaMitad,
              esUltimo: esUltimo,
              numero: numero,
              opacidad: _anim.value,
              onSiguiente: _avanzar,
              onSaltar: _saltar,
            ),
          ],
        );
      },
    );
  }
}

// ─── Globo de texto ───────────────────────────────────────────────────────────

class _Globo extends StatelessWidget {
  const _Globo({
    required this.paso,
    required this.target,
    required this.enCimaMitad,
    required this.esUltimo,
    required this.numero,
    required this.opacidad,
    required this.onSiguiente,
    required this.onSaltar,
  });

  final CoachMarkPaso paso;
  final Rect target;
  final bool enCimaMitad;
  final bool esUltimo;
  final String numero;
  final double opacidad;
  final VoidCallback onSiguiente;
  final VoidCallback onSaltar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final screenW = MediaQuery.sizeOf(context).width;
    const padding = 16.0;
    const globoW = 280.0;

    // Centrado sobre el target, clamped a los bordes
    double left = target.center.dx - globoW / 2;
    left = left.clamp(padding, screenW - globoW - padding);

    final top = enCimaMitad
        ? target.bottom + 16        // Globo debajo del target
        : (target.top - 220.0).clamp(padding, double.infinity); // Globo arriba

    return Positioned(
      left: left,
      top: top,
      width: globoW,
      child: Opacity(
        opacity: opacidad,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(EcoSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Número de paso
                Text(
                  numero,
                  style: text.labelSmall?.copyWith(
                    color: colors.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: EcoSpace.s4),
                // Título
                Text(
                  paso.titulo,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: EcoSpace.s8),
                // Descripción
                Text(
                  paso.descripcion,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                // Nota opcional
                if (paso.nota != null) ...[
                  const SizedBox(height: EcoSpace.s8),
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined, size: 14, color: colors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          paso.nota!,
                          style: text.labelSmall?.copyWith(color: colors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: EcoSpace.s16),
                // Botones
                Row(
                  children: [
                    if (!esUltimo)
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(vertical: EcoSpace.s8),
                          ),
                          onPressed: onSaltar,
                          child: const Text('Saltar'),
                        ),
                      ),
                    Expanded(
                      flex: esUltimo ? 1 : 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: EcoSpace.s8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onSiguiente,
                        child: Text(esUltimo ? 'Entendido' : 'Siguiente'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pintura de máscara ───────────────────────────────────────────────────────

class _PinturaMascara extends CustomPainter {
  const _PinturaMascara({
    required this.hueco,
    required this.radio,
    required this.circulo,
    required this.opacidad,
  });

  final Rect hueco;
  final double radio;
  final bool circulo;
  final double opacidad;

  static const _padding = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Paint()..color = Color.fromRGBO(0, 0, 0, opacidad);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final objetivo = hueco.inflate(_padding);

    final ruta = Path()..fillType = PathFillType.evenOdd;
    ruta.addRect(rect);

    if (circulo) {
      ruta.addOval(objetivo);
    } else {
      ruta.addRRect(RRect.fromRectAndRadius(objetivo, Radius.circular(radio)));
    }

    canvas.drawPath(ruta, fondo);

    // Borde brillante alrededor del hueco
    final borde = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * opacidad)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (circulo) {
      canvas.drawOval(objetivo, borde);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(objetivo, Radius.circular(radio)),
        borde,
      );
    }
  }

  @override
  bool shouldRepaint(_PinturaMascara old) =>
      old.hueco != hueco || old.radio != radio || old.opacidad != opacidad;
}
