import 'dart:ui' show PictureRecorder;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/cream_gold.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

void main() {
  const tpl = CreamGoldTemplate();
  final t = tpl.theme;

  test('id, Arabic name and registration after navy_gold', () {
    expect(tpl.id, 'cream_gold');
    expect(tpl.nameAr, 'كريمي وذهبي');
    final ids = allTemplates.map((e) => e.id).toList();
    expect(ids.first, 'navy_gold');
    expect(ids.indexOf('cream_gold'), ids.indexOf('emerald_garden') + 1);
    expect(templateById('cream_gold'), isA<CreamGoldTemplate>());
  });

  test('palette values are exact (plan Task 17 + ruling R7)', () {
    expect(t.background, const Color(0xFFFBF5E6));
    expect(t.frameColor, const Color(0xFFB8892B));
    expect(t.titleColor, const Color(0xFF7A5710));
    expect(t.bodyText, const Color(0xFF2B2416));
    expect(t.tableHeaderBg, const Color(0xFF8A6414)); // R7
    expect(t.tableHeaderFg, const Color(0xFFFFFFFF));
    expect(t.rowBg, const Color(0xFFFFFDF6));
    expect(t.rowAltBg, const Color(0xFFF5EBD0));
    expect(t.rowText, const Color(0xFF2B2416));
    expect(t.gridLine, const Color(0xFFD9C08A));
    expect(t.highlightBg, const Color(0xFF7A5710));
    expect(t.highlightFg, const Color(0xFFFFF4D6));
    expect(t.labelCellBg, const Color(0xFFE6CF94));
    expect(t.labelCellFg, const Color(0xFF2B2416));
    expect(t.quoteBoxBg, const Color(0xFFFFF8E5));
    expect(t.quoteBoxBorder, const Color(0xFFB8892B));
    expect(t.quoteText, const Color(0xFF2B2416));
    // Accent is the attribution TEXT colour on the quote box; the plan's
    // 0xFFB8892B is only 2.9:1 there, so it uses the R7 deep gold.
    expect(t.accent, const Color(0xFF8A6414));
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
}
