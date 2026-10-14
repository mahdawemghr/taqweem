import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/emerald_garden.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';
import 'contrast_test.dart' show contrastRatio;

const _t = EmeraldGardenTemplate();

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

KitMetrics _m([int rows = 30]) => emeraldGardenMetrics(kPosterSize, rows);

bool _close(Color a, Color b, [double tol = 0.02]) =>
    (a.r - b.r).abs() < tol &&
    (a.g - b.g).abs() < tol &&
    (a.b - b.b).abs() < tol;

/// Whether [p] lies inside the basket arch's upper half-ellipse of [arch]
/// shrunk by [margin] (or below its springing line).
bool _insideArch(Rect arch, Offset p, double margin) {
  final rise = gdArchShape.archRise(arch.width, arch.height);
  final cy = arch.top + rise;
  if (p.dy >= cy) {
    return p.dx > arch.left + margin && p.dx < arch.right - margin;
  }
  final a = arch.width / 2 - margin, b = rise - margin;
  final dx = (p.dx - arch.center.dx) / a, dy = (p.dy - cy) / b;
  return dx * dx + dy * dy < 1;
}

void main() {
  setUpAll(loadAppFonts);

  test('id, Arabic name, registered after emerald_mihrab', () {
    expect(_t.id, 'emerald_garden');
    expect(_t.nameAr, 'زمردي بالأرابيسك');
    final ids = allTemplates.map((t) => t.id).toList();
    expect(ids.indexOf('emerald_garden'), ids.indexOf('emerald_mihrab') + 1);
    expect(templateById('emerald_garden'), isA<EmeraldGardenTemplate>());
  });

  test('palette and theme constants', () {
    expect(gdEmerald, const Color(0xFF0B3D2E));
    expect(gdFieldLight, const Color(0xFF125440));
    expect(gdGold, const Color(0xFFD4AF5E));
    expect(gdNavy, const Color(0xFF0F1B33));
    expect(gdCream, const Color(0xFFF8EED6));
    expect(gdInk, const Color(0xFF0F1E18));
    final th = _t.theme;
    expect(th.background, gdFieldLight);
    expect(th.tableHeaderBg, gdGold);
    expect(th.tableHeaderFg, gdInk);
    // The theme's rows are the glass rows composited over the arch.
    expect(_close(th.rowBg, gdRowDarkOnArch, 0.01), isTrue);
    expect(_close(th.rowAltBg, gdRowLightOnArch, 0.01), isTrue);
    expect(th.rowText, gdCream);
    expect(th.highlightBg, gdGold);
    expect(th.labelCellBg, gdGold);
    expect(th.quoteBoxBg, gdNavy);
    expect(th.tableFont, 'Tajawal');
  });

  test('uses the double-ring emerald medallion (precached)', () {
    expect(_t.images, const [medallionEmeraldBAsset]);
    expect(
      medallionEmeraldBAsset.assetName,
      'assets/logos/medallion_emerald_b.png',
    );
  });

  group('contrast in the real composition (>= 4.5:1)', () {
    Color glass(Color row, Color under) => Color.alphaBlend(row, under);
    final pairs = <String, (Color, Color)>{
      'quote cream / banner top': (gdCream, gdNavyTop),
      'quote cream / banner bottom': (gdCream, gdNavy),
      'attribution gold / banner top': (gdGold, gdNavyTop),
      'brace gold / arch top': (gdBraceGold, gdArchTop),
      'brace gold / arch bottom': (gdBraceGold, gdArchBottom),
      'table header ink / gold': (gdInk, gdGold),
      'row cream / dark glass over arch top': (
        gdCream,
        glass(gdRowDark, gdArchTop),
      ),
      'row cream / dark glass over arch bottom': (
        gdCream,
        glass(gdRowDark, gdArchBottom),
      ),
      'row cream / light glass over arch top': (
        gdCream,
        glass(gdRowLight, gdArchTop),
      ),
      'row cream / light glass over arch bottom': (
        gdCream,
        glass(gdRowLight, gdArchBottom),
      ),
      'highlight ink / gold': (gdInk, gdGold),
      'weekday / hijri pill ink / gold': (gdInk, gdGold),
      'pill on highlighted row light gold / dark pill': (
        gdGoldLight,
        gdPillDark,
      ),
      'label ink / gold pill': (gdInk, gdGold),
      'strip label gold / strip fill': (gdGold, gdStripFill),
      'strip text cream / strip fill': (gdCream, gdStripFill),
      'footer note cream / lightest field': (gdCream, gdFieldLight),
      'article cream / article navy top': (gdCream, gdNavyTop),
      'article cream / article navy': (gdCream, gdNavy),
      'fatiha gold / article navy': (gdGold, gdNavy),
      'author ink / pill light gold': (gdInk, gdGoldLight),
      'author ink / pill gold': (gdInk, gdGold),
      'edited title gold / disc': (gdGoldLight, gdDisc),
    };
    pairs.forEach((name, p) {
      test(name, () {
        final r = contrastRatio(p.$1, p.$2);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name = $r');
      });
    });
  });

  test('geometry: everything stays clear of the ornate border', () {
    final s = _m().sections;
    final field = s['field']!;
    expect(field, const Rect.fromLTRB(42, 42, 958, 2158));
    final safe = field.deflate(6);
    for (final id in [
      'medallion',
      'banner',
      'quoteRightText',
      'quoteLeftText',
      'arch',
      'rule',
      'brace',
      'table',
      'stripRight',
      'stripLeft',
      'footerNote',
      'article',
      'pill',
    ]) {
      final r = s[id]!;
      expect(
        safe.contains(r.topLeft) &&
            safe.contains(r.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: '$id $r',
      );
    }
  });

  test('geometry: banner, medallion, brace in the arch apex, table fills '
      'the arch', () {
    final m = _m();
    final s = m.sections;
    final med = s['medallion']!;
    expect(med.width, closeTo(290, 0.01));
    expect(med.center.dx, 500);
    // The banner runs across behind the medallion; text boxes are clear of
    // the medallion and inside the banner outline.
    final banner = s['banner']!;
    expect(banner.left, lessThan(med.left));
    expect(banner.right, greaterThan(med.right));
    expect(banner.top, greaterThan(med.top));
    expect(banner.bottom, lessThan(med.bottom));
    final bp = gdBannerPath(banner);
    for (final id in ['quoteRightText', 'quoteLeftText']) {
      final r = s[id]!;
      // Clear of the visible disc (the asset has a transparent margin).
      final disc = med.deflate(gdMedInk);
      expect(r.overlaps(disc), isFalse, reason: id);
      // Room for the quote: >= 280 px of text width per banner end.
      expect(r.width, greaterThanOrEqualTo(280), reason: id);
      for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        expect(bp.contains(p), isTrue, reason: '$id $p');
      }
    }
    // Brace and its rule sit in the apex, clear of the cusped lace line
    // (lace inset 12 + shallow cusps < 24).
    final arch = s['arch']!;
    for (final id in ['brace', 'rule']) {
      final b = s[id]!;
      for (final p in [b.topLeft, b.topRight, b.bottomLeft, b.bottomRight]) {
        expect(_insideArch(arch, p, 26), isTrue, reason: '$id $p');
      }
    }
    expect(s['rule']!.bottom, lessThan(s['brace']!.top));
    expect(s['brace']!.top, greaterThan(med.bottom));
    // Table in the straight part of the arch; rows share the height.
    expect(
      s['table']!.top,
      greaterThanOrEqualTo(
        arch.top + gdArchShape.archRise(arch.width, arch.height),
      ),
    );
    expect(m.table.rowsBottom, closeTo(s['table']!.bottom, 0.01));
    expect(m.table.rowHeight, greaterThan(35));
    for (final id in ['stripRight', 'stripLeft']) {
      expect(s[id]!.overlaps(arch), isFalse, reason: id);
      expect(s[id]!.width, greaterThanOrEqualTo(46));
    }
    expect(s['footerNote']!.top, greaterThan(arch.bottom));
    expect(s['pill']!.top, greaterThan(s['footerNote']!.bottom));
    expect(s['pill']!.center.dy, closeTo(s['article']!.top, 0.01));
  });

  test('banner path: pointed ends, sagging edges', () {
    const r = Rect.fromLTWH(0, 0, 800, 200);
    final p = gdBannerPath(r);
    expect(p.contains(const Offset(798, 108)), isTrue); // right tip
    expect(p.contains(const Offset(2, 108)), isTrue); // left tip
    expect(p.contains(const Offset(400, 4)), isTrue); // high centre
    expect(p.contains(const Offset(780, 4)), isFalse); // sagged end
    expect(gdBannerPath(Rect.zero).getBounds(), Rect.zero);
  });

  test('arch lace: cusped line inside the arch, cached', () {
    final arch = _m().sections['arch']!;
    final a = gdArchLacePath(arch);
    expect(identical(a, gdArchLacePath(arch)), isTrue);
    final b = a.getBounds();
    expect(b.left, greaterThanOrEqualTo(11.9));
    expect(b.top, greaterThanOrEqualTo(11.9));
    expect(b.right, lessThanOrEqualTo(arch.width - 11.9));
    expect(b.bottom, lessThanOrEqualTo(arch.height - 11.9));
    expect(
      gdArchLacePath(const Rect.fromLTWH(0, 0, 10, 10)).getBounds(),
      Rect.zero,
    );
  });

  test('table styling: gold header, glass rows, gold pills', () {
    final spec = emeraldGardenTableSpec;
    final cols = spec.columns;
    final weekday = cols.firstWhere((c) => c.kind == ColumnKind.weekday);
    final hijri = cols.firstWhere((c) => c.kind == ColumnKind.hijri);
    final greg = cols.firstWhere((c) => c.kind == ColumnKind.gregorian);
    final fajr = cols.firstWhere((c) => c.kind == ColumnKind.time);
    final seed = seedReferenceMonth();
    final normal = seed.days.indexWhere((d) => !d.highlighted);
    final hl = seed.days.indexWhere((d) => d.highlighted);
    final label = seed.days.indexWhere(
      (d) => d.gregorian.isLabel && !d.highlighted,
    );
    expect(spec.header.background, gdGold);
    expect(spec.header.foreground, gdInk);
    for (final c in [weekday, hijri]) {
      final st = spec.resolve(c, cols.indexOf(c), seed.days[normal], normal);
      expect(st.badge?.color, gdGold);
      expect(st.foreground, gdInk);
      final sh = spec.resolve(c, cols.indexOf(c), seed.days[hl], hl);
      expect(sh.badge?.color, gdPillDark);
      expect(sh.foreground, gdGoldLight);
    }
    expect(spec.resolve(fajr, 4, seed.days[0], 0).background, gdRowDark);
    expect(spec.resolve(fajr, 4, seed.days[1], 1).background, gdRowLight);
    expect(spec.resolve(fajr, 4, seed.days[0], 0).foreground, gdCream);
    expect(spec.resolve(greg, 2, seed.days[normal], normal).badge, isNull);
    expect(spec.resolve(greg, 2, seed.days[hl], hl).background, gdGold);
    expect(spec.resolve(greg, 2, seed.days[hl], hl).foreground, gdInk);
    final ls = spec.resolve(greg, 2, seed.days[label], label);
    expect(ls.badge?.color, gdGold);
    expect(ls.foreground, gdInk);
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

  test('ornate border: cached per size, deterministic, any size', () {
    for (final size in [kPosterSize, const Size(10, 10), Size.zero]) {
      final m = emeraldGardenMetrics(size, 30);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      EmeraldGardenBackgroundPainter(m).paint(canvas, size);
      rec.endRecording().dispose();
    }
    final bg = EmeraldGardenBackgroundPainter(_m());
    expect(bg.shouldRepaint(bg), isFalse);
    final a = gdBorderPaths(kPosterSize);
    expect(identical(a, gdBorderPaths(kPosterSize)), isTrue);
    // Strands and flowers stay inside the band (both sides).
    for (final p in [a.strands, a.fills]) {
      final b = p.getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(1000));
      expect(b.width, greaterThan(950));
      expect(b.height, greaterThan(2150));
    }
    // A point in the field is not on any strand or fill.
    expect(a.fills.contains(const Offset(500, 1100)), isFalse);
    expect(a.fills.contains(const Offset(80, 1100)), isFalse);
  });

  testWidgets('seed render: real table geometry, FitText contained', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    expect(tester.takeException(), isNull);
    final m = _m(seedReferenceMonth().days.length);
    final origin = tester.getTopLeft(find.byType(PosterPreview));
    expect(
      tester.getRect(find.byKey(const ValueKey('gd-table'))).shift(-origin),
      _rectClose(m.sections['table']!),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('gd-arch'))).shift(-origin),
      _rectClose(m.sections['arch']!),
    );
    expect(expectFitTextsContained(tester), greaterThan(250));
    expect(midWordBreakOffenders(tester), isEmpty);
    expect(find.byKey(const ValueKey('gd-title-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('gd-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('gd-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('gd-brace')), findsOneWidget);
  });

  testWidgets('export right after pump + precache contains the medallion', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final med = _m().sections['medallion']!;
    expect(shot.width, 1000);
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

  testWidgets('no bleed: border band ornate, field and panels clean', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final s = _m().sections;
    // Gold ornament in all four sides of the band.
    for (final r in const [
      Rect.fromLTWH(0, 1000, 42, 300),
      Rect.fromLTWH(958, 1000, 42, 300),
      Rect.fromLTWH(300, 0, 300, 42),
      Rect.fromLTWH(300, 2158, 300, 42),
    ]) {
      expect(shot.goldIn(r), greaterThan(200), reason: '$r');
    }
    // The field below the arabesque (between strip and footer) is plain.
    expect(shot.goldIn(const Rect.fromLTWH(46, 1792, 50, 14)), 0);
    // The banner is opaque navy between its text box and its border.
    final qrt = s['quoteRightText']!;
    final px = shot.at(qrt.left + 4, s['banner']!.center.dy);
    expect(px.b > px.g && px.b > px.r, isTrue, reason: '$px');
    // The arch beside the brace shows the arch green (no gold).
    final b = s['brace']!;
    expect(shot.goldIn(Rect.fromLTWH(b.left - 40, b.bottom - 8, 20, 8)), 0);
    // Rows are glass over the arch: an empty notes cell shows the row tone.
    final row0 = _m(30).table.rowRect(0);
    expect(
      _close(
        shot.at(s['table']!.left + 5, row0.center.dy),
        gdRowDarkOnArch,
        0.03,
      ),
      isTrue,
      reason: '${shot.at(s['table']!.left + 5, row0.center.dy)}',
    );
  });

  test('wider table: notes column >= 260 px; notes header capped at 30', () {
    final m = _m();
    final notes = m.table.columns.last;
    expect(notes.width, greaterThanOrEqualTo(260));
    expect(gdBorderWidth, inInclusiveRange(42, 46));
    final nc = emeraldGardenTableSpec.columns.last;
    expect(nc.kind, ColumnKind.notes);
    expect(nc.headerStyle?.maxSize, lessThanOrEqualTo(30));
  });

  test('arabesque: cached (bounded), deterministic, inside its band', () {
    final a = gdArabesquePaths(kPosterSize);
    expect(identical(a, gdArabesquePaths(kPosterSize)), isTrue);
    final b = a.ribbons.getBounds();
    expect(b.top, greaterThanOrEqualTo(0));
    expect(b.bottom, lessThanOrEqualTo(gdArabesqueBottom + 0.01));
    expect(b.width, greaterThan(1000));
    // The clip region excludes the arch and stays in the field top band.
    final region = gdArabesqueRegion(_m());
    final s = _m().sections;
    expect(region.contains(s['brace']!.center), isFalse);
    expect(region.contains(s['rule']!.center), isFalse);
    expect(region.contains(const Offset(70, 450)), isTrue); // spandrel
    expect(region.contains(const Offset(200, 70)), isTrue); // top band
    expect(region.contains(const Offset(20, 70)), isFalse); // border band
    expect(region.getBounds().bottom, lessThanOrEqualTo(s['table']!.top + 12));
    // Bounded caches: never more than 4 entries.
    for (var i = 0; i < 7; i++) {
      final size = Size(900 + i * 10.0, 2200);
      gdArabesquePaths(size);
      gdBorderPaths(size);
      gdArchLacePath(Rect.fromLTWH(0, 0, 700 + i * 10.0, 1400));
    }
    expect(gdArabesqueCache.length, lessThanOrEqualTo(4));
    expect(gdBorderCache.length, lessThanOrEqualTo(4));
    expect(gdLaceCache.length, lessThanOrEqualTo(4));
    // Rebuilding an evicted size gives the same geometry (deterministic).
    expect(gdArabesqueCache.containsKey(kPosterSize), isFalse);
    expect(
      gdArabesquePaths(kPosterSize).leaves.getBounds(),
      a.leaves.getBounds(),
    );
  });

  test('background painter repaints only when its metrics change', () {
    final a = EmeraldGardenBackgroundPainter(_m());
    expect(a.shouldRepaint(EmeraldGardenBackgroundPainter(_m())), isFalse);
    expect(a.shouldRepaint(EmeraldGardenBackgroundPainter(_m(29))), isTrue);
    expect(
      a.shouldRepaint(
        EmeraldGardenBackgroundPainter(
          emeraldGardenMetrics(const Size(900, 2000), 30),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('header quotes are set at >= 26 px', (tester) async {
    final seed = seedReferenceMonth();
    await _pump(tester, seed);
    for (final q in [seed.texts.rightQuote.text, seed.texts.leftQuote.text]) {
      final f = find.descendant(
        of: find.byType(QuoteBlock),
        matching: find.text(q),
      );
      expect(f, findsOneWidget, reason: q);
      final size = tester.widget<Text>(f).style!.fontSize!;
      expect(size, greaterThanOrEqualTo(26), reason: '$q at $size');
    }
  });

  testWidgets('arabesque: rich gold in the top band and spandrels, none '
      'behind text', (tester) async {
    final seed = seedReferenceMonth();
    await _pump(tester, seed);
    final shot = await _capture(tester);
    final m = _m(seed.days.length);
    final s = m.sections;
    // Present: above the banner, and in both spandrels beside the apex.
    expect(shot.goldIn(const Rect.fromLTWH(60, 46, 260, 50)), greaterThan(300));
    expect(
      shot.goldIn(const Rect.fromLTWH(46, 360, 50, 160)),
      greaterThan(60),
    );
    expect(
      shot.goldIn(const Rect.fromLTWH(904, 360, 50, 160)),
      greaterThan(60),
    );
    // Absent behind text: header quote boxes (cream text on navy; the gold
    // attribution line at the bottom excluded) ...
    for (final id in ['quoteRightText', 'quoteLeftText']) {
      final r = s[id]!;
      expect(
        shot.goldIn(Rect.fromLTRB(r.left, r.top, r.right, r.bottom - 40)),
        0,
        reason: id,
      );
    }
    // ... the arch around the brace quote (between brace box and lace) ...
    final b = s['brace']!;
    expect(shot.goldIn(Rect.fromLTWH(b.left - 30, b.top, 16, b.height)), 0);
    expect(shot.goldIn(Rect.fromLTWH(b.right + 14, b.top, 16, b.height)), 0);
    // ... and the table: an empty notes cell shows only the glass tone.
    final empty = seed.days.indexWhere((d) => d.note.isEmpty && !d.highlighted);
    final notes = m.table.columns.last;
    final row = m.table.rowRect(empty);
    final cell = Rect.fromLTRB(
      notes.left,
      row.top,
      notes.right,
      row.bottom,
    ).deflate(5);
    expect(shot.goldIn(cell), 0);
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
    expect(find.byKey(const ValueKey('gd-title-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('gd-title-image')), findsNothing);
    expect(find.text('تقويم المؤمنين'), findsOneWidget);
    // The left quote still needs the banner.
    expect(find.byKey(const ValueKey('gd-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('gd-brace')), findsNothing);
    expect(find.byKey(const ValueKey('gd-pill')), findsNothing);
    expect(find.textContaining('سؤال'), findsOneWidget); // right strip only
    expect(find.textContaining('{'), findsOneWidget); // article body only
    expectFitTextsContained(tester);
  });

  testWidgets('no quotes: no banner', (tester) async {
    final seed = seedReferenceMonth();
    await _pump(
      tester,
      seed.copyWith(
        texts: seed.texts.copyWith(
          rightQuote: const HeaderQuote.empty(),
          leftQuote: const HeaderQuote.empty(),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('gd-banner')), findsNothing);
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
    print('emerald_garden warm builds (ms): $times');
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
