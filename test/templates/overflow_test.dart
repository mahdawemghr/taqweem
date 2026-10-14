import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/registry.dart';
import 'package:taqweem/templates/shared/fit_text.dart';

import '../test_helpers/fit_assertions.dart';
import '../test_helpers/load_fonts.dart';

/// [n] characters of Arabic text with word breaks.
String _arabic(int n) {
  const word = 'السلام عليكم ورحمة الله وبركاته ';
  final b = StringBuffer();
  while (b.length < n) {
    b.write(word);
  }
  return b.toString().substring(0, n);
}

MonthPoster _extreme() {
  final seed = seedReferenceMonth();
  final note = _arabic(400);
  final long = _arabic(240);
  return seed.copyWith(
    // Long calendar column headers.
    gregorianHeader: _arabic(90),
    solarHeader: _arabic(90),
    days: [
      for (final d in seed.days)
        d.copyWith(
          note: note,
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

MonthPoster _empty() => MonthPoster(
      id: 'empty',
      updatedAt: DateTime.utc(2026, 1, 1),
      hijriMonthIndex: 0,
      hijriYear: 1448,
    );

Future<void> _pump(WidgetTester tester, MonthPoster p) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PosterPreview(poster: p, width: 1000))));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  test('extreme poster has 30 rows of 400-char notes', () {
    final p = _extreme();
    expect(p.days, hasLength(30));
    expect(p.days.every((d) => d.note.length == 400), isTrue);
  });

  for (final t in allTemplates) {
    testWidgets('${t.id}: extreme data renders without exceptions',
        (tester) async {
      await _pump(tester, _extreme().copyWith(templateId: t.id));
      expect(tester.takeException(), isNull);
      expect(find.byType(FitText), findsWidgets);
      expect(expectFitTextsContained(tester), greaterThan(0));
    });

    testWidgets('${t.id}: empty poster (no rows, null times) renders',
        (tester) async {
      await _pump(tester, _empty().copyWith(templateId: t.id));
      expect(tester.takeException(), isNull);
      expect(find.byType(FitText), findsWidgets);
    });

    testWidgets('${t.id}: out-of-range month and long title render',
        (tester) async {
      final p = seedReferenceMonth().copyWith(
        templateId: t.id,
        hijriMonthIndex: 99,
        texts: seedReferenceMonth().texts.copyWith(title: _arabic(300)),
      );
      await _pump(tester, p);
      expect(tester.takeException(), isNull);
      expect(find.byType(FitText), findsWidgets);
    });
  }
}
