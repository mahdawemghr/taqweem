import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';
import 'package:taqweem/templates/shared/fit_text.dart';

import '../test_helpers/load_fonts.dart';

/// Captures the metrics handed to the frame painter.
LayoutMetrics? lastMetrics;

class _NoopPainter extends CustomPainter {
  const _NoopPainter();
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Minimal white/black theme used only by tests.
final testTheme = PosterTheme(
  background: const Color(0xFFFFFFFF),
  frameColor: const Color(0xFF000000),
  accent: const Color(0xFF000000),
  titleColor: const Color(0xFF000000),
  bodyText: const Color(0xFF000000),
  tableHeaderBg: const Color(0xFFFFFFFF),
  tableHeaderFg: const Color(0xFF000000),
  rowBg: const Color(0xFFFFFFFF),
  rowAltBg: const Color(0xFFF2F2F2),
  rowText: const Color(0xFF000000),
  gridLine: const Color(0xFF000000),
  highlightBg: const Color(0xFF000000),
  highlightFg: const Color(0xFFFFFFFF),
  labelCellBg: const Color(0xFF000000),
  labelCellFg: const Color(0xFFFFFFFF),
  quoteBoxBg: const Color(0xFFFFFFFF),
  quoteBoxBorder: const Color(0xFF000000),
  quoteText: const Color(0xFF000000),
  headingFont: 'ArefRuqaa',
  bodyFont: 'Amiri',
  backgroundPainter: () => const _NoopPainter(),
  framePainter: (m) {
    lastMetrics = m;
    return const _NoopPainter();
  },
);

class TestTemplate extends PosterTemplate {
  const TestTemplate();
  @override
  String get id => 'test';
  @override
  String get nameAr => 'اختبار';
  @override
  PosterTheme get theme => testTheme;
}

String _chars(int n) {
  final buf = StringBuffer();
  while (buf.length < n) {
    buf.write('ذكرى استشهاد الإمام موسى الكاظم(ع) 183هـ - ');
  }
  return buf.toString().substring(0, n);
}

Future<void> _pump(WidgetTester tester, MonthPoster p) async {
  tester.view.physicalSize = kPosterSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Center(
      child: SizedBox.fromSize(
        size: kPosterSize,
        child: PosterPreview(poster: p, template: const TestTemplate()),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('renders the seed poster', (tester) async {
    await _pump(tester, seedReferenceMonth());
    expect(tester.takeException(), isNull);
    expect(find.text('تقويم أهل البيت'), findsOneWidget);
    // Fajr is 4:18 on both day 1 and day 2 of the reference month.
    expect(find.text('4:18'), findsNWidgets(2));
    expect(find.text('ملاحظات'), findsOneWidget);
    expect(find.text('جمادى الأول\n1448'), findsOneWidget);
    expect(find.text('أكتوبر\nنوفمبر\n2026'), findsOneWidget);
    expect(find.text('آبان'), findsOneWidget); // solar label cell
    // Uncertain flags are an editor concern: no marker on the poster.
    expect(find.textContaining('?'), findsNothing);
  });

  testWidgets('frame painter receives real section metrics', (tester) async {
    lastMetrics = null;
    await _pump(tester, seedReferenceMonth());
    final m = lastMetrics!;
    expect(m.size, kPosterSize);
    expect(m.contentRect, const Rect.fromLTRB(40, 48, 960, 2152));
    expect(m.headerBottom, 48 + 250);
    expect(m.tableTop, m.headerBottom + 90);
    expect(m.tableHeaderBottom, m.tableTop + 84);
    expect(m.tableRect.width, 816);
    expect(m.rightStripRect.width, 52);
    expect(m.leftStripRect.width, 52);
    expect(m.tableBottom, greaterThan(m.tableHeaderBottom));
    expect(m.articleTop, greaterThan(m.tableBottom));
    expect(m.rowCount, 30);
    // Table rect really is where the table header was laid out.
    final header = tester.getRect(find.text('ملاحظات'));
    expect(m.tableRect.contains(header.center), isTrue);
    expect(header.top, greaterThanOrEqualTo(m.tableTop));
    expect(header.bottom, lessThanOrEqualTo(m.tableHeaderBottom));
    // Metrics match what was really laid out.
    bool near(double a, double b) => (a - b).abs() <= 1;
    final table = tester.getRect(find.byKey(const ValueKey('poster-table')));
    expect(near(table.left, m.tableRect.left), isTrue);
    expect(near(table.right, m.tableRect.right), isTrue);
    expect(near(table.top, m.tableTop), isTrue);
    expect(near(table.bottom, m.tableBottom), isTrue);
    final footer = tester.getRect(find.byKey(const ValueKey('poster-footer')));
    expect(near(footer.top, m.tableBottom), isTrue);
    expect(near(footer.bottom, m.articleTop), isTrue);
    final article =
        tester.getRect(find.byKey(const ValueKey('poster-article')));
    expect(near(article.top, m.articleTop), isTrue);
    expect(near(article.bottom, m.articleBottom), isTrue);
    final heading = tester.getRect(find.byWidgetPredicate(
        (w) => w is FitText && w.text.startsWith(':: ')));
    expect(near(heading.top, m.articleTop + 2), isTrue); // 2 px padding
  });

  testWidgets('column proportions follow the reference (R11)',
      (tester) async {
    await _pump(tester, seedReferenceMonth());
    final notesCell = tester.getRect(find
        .ancestor(
            of: find.text('ملاحظات'), matching: find.byType(DecoratedBox))
        .first);
    expect(notesCell.width, inInclusiveRange(395, 410));
    // ≈ 49 % of the 816 px table.
    expect(notesCell.width / 816, closeTo(0.49, 0.01));
    final weekday = tester.getRect(find
        .ancestor(of: find.text('اليوم'), matching: find.byType(DecoratedBox))
        .first);
    expect(weekday.width, 60);
    expect(weekday.height, 84);
  });

  testWidgets('all day rows share the height equally', (tester) async {
    await _pump(tester, seedReferenceMonth());
    Rect cellOf(Finder text) => tester.getRect(
        find.ancestor(of: text, matching: find.byType(DecoratedBox)).first);
    final first = cellOf(find.text('1').first); // hijri day 1
    final last = cellOf(find.text('5:05')); // maghrib on day 30
    expect(first.height, greaterThan(40));
    expect(last.height, closeTo(first.height, 0.01));
    expect(find.text('الثلاثاء'), findsWidgets);
    final weekdays = find.text('الثلاثاء').evaluate().toList();
    final h0 = tester.getRect(find.byWidget(weekdays.first.widget)).height;
    final h1 = tester.getRect(find.byWidget(weekdays.last.widget)).height;
    expect(h1, closeTo(h0, 0.01));
  });

  testWidgets('braces print like the reference: { at right, } at left',
      (tester) async {
    await _pump(tester, seedReferenceMonth());
    final brace = find.byWidgetPredicate(
        (w) => w is FitText && w.text.contains('إذا عرضتم'));
    final text = (tester.widget(brace) as FitText).text;
    // Each brace in an LTR isolate so the RTL paragraph does not mirror it
    // (verified visually: `{` prints at the right end, `}` at the left).
    expect(text, startsWith('\u2066{\u2069 " '));
    expect(text, endsWith(' " \u2066}\u2069'));
    final body = find.byWidgetPredicate(
        (w) => w is FitText && w.text.contains('فالحسين'));
    final bodyText = (tester.widget(body) as FitText).text;
    expect(bodyText, startsWith('\u2066{\u2069 '));
    expect(bodyText, endsWith(' \u2066}\u2069'));
  });

  testWidgets('30 rows with 400-char notes never overflow', (tester) async {
    final seed = seedReferenceMonth();
    final rows = [
      for (var i = 0; i < 30; i++)
        seed.days[i % seed.days.length].copyWith(note: _chars(400)),
    ];
    final long = _chars(400);
    final p = seed.copyWith(
      days: rows,
      texts: seed.texts.copyWith(
        rightQuote: HeaderQuote(text: long, attribution: long),
        leftQuote: HeaderQuote(text: long, attribution: long),
        braceQuote: long,
        footerNotes: long,
        article: ClosingArticle(author: long, body: _chars(2000)),
        sideLeft: SideQa(question: long, answer: long),
        sideRight: SideQa(question: long, answer: long),
        title: long,
      ),
    );
    await _pump(tester, p);
    expect(tester.takeException(), isNull);
    // Every FitText's paragraph lies entirely inside the FitText's box and
    // never truncates lines (no clipping, no ellipsis).
    final fits = find.byType(FitText);
    expect(fits, findsWidgets);
    for (final e in fits.evaluate()) {
      final box = tester.getRect(find.byWidget(e.widget));
      final rich = find.descendant(
          of: find.byWidget(e.widget), matching: find.byType(RichText));
      if (rich.evaluate().isEmpty) continue; // empty string
      final para = tester.renderObject<RenderParagraph>(rich);
      expect(para.didExceedMaxLines, isFalse);
      expect(para.textSize.height, lessThanOrEqualTo(para.size.height + 0.01));
      final r = tester.getRect(rich);
      expect(r.top, greaterThanOrEqualTo(box.top - 0.01));
      expect(r.bottom, lessThanOrEqualTo(box.bottom + 0.01));
      expect(r.left, greaterThanOrEqualTo(box.left - 0.01));
      expect(r.right, lessThanOrEqualTo(box.right + 0.01));
    }
  });

  testWidgets('empty notes and null times render empty cells',
      (tester) async {
    final seed = seedReferenceMonth();
    final p = seed.copyWith(
      days: [
        for (final d in seed.days)
          d.copyWith(note: '', times: const PrayerTimes()),
      ],
      // Every free text empty except the title/fatiha defaults.
      texts: const PosterTexts.empty().copyWith(footerNotes: ''),
    );
    await _pump(tester, p);
    expect(tester.takeException(), isNull);
    expect(find.textContaining(':'), findsNothing);
    expect(find.textContaining('{'), findsNothing); // no braces for empty text
    expect(find.textContaining('}'), findsNothing);
    expect(find.text('-'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  test('registry never throws for unknown ids', () {
    expect(() => templateById('does-not-exist'), returnsNormally);
    expect(templateById('does-not-exist').theme, isNotNull);
  });
}
