// PosterThumbnail / ThumbnailCache: cached low-resolution rasters instead of
// live posters (Home cards, editor mini preview).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/features/preview/poster_thumbnail.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';

const _placeholder = ValueKey('thumbnail-placeholder');

/// A rasterizer that records its calls and returns a tiny image at once.
class _FakeRaster {
  final calls = <(String, int)>[];
  Future<ui.Image> call(BuildContext context, MonthPoster p, int widthPx) {
    calls.add((p.id, widthPx));
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(
      const Rect.fromLTWH(0, 0, 4, 8),
      Paint()..color = const Color(0xFF123456),
    );
    final pic = rec.endRecording();
    final img = pic.toImageSync(4, 8);
    pic.dispose();
    return Future.value(img);
  }
}

ThumbnailCache _cache(_FakeRaster r, {int capacity = kThumbnailCacheSize}) =>
    ThumbnailCache(
      capacity: capacity,
      rasterizer: r.call,
      scheduler: <T>(T Function() task) async => task(),
    );

MonthPoster _p(String id, {int year = 1448}) =>
    seedReferenceMonth().copyWith(id: id, hijriYear: year);

Widget _host(Widget child) => MaterialApp(home: Center(child: child));

void main() {
  setUpAll(loadAppFonts);

  test('the content stamp ignores updatedAt only', () {
    final p = seedReferenceMonth();
    expect(
      posterContentStamp(p),
      posterContentStamp(p.copyWith(updatedAt: DateTime(2001))),
    );
    expect(
      posterContentStamp(p),
      isNot(posterContentStamp(p.copyWith(templateId: 'mosque_blue'))),
    );
    expect(
      posterContentStamp(p),
      isNot(posterContentStamp(p.copyWith(hijriYear: 1))),
    );
  });

  testWidgets('placeholder first, then the raster; never a live poster', (
    tester,
  ) async {
    final r = _FakeRaster();
    final cache = _cache(r);
    addTearDown(cache.dispose);
    await tester.pumpWidget(
      _host(PosterThumbnail(poster: _p('a'), width: 150, cache: cache)),
    );
    expect(find.byKey(_placeholder), findsOneWidget);
    expect(find.byType(PosterPreview), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(r.calls, [('a', 480)]); // 150 px x dpr 3 -> 480 px bucket
    expect(find.byKey(_placeholder), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(PosterPreview), findsNothing);
    expect(tester.getSize(find.byType(PosterThumbnail)), const Size(150, 330));
  });

  testWidgets('same content is never rendered twice; a change re-renders '
      'while the stale raster stays visible', (tester) async {
    final r = _FakeRaster();
    final cache = _cache(r);
    addTearDown(cache.dispose);
    final p = _p('a');
    Future<void> show(MonthPoster p, {Key? key}) async {
      await tester.pumpWidget(
        _host(PosterThumbnail(key: key, poster: p, width: 100, cache: cache)),
      );
      await tester.pump();
      await tester.pump();
    }

    await show(p);
    expect(r.calls, hasLength(1));
    // Only updatedAt changed (e.g. a no-op save): no new render.
    await show(p.copyWith(updatedAt: DateTime(2030)));
    // A brand-new widget for the same draft shows the cached raster at once.
    await tester.pumpWidget(
      _host(
        PosterThumbnail(key: UniqueKey(), poster: p, width: 100, cache: cache),
      ),
    );
    expect(find.byType(RawImage), findsOneWidget);
    await tester.pump();
    expect(r.calls, hasLength(1));
    // Real change: the old raster stays until the new one is ready.
    await tester.pumpWidget(
      _host(
        PosterThumbnail(
          poster: p.copyWith(hijriYear: 1449),
          width: 100,
          cache: cache,
        ),
      ),
    );
    expect(find.byKey(_placeholder), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(r.calls, hasLength(2));
  });

  testWidgets('generation is serial and the cache is a bounded LRU', (
    tester,
  ) async {
    final r = _FakeRaster();
    final cache = _cache(r, capacity: 4);
    addTearDown(cache.dispose);
    await tester.pumpWidget(
      _host(
        Wrap(
          children: [
            for (var i = 0; i < 6; i++)
              PosterThumbnail(poster: _p('d$i'), width: 40, cache: cache),
          ],
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(r.calls.map((c) => c.$1), ['d0', 'd1', 'd2', 'd3', 'd4', 'd5']);
    expect(cache.debugMaxConcurrentRenders, 1);
    expect(cache.debugLength, 4);
    expect(cache.debugPending, 0);
  });

  testWidgets('a debounced thumbnail renders once per pause in editing', (
    tester,
  ) async {
    final r = _FakeRaster();
    final cache = _cache(r);
    addTearDown(cache.dispose);
    Future<void> show(int year) async {
      await tester.pumpWidget(
        _host(
          PosterThumbnail(
            poster: _p('e', year: year),
            width: 19,
            debounce: kThumbnailDebounce,
            cache: cache,
          ),
        ),
      );
      await tester.pump();
    }

    await show(1);
    await tester.pump();
    expect(r.calls, hasLength(1)); // the first picture is not debounced
    for (var y = 2; y < 6; y++) {
      await show(y);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(r.calls, hasLength(1));
    await tester.pump(kThumbnailDebounce);
    await tester.pump();
    expect(r.calls, hasLength(2));
    await tester.pump(const Duration(seconds: 3));
    expect(r.calls, hasLength(2));
  });

  testWidgets('the off-screen raster matches a live capture pixel for pixel', (
    tester,
  ) async {
    // One vector template and one with raster logos.
    for (final id in ['mosque_blue', 'navy_calligraphy']) {
      final t = templateById(id);
      final poster = seedReferenceMonth().copyWith(templateId: t.id);
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterPreview(poster: poster, width: 1000, boundaryKey: key),
          ),
        ),
      );
      final ctx = tester.element(find.byType(PosterPreview));
      await tester.runAsync(() => t.precache(ctx));
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final (live, off) = (await tester.runAsync(() async {
        final a = await boundary.toImage(pixelRatio: 0.36);
        final b = await rasterizePoster(ctx, poster, 360);
        final ab = await a.toByteData();
        final bb = await b.toByteData();
        expect((b.width, b.height), (a.width, a.height));
        a.dispose();
        b.dispose();
        return (ab!.buffer.asUint8List(), bb!.buffer.asUint8List());
      }))!;
      var differing = 0;
      for (var i = 0; i < live.length; i++) {
        if (live[i] != off[i]) differing++;
      }
      expect(differing, 0, reason: id);
      expect(tester.takeException(), isNull);
    }
  });
}
