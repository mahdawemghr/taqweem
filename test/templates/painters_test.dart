import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/shared/painters.dart';

void _smoke(CustomPainter p, [Size size = const Size(1000, 2200)]) {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), size);
  rec.endRecording().dispose();
}

void main() {
  const c = Color(0xFF123456);

  test('GeometricPatternPainter paints and compares by value', () {
    _smoke(const GeometricPatternPainter(color: c));
    _smoke(const GeometricPatternPainter(color: c, cell: 0));
    // A 1-px cell is clamped to 16 px: finishes fast instead of drawing
    // ~2.2 million stars.
    final sw = Stopwatch()..start();
    _smoke(const GeometricPatternPainter(color: c, cell: 1));
    _smoke(const GeometricPatternPainter(color: c, cell: double.nan));
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    expect(
      const GeometricPatternPainter(color: c)
          .shouldRepaint(const GeometricPatternPainter(color: c)),
      isFalse,
    );
    expect(
      const GeometricPatternPainter(color: c, opacity: .2)
          .shouldRepaint(const GeometricPatternPainter(color: c)),
      isTrue,
    );
  });

  test('DoubleBorderPainter paints, incl. degenerate sizes', () {
    _smoke(const DoubleBorderPainter(color: c));
    _smoke(const DoubleBorderPainter(color: c), const Size(10, 10));
    _smoke(const DoubleBorderPainter(color: c), Size.zero);
    expect(
      const DoubleBorderPainter(color: c)
          .shouldRepaint(const DoubleBorderPainter(color: c, gap: 3)),
      isTrue,
    );
  });

  test('MosqueSilhouettePainter paints whole canvas or an area', () {
    _smoke(const MosqueSilhouettePainter(color: c));
    _smoke(const MosqueSilhouettePainter(
        color: c, area: Rect.fromLTWH(100, 1800, 800, 400)));
    _smoke(const MosqueSilhouettePainter(color: c), Size.zero);
    expect(
      const MosqueSilhouettePainter(color: c)
          .shouldRepaint(const MosqueSilhouettePainter(color: c)),
      isFalse,
    );
  });

  test('StarMedallionPainter paints with and without core fill', () {
    _smoke(const StarMedallionPainter(color: c), const Size(120, 120));
    _smoke(const StarMedallionPainter(color: c, fill: Color(0xFFFFFFFF)),
        const Size(200, 120));
    _smoke(const StarMedallionPainter(color: c), Size.zero);
    expect(
      const StarMedallionPainter(color: c).shouldRepaint(
          const StarMedallionPainter(color: c, fill: Color(0xFFFFFFFF))),
      isTrue,
    );
  });
}
