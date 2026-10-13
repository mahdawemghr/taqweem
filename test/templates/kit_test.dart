import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';
import 'kit_demo_template.dart';

const _demo = KitDemoTemplate();

/// [n] characters of Arabic text with word breaks (as in overflow_test).
String _arabic(int n) {
  const word = 'السلام عليكم ورحمة الله وبركاته ';
  final b = StringBuffer();
  while (b.length < n) {
    b.write(word);
  }
  return b.toString().substring(0, n);
}

/// 30 rows x 400-char notes, null times, long texts everywhere.
MonthPoster _extreme() {
  final seed = seedReferenceMonth();
  final long = _arabic(240);
  return seed.copyWith(
    gregorianHeader: _arabic(90),
    solarHeader: _arabic(90),
    days: [
      for (final d in seed.days)
        d.copyWith(
          note: _arabic(400),
          times: const PrayerTimes(),
          highlighted: d.hijriDay.isEven,
        ),
    ],
    texts: seed.texts.copyWith(
      title: _arabic(120),
      braceQuote: long,
      rightQuote: HeaderQuote(text: long, attribution: _arabic(80)),
      leftQuote: HeaderQuote(text: long, attribution: _arabic(80)),
      article: ClosingArticle(author: _arabic(100), body: _arabic(2000)),
      sideRight: SideQa(question: long, answer: long),
      sideLeft: SideQa(question: long, answer: long),
      footerNotes: _arabic(300),
      fatiha: _arabic(200),
    ),
  );
}

/// Empty notes, all-null times, every free text empty.
MonthPoster _emptyNotes() {
  final seed = seedReferenceMonth();
  return seed.copyWith(
    days: [
      for (final d in seed.days)
        d.copyWith(note: '', times: const PrayerTimes()),
    ],
    texts: const PosterTexts.empty().copyWith(footerNotes: ''),
  );
}

/// No rows at all.
MonthPoster _noRows() => MonthPoster(
  id: 'empty',
  updatedAt: DateTime.utc(2026, 1, 1),
  hijriMonthIndex: 0,
  hijriYear: 1448,
);

Future<void> _pump(WidgetTester tester, MonthPoster p) async {
  await tester.binding.setSurfaceSize(kPosterSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosterPreview(poster: p, width: 1000, template: _demo),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// A 1x1 opaque white PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/'
  'fteaysAAAAASUVORK5CYII=',
);

void main() {
  setUpAll(loadAppFonts);

  group('PanelShape', () {
    const r = Rect.fromLTWH(0, 0, 200, 300);

    test('rect and rounded', () {
      final rect = const PanelShape.rect().pathFor(r);
      expect(rect.contains(const Offset(1, 1)), isTrue);
      expect(rect.contains(const Offset(199, 299)), isTrue);
      final rounded = const PanelShape.rounded(40).pathFor(r);
      expect(rounded.contains(const Offset(2, 2)), isFalse); // corner cut
      expect(rounded.contains(const Offset(40, 40)), isTrue);
      expect(rounded.contains(const Offset(100, 1)), isTrue);
    });

    test('round arch: semicircular top, square bottom', () {
      final p = const PanelShape.arch().pathFor(r); // rise = 100
      expect(p.contains(const Offset(100, 2)), isTrue); // apex
      expect(p.contains(const Offset(5, 5)), isFalse); // top corners empty
      expect(p.contains(const Offset(195, 5)), isFalse);
      expect(p.contains(const Offset(2, 150)), isTrue); // straight sides
      expect(p.contains(const Offset(1, 299)), isTrue); // square bottom
    });

    test('pointed arch with rise and rounded bottom corners', () {
      const s = PanelShape.arch(rise: 120, pointed: true, radius: 20);
      final p = s.pathFor(r);
      expect(p.contains(const Offset(100, 3)), isTrue); // near the point
      expect(p.contains(const Offset(60, 10)), isFalse); // outside the ogive
      expect(p.contains(const Offset(3, 125)), isTrue); // springing line
      expect(p.contains(const Offset(1, 299)), isFalse); // rounded corner
      expect(s.safeInsets(r.size).top, 120);
    });

    test('ribbon: pointed and notched ends', () {
      final pointed = const PanelShape.ribbon(depth: 30).pathFor(r);
      expect(pointed.contains(const Offset(2, 150)), isTrue); // tip
      expect(pointed.contains(const Offset(2, 5)), isFalse);
      expect(pointed.contains(const Offset(100, 2)), isTrue);
      final notched = const PanelShape.ribbon(
        depth: 30,
        notched: true,
      ).pathFor(r);
      expect(notched.contains(const Offset(5, 150)), isFalse); // notch
      expect(notched.contains(const Offset(195, 150)), isFalse);
      expect(notched.contains(const Offset(2, 3)), isTrue); // tails
      expect(notched.contains(const Offset(100, 150)), isTrue);
    });

    test('cartouche: chamfered and concave corners', () {
      final cut = const PanelShape.cartouche(cut: 30).pathFor(r);
      expect(cut.contains(const Offset(5, 5)), isFalse);
      expect(cut.contains(const Offset(28, 28)), isTrue); // past the chamfer
      expect(cut.contains(const Offset(100, 2)), isTrue);
      final concave = const PanelShape.cartouche(
        cut: 30,
        concave: true,
      ).pathFor(r);
      expect(concave.contains(const Offset(5, 5)), isFalse);
      // Inside the quarter-circle bite but past a straight chamfer.
      expect(concave.contains(const Offset(18, 18)), isFalse);
      expect(concave.contains(const Offset(32, 32)), isTrue);
      expect(concave.contains(const Offset(195, 295)), isFalse);
      expect(concave.contains(const Offset(100, 150)), isTrue);
    });

    test('inset shrinks the outline', () {
      const s = PanelShape.rounded(10);
      final p = s.pathFor(r, inset: 8);
      expect(p.contains(const Offset(4, 150)), isFalse);
      expect(p.contains(const Offset(12, 150)), isTrue);
      expect(
        const PanelShape.rect().pathFor(r, inset: 200).getBounds(),
        Rect.zero,
      );
    });

    testWidgets('PosterPanel clips content to its shape', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: SizedBox(
            width: 200,
            height: 300,
            child: PosterPanel(
              style: PanelStyle(
                shape: PanelShape.arch(rise: 100),
                color: Color(0xFF000000),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final clip = tester.widget<ClipPath>(find.byType(ClipPath));
      final path = clip.clipper!.getClip(const Size(200, 300));
      expect(path.contains(const Offset(5, 5)), isFalse);
      expect(path.contains(const Offset(100, 150)), isTrue);
      // Content is pushed below the arch by the shape's safe insets.
      final child = tester.getRect(find.byType(SizedBox).last);
      final panel = tester.getRect(find.byType(PosterPanel));
      expect(child.top - panel.top, closeTo(100, 0.01));
    });

    testWidgets('plain rect panel is a BoxDecoration (no clip layer)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: PosterPanel(
            style: PanelStyle(
              color: Color(0xFFFFFFFF),
              border: BorderSide(width: 2),
            ),
          ),
        ),
      );
      expect(find.byType(ClipPath), findsNothing);
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      expect((box.decoration as BoxDecoration).border, Border.all(width: 2));
    });
  });

  group('layout helpers', () {
    test('SectionLayout slices fixed and flex sections', () {
      final l = SectionLayout.vertical(
        const Rect.fromLTWH(0, 0, 100, 1000),
        const [Section('a', 100), Section.flex('b'), Section('c', 200)],
        gap: 10,
      );
      expect(l['a'], const Rect.fromLTWH(0, 0, 100, 100));
      expect(l['b'], const Rect.fromLTWH(0, 110, 100, 680));
      expect(l['c'], const Rect.fromLTWH(0, 800, 100, 200));
      final h = SectionLayout.horizontal(
        const Rect.fromLTWH(0, 0, 300, 10),
        const [Section('r', 100), Section.flex('l')],
      );
      expect(h['r'], const Rect.fromLTWH(200, 0, 100, 10)); // RTL
      expect(h['l'], const Rect.fromLTWH(0, 0, 200, 10));
      expect(() => l['zzz'], throwsArgumentError);
    });

    test('CellStyle.merge: later non-null fields win', () {
      const a = CellStyle(maxSize: 20, lineHeight: 1.2, wrap: false);
      final m = a.merge(
        const CellStyle(lineHeight: kFontLineHeight, wrap: true),
      );
      expect(m.maxSize, 20);
      expect(m.wrap, isTrue);
      expect(m.textStyle.height, isNull); // font line height
      expect(a.textStyle.height, 1.2);
    });

    test('LayoutMetrics is a LayoutMetricsLike with sections and rows', () {
      final t = allTemplates.first.theme;
      final LayoutMetricsLike m = LayoutMetrics.compute(kPosterSize, t, 30);
      expect(m.section('table'), m.tableRect);
      expect(m.section('nope'), isNull);
      expect(m.rowRect(0).top, m.tableHeaderBottom);
      expect(m.rowRect(29).bottom, closeTo(m.section('footer')!.top, 0.01));
    });

    testWidgets('TitleBlock renders an in-memory image logo', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 100,
              child: TitleBlock.image(
                MemoryImage(_png),
                tint: const Color(0xFFD4AF37),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(_png),
          tester.element(find.byType(TitleBlock)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.color, const Color(0xFFD4AF37));
      expect(img.colorBlendMode, BlendMode.srcIn);
      expect(tester.getSize(find.byType(Image)), const Size(300, 100));
    });

    testWidgets('BraceQuote uses bidi-isolated braces; empty draws nothing', (
      tester,
    ) async {
      expect(const BraceQuote('x').display, '\u2066{\u2069 " x " \u2066}\u2069');
      expect(const BraceQuote('x', quoteMarks: false).display, '\u2066{\u2069 x \u2066}\u2069');
      expect(const BraceQuote('').display, '');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: QuoteBlock(HeaderQuote(text: '', attribution: '')),
        ),
      );
      expect(find.byType(PosterPanel), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('kit demo template', () {
    testWidgets('seed poster renders, geometry matches the real table', (
      tester,
    ) async {
      final seed = seedReferenceMonth();
      await _pump(tester, seed);
      expect(tester.takeException(), isNull);
      expect(find.text('تقويم أهل البيت'), findsOneWidget);
      expect(find.text('4:18'), findsNWidgets(2));
      expect(find.text('ملاحظات'), findsOneWidget);
      expect(expectFitTextsContained(tester), greaterThan(200));

      // Three separate glass panels: dates | times | notes (right → left).
      final table = find.byKey(const ValueKey('kit-table'));
      final panels = find.descendant(
        of: table,
        matching: find.byType(PosterPanel),
      );
      expect(panels, findsNWidgets(3));
      final m = demoMetrics(kPosterSize, seed.days.length);
      expect(m.table.panels, hasLength(3));
      final real = [
        for (final e in panels.evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      // Painter geometry == laid-out panels (same order: right → left).
      for (var i = 0; i < 3; i++) {
        expect(real[i].left, closeTo(m.table.panels[i].left, 0.01));
        expect(real[i].right, closeTo(m.table.panels[i].right, 0.01));
        expect(real[i].top, closeTo(m.table.panels[i].top, 0.01));
        expect(real[i].bottom, closeTo(m.table.panels[i].bottom, 0.01));
      }
      expect(real[0].left, greaterThan(real[1].right)); // dates at the right
      expect(real[1].left, greaterThan(real[2].right));
      expect(tester.getRect(table).top, closeTo(m.tableRect.top, 0.01));

      // Rows share the height equally and sit where the geometry says.
      final day1 = tester.getRect(
        find
            .ancestor(
              of: find.text('4:18').first,
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(day1.top, closeTo(m.rowRect(0).top, 0.01));
      expect(day1.height, closeTo(m.rowHeight, 0.01));

      // Filled hijri column: every hijri cell is gold.
      final hijri1 = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('1').first,
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (hijri1.decoration as BoxDecoration).color,
        const Color(0xFFD4AF37),
      );

      // Month-label cells and highlighted weekdays get a pill badge.
      final badges = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((b) => b.decoration is ShapeDecoration)
          .map((b) => (b.decoration as ShapeDecoration).shape)
          .whereType<StadiumBorder>();
      final labels = seed.days
          .expand((d) => [d.gregorian, d.solar])
          .where((c) => c.isLabel)
          .length;
      final highlighted = seed.days.where((d) => d.highlighted).length;
      expect(badges.length, greaterThanOrEqualTo(labels + highlighted - 2));
      expect(badges, isNotEmpty);
    });

    testWidgets('extreme data: no exceptions, nothing clipped', (tester) async {
      final p = _extreme();
      expect(p.days, hasLength(30));
      await _pump(tester, p);
      expect(tester.takeException(), isNull);
      expectFitTextsContained(tester);
    });

    testWidgets('empty notes / null times / empty texts render', (
      tester,
    ) async {
      await _pump(tester, _emptyNotes());
      expect(tester.takeException(), isNull);
      expectFitTextsContained(tester);
      expect(find.textContaining(':'), findsNothing);
      expect(find.textContaining('{'), findsNothing);
    });

    testWidgets('poster without rows renders', (tester) async {
      await _pump(tester, _noRows());
      expect(tester.takeException(), isNull);
      expect(find.text('ملاحظات'), findsOneWidget);
    });

    for (var month = 0; month < 12; month++) {
      testWidgets('no mid-word breaks in the demo: month $month', (
        tester,
      ) async {
        await _pump(
          tester,
          seedReferenceMonth().copyWith(
            hijriMonthIndex: month,
            hijriYear: 1448,
          ),
        );
        expect(tester.takeException(), isNull);
        final offenders = midWordBreakOffenders(tester);
        expect(offenders, isEmpty, reason: offenders.join('\n'));
      });
    }

    testWidgets('golden kit_demo', (tester) async {
      await _pump(tester, seedReferenceMonth());
      await expectLater(
        find.byType(PosterPreview),
        matchesGoldenFile('goldens/kit_demo.png'),
      );
    });
  });

  group('reference table spec through the kit', () {
    testWidgets('header word-break guard holds for every template spec', (
      tester,
    ) async {
      // The shared layout's table is a PosterTableView with
      // referenceTableSpec(theme); check it on its own at the real width
      // for a long-month header.
      for (final t in allTemplates) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 816,
                height: 1700,
                child: PosterTableView(
                  poster: seedReferenceMonth().copyWith(hijriMonthIndex: 5),
                  spec: referenceTableSpec(t.theme),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(midWordBreakOffenders(tester), isEmpty, reason: t.id);
      }
    });
  });
}
