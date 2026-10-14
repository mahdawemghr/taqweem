import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/brand/svg_path.dart';

void main() {
  test('absolute and relative commands give the same bounds', () {
    final a = parseSvgPath('M10 10 L30 10 L30 20 L10 20 Z');
    final r = parseSvgPath('m10 10 l20 0 l0 10 l-20 0 z');
    expect(a.getBounds(), const Rect.fromLTRB(10, 10, 30, 20));
    expect(r.getBounds(), a.getBounds());
  });

  test('implicit repeats and compact number forms', () {
    final p = parseSvgPath('M0 0 10 0 10 10 1.5.5-1-2Z');
    expect(p.getBounds().right, 10);
    expect(p.contains(const Offset(5, 2)), isTrue);
  });

  test('curves and H/V are supported; default fill is even-odd', () {
    final p = parseSvgPath('M0 0 H20 V20 C20 30 0 30 0 20 Z');
    expect(p.fillType, PathFillType.evenOdd);
    expect(p.getBounds().bottom, greaterThan(20));
  });

  test('arcs and malformed data throw FormatException', () {
    expect(() => parseSvgPath('M0 0 A5 5 0 0 1 10 10'), throwsFormatException);
    expect(() => parseSvgPath('10 10 L5 5'), throwsFormatException);
  });
}
