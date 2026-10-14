// Fix round A checks shared by the five kit templates (navy_calligraphy,
// emerald_mihrab, emerald_garden, ivory_medallion, midnight_dome): logo
// rasterisation quality and text fallback, painters that repaint only when
// their inputs change, bounded path caches, and the mihrab strip labels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/emerald_garden.dart';
import 'package:taqweem/templates/emerald_mihrab.dart';
import 'package:taqweem/templates/ivory_medallion.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/midnight_dome.dart';
import 'package:taqweem/templates/navy_calligraphy.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';

const _ids = [
  'navy_calligraphy',
  'emerald_mihrab',
  'emerald_garden',
  'ivory_medallion',
  'midnight_dome',
];

Future<void> _pump(WidgetTester tester, String id, {bool load = true}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosterPreview(
          poster: seedReferenceMonth().copyWith(templateId: id),
          width: 1000,
        ),
      ),
    ),
  );
  if (load) await precacheTemplate(tester, templateById(id));
  await tester.pumpAndSettle();
}

/// Same inputs → no repaint; each changed input → repaint.
void _expectRepaint<T extends CustomPainter>(
  T Function(KitMetrics m) make,
  KitMetrics Function(Size size, int rows) metrics,
) {
  final a = make(metrics(kPosterSize, 30));
  expect(a.shouldRepaint(make(metrics(kPosterSize, 30))), isFalse);
  expect(a.shouldRepaint(make(metrics(kPosterSize, 29))), isTrue);
  expect(a.shouldRepaint(make(metrics(const Size(900, 2000), 30))), isTrue);
}

void main() {
  setUpAll(loadAppFonts);

  group('logos: high-quality sampling and a text fallback', () {
    for (final id in _ids) {
      testWidgets('$id draws every image with FilterQuality.high + AA', (
        tester,
      ) async {
        await _pump(tester, id);
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, isNotEmpty);
        for (final img in images) {
          expect(img.filterQuality, FilterQuality.high, reason: '${img.key}');
          expect(img.isAntiAlias, isTrue, reason: '${img.key}');
        }
        // The title logo falls back to the poster title as text.
        final titles = tester
            .widgetList<TitleBlock>(find.byType(TitleBlock))
            .where((t) => t.image != null && '${t.key}'.contains('title'))
            .toList();
        expect(titles, hasLength(1));
        expect(titles.single.fallbackText, defaultTitle);
      });
    }

    testWidgets('a missing asset shows the fallback title text', (
      tester,
    ) async {
      const missing = AssetImage('assets/logos/does_not_exist.png');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 120,
              child: TitleBlock.image(
                missing,
                fallbackText: defaultTitle,
                style: TextStyle(fontFamily: 'ArefRuqaa'),
                maxSize: 60,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          missing,
          tester.element(find.byType(TitleBlock)),
          onError: (_, _) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('title-fallback')), findsOneWidget);
      expect(find.text(defaultTitle), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.filterQuality, FilterQuality.high);
      expect(img.isAntiAlias, isTrue);
    });

    testWidgets('a missing asset without fallbackText draws nothing', (
      tester,
    ) async {
      const missing = AssetImage('assets/logos/does_not_exist_2.png');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 300,
            height: 120,
            child: TitleBlock.image(missing),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          missing,
          tester.element(find.byType(TitleBlock)),
          onError: (_, _) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('title-fallback')), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('painters repaint only when their inputs change', () {
    test('navy_calligraphy background', () {
      _expectRepaint(
        (m) => NavyCalligraphyBackgroundPainter(m, hasBrace: true),
        navyCalligraphyMetrics,
      );
      final m = navyCalligraphyMetrics(kPosterSize, 30);
      expect(
        NavyCalligraphyBackgroundPainter(
          m,
          hasBrace: true,
        ).shouldRepaint(NavyCalligraphyBackgroundPainter(m, hasBrace: false)),
        isTrue,
      );
    });

    test('navy_calligraphy knots', () {
      _expectRepaint(
        (m) => NavyCalligraphyKnotPainter(m, hasBrace: true),
        navyCalligraphyMetrics,
      );
      final m = navyCalligraphyMetrics(kPosterSize, 30);
      expect(
        NavyCalligraphyKnotPainter(
          m,
          hasBrace: true,
        ).shouldRepaint(NavyCalligraphyKnotPainter(m, hasBrace: false)),
        isTrue,
      );
    });

    test('emerald_mihrab background', () {
      _expectRepaint(EmeraldMihrabBackgroundPainter.new, emeraldMihrabMetrics);
    });

    test('emerald_garden background', () {
      _expectRepaint(EmeraldGardenBackgroundPainter.new, emeraldGardenMetrics);
    });

    test('ivory_medallion background', () {
      _expectRepaint(
        IvoryMedallionBackgroundPainter.new,
        ivoryMedallionMetrics,
      );
    });

    test('midnight_dome background', () {
      _expectRepaint(MidnightDomeBackgroundPainter.new, midnightDomeMetrics);
    });

    test('KitMetrics.sameLayout compares values, not identity', () {
      final a = emeraldGardenMetrics(kPosterSize, 30);
      expect(a.sameLayout(emeraldGardenMetrics(kPosterSize, 30)), isTrue);
      expect(a.sameLayout(emeraldGardenMetrics(kPosterSize, 31)), isFalse);
      expect(a.sameLayout(emeraldMihrabMetrics(kPosterSize, 30)), isFalse);
    });
  });

  group('static path caches hold at most 4 entries', () {
    test('BoundedCache evicts the oldest entry', () {
      final c = BoundedCache<int, String>();
      var builds = 0;
      String b(int i) {
        builds++;
        return 'v$i';
      }

      for (var i = 0; i < 6; i++) {
        expect(c.get(i, () => b(i)), 'v$i');
      }
      expect(c.length, 4);
      expect(c.containsKey(0), isFalse);
      expect(c.containsKey(1), isFalse);
      expect(c.containsKey(5), isTrue);
      expect(c.get(5, () => b(99)), 'v5'); // hit: not rebuilt
      expect(builds, 6);
    });

    test('lattice / brace / border / lace caches stay bounded', () {
      for (var i = 0; i < 7; i++) {
        final size = Size(800 + i * 20.0, 2000);
        emLatticePath(size);
        ivLatticePath(size);
        mdLatticePath(size);
        ivBracePath(Size(40, 100 + i * 10.0), opensRight: i.isEven);
        gdBorderPaths(size);
        gdArabesquePaths(size);
        gdArchLacePath(Rect.fromLTWH(0, 0, 600 + i * 10.0, 1200));
      }
      for (final (name, n) in [
        ('em lattice', emLatticeCache.length),
        ('iv lattice', ivLatticeCache.length),
        ('md lattice', mdLatticeCache.length),
        ('iv brace', ivBraceCache.length),
        ('gd border', gdBorderCache.length),
        ('gd arabesque', gdArabesqueCache.length),
        ('gd lace', gdLaceCache.length),
      ]) {
        expect(n, inInclusiveRange(1, 4), reason: name);
      }
      // A cached size is still served without rebuilding.
      final s = const Size(920, 2000);
      expect(identical(emLatticePath(s), emLatticePath(s)), isTrue);
    });
  });

  testWidgets('emerald_mihrab side-strip labels are >= 18 px', (tester) async {
    await _pump(tester, 'emerald_mihrab');
    final m = emeraldMihrabMetrics(
      kPosterSize,
      seedReferenceMonth().days.length,
    );
    for (final id in ['stripRight', 'stripLeft']) {
      expect(m.sections[id]!.width, greaterThanOrEqualTo(54), reason: id);
    }
    var seen = 0;
    for (final label in ['سؤال :', 'الجواب :']) {
      for (final t in tester.widgetList<Text>(find.text(label))) {
        expect(t.style!.fontSize, greaterThanOrEqualTo(18), reason: label);
        seen++;
      }
    }
    expect(seen, 4);
  });

  test('every new template keeps PosterTemplate images precacheable', () {
    for (final id in _ids) {
      final PosterTemplate t = templateById(id);
      expect(t.images, isNotEmpty, reason: id);
    }
  });
}
