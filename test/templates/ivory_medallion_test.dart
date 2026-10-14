import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/ivory_medallion.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';
import 'contrast_test.dart' show contrastRatio;

const _t = IvoryMedallionTemplate();

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

  /// Dark navy pixels (the medallion calligraphy) in [r].
  int navyIn(Rect r) =>
      _count(r, (c) => c.computeLuminance() < 0.08 && c.b > c.r);

  /// Gold-ish pixels (red well above blue) in [r].
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

KitMetrics _m([int rows = 30]) => ivoryMedallionMetrics(kPosterSize, rows);

bool _close(Color a, Color b, [double tol = 0.02]) =>
    (a.r - b.r).abs() < tol && (a.g - b.g).abs() < tol && (a.b - b.b).abs() < tol;

void main() {
  setUpAll(loadAppFonts);

  test('id, Arabic name, registered after cream_gold', () {
    expect(_t.id, 'ivory_medallion');
    expect(_t.nameAr, 'عاجي بالميدالية');
    final ids = allTemplates.map((t) => t.id).toList();
    expect(ids.indexOf('ivory_medallion'), ids.indexOf('cream_gold') + 1);
    expect(templateById('ivory_medallion'), isA<IvoryMedallionTemplate>());
  });

  test('palette and theme constants', () {
    expect(ivBg, const Color(0xFFF8F5EC));
    expect(ivNavy, const Color(0xFF1B2A4A));
    expect(ivHeader, const Color(0xFF16264A));
    expect(ivGold, const Color(0xFFC9A24E));
    expect(ivBlue, const Color(0xFF2F5D7A));
    expect(ivHighlight, const Color(0xFF8A6524));
    final th = _t.theme;
    expect(th.background, ivBg);
    expect(th.tableHeaderBg, ivHeader);
    expect(th.tableHeaderFg, ivWhite);
    expect(th.rowBg, ivRow);
    expect(th.rowAltBg, ivRowAlt);
    expect(th.rowText, ivNavy);
    expect(th.highlightBg, ivHighlight);
    expect(th.highlightFg, ivWhite);
    expect(th.labelCellBg, ivGold);
    expect(th.quoteBoxBg, ivPanel);
    expect(th.accent, ivGoldText);
    expect(th.tableFont, 'Tajawal');
  });

  test('clearly different from cream_gold (navy header, other palette)', () {
    final cream = templateById('cream_gold').theme;
    final th = _t.theme;
    expect(th.tableHeaderBg, isNot(cream.tableHeaderBg));
    expect(th.highlightBg, isNot(cream.highlightBg));
    expect(th.background, isNot(cream.background));
    expect(_t.images, isNotEmpty);
    expect(templateById('cream_gold').images, isEmpty);
  });

  test('uses the ivory medallion (precached)', () {
    expect(_t.images, const [medallionIvoryAsset]);
    expect(medallionIvoryAsset.assetName, 'assets/logos/medallion_ivory.png');
  });

  group('contrast in the real composition (>= 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'brace / footer navy on ivory field': (ivNavy, ivBg),
      'brace / footer navy on the darkest lattice': (ivNavy, ivPatternDarkest),
      'quote navy / panel ivory': (ivNavy, ivPanel),
      'attribution dark gold / panel ivory': (ivGoldText, ivPanel),
      'header white / navy': (ivWhite, ivHeader),
      'row navy / white row': (ivNavy, ivRow),
      'row navy / grey stripe': (ivNavy, ivRowAlt),
      'hijri white / blue': (ivWhite, ivBlue),
      'highlight white / gold-brown': (ivWhite, ivHighlight),
      'label navy / gold pill': (ivNavy, ivGold),
      'strip label dark gold / ivory': (ivGoldText, ivPanel),
      'strip text navy / ivory': (ivNavy, ivPanel),
      'author dark gold / article ivory': (ivGoldText, ivPanel),
      'article + fatiha navy / article ivory': (ivNavy, ivPanel),
      'edited title navy / disc ivory': (ivNavy, ivPanel),
    };
    pairs.forEach((name, p) {
      test(name, () {
        final r = contrastRatio(p.$1, p.$2);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name = $r');
      });
    });

    test('the lattice stays subtle (< 1.4:1 against the field)', () {
      expect(contrastRatio(ivPatternDarkest, ivBg), lessThan(1.4));
      final base = Color.alphaBlend(
        ivPattern.withValues(alpha: ivPatternBaseAlpha),
        ivBg,
      );
      expect(contrastRatio(base, ivBg), lessThan(1.2));
    });
  });

  test('geometry: sections inside the page, nothing collides', () {
    final m = _m();
    final s = m.sections;
    final page = (Offset.zero & kPosterSize).deflate(20);
    for (final e in s.entries) {
      expect(
        page.contains(e.value.topLeft) &&
            page.contains(e.value.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: '${e.key} ${e.value}',
      );
    }
    final med = s['medallion']!;
    expect(med.width, 330);
    expect(med.center.dx, 500);
    // Finials touch the medallion and sit between it and the quote panels.
    expect(s['finialRight']!.left, lessThan(med.right));
    expect(s['finialLeft']!.right, greaterThan(med.left));
    expect(s['quoteRight']!.left, greaterThan(s['finialRight']!.right));
    expect(s['quoteLeft']!.right, lessThan(s['finialLeft']!.left));
    for (final id in ['quoteRight', 'quoteLeft']) {
      expect(s[id]!.overlaps(med), isFalse, reason: id);
      expect(s[id]!.width, greaterThan(240), reason: id);
    }
    // Braces flank the brace text, below the medallion, above the table.
    final brace = s['brace']!;
    expect(s['braceRight']!.left, greaterThan(brace.right));
    expect(s['braceLeft']!.right, lessThan(brace.left));
    expect(brace.top, greaterThan(med.bottom));
    expect(brace.bottom, lessThan(s['table']!.top));
    // Table rows share the height equally and are not cramped.
    expect(m.table.rowsBottom, closeTo(s['table']!.bottom, 0.01));
    expect(m.table.rowHeight, greaterThan(40));
    for (final id in ['stripRight', 'stripLeft']) {
      expect(s[id]!.overlaps(s['table']!), isFalse, reason: id);
      expect(s[id]!.height, s['table']!.height);
    }
    expect(s['footerNote']!.top, greaterThan(s['table']!.bottom));
    expect(s['article']!.top, greaterThan(s['footerNote']!.bottom));
  });

  test('braces: cached, mirrored, inside their box, thick-thin', () {
    const size = Size(46, 120);
    final l = ivBracePath(size, opensRight: true);
    final r = ivBracePath(size, opensRight: false);
    expect(identical(l, ivBracePath(size, opensRight: true)), isTrue);
    for (final p in [l, r]) {
      final b = p.getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(46));
      expect(b.bottom, lessThanOrEqualTo(120));
      expect(b.height, greaterThan(100));
    }
    // `{` points left (tip at the left middle), `}` points right.
    expect(l.contains(const Offset(6, 60)), isTrue);
    expect(r.contains(const Offset(40, 60)), isTrue);
    expect(l.contains(const Offset(40, 60)), isFalse);
    // The arm is thick in its middle (~6 px), a hairline near the ends.
    final armX = 4 + 38 * 0.52;
    var thickMid = 0, thinEnd = 0;
    for (var d = -6.0; d <= 6; d += 0.5) {
      if (l.contains(Offset(armX + d, 4 + 112 * 0.27))) thickMid++;
      if (l.contains(Offset(34, 4 + d))) thinEnd++;
    }
    expect(thickMid, greaterThan(9));
    expect(thinEnd, greaterThan(0));
    expect(thinEnd, lessThan(thickMid / 2));
    expect(ivBracePath(const Size(5, 5), opensRight: true).getBounds(),
        Rect.zero);
  });

  test('lattice: cached, deterministic, covers the page, any size', () {
    final a = ivLatticePath(kPosterSize);
    expect(identical(a, ivLatticePath(kPosterSize)), isTrue);
    final b = a.getBounds();
    expect(b.left, lessThanOrEqualTo(0));
    expect(b.top, lessThanOrEqualTo(0));
    expect(b.right, greaterThanOrEqualTo(1000));
    expect(b.bottom, greaterThanOrEqualTo(2200));
    for (final size in [kPosterSize, const Size(10, 10), Size.zero]) {
      final rec = ui.PictureRecorder();
      IvoryMedallionBackgroundPainter(
        ivoryMedallionMetrics(size, 30),
      ).paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }
    final bg = IvoryMedallionBackgroundPainter(_m());
    expect(bg.shouldRepaint(bg), isFalse);
  });

  test('table styling: navy header, stripes, blue day column, highlight', () {
    final spec = ivoryMedallionTableSpec;
    final cols = spec.columns;
    final hijri = cols.firstWhere((c) => c.kind == ColumnKind.hijri);
    final greg = cols.firstWhere((c) => c.kind == ColumnKind.gregorian);
    final fajr = cols.firstWhere((c) => c.kind == ColumnKind.time);
    final seed = seedReferenceMonth();
    final normal = seed.days.indexWhere((d) => !d.highlighted);
    final hl = seed.days.indexWhere((d) => d.highlighted);
    final label = seed.days.indexWhere(
      (d) => d.gregorian.isLabel && !d.highlighted,
    );
    expect(spec.header.background, ivHeader);
    expect(spec.header.foreground, ivWhite);
    expect(spec.grid.headerBottom?.color, ivGold);
    // Stripes.
    expect(spec.resolve(fajr, 4, seed.days[0], 0).background, ivRow);
    expect(spec.resolve(fajr, 4, seed.days[1], 1).background, ivRowAlt);
    expect(spec.resolve(fajr, 4, seed.days[0], 0).foreground, ivNavy);
    // The hijri column stays blue with white numerals on every row.
    for (final i in [normal, hl]) {
      final st = spec.resolve(hijri, 1, seed.days[i], i);
      expect(st.background, ivBlue);
      expect(st.foreground, ivWhite);
    }
    // Highlighted rows: gold-brown with white text.
    final h = spec.resolve(greg, 2, seed.days[hl], hl);
    expect(h.background, ivHighlight);
    expect(h.foreground, ivWhite);
    // Month-change label: gold pill with navy text.
    final ls = spec.resolve(greg, 2, seed.days[label], label);
    expect(ls.badge?.color, ivGold);
    expect(ls.foreground, ivNavy);
    expect(cols.map((c) => c.kind).toList(), [
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

  test('braces in Tajawal: plain braces (Tajawal glyphs are pre-mirrored)',
      () {
    expect(ivTajawalBraced('x'), '{ x }');
  });

  testWidgets('seed render: real table geometry, FitText contained', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    expect(tester.takeException(), isNull);
    final m = _m(seedReferenceMonth().days.length);
    final origin = tester.getTopLeft(find.byType(PosterPreview));
    expect(
      tester.getRect(find.byKey(const ValueKey('iv-table'))).shift(-origin),
      _rectClose(m.sections['table']!),
    );
    expect(expectFitTextsContained(tester), greaterThan(250));
    expect(midWordBreakOffenders(tester), isEmpty);
    for (final k in [
      'iv-title-image',
      'iv-quote-right',
      'iv-quote-left',
      'iv-brace',
      'iv-brace-left',
      'iv-brace-right',
      'iv-strip-right',
      'iv-strip-left',
      'iv-article',
      'iv-author',
    ]) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
  });

  testWidgets('export right after pump + precache contains the medallion', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    expect(shot.width, 1000);
    final med = _m().sections['medallion']!;
    final inner = Rect.fromCenter(
      center: med.center,
      width: med.width * 0.6,
      height: med.height * 0.6,
    );
    expect(shot.navyIn(inner), greaterThan(800));
  });

  testWidgets('control: without precache the medallion is missing', (
    tester,
  ) async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await _pump(tester, seedReferenceMonth(), precache: false);
    final shot = await _capture(tester);
    final med = _m().sections['medallion']!;
    final inner = Rect.fromCenter(
      center: med.center,
      width: med.width * 0.6,
      height: med.height * 0.6,
    );
    // Only the ivory backing disc remains under the (missing) medallion.
    expect(shot.navyIn(inner), lessThan(50));
  });

  testWidgets('no bleed: lattice faint, panels opaque, header separators', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final m = _m();
    final s = m.sections;
    // Panels are opaque ivory just inside their double border (no lattice).
    for (final id in ['quoteRight', 'quoteLeft', 'article']) {
      final r = s[id]!;
      final px = shot.at(r.left + 12, r.bottom - 12);
      expect(_close(px, ivPanel, 0.02), isTrue, reason: '$id $px');
    }
    // An empty notes cell shows the plain white row.
    final row0 = m.table.rowRect(0);
    expect(
      _close(shot.at(s['table']!.left + 6, row0.center.dy), ivRow, 0.02),
      isTrue,
    );
    // The field is never far from ivory (the lattice is subtle) ...
    for (final p in const [
      Offset(60, 360),
      Offset(940, 360),
      Offset(500, 515),
    ]) {
      expect(
        contrastRatio(shot.at(p.dx, p.dy), ivBg),
        lessThan(1.4),
        reason: '$p',
      );
    }
    // ... but it is there, and stronger in the corners than in the centre.
    double lum(Rect r) {
      var sum = 0.0, n = 0;
      for (var y = r.top; y < r.bottom; y += 1) {
        for (var x = r.left; x < r.right; x += 1) {
          sum += shot.at(x, y).computeLuminance();
          n++;
        }
      }
      return sum / n;
    }
    final bgLum = ivBg.computeLuminance();
    final corner = lum(const Rect.fromLTWH(0, 0, 14, 300));
    final centre = lum(const Rect.fromLTWH(0, 1000, 14, 300));
    expect(corner, lessThan(bgLum));
    expect(centre, lessThan(bgLum));
    expect(corner, lessThan(centre));
    // Gold separators in the navy header between the columns.
    final cols = m.table.columns;
    final hy = (s['table']!.top + m.table.headerBottom) / 2;
    for (var i = 0; i < cols.length - 1; i++) {
      final px = shot.at(cols[i].left + 0.5, hy);
      expect(px.r > .55 && px.r - px.b > .2, isTrue, reason: 'col $i $px');
    }
    // The braces are gold.
    for (final id in ['braceRight', 'braceLeft']) {
      expect(shot.goldIn(s[id]!), greaterThan(40), reason: id);
    }
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

  testWidgets('edited title is set as text; empty texts draw nothing', (
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
    expect(find.byKey(const ValueKey('iv-title-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-title-image')), findsNothing);
    expect(find.text('تقويم المؤمنين'), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-quote-right')), findsNothing);
    expect(find.byKey(const ValueKey('iv-quote-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-brace')), findsNothing);
    expect(find.byKey(const ValueKey('iv-brace-left')), findsNothing);
    expect(find.byKey(const ValueKey('iv-author')), findsNothing);
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
    print('ivory_medallion warm builds (ms): $times');
    expect(times.skip(1).reduce(math.min), lessThan(400));
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
