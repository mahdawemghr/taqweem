import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/preview/poster_thumbnail.dart';

/// Replaces the global [ThumbnailCache] for each test in the current group
/// with one that rasterizes a tiny image immediately and without the 48 ms
/// idle delay, so no timer is left pending when the widget tree is disposed
/// (the real rasterizer cannot finish under the fake clock anyway).
void useInstantThumbnails() {
  late ThumbnailCache original;
  setUp(() {
    original = ThumbnailCache.instance;
    ThumbnailCache.instance = ThumbnailCache(
      rasterizer: (BuildContext c, MonthPoster p, int w) {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(
          const Rect.fromLTWH(0, 0, 4, 8),
          Paint()..color = const Color(0xFF123456),
        );
        final pic = rec.endRecording();
        final img = pic.toImageSync(4, 8);
        pic.dispose();
        return Future.value(img);
      },
      scheduler: <T>(T Function() task) async => task(),
    );
  });
  tearDown(() {
    ThumbnailCache.instance.dispose();
    ThumbnailCache.instance = original;
  });
}
