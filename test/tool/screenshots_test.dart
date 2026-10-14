// Headless "screenshots" of every screen (no display needed). Skipped by
// default (tag `screenshots`); run:
//   flutter test --run-skipped --tags screenshots test/tool/screenshots_test.dart
// Output: build/screenshots/*.png (override with SHOTS_DIR).
@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/app.dart';
import 'package:taqweem/features/home/draft_card.dart';
import 'package:taqweem/data/poster_repository.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/state/providers.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';

final _shot = GlobalKey();

/// Real file IO started under the fake clock never completes, so the drafts
/// are loaded up front (in real time) and handed to the provider.
class _Preloaded extends PostersNotifier {
  _Preloaded(this.list);
  final List<MonthPoster> list;
  @override
  Future<List<MonthPoster>> build() async => list;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });
  final out = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/screenshots')
    ..createSync(recursive: true);

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      for (var j = 0; j < 4; j++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> snap(WidgetTester t, String name) async {
    await settle(t);
    final b = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await t.runAsync(() async {
      final img = await b.toImage(pixelRatio: 1.5);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      return d!.buffer.asUint8List();
    });
    File('${out.path}/$name.png').writeAsBytesSync(bytes!);
  }

  Future<void> pumpApp(WidgetTester t, Directory dir, Size size,
      {double textScale = 1}) async {
    final loaded = await t.runAsync(PosterRepository(dir).loadAll) ?? [];
    await t.binding.setSurfaceSize(size);
    t.view.devicePixelRatio = 1;
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      RepaintBoundary(
        key: _shot,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [
            repositoryProvider.overrideWith((ref) async => PosterRepository(dir)),
            postersProvider.overrideWith(() => _Preloaded(loaded)),
          ],
          child: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: const TaqweemApp(),
          ),
        ),
      ),
    );
    await settle(t);
  }

  for (final cfg in [
    ('phone', const Size(390, 844), 1.0),
    ('phone-large-text', const Size(360, 740), 1.4),
    ('tablet', const Size(1024, 768), 1.0),
  ]) {
    final (label, size, scale) = cfg;
    testWidgets('empty home + editor tour ($label)', (t) async {
      final dir = Directory.systemTemp.createTempSync('shots_');
      await pumpApp(t, dir, size, textScale: scale);
      await snap(t, '$label-01-home-empty');
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await snap(t, '$label-02-editor-step1');
      for (var i = 1; i < 4; i++) {
        await t.tap(find.byKey(ValueKey('step-$i')));
        await settle(t);
        await snap(t, '$label-0${i + 2}-editor-step${i + 1}');
      }
    });

    testWidgets('home with drafts + seeded editor ($label)', (t) async {
      final dir = Directory.systemTemp.createTempSync('shots_');
      final repo = PosterRepository(dir);
      final seed = seedReferenceMonth();
      var n = 0;
      for (final tpl in allTemplates.take(4)) {
        await t.runAsync(() => repo.save(seed.copyWith(
              id: 'seed-${n++}',
              templateId: tpl.id,
            )));
      }
      await pumpApp(t, dir, size, textScale: scale);
      await snap(t, '$label-10-home-drafts');
      await t.tap(find.byType(DraftCard).first);
      await settle(t);
      await snap(t, '$label-11-editor-seeded-step1');
      await t.tap(find.byKey(const ValueKey('step-1')));
      await settle(t);
      await snap(t, '$label-12-editor-grid');
      await t.tap(find.byKey(const ValueKey('step-3')));
      await settle(t);
      await snap(t, '$label-13-editor-export');
    });
  }
}
