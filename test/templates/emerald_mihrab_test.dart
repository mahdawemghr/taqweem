import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/emerald_mihrab.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';
import 'contrast_test.dart' show contrastRatio;

const _t = EmeraldMihrabTemplate();

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

  /// Pixels in [r] that are gold-ish (red well above blue).
  int goldIn(Rect r) =>
      _count(r, (c) => c.r > .55 && c.r - c.b > .2 && c.g > .4);

  /// Pixels in [r] tinted by the (semi-transparent) gold lattice.
  int latticeIn(Rect r) => _count(r, (c) => c.r > .3 && c.r - c.b > .12);

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

KitMetrics _m([int rows = 30]) => emeraldMihrabMetrics(kPosterSize, rows);

bool _close(Color a, Color b, [double tol = 0.02]) =>
    (a.r - b.r).abs() < tol && (a.g - b.g).abs() < tol && (a.b - b.b).abs() < tol;

void main() {
  setUpAll(loadAppFonts);

  test('id, Arabic name, registered after deep_green', () {
    expect(_t.id, 'emerald_mihrab');
    expect(_t.nameAr, 'زمردي بالمحراب');
    final ids = allTemplates.map((t) => t.id).toList();
    expect(ids.indexOf('emerald_mihrab'), ids.indexOf('deep_green') + 1);
    expect(templateById('emerald_mihrab'), isA<EmeraldMihrabTemplate>());
  });

  test('palette and theme constants', () {
    expect(emEmerald, const Color(0xFF0B3D2E));
    expect(emGold, const Color(0xFFD4AF5E));
    expect(emGoldLight, const Color(0xFFEBD08F));
    expect(emNavy, const Color(0xFF0E1A30));
    expect(emNavyRow, const Color(0xFF0C1727));
    expect(emGreenRow, const Color(0xFF0B3125));
    expect(emCream, const Color(0xFFF7EDD3));
    expect(emInk, const Color(0xFF0E1A2E));
    final th = _t.theme;
    expect(th.background, emEmerald);
    expect(th.tableHeaderBg, emGold);
    expect(th.tableHeaderFg, emInk);
    expect(th.rowBg, emNavyRow);
    expect(th.rowAltBg, emGreenRow);
    expect(th.rowText, emCream);
    expect(th.highlightBg, emGold);
    expect(th.labelCellBg, emGold);
    expect(th.quoteBoxBg, emNavy);
    expect(th.tableFont, 'Tajawal');
  });

  test('uses the emerald medallion asset (precached)', () {
    expect(_t.images, const [medallionEmeraldAsset]);
    expect(
      medallionEmeraldAsset.assetName,
      'assets/logos/medallion_emerald.png',
    );
  });

  group('contrast in the real composition (>= 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'quote cream / quote panel top': (emCream, emNavyTop),
      'quote cream / quote panel bottom': (emCream, emNavy),
      'attribution gold / quote panel top': (emGold, emNavyTop),
      'brace light gold / arch top': (emGoldLight, emArchTop),
      'brace light gold / arch bottom': (emGoldLight, emArchBottom),
      'table header ink / gold': (emInk, emGold),
      'row cream / navy row': (emCream, emNavyRow),
      'row cream / green row': (emCream, emGreenRow),
      'highlight ink / gold': (emInk, emGold),
      'hijri ink / light gold': (emInk, emGoldLight),
      'label ink / gold pill': (emInk, emGold),
      'strip label gold / strip fill': (emGold, emStripFill),
      'strip text cream / strip fill': (emCream, emStripFill),
      'footer note cream / lightest emerald': (emCream, emEmerald),
      'article cream / article navy': (emCream, emNavy),
      'fatiha gold / article navy': (emGold, emNavy),
      'author ink / pill light gold': (emInk, emGoldLight),
      'author ink / pill gold': (emInk, emGold),
      'edited title gold / disc': (emGoldLight, emDisc),
    };
    pairs.forEach((name, p) {
      test(name, () {
        final r = contrastRatio(p.$1, p.$2);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name = $r');
      });
    });
  });

  test('geometry: medallion over tucked panels, brace inside arch, table '
      'fills the arch', () {
    final m = _m();
    final s = m.sections;
    final med = s['medallion']!;
    expect(med.width, closeTo(330, 0.01));
    expect(med.center.dx, 500);
    // Panels' inner ends tuck behind the medallion; text boxes stay clear.
    expect(s['quoteRight']!.left, lessThan(med.right));
    expect(s['quoteLeft']!.right, greaterThan(med.left));
    expect(s['quoteRightText']!.left, greaterThan(med.right));
    expect(s['quoteLeftText']!.right, lessThan(med.left));
    // Brace box (with margin) lies inside the arch outline.
    final arch = emArchShape.pathFor(s['arch']!);
    final b = s['brace']!.inflate(4);
    for (final p in [b.topLeft, b.topRight, b.bottomLeft, b.bottomRight]) {
      expect(arch.contains(p), isTrue, reason: '$p');
    }
    // Table sits in the straight part of the arch and fills it.
    final a = s['arch']!;
    expect(a.top + emArchShape.archRise(a.width, a.height), greaterThan(a.top));
    expect(s['table']!.top,
        greaterThanOrEqualTo(a.top + emArchShape.archRise(a.width, a.height)));
    expect(m.table.rowsBottom, closeTo(s['table']!.bottom, 0.01));
    expect(m.table.rowHeight, greaterThan(34));
    for (final id in ['stripRight', 'stripLeft']) {
      expect(s[id]!.overlaps(s['arch']!), isFalse, reason: id);
    }
    expect(s['footerNote']!.top, greaterThan(s['arch']!.bottom));
    expect(s['pill']!.center.dy, closeTo(s['article']!.top, 0.01));
    expect(s['article']!.bottom, lessThan(kPosterSize.height));
  });

  test('quote panel path: outer lobe tip, straight inner end', () {
    const r = Rect.fromLTWH(0, 0, 360, 200);
    final right = emQuotePanelPath(r, outerRight: true);
    expect(right.contains(const Offset(358, 100)), isTrue); // lobe tip
    expect(right.contains(const Offset(2, 3)), isTrue); // inner corner
    expect(right.contains(const Offset(356, 6)), isFalse);
    final left = emQuotePanelPath(r, outerRight: false);
    expect(left.contains(const Offset(2, 100)), isTrue);
    expect(left.contains(const Offset(358, 3)), isTrue);
    expect(emQuotePanelPath(Rect.zero, outerRight: true).getBounds(),
        Rect.zero);
  });

  test('table styling: gold header/highlights/hijri, label pills', () {
    final spec = emeraldMihrabTableSpec;
    final hijri = spec.columns.firstWhere((c) => c.kind == ColumnKind.hijri);
    final greg = spec.columns.firstWhere(
      (c) => c.kind == ColumnKind.gregorian,
    );
    final fajr = spec.columns.firstWhere((c) => c.kind == ColumnKind.time);
    final seed = seedReferenceMonth();
    final normal = seed.days.indexWhere((d) => !d.highlighted);
    final hl = seed.days.indexWhere((d) => d.highlighted);
    final label = seed.days.indexWhere(
      (d) => d.gregorian.isLabel && !d.highlighted,
    );
    expect(spec.header.background, emGold);
    expect(spec.header.foreground, emInk);
    expect(spec.resolve(hijri, 1, seed.days[normal], normal).background,
        emGoldLight);
    expect(spec.resolve(hijri, 1, seed.days[normal], normal).foreground,
        emInk);
    expect(spec.resolve(fajr, 4, seed.days[0], 0).background, emNavyRow);
    expect(spec.resolve(fajr, 4, seed.days[1], 1).background, emGreenRow);
    expect(spec.resolve(fajr, 4, seed.days[0], 0).foreground, emCream);
    expect(spec.resolve(greg, 2, seed.days[hl], hl).background, emGold);
    expect(spec.resolve(greg, 2, seed.days[hl], hl).foreground, emInk);
    final ls = spec.resolve(greg, 2, seed.days[label], label);
    expect(ls.badge?.color, emGold);
    expect(ls.foreground, emInk);
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

  test('painters: no repaint, deterministic lattice, any size', () {
    for (final size in [kPosterSize, const Size(10, 10), Size.zero]) {
      final m = emeraldMihrabMetrics(size, 30);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      EmeraldMihrabBackgroundPainter(m).paint(canvas, size);
      rec.endRecording().dispose();
    }
    final bg = EmeraldMihrabBackgroundPainter(_m());
    expect(bg.shouldRepaint(bg), isFalse);
    // The lattice path is built once per size and reused.
    final a = emLatticePath(kPosterSize);
    expect(identical(a, emLatticePath(kPosterSize)), isTrue);
    // Stars of the last node row may reach half a cell below the band (the
    // painter clips to the band).
    expect(a.getBounds().bottom, lessThanOrEqualTo(emLatticeHeight + 34));
    expect(a.getBounds().width, greaterThan(900));
  });

  testWidgets('seed render: real table geometry, FitText contained', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    expect(tester.takeException(), isNull);
    final m = _m(seedReferenceMonth().days.length);
    final origin = tester.getTopLeft(find.byType(PosterPreview));
    expect(
      tester.getRect(find.byKey(const ValueKey('em-table'))).shift(-origin),
      _rectClose(m.sections['table']!),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('em-arch'))).shift(-origin),
      _rectClose(m.sections['arch']!),
    );
    expect(expectFitTextsContained(tester), greaterThan(250));
    expect(midWordBreakOffenders(tester), isEmpty);
    expect(find.byKey(const ValueKey('em-title-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('em-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('em-brace')), findsOneWidget);
  });

  testWidgets('export right after pump + precache contains the medallion', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final med = _m().sections['medallion']!;
    expect(shot.width, 1000);
    // Dark-green disc in the medallion centre area, gold calligraphy in it.
    final inner = Rect.fromCenter(
      center: med.center,
      width: med.width * 0.6,
      height: med.height * 0.6,
    );
    expect(shot.goldIn(inner), greaterThan(800));
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
    // Only the dark backing disc remains under the (missing) medallion.
    expect(shot.goldIn(inner), lessThan(300));
  });

  testWidgets('no bleed: panels opaque over the lattice; rows opaque', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final s = _m().sections;
    // Lattice is visible in the top corners ...
    expect(shot.latticeIn(const Rect.fromLTWH(0, 300, 60, 200)), greaterThan(20));
    // ... but not inside the quote panels (between text box and border).
    final qr = s['quoteRight']!, qrt = s['quoteRightText']!;
    final probe = Offset(qrt.left + 4, qr.top + 12);
    expect(_close(shot.at(probe.dx, probe.dy), emNavyTop, 0.04), isTrue,
        reason: '${shot.at(probe.dx, probe.dy)}');
    // ... nor inside the arch panel beside the brace quote.
    final b = s['brace']!;
    final archPx = shot.at(b.left + 2, b.bottom + 2);
    expect(shot.goldIn(Rect.fromLTWH(b.left - 30, b.bottom - 6, 20, 6)), 0);
    expect(archPx.g > archPx.r && archPx.g < .45, isTrue, reason: '$archPx');
    // Rows are opaque: a notes cell gap shows the row colour.
    final row0 = _m(30).table.rowRect(0);
    expect(_close(shot.at(s['table']!.left + 5, row0.center.dy), emNavyRow),
        isTrue);
    // Bottom half below the lattice is plain (no gold strokes behind text);
    // the page edge left of the (wider, x >= 8) side strip.
    expect(
      shot.goldIn(Rect.fromLTWH(0, emLatticeHeight + 40, 6, 400)),
      0,
    );
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
    expect(find.byKey(const ValueKey('em-title-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('em-title-image')), findsNothing);
    expect(find.text('تقويم المؤمنين'), findsOneWidget);
    expect(find.byKey(const ValueKey('em-quote-right')), findsNothing);
    expect(find.byKey(const ValueKey('em-quote-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('em-brace')), findsNothing);
    expect(find.byKey(const ValueKey('em-pill')), findsNothing);
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
    print('emerald_mihrab warm builds (ms): $times');
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
