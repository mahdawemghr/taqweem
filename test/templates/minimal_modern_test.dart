import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/templates/cream_gold.dart';
import 'package:taqweem/templates/minimal_modern.dart';
import 'package:taqweem/templates/navy_gold.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';

void main() {
  const tpl = MinimalModernTemplate();
  final t = tpl.theme;

  test('id, Arabic name and registration after cream_gold', () {
    expect(tpl.id, 'minimal_modern');
    expect(tpl.nameAr, 'عصري بسيط');
    final ids = allTemplates.map((e) => e.id).toList();
    expect(ids.first, 'navy_gold');
    expect(ids.indexOf('minimal_modern'), ids.indexOf('ivory_medallion') + 1);
    expect(templateById('minimal_modern'), isA<MinimalModernTemplate>());
  });

  test('palette values are exact (plan Task 18)', () {
    expect(t.background, const Color(0xFFFFFFFF));
    expect(t.frameColor, const Color(0xFF111827));
    expect(t.accent, const Color(0xFF0F766E));
    expect(t.titleColor, const Color(0xFF111827));
    expect(t.bodyText, const Color(0xFF1F2937));
    expect(t.tableHeaderBg, const Color(0xFF111827));
    expect(t.tableHeaderFg, const Color(0xFFFFFFFF));
    expect(t.rowBg, const Color(0xFFFFFFFF));
    expect(t.rowAltBg, const Color(0xFFF3F4F6));
    expect(t.rowText, const Color(0xFF111827));
    expect(t.gridLine, const Color(0xFFE5E7EB));
    expect(t.highlightBg, const Color(0xFF0F766E));
    expect(t.highlightFg, const Color(0xFFFFFFFF));
    expect(t.labelCellBg, const Color(0xFFE5E7EB));
    expect(t.labelCellFg, const Color(0xFF111827));
    expect(t.quoteBoxBg, const Color(0xFFF9FAFB));
    expect(t.quoteBoxBorder, const Color(0xFFD1D5DB));
    expect(t.quoteText, const Color(0xFF1F2937));
    expect(t.headingFont, 'Tajawal');
    expect(t.bodyFont, 'Tajawal');
    expect(t.contentPadding, const EdgeInsets.all(56));
  });

  test('hairline table: no vertical grid lines, thin borders', () {
    expect(t.verticalGridLines, isFalse);
    expect(t.tableBorderWidth, 1);
    expect(t.quoteBoxBorderWidth, 1);
  });

  test('new theme fields default to the original look', () {
    for (final other in [
      const NavyGoldTemplate().theme,
      const CreamGoldTemplate().theme,
    ]) {
      expect(other.verticalGridLines, isTrue);
      expect(other.tableBorderWidth, 2.5);
      expect(other.quoteBoxBorderWidth, 2.5);
    }
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

  group('layout honours verticalGridLines', () {
    setUpAll(loadAppFonts);

    Future<List<Border>> cellBorders(
      WidgetTester tester,
      PosterTheme theme,
    ) async {
      await tester.binding.setSurfaceSize(kPosterSize);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        SizedBox.fromSize(
          size: kPosterSize,
          child: PosterLayout(poster: seedReferenceMonth(), theme: theme),
        ),
      );
      final table = find.byKey(const ValueKey('poster-table'));
      return tester
          .widgetList<DecoratedBox>(
            find.descendant(of: table, matching: find.byType(DecoratedBox)),
          )
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>()
          // Skip the table's uniform outer border; keep the cell borders.
          .where((b) => !b.isUniform || b.top == BorderSide.none)
          .toList();
    }

    testWidgets('minimal_modern cells have no left borders', (tester) async {
      final borders = await cellBorders(tester, t);
      expect(borders, isNotEmpty);
      expect(borders.every((b) => b.left == BorderSide.none), isTrue);
      expect(borders.any((b) => b.bottom != BorderSide.none), isTrue);
    });

    testWidgets('navy_gold cells keep their vertical lines', (tester) async {
      final borders = await cellBorders(tester, const NavyGoldTemplate().theme);
      expect(borders.any((b) => b.left != BorderSide.none), isTrue);
    });
  });
}
