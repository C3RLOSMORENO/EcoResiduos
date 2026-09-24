import 'package:flutter/material.dart';

/// Firma visual de EcoResiduos: Borde con forma de etiqueta de residuo.
///
/// Presenta esquinas redondeadas en 3 vértices y un corte a 45° en el vértice
/// superior derecho, con opción de un ojal circular recortado (vaciado real
/// con `PathOperation.difference`).
class EtiquetaBorder extends OutlinedBorder {
  const EtiquetaBorder({
    this.radius = 12.0,
    this.cut = 16.0,
    this.hole = 0.0,
    this.holeCenter = const Offset(26, 26),
    super.side,
  });

  final double radius;
  final double cut;
  final double hole;
  final Offset holeCenter;

  Path _path(Rect r) {
    final p = Path()
      ..moveTo(r.left + radius, r.top)
      ..lineTo(r.right - cut, r.top)
      ..lineTo(r.right, r.top + cut)
      ..lineTo(r.right, r.bottom - radius)
      ..arcToPoint(Offset(r.right - radius, r.bottom), radius: Radius.circular(radius))
      ..lineTo(r.left + radius, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - radius), radius: Radius.circular(radius))
      ..lineTo(r.left, r.top + radius)
      ..arcToPoint(Offset(r.left + radius, r.top), radius: Radius.circular(radius))
      ..close();

    if (hole <= 0) return p;
    final o = Path()..addOval(Rect.fromCircle(center: r.topLeft + holeCenter, radius: hole));
    return Path.combine(PathOperation.difference, p, o);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  void paint(Canvas c, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    c.drawPath(_path(rect), side.toPaint());
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      EtiquetaBorder(radius: radius * t, cut: cut * t, hole: hole * t, holeCenter: holeCenter * t, side: side.scale(t));

  @override
  EtiquetaBorder copyWith({BorderSide? side, double? radius, double? cut, double? hole, Offset? holeCenter}) =>
      EtiquetaBorder(
        radius: radius ?? this.radius,
        cut: cut ?? this.cut,
        hole: hole ?? this.hole,
        holeCenter: holeCenter ?? this.holeCenter,
        side: side ?? this.side,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is EtiquetaBorder &&
        other.side == side &&
        other.radius == radius &&
        other.cut == cut &&
        other.hole == hole &&
        other.holeCenter == holeCenter;
  }

  @override
  int get hashCode => Object.hash(side, radius, cut, hole, holeCenter);
}

/// Etiqueta colgante de los chips de categoría: punta a la izquierda con
/// ojal y esquinas redondeadas a la derecha.
class EtiquetaChipBorder extends OutlinedBorder {
  const EtiquetaChipBorder({this.tip = 9, this.radius = 8, this.hole = 3, super.side});

  final double tip;
  final double radius;
  final double hole;

  Path _path(Rect r) {
    final p = Path()
      ..moveTo(r.left + tip, r.top)
      ..lineTo(r.right - radius, r.top)
      ..arcToPoint(Offset(r.right, r.top + radius), radius: Radius.circular(radius))
      ..lineTo(r.right, r.bottom - radius)
      ..arcToPoint(Offset(r.right - radius, r.bottom), radius: Radius.circular(radius))
      ..lineTo(r.left + tip, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
    if (hole <= 0) return p;
    final ojal = Path()..addOval(Rect.fromCircle(center: Offset(r.left + tip + 3, r.center.dy), radius: hole));
    return Path.combine(PathOperation.difference, p, ojal);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect), side.toPaint());
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      EtiquetaChipBorder(tip: tip * t, radius: radius * t, hole: hole * t, side: side.scale(t));

  @override
  EtiquetaChipBorder copyWith({BorderSide? side}) =>
      EtiquetaChipBorder(tip: tip, radius: radius, hole: hole, side: side ?? this.side);

  @override
  bool operator ==(Object other) =>
      other is EtiquetaChipBorder &&
      other.side == side &&
      other.tip == tip &&
      other.radius == radius &&
      other.hole == hole;

  @override
  int get hashCode => Object.hash(side, tip, radius, hole);
}
