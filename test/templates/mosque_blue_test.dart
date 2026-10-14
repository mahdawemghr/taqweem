import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/templates/mosque_blue.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';

/// RGBA bytes of [painter] painted on a [size] canvas.
Future<Uint8List> _paintBytes(CustomPainter painter, Size size) async {
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), size);
  final pic = rec.endRecording();
  final img = await pic.toImage(size.width.toInt(), size.height.toInt());
  final data = await img.toByteData();
  img.dispose();
  pic.dispose();
  return data!.buffer.asUint8List();
}

Color _pixel(ByteData d, int width, Offset p) {
  final i = (p.dy.toInt() * width + p.dx.toInt()) * 4;
  return Color.fromARGB(
    d.getUint8(i + 3),
    d.getUint8(i),
    d.getUint8(i + 1),
    d.getUint8(i + 2),
  );
}

void main() {
  const tpl = MosqueBlueTemplate();
  final t = tpl.theme;

  test('id, Arabic name and registration after deep_green', () {
    expect(tpl.id, 'mosque_blue');
    expect(tpl.nameAr, 'أزرق ليلي ومسجد');
    final ids = allTemplates.map((e) => e.id).toList();
    expect(ids.first, 'navy_gold');
    expect(ids.indexOf('mosque_blue'), ids.indexOf('midnight_dome') + 1);
    expect(templateById('mosque_blue'), isA<MosqueBlueTemplate>());
  });

  test('palette values are exact (plan Task 20)', () {
    expect(t.background, const Color(0xFF08122B));
    expect(t.frameColor, const Color(0xFFE8C766));
    expect(t.accent, const Color(0xFFE8C766));
    expect(t.titleColor, const Color(0xFFFFE9A8));
    expect(t.bodyText, const Color(0xFFEAF0FF));
    expect(t.tableHeaderBg, const Color(0xFF0E2A57));
    expect(t.tableHeaderFg, const Color(0xFFFFE9A8));
    expect(t.rowBg, const Color(0xFFEEF3FF));
    expect(t.rowAltBg, const Color(0xFFDCE6FB));
    expect(t.rowText, const Color(0xFF08122B));
    expect(t.gridLine, const Color(0xFF7F9ACB));
    expect(t.highlightBg, const Color(0xFF08122B));
    expect(t.highlightFg, const Color(0xFFFFE9A8));
    expect(t.labelCellBg, const Color(0xFFE8C766));
    expect(t.labelCellFg, const Color(0xFF08122B));
    expect(t.quoteBoxBg, const Color(0xFF0E2A57));
    expect(t.quoteBoxBorder, const Color(0xFFE8C766));
    expect(t.quoteText, const Color(0xFFEAF0FF));
    expect(t.headingFont, 'ArefRuqaa');
    expect(t.bodyFont, 'Amiri');
    expect(t.emblemPainter, isNotNull);
  });

  test('silhouette colour is 0xFF0B2350 at 90 % opacity', () {
    expect(kMosqueSilhouetteColor, const Color(0xFF0B2350));
    expect(kMosqueSilhouetteOpacity, 0.9);
  });

  test('painters paint without throwing at any size', () {
    final m = LayoutMetrics.compute(kPosterSize, t, 30);
    for (final p in [
      t.backgroundPainter(),
      t.framePainter(m),
      t.framePainter(null),
      t.emblemPainter!(),
    ]) {
      for (final size in [kPosterSize, const Size(120, 120), Size.zero]) {
        final rec = ui.PictureRecorder();
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

  test('stars: at most 40, inside the header region, fixed seed', () {
    final a = mosqueBlueStars(kPosterSize);
    final b = mosqueBlueStars(kPosterSize);
    expect(a, isNotEmpty);
    expect(a.length, lessThanOrEqualTo(40));
    expect(a, b);
    for (final s in a) {
      expect(s.center.dy, lessThanOrEqualTo(300));
      expect(s.center.dx, inInclusiveRange(0, kPosterSize.width));
    }
  });

  testWidgets('background painter is deterministic (two renders identical)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final a = await _paintBytes(t.backgroundPainter(), kPosterSize);
      final b = await _paintBytes(t.backgroundPainter(), kPosterSize);
      expect(a.length, b.length);
      expect(a, b);
      // Not blank: the gradient changes from top to bottom.
      final d = ByteData.sublistView(a);
      expect(
        _pixel(d, 1000, const Offset(5, 5)),
        isNot(_pixel(d, 1000, const Offset(5, 2190))),
      );
    });
  });

  testWidgets('no silhouette bleed: rows and quote boxes stay opaque', (
    tester,
  ) async {
    await loadAppFonts();
    final seed = seedReferenceMonth();
    // Empty notes so the probe points hit plain cell background only.
    final poster = seed.copyWith(
      templateId: tpl.id,
      days: [
        for (final d in seed.days) d.copyWith(note: '', highlighted: false),
      ],
    );
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(kPosterSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: kPosterSize, child: tpl.build(poster)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final m = LayoutMetrics.compute(kPosterSize, t, poster.days.length);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late ByteData data;
    await tester.runAsync(() async {
      final img = await boundary.toImage();
      data = (await img.toByteData())!;
      img.dispose();
    });

    // Notes cell (left part of the table, RTL) of the first, an odd and
    // the last row: rowBg / rowAltBg exactly, opaque.
    final notesX = m.tableRect.left + 120;
    for (final i in [0, 1, 2, poster.days.length - 1]) {
      final y = m.tableHeaderBottom + m.rowHeight * (i + 0.5);
      final want = i.isEven ? t.rowBg : t.rowAltBg;
      expect(
        _pixel(data, 1000, Offset(notesX, y)),
        want,
        reason: 'row $i at ($notesX, $y)',
      );
    }

    // Header quote boxes: an inner padding pixel (no text) on each box sits
    // inside the top-300 px silhouette band and must be quoteBoxBg.
    final c = m.contentRect;
    final colW = c.width * 0.3;
    final boxTop = c.top + t.headerHeight * 0.17;
    for (final x in [c.right - colW / 2, c.left + colW / 2]) {
      expect(
        _pixel(data, 1000, Offset(x, boxTop + 5)),
        t.quoteBoxBg,
        reason: 'quote box at ($x, ${boxTop + 5})',
      );
    }
  });
}
