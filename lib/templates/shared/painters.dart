import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 8-point star (two overlapping squares) centred on [c] with outer
/// radius [r].
Path _eightPointStar(Offset c, double r) {
  final p = Path();
  for (var k = 0; k < 2; k++) {
    final a0 = k * math.pi / 4;
    for (var i = 0; i < 4; i++) {
      final a = a0 + i * math.pi / 2;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
  }
  return p;
}

/// Star polygon outline (16 vertices) – a filled 8-point star.
Path _starOutline(Offset c, double outer, double inner) {
  final p = Path();
  for (var i = 0; i < 16; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 8;
    final pt = c + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Repeating lattice of 8-point stars joined by diagonal links, stroked in
/// [color] at [opacity]. [cell] is the lattice pitch in logical pixels
/// (values below 16 are treated as 16).
class GeometricPatternPainter extends CustomPainter {
  const GeometricPatternPainter({
    required this.color,
    this.opacity = 0.08,
    this.cell = 80,
  });

  final Color color;
  final double opacity;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Clamp so a tiny or invalid cell can never explode the draw count.
    final cell = this.cell.isNaN ? 16.0 : math.max(this.cell, 16.0);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, cell / 60);
    final r = cell * 0.32;
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        final c = Offset(x * cell, y * cell);
        canvas.drawPath(_eightPointStar(c, r), paint);
        // Small rosette in the middle of each lattice cell.
        final m = c + Offset(cell / 2, cell / 2);
        canvas.drawPath(_eightPointStar(m, r * 0.45), paint);
        // Links from the star tips to the neighbouring rosettes.
        for (final d in const [Offset(1, 1), Offset(-1, 1)]) {
          final from = c + d * (r * 0.72);
          final to = c + d * (cell / 2 - r * 0.32);
          canvas.drawLine(from, to, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(GeometricPatternPainter old) =>
      old.color != color || old.opacity != opacity || old.cell != cell;
}

/// Outer rule plus an inner rule [gap] further in, the inner one with square
/// notches of [cornerSize] at each corner and a small diamond in every
/// notch.
class DoubleBorderPainter extends CustomPainter {
  const DoubleBorderPainter({
    required this.color,
    this.inset = 20,
    this.gap = 8,
    this.stroke = 2,
    this.cornerSize = 24,
  });

  final Color color;
  final double inset, gap, stroke, cornerSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final outer = (Offset.zero & size).deflate(inset);
    if (outer.width <= 0 || outer.height <= 0) return;
    canvas.drawRect(
      outer,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.6,
    );

    final inner = outer.deflate(gap + stroke);
    final n = math.min(cornerSize, math.min(inner.width, inner.height) / 3);
    if (inner.width <= 0 || inner.height <= 0) return;
    final l = inner.left, t = inner.top, r = inner.right, b = inner.bottom;
    final path = Path()
      ..moveTo(l + n, t)
      ..lineTo(r - n, t)
      ..lineTo(r - n, t + n)
      ..lineTo(r, t + n)
      ..lineTo(r, b - n)
      ..lineTo(r - n, b - n)
      ..lineTo(r - n, b)
      ..lineTo(l + n, b)
      ..lineTo(l + n, b - n)
      ..lineTo(l, b - n)
      ..lineTo(l, t + n)
      ..lineTo(l + n, t + n)
      ..close();
    canvas.drawPath(path, paint);

    final fill = Paint()..color = color;
    for (final c in [
      Offset(l + n / 2, t + n / 2),
      Offset(r - n / 2, t + n / 2),
      Offset(l + n / 2, b - n / 2),
      Offset(r - n / 2, b - n / 2),
    ]) {
      final d = n * 0.3;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - d)
          ..lineTo(c.dx + d, c.dy)
          ..lineTo(c.dx, c.dy + d)
          ..lineTo(c.dx - d, c.dy)
          ..close(),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(DoubleBorderPainter old) =>
      old.color != color ||
      old.inset != inset ||
      old.gap != gap ||
      old.stroke != stroke ||
      old.cornerSize != cornerSize;
}

/// Filled mosque silhouette — central onion dome on a prayer hall with
/// arched openings, flanked by two minarets — drawn inside [area]
/// (canvas coordinates; null = the whole canvas).
class MosqueSilhouettePainter extends CustomPainter {
  const MosqueSilhouettePainter({required this.color, this.area});

  final Color color;
  final Rect? area;

  @override
  void paint(Canvas canvas, Size size) {
    final a = area ?? Offset.zero & size;
    if (a.width <= 0 || a.height <= 0) return;
    final w = a.width, h = a.height;
    double x(double f) => a.left + f * w;
    double y(double f) => a.top + f * h;

    final body = Path()
      // Prayer hall.
      ..addRect(Rect.fromLTRB(x(0.2), y(0.62), x(0.8), y(1)))
      // Drum under the dome.
      ..addRect(Rect.fromLTRB(x(0.36), y(0.5), x(0.64), y(0.63)));
    // Onion dome with finial.
    final dome = Path()
      ..moveTo(x(0.33), y(0.5))
      ..cubicTo(x(0.28), y(0.36), x(0.42), y(0.26), x(0.5), y(0.16))
      ..cubicTo(x(0.58), y(0.26), x(0.72), y(0.36), x(0.67), y(0.5))
      ..close()
      ..addRect(Rect.fromLTRB(x(0.495), y(0.08), x(0.505), y(0.17)))
      ..addOval(
        Rect.fromCenter(
          center: Offset(x(0.5), y(0.075)),
          width: w * 0.03,
          height: w * 0.03,
        ),
      );
    // Two minarets: shaft, balcony and pointed cap.
    final minarets = Path();
    for (final cx in [0.1, 0.9]) {
      minarets
        ..addRect(Rect.fromLTRB(x(cx - 0.035), y(0.22), x(cx + 0.035), y(1)))
        ..addRect(Rect.fromLTRB(x(cx - 0.055), y(0.36), x(cx + 0.055), y(0.39)))
        ..moveTo(x(cx - 0.04), y(0.22))
        ..lineTo(x(cx), y(0.06))
        ..lineTo(x(cx + 0.04), y(0.22))
        ..close();
    }
    // Small side domes.
    for (final cx in [0.3, 0.7]) {
      body.addArc(
        Rect.fromCenter(
          center: Offset(x(cx), y(0.62)),
          width: w * 0.16,
          height: h * 0.16,
        ),
        math.pi,
        math.pi,
      );
    }
    var shape = Path.combine(PathOperation.union, body, dome);
    shape = Path.combine(PathOperation.union, shape, minarets);

    // Arched doorways cut out of the hall.
    final arches = Path();
    for (final cx in [0.3, 0.42, 0.5, 0.58, 0.7]) {
      final hw = cx == 0.5 ? 0.045 : 0.03;
      final top = cx == 0.5 ? 0.74 : 0.8;
      arches
        ..moveTo(x(cx - hw), y(1))
        ..lineTo(x(cx - hw), y(top + 0.04))
        ..quadraticBezierTo(x(cx - hw), y(top), x(cx), y(top - 0.03))
        ..quadraticBezierTo(x(cx + hw), y(top), x(cx + hw), y(top + 0.04))
        ..lineTo(x(cx + hw), y(1))
        ..close();
    }
    shape = Path.combine(PathOperation.difference, shape, arches);
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(MosqueSilhouettePainter old) =>
      old.color != color || old.area != area;
}

/// Emblem fallback: two rings around a filled 8-point star with a
/// contrasting core, sized to the shortest side of the canvas.
class StarMedallionPainter extends CustomPainter {
  const StarMedallionPainter({required this.color, this.fill});

  final Color color;

  /// Core colour; defaults to transparent (shows what is behind).
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 0) return;
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.04);
    canvas.drawCircle(c, r * 0.96, ring);
    canvas.drawCircle(c, r * 0.86, ring..strokeWidth = math.max(1, r * 0.02));
    final star = Path.combine(
      PathOperation.difference,
      _starOutline(c, r * 0.8, r * 0.58),
      Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.4)),
    );
    canvas.drawPath(star, Paint()..color = color);
    if (fill != null) canvas.drawCircle(c, r * 0.4, Paint()..color = fill!);
    canvas.drawPath(
      _eightPointStar(c, r * 0.32),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.03),
    );
  }

  @override
  bool shouldRepaint(StarMedallionPainter old) =>
      old.color != color || old.fill != fill;
}
