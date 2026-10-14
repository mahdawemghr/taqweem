import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/navy_calligraphy.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';
import 'contrast_test.dart' show contrastRatio;

const _t = NavyCalligraphyTemplate();

/// An RGBA capture of the poster (1 px = 1 logical px).
class _Shot {
  _Shot(this.bytes, this.width);
  final ByteData bytes;
  final int width;

  Color at(double x, double y) {
    final i = (y.floor() * width + x.floor()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  /// Pixels in [r] that are near-white (the white calligraphy).
  int whiteIn(Rect r) => _count(r, (c) => c.r > .92 && c.g > .92 && c.b > .92);

  /// Pixels in [r] that are gold-ish (red well above blue).
  int goldIn(Rect r) =>
      _count(r, (c) => c.r > .55 && c.r - c.b > .2 && c.g > .4);

  int _count(Rect r, bool Function(Color) f) {
    var n = 0;
    for (var y = r.top; y < r.bottom; y += 2) {
      for (var x = r.left; x < r.right; x += 2) {
        if (f(at(x, y))) n++;
      }
    }
    return n;
  }
}

final _key = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  MonthPoster p, {
  bool precache = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosterPreview(
          poster: p.copyWith(templateId: _t.id),
          boundaryKey: _key,
          width: 1000,
        ),
      ),
    ),
  );
  if (precache) await precacheTemplate(tester, _t);
  await tester.pumpAndSettle();
}

Future<_Shot> _capture(WidgetTester tester) async {
  final shot = await tester.runAsync(() async {
    final png = await PosterExporter.toPng(_key, pixelRatio: 1);
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    final w = frame.image.width;
    frame.image.dispose();
    return _Shot(data!, w);
  });
  return shot!;
}

KitMetrics _m([int rows = 30]) => navyCalligraphyMetrics(kPosterSize, rows);

void main() {
  setUpAll(loadAppFonts);

  test('id, Arabic name, registered after navy_gold', () {
    expect(_t.id, 'navy_calligraphy');
    expect(_t.nameAr, 'كحلي بالخط العربي');
    final ids = allTemplates.map((t) => t.id).toList();
    expect(ids.indexOf('navy_calligraphy'), ids.indexOf('navy_gold') + 1);
    expect(templateById('navy_calligraphy'), isA<NavyCalligraphyTemplate>());
  });

  test('palette and theme constants', () {
    expect(ncNavy, const Color(0xFF0B1F38));
    expect(ncGold, const Color(0xFFCBA862));
    expect(ncGoldDeep, const Color(0xFF8A6A2B));
    expect(ncPaper, const Color(0xFFFDFCF9));
    expect(ncRowAlt, const Color(0xFFECEBE7));
    expect(ncInk, const Color(0xFF111A2B));
    final th = _t.theme;
    expect(th.background, ncNavy);
    expect(th.tableHeaderBg, ncGoldDeep);
    expect(th.tableHeaderFg, ncWhite);
    expect(th.highlightBg, ncNavy);
    expect(th.labelCellBg, ncNavy);
    expect(th.rowBg, ncRow);
    expect(th.rowAltBg, ncRowAlt);
    expect(th.tableFont, 'Tajawal');
  });

  test('uses the white title and gold finial assets (precached)', () {
    expect(_t.images, const [titleWhiteAsset, finialGoldAsset]);
    expect(titleWhiteAsset.assetName, 'assets/logos/title_white.png');
    expect(finialGoldAsset.assetName, 'assets/logos/finial_gold.png');
  });

  group('contrast in the real composition (>= 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'quote text / quote panel': (ncWhite, ncNavy),
      'attribution gold / quote panel': (ncGold, ncNavy),
      'header text / header glow (lightest navy)': (ncWhite, ncNavyGlow),
      'brace ink / ribbon top': (ncInk, ncRibbonTop),
      'brace ink / ribbon bottom': (ncInk, ncRibbonBottom),
      'table header white / deep gold': (ncWhite, ncGoldDeep),
      'row ink / white row': (ncInk, ncRow),
      'row ink / grey stripe': (ncInk, ncRowAlt),
      'highlight white / navy': (ncWhite, ncNavy),
      'occasion day white / navy': (ncWhite, ncNavy),
      'label cell white / navy': (ncWhite, ncNavy),
      'strip label gold / paper': (ncGoldText, ncPaper),
      'strip text navy / paper': (ncNavy, ncPaper),
      'footer note ink / paper': (ncInk, ncPaper),
      'author gold / pill': (ncGold, ncNavy),
      'article white / article panel': (ncWhite, ncArticleFill),
      'fatiha gold / article panel': (ncGold, ncArticleFill),
    };
    pairs.forEach((name, p) {
      test(name, () {
        final r = contrastRatio(p.$1, p.$2);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name = $r');
      });
    });
  });

  test('geometry: header rule through the quotes, table fills its area', () {
    final m = _m();
    final s = m.sections;
    final hb = s['headerBlock']!.bottom;
    for (final id in ['quoteRight', 'quoteLeft']) {
      expect(s[id]!.top, lessThan(hb));
      expect(s[id]!.bottom, greaterThan(hb));
    }
    expect(s['title']!.width, lessThanOrEqualTo(560));
    expect(s['title']!.overlaps(s['finial']!), isFalse);
    expect(m.table.rowsBottom, closeTo(s['table']!.bottom, 0.01));
    expect(s['stripRight']!.overlaps(s['table']!), isFalse);
    expect(s['stripLeft']!.overlaps(s['table']!), isFalse);
    // Ribbon knots sit outside the ribbon body; article knots stay out of
    // the article's text box (lobe + padding).
    final ribbon = s['ribbon']!;
    expect(s['knotRight']!.left, greaterThan(ribbon.right - 32));
    expect(s['knotLeft']!.right, lessThan(ribbon.left + 32));
    final article = s['article']!;
    final textBox = Rect.fromLTRB(
      article.left + 54,
      article.top,
      article.right - 54,
      article.bottom,
    );
    expect(s['articleKnotRight']!.overlaps(textBox), isFalse);
    expect(s['articleKnotLeft']!.overlaps(textBox), isFalse);
    expect(s['footerBlock']!.bottom, kPosterSize.height);
  });

  test('lobedPath: pointed side lobes, cut corners', () {
    const r = Rect.fromLTWH(0, 0, 400, 160);
    final p = lobedPath(r, 30, 16);
    expect(p.contains(const Offset(2, 80)), isTrue); // left tip
    expect(p.contains(const Offset(398, 80)), isTrue); // right tip
    expect(p.contains(const Offset(200, 80)), isTrue);
    expect(p.contains(const Offset(4, 6)), isFalse); // outside the lobe
    expect(p.contains(const Offset(396, 154)), isFalse);
    expect(lobedPath(Rect.zero, 30, 16).getBounds(), Rect.zero);
  });

  test('table styling: navy highlights, labels and occasion days', () {
    final spec = navyCalligraphyTableSpec;
    final hijri = spec.columns.firstWhere((c) => c.kind == ColumnKind.hijri);
    final greg = spec.columns.firstWhere(
      (c) => c.kind == ColumnKind.gregorian,
    );
    final seed = seedReferenceMonth();
    final withNote = seed.days.firstWhere(
      (d) => d.note.isNotEmpty && !d.highlighted,
    );
    final noNote = seed.days.firstWhere(
      (d) => d.note.isEmpty && !d.highlighted,
    );
    final hl = seed.days.firstWhere((d) => d.highlighted);
    final label = seed.days.firstWhere(
      (d) => d.gregorian.isLabel && !d.highlighted,
    );
    expect(spec.resolve(hijri, 1, withNote, 0).background, ncNavy);
    expect(spec.resolve(hijri, 1, noNote, 0).background, ncRow);
    expect(spec.resolve(hijri, 1, noNote, 1).background, ncRowAlt);
    expect(spec.resolve(greg, 2, hl, 0).background, ncNavy);
    expect(spec.resolve(greg, 2, hl, 0).foreground, ncWhite);
    expect(spec.resolve(greg, 2, label, 0).background, ncNavy);
    expect(spec.columns.map((c) => c.kind).toList(), [
      ColumnKind.weekday,
      ColumnKind.hijri,
      ColumnKind.gregorian,
      ColumnKind.solar,
      ColumnKind.time,
      ColumnKind.time,
      ColumnKind.time,
      ColumnKind.time,
      ColumnKind.notes,
    ]);
  });

  test('painters: no repaint, paint at any size without throwing', () {
    for (final size in [kPosterSize, const Size(10, 10), Size.zero]) {
      final m = navyCalligraphyMetrics(size, 30);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      NavyCalligraphyBackgroundPainter(m, hasBrace: true).paint(canvas, size);
      NavyCalligraphyKnotPainter(m, hasBrace: true).paint(canvas, size);
      rec.endRecording().dispose();
    }
    final m = _m();
    final bg = NavyCalligraphyBackgroundPainter(m, hasBrace: true);
    expect(bg.shouldRepaint(bg), isFalse);
    final k = NavyCalligraphyKnotPainter(m, hasBrace: true);
    expect(k.shouldRepaint(k), isFalse);
  });

  testWidgets('seed render: real table geometry, FitText contained', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    expect(tester.takeException(), isNull);
    final m = _m(seedReferenceMonth().days.length);
    final table = find.byKey(const ValueKey('nc-table'));
    final origin = tester.getTopLeft(find.byType(PosterPreview));
    expect(
      tester.getRect(table).shift(-origin),
      _rectClose(m.sections['table']!),
    );
    expect(expectFitTextsContained(tester), greaterThan(250));
    expect(midWordBreakOffenders(tester), isEmpty);
    expect(find.byKey(const ValueKey('nc-title-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('nc-ribbon')), findsOneWidget);
    expect(find.byKey(const ValueKey('nc-pill')), findsOneWidget);
  });

  testWidgets('export right after pump + precache contains both logos', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final m = _m();
    expect(shot.width, 1000);
    // White calligraphy in the title box; gold finial in its box.
    expect(shot.whiteIn(m.sections['title']!), greaterThan(800));
    expect(shot.goldIn(m.sections['finial']!), greaterThan(300));
  });

  testWidgets('control: without precache the capture has no logo', (
    tester,
  ) async {
    // The global ImageCache keeps logos decoded by earlier tests; empty it so
    // the control really starts cold.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await _pump(tester, seedReferenceMonth(), precache: false);
    final shot = await _capture(tester);
    final m = _m();
    expect(shot.whiteIn(m.sections['title']!), lessThan(20));
  });

  testWidgets('no bleed: panels are opaque over rules, lattice and hairline', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final s = _m().sections;
    final hb = s['headerBlock']!.bottom;
    // Header gold rule runs behind the quote panels: inside them (in the
    // padding, beside the text) the pixel is the panel's navy.
    final qr = s['quoteRight']!, ql = s['quoteLeft']!;
    expect(shot.at(qr.left + 36, hb), ncNavy);
    expect(shot.at(ql.right - 36, hb), ncNavy);
    // ... but visible between them.
    expect(shot.goldIn(Rect.fromLTRB(ql.right + 4, hb - 1, qr.left - 4, hb + 1)),
        greaterThan(0));
    // The brace hairline does not cross the ribbon body.
    final rb = s['ribbon']!;
    final c = shot.at(rb.left + 40, rb.center.dy);
    expect(c.r > .85 && c.g > .85 && c.b > .85, isTrue, reason: '$c');
    // Faint lattice never shows inside the quote panel (flat navy).
    expect(shot.at(qr.left + 36, qr.top + 20), ncNavy);
    // Table rows are opaque: a notes cell gap is the row colour.
    final row0 = _m(30).table.rowRect(0);
    expect(shot.at(s['table']!.left + 6, row0.center.dy), ncRow);
  });

  testWidgets('deterministic: two renders are identical', (tester) async {
    await _pump(tester, seedReferenceMonth());
    final a = await _capture(tester);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, seedReferenceMonth());
    final b = await _capture(tester);
    expect(
      a.bytes.buffer.asUint8List(),
      orderedEquals(b.bytes.buffer.asUint8List()),
    );
  });

  testWidgets('edited title is set as text; empty texts draw no panels', (
    tester,
  ) async {
    final seed = seedReferenceMonth();
    await _pump(
      tester,
      seed.copyWith(
        texts: seed.texts.copyWith(
          title: 'تقويم المؤمنين',
          rightQuote: const HeaderQuote.empty(),
          braceQuote: '',
          article: const ClosingArticle(author: '', body: 'نص'),
          sideLeft: const SideQa.empty(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('nc-title-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('nc-title-image')), findsNothing);
    expect(find.text('تقويم المؤمنين'), findsOneWidget);
    expect(find.byKey(const ValueKey('nc-ribbon')), findsNothing);
    expect(find.byKey(const ValueKey('nc-pill')), findsNothing);
    expect(find.textContaining('سؤال'), findsOneWidget); // right strip only
    expect(find.textContaining('{'), findsOneWidget); // article body only
    expectFitTextsContained(tester);
  });

  testWidgets('warm build stays fast', (tester) async {
    await _pump(tester, seedReferenceMonth());
    final sw = Stopwatch();
    final times = <int>[];
    for (var i = 0; i < 4; i++) {
      sw
        ..reset()
        ..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterPreview(
              key: ValueKey(i),
              poster: seedReferenceMonth().copyWith(templateId: _t.id),
              width: 1000,
            ),
          ),
        ),
      );
      sw.stop();
      times.add(sw.elapsedMilliseconds);
    }
    // ignore: avoid_print
    print('navy_calligraphy warm builds (ms): $times');
    expect(times.skip(1).reduce((a, b) => a < b ? a : b), lessThan(400));
  });
}

Matcher _rectClose(Rect r) => predicate<Rect>(
  (a) =>
      (a.left - r.left).abs() < 0.5 &&
      (a.top - r.top).abs() < 0.5 &&
      (a.right - r.right).abs() < 0.5 &&
      (a.bottom - r.bottom).abs() < 0.5,
  'close to $r',
);
