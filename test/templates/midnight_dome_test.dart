import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/midnight_dome.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';
import 'contrast_test.dart' show contrastRatio;

const _t = MidnightDomeTemplate();

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

  /// Gold-ish pixels (red well above blue, bright) in [r].
  int goldIn(Rect r) =>
      _count(r, (c) => c.r > .55 && c.r - c.b > .2 && c.g > .4);

  /// Green pixels (green well above red and blue) in [r].
  int greenIn(Rect r) =>
      _count(r, (c) => c.g > .3 && c.g - c.r > .12 && c.g - c.b > .05);

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

KitMetrics _m([int rows = 30]) => midnightDomeMetrics(kPosterSize, rows);

/// [local] (relative to [r]'s centre, unrotated) mapped into the poster by
/// the panel's tilt [angle].
Offset _tilted(Rect r, Offset local, double angle) {
  final c = math.cos(angle), s = math.sin(angle);
  return r.center +
      Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
}

void main() {
  setUpAll(loadAppFonts);

  test('id, Arabic name, registered after navy_calligraphy', () {
    expect(_t.id, 'midnight_dome');
    expect(_t.nameAr, 'ليلي بالقبة الخضراء');
    final ids = allTemplates.map((t) => t.id).toList();
    expect(ids.indexOf('midnight_dome'), ids.indexOf('navy_calligraphy') + 1);
    expect(templateById('midnight_dome'), isA<MidnightDomeTemplate>());
  });

  test('palette and theme constants', () {
    expect(mdBgMid, const Color(0xFF0A1529));
    expect(mdGold, const Color(0xFFC9A04E));
    expect(mdGoldText, const Color(0xFFE6C274));
    expect(mdCream, const Color(0xFFF4EBD8));
    expect(mdGreen, const Color(0xFF1C6847));
    expect(mdGreenHeader, const Color(0xFF0F4732));
    expect(mdHighlight, const Color(0xFF7A5424));
    final th = _t.theme;
    expect(th.background, mdBgMid);
    expect(th.tableHeaderBg, mdHeader);
    expect(th.tableHeaderFg, mdGoldText);
    expect(th.rowText, mdCream);
    expect(th.highlightBg, mdHighlight);
    expect(th.highlightFg, mdCream);
    expect(th.labelCellBg, mdGreen);
    expect(th.quoteBoxBg, mdPanel);
    expect(th.quoteText, mdCream);
    expect(th.tableFont, 'Tajawal');
  });

  test('clearly different from mosque_blue and navy_calligraphy', () {
    final th = _t.theme;
    for (final id in ['mosque_blue', 'navy_calligraphy']) {
      final o = templateById(id);
      expect(th.tableHeaderBg, isNot(o.theme.tableHeaderBg), reason: id);
      expect(th.highlightBg, isNot(o.theme.highlightBg), reason: id);
      expect(th.rowBg, isNot(o.theme.rowBg), reason: id);
      expect(o.images, isNot(contains(titleGoldAsset)), reason: id);
    }
    // The signature pieces: gold title + dome, three glass panels.
    expect(_t.images, const [titleGoldAsset, domeGreenAsset]);
    expect(midnightDomeTableSpec.split, isTrue);
    expect(midnightDomeTableSpec.panels, hasLength(3));
  });

  test('assets: gold title and green dome', () {
    expect(titleGoldAsset.assetName, 'assets/logos/title_gold.png');
    expect(domeGreenAsset.assetName, 'assets/logos/dome_green.png');
  });

  test('theme pairs reach 4.5:1 (the loop in contrast_test checks too)', () {
    final pairs = <(Color, Color)>[
      (mdCream, mdGlassRow),
      (mdGoldText, mdHeader),
      (mdGoldText, mdGreenHeader),
      (mdCream, mdHighlight),
      (mdCream, mdGreen),
      (mdWhite, mdGreenDeep),
      (mdCream, mdPanel),
      (mdGoldText, mdPanel),
      (mdGoldText, mdPill),
      (mdCream, mdBronzeA),
      (mdCream, mdBronzeC),
      (mdCream, mdTealA),
    ];
    for (final p in pairs) {
      expect(
        contrastRatio(p.$1, p.$2),
        greaterThanOrEqualTo(4.5),
        reason: '$p',
      );
    }
  });

  test('geometry: sections inside the page, nothing collides', () {
    final m = _m();
    final s = m.sections;
    final page = (Offset.zero & kPosterSize).deflate(10);
    for (final e in s.entries) {
      expect(
        page.contains(e.value.topLeft) &&
            page.contains(e.value.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: '${e.key} ${e.value}',
      );
    }
    final title = s['title']!;
    expect(title.width, 480);
    expect(title.center.dx, 500);
    final dome = s['dome']!;
    expect(dome.width, 138); // 1:1 with the asset: sharp
    expect(dome.center.dx, 500);
    expect(dome.top, greaterThan(title.top + title.height * 0.8));
    expect(s['ribbon']!.top, greaterThan(dome.bottom));
    expect(s['ribbon']!.bottom, lessThan(s['table']!.top));
    // Rows share the height equally, line up across the panels and are not
    // cramped.
    expect(m.table.panels, hasLength(3));
    expect(m.table.rowsBottom, closeTo(m.table.innerPanels.first.bottom, .01));
    for (final r in m.table.innerPanels) {
      expect(r.top, closeTo(m.table.innerPanels.first.top, .01));
      expect(r.bottom, closeTo(m.table.innerPanels.first.bottom, .01));
    }
    expect(m.table.rowHeight, greaterThan(40));
    // Notes panel (left) is the widest.
    final widths = m.table.panels.map((r) => r.width).toList();
    expect(widths[2], greaterThan(widths[0]));
    expect(widths[2], greaterThan(widths[1]));
    for (final id in ['stripRight', 'stripLeft']) {
      expect(s[id]!.overlaps(s['table']!), isFalse, reason: id);
      expect(s[id]!.height, s['table']!.height);
    }
    expect(s['footerNote']!.top, greaterThan(s['table']!.bottom));
    expect(s['article']!.top, greaterThan(s['footerNote']!.bottom));
    expect(s['fatiha']!.top, greaterThan(s['article']!.bottom));
  });

  test('tilted quote panels stay on the page and clear of title ink, dome '
      'and ribbon', () {
    final s = _m().sections;
    final title = s['title']!;
    // title_gold.png has 23 px transparent margins (of 601) left and right.
    final ink = Rect.fromLTRB(
      title.left + title.width * 23 / 601,
      title.top,
      title.right - title.width * 23 / 601,
      title.bottom,
    );
    final page = (Offset.zero & kPosterSize).deflate(12);
    for (final (id, angle) in [
      ('quoteRight', mdQuoteTilt),
      ('quoteLeft', -mdQuoteTilt),
    ]) {
      final corners = mdRotatedCorners(s[id]!, angle);
      for (final c in corners) {
        expect(page.contains(c), isTrue, reason: '$id $c');
        expect(ink.contains(c), isFalse, reason: '$id $c');
      }
      final xs = corners.map((c) => c.dx);
      final ys = corners.map((c) => c.dy);
      final box = Rect.fromLTRB(
        xs.reduce(math.min),
        ys.reduce(math.min),
        xs.reduce(math.max),
        ys.reduce(math.max),
      );
      expect(box.overlaps(ink), isFalse, reason: id);
      expect(box.overlaps(s['dome']!), isFalse, reason: id);
      expect(box.bottom, lessThan(s['ribbon']!.top), reason: id);
    }
    expect(mdQuoteTilt, closeTo(6 * math.pi / 180, 1e-9));
  });

  test('lattice: cached, covers the page, painters safe at any size', () {
    final a = mdLatticePath(kPosterSize);
    expect(identical(a, mdLatticePath(kPosterSize)), isTrue);
    final b = a.getBounds();
    expect(b.left, lessThanOrEqualTo(0));
    expect(b.top, lessThanOrEqualTo(0));
    expect(b.right, greaterThanOrEqualTo(1000));
    expect(b.bottom, greaterThanOrEqualTo(2200));
    for (final size in [kPosterSize, const Size(10, 10), Size.zero]) {
      final rec = ui.PictureRecorder();
      MidnightDomeBackgroundPainter(midnightDomeMetrics(size, 30))
          .paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }
    final bg = MidnightDomeBackgroundPainter(_m());
    expect(bg.shouldRepaint(bg), isFalse);
  });

  test('table styling: headers, pills, highlight, labels, column order', () {
    final spec = midnightDomeTableSpec;
    final cols = spec.columns;
    final hijri = cols.firstWhere((c) => c.kind == ColumnKind.hijri);
    final greg = cols.firstWhere((c) => c.kind == ColumnKind.gregorian);
    final notes = cols.firstWhere((c) => c.kind == ColumnKind.notes);
    final fajr = cols.firstWhere((c) => c.kind == ColumnKind.time);
    final seed = seedReferenceMonth();
    final normal = seed.days.indexWhere((d) => !d.highlighted);
    final hl = seed.days.indexWhere((d) => d.highlighted);
    final label = seed.days.indexWhere(
      (d) => d.gregorian.isLabel && !d.highlighted,
    );
    expect(spec.header.background, mdHeader);
    expect(spec.header.foreground, mdGoldText);
    expect(spec.header.merge(notes.headerStyle).background, mdGreenHeader);
    expect(spec.panel?.shape.kind, ShapeKind.rounded);
    // Green day pill; gold-ringed on highlighted days.
    final np = spec.resolve(hijri, 1, seed.days[normal], normal);
    expect(np.badge?.color, mdGreen);
    final hp = spec.resolve(hijri, 1, seed.days[hl], hl);
    expect(hp.badge, mdImportantPill);
    expect(hp.badge?.border?.color, mdGoldText);
    // Highlighted rows: brown-gold with cream text.
    final h = spec.resolve(greg, 2, seed.days[hl], hl);
    expect(h.background, mdHighlight);
    expect(h.foreground, mdCream);
    // Month-change label: green pill, cream text.
    final ls = spec.resolve(greg, 2, seed.days[label], label);
    expect(ls.badge?.color, mdGreen);
    expect(ls.foreground, mdCream);
    expect(spec.resolve(fajr, 4, seed.days[0], 0).foreground, mdWhite);
    expect(spec.panels.map((g) => g.map((c) => c.kind).toList()).toList(), [
      [
        ColumnKind.weekday,
        ColumnKind.hijri,
        ColumnKind.gregorian,
        ColumnKind.solar,
      ],
      [ColumnKind.time, ColumnKind.time, ColumnKind.time, ColumnKind.time],
      [ColumnKind.notes],
    ]);
  });

  test('Tajawal braces and bracketed attribution are plain', () {
    expect(mdTajawalBraced('x'), '{ x }');
    expect(mdAttribution('a'), '[ a ]');
    expect(mdAttribution(''), '');
  });

  testWidgets('seed render: real table geometry, FitText contained', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    expect(tester.takeException(), isNull);
    final m = _m(seedReferenceMonth().days.length);
    final origin = tester.getTopLeft(find.byType(PosterPreview));
    expect(
      tester.getRect(find.byKey(const ValueKey('md-table'))).shift(-origin),
      _rectClose(m.sections['table']!),
    );
    expect(expectFitTextsContained(tester), greaterThan(250));
    expect(midWordBreakOffenders(tester), isEmpty);
    for (final k in [
      'md-title-image',
      'md-dome',
      'md-quote-right',
      'md-quote-left',
      'md-ribbon',
      'md-brace',
      'md-strip-right',
      'md-strip-left',
      'md-article',
      'md-author',
      'md-fatiha',
    ]) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
  });

  testWidgets('long quotes fit inside the tilted panels (FitText)', (
    tester,
  ) async {
    final seed = seedReferenceMonth();
    const long =
        'نحن وسيلته في خلقه ونحن خاصته ومحل قدسه ونحن حجته في غيبه ونحن '
        'ورثة أنبيائه نحن وسيلته في خلقه ونحن خاصته ومحل قدسه ونحن حجته '
        'في غيبه ونحن ورثة أنبيائه';
    await _pump(
      tester,
      seed.copyWith(
        texts: seed.texts.copyWith(
          rightQuote: const HeaderQuote(
            text: long,
            attribution: 'فاطمة الزهراء(س)',
          ),
          leftQuote: const HeaderQuote(
            text: long,
            attribution: 'الإمام الكاظم(ع)',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expectFitTextsContained(tester);
    expect(midWordBreakOffenders(tester), isEmpty);
    // The quote panels really are rotated.
    final tr = tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(const ValueKey('md-quote-right')),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(tr.transform.storage[1], closeTo(math.sin(mdQuoteTilt), 1e-6));
  });

  testWidgets('export right after pump + precache contains title and dome', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    expect(shot.width, 1000);
    final s = _m().sections;
    expect(shot.goldIn(s['title']!.deflate(20)), greaterThan(1500));
    expect(shot.greenIn(s['dome']!.deflate(20)), greaterThan(300));
  });

  testWidgets('control: without precache the logos are missing', (
    tester,
  ) async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await _pump(tester, seedReferenceMonth(), precache: false);
    final shot = await _capture(tester);
    final s = _m().sections;
    expect(shot.goldIn(s['title']!.deflate(20)), lessThan(50));
    expect(shot.greenIn(s['dome']!.deflate(20)), lessThan(20));
  });

  testWidgets('contrast measured on the rendered pixels (>= 4.5:1)', (
    tester,
  ) async {
    final seed = seedReferenceMonth();
    await _pump(tester, seed);
    final shot = await _capture(tester);
    final m = _m(seed.days.length);
    final s = m.sections;
    final g = m.table;
    final cols = midnightDomeTableSpec.columns;
    int col(ColumnKind k) => cols.indexWhere((c) => c.kind == k);
    final notesCol = g.columns[col(ColumnKind.notes)];
    final fajrCol = g.columns[col(ColumnKind.time)];
    final hijriCol = g.columns[col(ColumnKind.hijri)];
    final days = seed.days;
    int row(bool Function(DayRow d, int i) f) {
      for (var i = 0; i < days.length; i++) {
        if (f(days[i], i)) return i;
      }
      throw StateError('no row');
    }

    final normalEmpty = row(
      (d, i) => i.isEven && !d.highlighted && d.note.isEmpty,
    );
    final altEmpty = row((d, i) => i.isOdd && !d.highlighted && d.note.isEmpty);
    final hl = row((d, i) => d.highlighted);
    final plainDay = row((d, i) => !d.highlighted);
    final labelRow = row((d, i) => d.gregorian.isLabel && !d.highlighted);
    final gregCol = g.columns[col(ColumnKind.gregorian)];

    final samples = <String, (Color, List<Offset>)>{
      'cream row text / glass (normal row)': (
        mdCream,
        [
          Offset(notesCol.center.dx, g.rowRect(normalEmpty).center.dy),
          Offset(fajrCol.left + 2, g.rowRect(normalEmpty).top + 3),
        ],
      ),
      'cream row text / glass (stripe)': (
        mdCream,
        [
          Offset(notesCol.center.dx, g.rowRect(altEmpty).center.dy),
          Offset(fajrCol.left + 2, g.rowRect(altEmpty).top + 3),
        ],
      ),
      'cream / bronze highlighted row': (
        mdCream,
        [
          Offset(notesCol.left + 3, g.rowRect(hl).top + 3),
          Offset(fajrCol.left + 2, g.rowRect(hl).top + 3),
        ],
      ),
      'gold header text / dark header': (
        mdGoldText,
        [
          Offset(fajrCol.left + 3, g.innerPanels[1].top + 3),
          Offset(hijriCol.left + 3, g.innerPanels[0].top + 3),
        ],
      ),
      'gold header text / green notes header': (
        mdGoldText,
        [
          Offset(notesCol.left + 6, g.innerPanels[2].top + 4),
          Offset(notesCol.right - 6, g.headerBottom - 4),
        ],
      ),
      'white day number / green pill': (
        mdWhite,
        [Offset(hijriCol.left + 10, g.rowRect(plainDay).center.dy)],
      ),
      'white day number / gold-ringed pill': (
        mdWhite,
        [Offset(hijriCol.left + 11, g.rowRect(hl).center.dy)],
      ),
      'cream label / green label pill': (
        mdCream,
        [Offset(gregCol.center.dx, g.rowRect(labelRow).top + 8)],
      ),
      'cream quote / tilted navy panel': (
        mdCream,
        [
          _tilted(s['quoteRight']!, const Offset(-101, 119), mdQuoteTilt),
          _tilted(s['quoteLeft']!, const Offset(101, 119), -mdQuoteTilt),
          _tilted(s['quoteRight']!, const Offset(101, -119), mdQuoteTilt),
        ],
      ),
      'gold attribution / tilted navy panel': (
        mdGoldText,
        [_tilted(s['quoteLeft']!, const Offset(-101, 119), -mdQuoteTilt)],
      ),
      'cream brace text / teal ribbon': (
        mdCream,
        [
          Offset(500, s['ribbon']!.top + 9.5),
          Offset(500, s['ribbon']!.bottom - 9.5),
        ],
      ),
      'strip text / navy strip': (
        mdCream,
        [
          Offset(s['stripRight']!.center.dx, s['stripRight']!.bottom - 9),
          Offset(s['stripLeft']!.center.dx, s['stripLeft']!.bottom - 9),
        ],
      ),
      'cream article body / bronze panel': (
        mdCream,
        [
          s['article']!.bottomLeft + const Offset(20, -16),
          s['article']!.topRight + const Offset(-40, 30),
          s['article']!.bottomRight + const Offset(-20, -16),
        ],
      ),
      'gold author / dark pill': (
        mdGoldText,
        [Offset(500 - 470 / 2 + 30, s['article']!.top + 7.2 + 10 + 24)],
      ),
      'cream footer / field': (
        mdCream,
        [
          Offset(500, s['footerNote']!.top - 2),
          Offset(60, s['footerNote']!.bottom + 2),
          Offset(940, s['footerNote']!.bottom + 2),
        ],
      ),
      'cream fatiha / field (green glow)': (
        mdCream,
        [
          Offset(500, s['fatiha']!.top + 2),
          Offset(960, s['fatiha']!.center.dy),
          Offset(500, 2196),
        ],
      ),
    };
    final report = <String>[];
    samples.forEach((name, v) {
      for (final p in v.$2) {
        final px = shot.at(p.dx, p.dy);
        final r = contrastRatio(v.$1, px);
        report.add(
          '$name @${p.dx.round()},${p.dy.round()}: '
          '${r.toStringAsFixed(2)}',
        );
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name $p $px = $r');
      }
    });
    // ignore: avoid_print
    print('midnight_dome measured contrast:\n${report.join('\n')}');
  });

  testWidgets('no bleed: glass stays dark, lattice faint, ornaments gold', (
    tester,
  ) async {
    await _pump(tester, seedReferenceMonth());
    final shot = await _capture(tester);
    final m = _m();
    final s = m.sections;
    // Glass panels are dark (luminance well below cream text).
    for (final r in m.table.innerPanels) {
      final px = shot.at(r.left + 4, m.table.rowRect(0).center.dy);
      expect(px.computeLuminance(), lessThan(0.04), reason: '$r $px');
    }
    // The lattice is faint: the corner is never far from the field.
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

    final corner = lum(const Rect.fromLTWH(0, 0, 12, 300));
    final mid = lum(const Rect.fromLTWH(0, 1100, 12, 300));
    expect(corner, greaterThan(mid)); // the pattern shows in the corner
    expect(corner, lessThan(0.03)); // ... but only faintly
    // The ribbon tips and the fatiha stars are gold.
    final deco = s['ribbonDeco']!;
    expect(
      shot.goldIn(Rect.fromLTWH(deco.left, deco.top, 60, deco.height)),
      greaterThan(10),
    );
    final f = s['fatiha']!;
    expect(
      shot.goldIn(Rect.fromLTWH(f.left, f.top, 120, f.height)),
      greaterThan(10),
    );
    // Green glow at the bottom-right is greener than the bottom-left.
    final br = shot.at(990, 2000), bl = shot.at(10, 2000);
    expect(br.g - br.b, greaterThan(bl.g - bl.b));
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
          fatiha: '',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('md-title-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('md-title-image')), findsNothing);
    expect(find.text('تقويم المؤمنين'), findsOneWidget);
    expect(find.byKey(const ValueKey('md-quote-right')), findsNothing);
    expect(find.byKey(const ValueKey('md-quote-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('md-ribbon')), findsNothing);
    expect(find.byKey(const ValueKey('md-author')), findsNothing);
    expect(find.byKey(const ValueKey('md-fatiha')), findsNothing);
    expect(find.byKey(const ValueKey('md-dome')), findsOneWidget);
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
    print('midnight_dome warm builds (ms): $times');
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
