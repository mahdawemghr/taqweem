import 'dart:ui' show PictureRecorder;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/deep_green.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

void main() {
  const tpl = DeepGreenTemplate();
  final t = tpl.theme;

  test('id, Arabic name and registration after minimal_modern', () {
    expect(tpl.id, 'deep_green');
    expect(tpl.nameAr, 'أخضر إسلامي');
    final ids = allTemplates.map((e) => e.id).toList();
    expect(ids.first, 'navy_gold');
    expect(ids.indexOf('deep_green'), ids.indexOf('mosque_blue') + 1);
    expect(templateById('deep_green'), isA<DeepGreenTemplate>());
  });

  test('palette values are exact (plan Task 19)', () {
    expect(t.background, const Color(0xFF0A3B2C));
    expect(t.frameColor, const Color(0xFFD4AF37));
    expect(t.accent, const Color(0xFFD4AF37));
    expect(t.titleColor, const Color(0xFFF3E3A1));
    expect(t.bodyText, const Color(0xFFF6F1DC));
    expect(t.tableHeaderBg, const Color(0xFF0F5A43));
    expect(t.tableHeaderFg, const Color(0xFFF3E3A1));
    expect(t.rowBg, const Color(0xFFF4F1E1));
    expect(t.rowAltBg, const Color(0xFFE6E3CE));
    expect(t.rowText, const Color(0xFF0A3B2C));
    expect(t.gridLine, const Color(0xFFB9A24A));
    expect(t.highlightBg, const Color(0xFF0A3B2C));
    expect(t.highlightFg, const Color(0xFFF3E3A1));
    expect(t.labelCellBg, const Color(0xFFD4AF37));
    expect(t.labelCellFg, const Color(0xFF0A3B2C));
    expect(t.quoteBoxBg, const Color(0xFF0F4A38));
    expect(t.quoteBoxBorder, const Color(0xFFD4AF37));
    expect(t.quoteText, const Color(0xFFF6F1DC));
    expect(t.headingFont, 'ArefRuqaa');
    expect(t.bodyFont, 'Amiri');
    expect(t.emblemPainter, isNotNull);
  });

  test('painters paint deterministically without throwing', () {
    final m = LayoutMetrics.compute(kPosterSize, t, 30);
    for (final p in [
      t.backgroundPainter(),
      t.framePainter(m),
      t.framePainter(null),
      t.emblemPainter!(),
    ]) {
      for (final size in [kPosterSize, const Size(120, 120), Size.zero]) {
        final rec = PictureRecorder();
        p.paint(Canvas(rec), size);
        rec.endRecording().dispose();
      }
    }
  });

  test('frame repaints only when the metrics change', () {
    final m = LayoutMetrics.compute(kPosterSize, t, 30);
    final n = LayoutMetrics.compute(kPosterSize, t, 29);
    expect(t.framePainter(m).shouldRepaint(t.framePainter(m)), isFalse);
    expect(t.framePainter(m).shouldRepaint(t.framePainter(n)), isTrue);
  });
}
