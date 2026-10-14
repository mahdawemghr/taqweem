// FitText memoisation: cached results must be IDENTICAL to the uncached
// binary search (differential test over 360 generated cases), warm posters
// must lay out exactly like cold ones, and the cache must stay bounded.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/registry.dart';
import 'package:taqweem/templates/shared/fit_text.dart';

import '../test_helpers/load_fonts.dart';

const _words = [
  'وفاة',
  'السيد',
  'مولد',
  'الإمام',
  'الحسين(ع)',
  'زينب',
  'الكبرى',
  'هـ',
  'أمير',
  'المؤمنين',
  'جمادىالآخرة',
  'الفجر',
  'الظهر',
  'المغرب',
  '1448',
  '12:34',
  'تقويم',
  'أهل',
  'البيت',
  'ليلة',
  'القدر',
  '-',
  'ذكرى',
];

const _styles = [
  TextStyle(fontFamily: 'Amiri', color: Color(0xFF000000)),
  TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700),
  TextStyle(fontFamily: 'Tajawal', height: 1.2),
  TextStyle(fontFamily: 'ArefRuqaa', letterSpacing: 0.5),
  TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, height: 1.05),
];

typedef _Case = (
  String,
  TextStyle,
  double,
  double,
  double,
  double,
  int?,
  TextAlign,
);

List<_Case> _cases(int n) {
  final r = math.Random(20261014);
  return [
    for (var i = 0; i < n; i++)
      (
        [
          for (var w = 0; w < 1 + r.nextInt(i.isEven ? 4 : 30); w++)
            _words[r.nextInt(_words.length)],
        ].join(' '),
        _styles[r.nextInt(_styles.length)],
        20.0 + r.nextInt(400) + (r.nextBool() ? 0.37 : 0), // width
        10.0 + r.nextInt(160) + (r.nextBool() ? 0.5 : 0), // height
        8.0 + r.nextInt(60) * 0.5, // maxSize
        5.0 + r.nextInt(6), // minSize (some below the floor)
        const [null, 1, 2, 3][r.nextInt(4)],
        const [TextAlign.center, TextAlign.right, TextAlign.start][r.nextInt(
          3,
        )],
      ),
  ];
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    FitText.debugCacheEnabled = true;
    FitText.debugClearCache();
  });
  tearDown(() => FitText.debugCacheEnabled = true);

  testWidgets('cached results equal the uncached search (360 cases)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.rtl, child: SizedBox()),
    );
    final cases = _cases(360);
    expect(cases.length, greaterThanOrEqualTo(300));
    var shrunk = 0, overflowing = 0;
    for (final (text, style, w, h, max, min, lines, align) in cases) {
      final fit = FitText(
        text,
        style: style,
        maxSize: max,
        minSize: min,
        maxLines: lines,
        align: align,
      );
      final reason = '"$text" ${w}x$h max=$max min=$min lines=$lines $align';
      final want = fit.fitFontSizeUncached(style, w, h);
      final miss = fit.fitFontSize(style, w, h);
      final layouts = FitText.debugLayoutCount;
      final hits = FitText.debugCacheHits;
      final hit = fit.fitFontSize(style, w, h);
      expect(miss, want, reason: reason);
      expect(hit, want, reason: reason);
      // The second call is a pure cache hit: no text layout at all.
      expect(FitText.debugLayoutCount, layouts, reason: reason);
      expect(FitText.debugCacheHits, hits + 1, reason: reason);
      if (want.$1 < max) shrunk++;
      if (!want.$3) overflowing++;
    }
    // The generated cases exercise every branch of the search.
    expect(shrunk, greaterThan(50));
    expect(cases.length - shrunk, greaterThan(50));
    expect(overflowing, greaterThan(0));
  });

  testWidgets('a key differing in any single input is a separate entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.rtl, child: SizedBox()),
    );
    const text = 'مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة';
    const s = TextStyle(fontFamily: 'Amiri');
    final base = const FitText(text, style: s, maxSize: 22);
    final variants = <(FitText, TextStyle, double, double)>[
      (base, s, 170, 44),
      (base, s, 171, 44),
      (base, s, 170, 45),
      (base, s.copyWith(fontWeight: FontWeight.w700), 170, 44),
      (const FitText('$text.', style: s, maxSize: 22), s, 170, 44),
      (const FitText(text, style: s, maxSize: 21.5), s, 170, 44),
      (const FitText(text, style: s, maxSize: 22, minSize: 6), s, 170, 44),
      (const FitText(text, style: s, maxSize: 22, maxLines: 1), s, 170, 44),
      (
        const FitText(text, style: s, maxSize: 22, align: TextAlign.right),
        s,
        170,
        44,
      ),
    ];
    for (final (f, st, w, h) in variants) {
      expect(f.fitFontSize(st, w, h), f.fitFontSizeUncached(st, w, h));
    }
    expect(FitText.debugCacheLength, variants.length);
  });

  testWidgets('the cache is a bounded LRU', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.rtl, child: SizedBox()),
    );
    const s = TextStyle(fontFamily: 'Tajawal');
    const first = FitText('الأول', style: s, maxSize: 10);
    first.fitFontSize(s, 100, 20);
    for (var i = 0; i < kFitTextCacheSize + 50; i++) {
      // Touch the first entry now and then: it stays (most recently used).
      if (i % 1000 == 0) first.fitFontSize(s, 100, 20);
      FitText('$i', style: s, maxSize: 10).fitFontSize(s, 100, 20);
    }
    expect(FitText.debugCacheLength, kFitTextCacheSize);
    final hits = FitText.debugCacheHits;
    first.fitFontSize(s, 100, 20);
    expect(FitText.debugCacheHits, hits + 1);
    // The oldest untouched entry was evicted.
    final layouts = FitText.debugLayoutCount;
    const FitText('0', style: s, maxSize: 10).fitFontSize(s, 100, 20);
    expect(FitText.debugLayoutCount, greaterThan(layouts));
  });

  testWidgets('a font change drops the cache', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.rtl, child: SizedBox()),
    );
    const s = TextStyle(fontFamily: 'Amiri');
    const FitText('الفجر', style: s).fitFontSize(s, 100, 30);
    expect(FitText.debugCacheLength, 1);
    // What the engine sends after a font is loaded.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.system.name,
      SystemChannels.system.codec.encodeMessage({'type': 'fontsChange'}),
      (_) {},
    );
    expect(FitText.debugCacheLength, 0);
  });

  for (final t in allTemplates) {
    testWidgets('${t.id}: warm (cached) poster lays out like a cold one', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final poster = seedReferenceMonth().copyWith(templateId: t.id);
      Future<List<(String, double?, int?, Rect)>> snapshot(Key key) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PosterPreview(key: key, poster: poster, width: 1000),
            ),
          ),
        );
        return [
          for (final e
              in find
                  .descendant(
                    of: find.byType(FitText),
                    matching: find.byType(Text),
                  )
                  .evaluate())
            (
              (e.widget as Text).data!,
              (e.widget as Text).style?.fontSize,
              (e.widget as Text).maxLines,
              tester.getRect(find.byWidget(e.widget)),
            ),
        ];
      }

      FitText.debugCacheEnabled = false;
      final cold = await snapshot(const ValueKey('cold'));
      FitText.debugCacheEnabled = true;
      final miss = await snapshot(const ValueKey('miss'));
      final layouts = FitText.debugLayoutCount;
      final warm = await snapshot(const ValueKey('warm'));
      expect(cold, isNotEmpty);
      expect(miss, cold);
      expect(warm, cold);
      // A warm rebuild of the same poster performs no text layout.
      expect(FitText.debugLayoutCount, layouts);
      expect(tester.takeException(), isNull);
    });
  }
}
