// Performance benchmark (tag `perf`, skipped by default; see dart_test.yaml).
// Run:  flutter test --run-skipped -t perf test/perf/perf_benchmark_test.dart
// Numbers are printed as `PERF ...` lines; docs/design/performance.md
// records them. "before" rows emulate the previous behaviour (FitText cache
// off / a live PosterPreview where a raster thumbnail is used now).
@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/editor/step_grid.dart';
import 'package:taqweem/features/home/draft_card.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/features/preview/poster_thumbnail.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';
import 'package:taqweem/templates/registry.dart';
import 'package:taqweem/templates/shared/fit_text.dart';

import '../test_helpers/load_fonts.dart';

// ignore: avoid_print
void _report(String line) => print('PERF $line');

double _median(List<int> xs) {
  final s = [...xs]..sort();
  return s.length.isOdd
      ? s[s.length ~/ 2].toDouble()
      : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

Widget _app(Widget home) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => FitText.debugCacheEnabled = true);

  testWidgets('FitText layouts and build time per poster (cold vs warm)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var key = 0;
    Future<(int, int)> build(MonthPoster p) async {
      final layouts = FitText.debugLayoutCount;
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: PosterPreview(key: ValueKey(key++), poster: p, width: 1000),
          ),
        ),
      );
      sw.stop();
      return (FitText.debugLayoutCount - layouts, sw.elapsedMicroseconds);
    }

    var beforeLayouts = 0, afterLayouts = 0;
    final beforeUs = <int>[], afterUs = <int>[];
    for (final t in allTemplates) {
      final p = seedReferenceMonth().copyWith(templateId: t.id);
      await build(p); // warm-up (fonts, shaders, images)
      FitText.debugCacheEnabled = false;
      for (var i = 0; i < 3; i++) {
        final (l, us) = await build(p);
        beforeLayouts += l;
        beforeUs.add(us);
      }
      FitText.debugCacheEnabled = true;
      FitText.debugClearCache();
      await build(p); // fills the cache (a cold build)
      for (var i = 0; i < 3; i++) {
        final (l, us) = await build(p);
        afterLayouts += l;
        afterUs.add(us);
      }
      final fits = find.byType(FitText).evaluate().length;
      _report('${t.id}: FitText widgets=$fits');
    }
    final n = allTemplates.length * 3;
    final b = beforeLayouts / n, a = afterLayouts / n;
    _report(
      'FitText text layouts per warm poster rebuild: before=${b.round()} '
      'after=${a.round()} (-${((1 - a / b) * 100).toStringAsFixed(1)}%)',
    );
    _report(
      'warm poster build+layout+paint (median ms): '
      'before=${(_median(beforeUs) / 1000).toStringAsFixed(1)} '
      'after=${(_median(afterUs) / 1000).toStringAsFixed(1)}',
    );
    expect(a, lessThanOrEqualTo(b * 0.2)); // >= 80% fewer layouts
  });

  testWidgets('one cell edit: FitText layouts in a live poster', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = seedReferenceMonth();
    Future<int> edit(String note) async {
      await tester.pumpWidget(
        _app(Scaffold(body: PosterPreview(poster: p, width: 1000))),
      );
      final days = [...p.days];
      days[3] = days[3].copyWith(note: note);
      final layouts = FitText.debugLayoutCount;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: PosterPreview(poster: p.copyWith(days: days), width: 1000),
          ),
        ),
      );
      return FitText.debugLayoutCount - layouts;
    }

    FitText.debugCacheEnabled = false;
    final before = await edit('ملاحظة أ');
    FitText.debugCacheEnabled = true;
    await edit('ملاحظة ب');
    final after = await edit('ملاحظة ب'); // the edited cell seen once already
    final afterNew = await edit('ملاحظة ج');
    _report(
      'live poster, one note edited: layouts before=$before '
      'after=$afterNew (new text) / $after (text seen before)',
    );
    expect(afterNew, lessThan(before * 0.2));
  });

  testWidgets('Home grid with 12 drafts: live posters and first frame', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    final ids = [for (var i = 0; i < 12; i++) 'd$i'];
    final drafts = [
      for (final (i, id) in ids.indexed)
        seedReferenceMonth().copyWith(
          id: id,
          templateId: allTemplates[i % allTemplates.length].id,
        ),
    ];
    Widget grid(Widget Function(MonthPoster) cell) => _app(
      Scaffold(
        body: GridView.count(
          crossAxisCount: 6,
          childAspectRatio: 0.38,
          children: [for (final d in drafts) cell(d)],
        ),
      ),
    );
    // Warm fonts/images once.
    await tester.pumpWidget(grid((d) => PosterPreview(poster: d)));
    await tester.pumpWidget(const SizedBox());
    FitText.debugCacheEnabled = false;
    var sw = Stopwatch()..start();
    await tester.pumpWidget(grid((d) => PosterPreview(poster: d)));
    sw.stop();
    final liveBefore = find.byType(PosterPreview).evaluate().length;
    final beforeMs = sw.elapsedMilliseconds;
    await tester.pumpWidget(const SizedBox());
    FitText.debugCacheEnabled = true;

    // After: the real DraftCard (raster thumbnail) with a real cache.
    final cache = ThumbnailCache();
    ThumbnailCache.instance = cache;
    addTearDown(() => ThumbnailCache.instance = ThumbnailCache());
    sw = Stopwatch()..start();
    await tester.pumpWidget(
      grid((d) => DraftCard(key: ValueKey(d.id), poster: d, onAction: (_) {})),
    );
    sw.stop();
    final liveAfter = find.byType(PosterPreview).evaluate().length;
    // Let the idle queue render every raster (real engine readback).
    var maxPending = 0;
    for (var i = 0; i < 400 && cache.debugLength < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      if (cache.debugPending > maxPending) maxPending = cache.debugPending;
    }
    await tester.pump();
    _report(
      'Home 12 drafts first frame: before=${beforeMs}ms '
      '($liveBefore live posters in the tree) after=${sw.elapsedMilliseconds}ms '
      '($liveAfter live posters; placeholders)',
    );
    _report(
      'Home thumbnails: rendered=${cache.debugRenderCount} '
      'max concurrent off-screen posters=${cache.debugMaxConcurrentRenders} '
      'rasters cached=${cache.debugLength}',
    );
    expect(liveAfter, 0);
    expect(cache.debugMaxConcurrentRenders, lessThanOrEqualTo(1));
    expect(find.byType(RawImage), findsNWidgets(cache.debugLength));
    // Rebuild (e.g. back from the editor): nothing is rendered again.
    final renders = cache.debugRenderCount;
    await tester.pumpWidget(const SizedBox());
    sw = Stopwatch()..start();
    await tester.pumpWidget(
      grid((d) => DraftCard(key: ValueKey(d.id), poster: d, onAction: (_) {})),
    );
    sw.stop();
    await tester.pump(const Duration(milliseconds: 10));
    _report('Home 12 drafts, warm cache: ${sw.elapsedMilliseconds}ms');
    expect(cache.debugRenderCount, renders);
    expect(find.byType(RawImage), findsNWidgets(cache.debugLength));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('editor commit: no full poster, exactly one grid row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [posterSaverProvider.overrideWithValue((p) async {})],
        child: _app(EditorShell(initial: seedReferenceMonth())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(EditorShell)),
    );
    final us = <int>[];
    var layouts = 0;
    final rowsRebuilt = <int>[];
    for (var k = 0; k < 5; k++) {
      debugGridRowBuilds.clear();
      final l0 = FitText.debugLayoutCount;
      final sw = Stopwatch()..start();
      c.read(editorProvider.notifier).update((p) {
        final days = [...p.days];
        days[2] = days[2].copyWith(note: 'ملاحظة $k');
        return p.copyWith(days: days);
      });
      await tester.pump();
      sw.stop();
      us.add(sw.elapsedMicroseconds);
      layouts += FitText.debugLayoutCount - l0;
      rowsRebuilt.add(debugGridRowBuilds.length);
      expect(find.byType(PosterPreview), findsNothing);
    }
    await tester.pump(kThumbnailDebounce);
    await tester.pumpAndSettle();
    _report(
      'editor commit (grid step): frame median='
      '${(_median(us) / 1000).toStringAsFixed(1)}ms, FitText layouts=$layouts, '
      'rows rebuilt per commit=$rowsRebuilt',
    );
    expect(layouts, 0);
    expect(rowsRebuilt.every((n) => n == 1), isTrue);
  });

  testWidgets('before: a live mini preview per commit', (tester) async {
    // Emulates the previous AppBar mini preview (a live 19 px poster).
    final p = seedReferenceMonth();
    final us = <int>[];
    var layouts = 0;
    FitText.debugCacheEnabled = false;
    for (var k = 0; k < 5; k++) {
      final days = [...p.days];
      days[2] = days[2].copyWith(note: 'ملاحظة $k');
      final l0 = FitText.debugLayoutCount;
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _app(
          Center(
            child: PosterPreview(poster: p.copyWith(days: days), width: 19),
          ),
        ),
      );
      sw.stop();
      if (k > 0) us.add(sw.elapsedMicroseconds);
      layouts += FitText.debugLayoutCount - l0;
    }
    _report(
      'before: editor commit with a live mini preview: frame median='
      '${(_median(us) / 1000).toStringAsFixed(1)}ms, FitText layouts per '
      'commit=${layouts ~/ 5}',
    );
  });
}
