import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/templates/registry.dart';
import 'package:taqweem/data/new_poster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/app.dart';
import 'package:taqweem/data/poster_repository.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/export/poster_exporter_api.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/home/draft_card.dart';
import 'package:taqweem/state/providers.dart';

import '../test_helpers/load_fonts.dart';

class _RecordingExporter implements PosterExporterApi {
  final calls = <String>[];
  final ratios = <double>[];
  final names = <String>[];
  @override
  Future<Uint8List> toPng(GlobalKey key, {double pixelRatio = 3}) async {
    calls.add('png');
    ratios.add(pixelRatio);
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Uint8List> toPdf(
    Uint8List png, {
    PdfPageSize size = PdfPageSize.a4,
  }) async {
    calls.add('pdf');
    return Uint8List.fromList([9]);
  }

  @override
  Future<File> saveBytes(Uint8List bytes, String fileName) async {
    calls.add('save');
    names.add(fileName);
    return File('/tmp/exports/$fileName');
  }

  @override
  Future<void> share(File file, {Rect? sharePositionOrigin}) async {
    calls.add('share');
  }

  @override
  String fileNameFor(MonthPoster p, String ext, {String? suffix}) =>
      PosterExporter.fileNameFor(p, ext, suffix: suffix);
}

void main() {
  setUpAll(loadAppFonts);

  late Directory tmp;
  late _RecordingExporter exporter;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('taqweem_e2e_');
    exporter = _RecordingExporter();
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Real file IO needs real time: let it run, then settle the frames.
  Future<void> settleIO(WidgetTester tester) async {
    // (pumpAndSettle can not be used: the saving spinner never settles.)
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          repositoryProvider.overrideWith(
            (ref) async => PosterRepository(Directory('${tmp.path}/posters')),
          ),
          posterExporterProvider.overrideWithValue(exporter),
        ],
        child: const TaqweemApp(),
      ),
    );
    await settleIO(tester);
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await settleIO(tester);
    await tester.enterText(f, text);
    await settleIO(tester);
  }

  Future<void> pick(WidgetTester tester, String key, String item) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await settleIO(tester);
    await tester.tap(f);
    await settleIO(tester);
    await tester.tap(find.text(item).last);
    await settleIO(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await settleIO(tester);
    await tester.tap(f);
    await settleIO(tester);
  }

  Future<List<MonthPoster>> diskPosters() =>
      PosterRepository(Directory('${tmp.path}/posters')).loadAll();

  testWidgets(
    'home -> setup -> times -> texts -> template -> export -> reopen',
    (tester) async {
      // Autosave uses real file IO, which needs real async time.
      await pumpApp(tester);

      // Home (empty state).
      expect(find.text('لا توجد تقاويم بعد'), findsOneWidget);
      await tester.tap(find.text('ابدأ تقويماً جديداً'));
      await settleIO(tester);

      // Step 1.
      await pick(tester, 'hijriMonth', 'جمادى الأول');
      await enter(tester, 'hijriYear', '1448');
      await enter(tester, 'gYear', '2026');
      await pick(tester, 'gMonth', 'أكتوبر');
      await enter(tester, 'gDay', '13');
      await enter(tester, 'sYear', '1405');
      await pick(tester, 'sMonth', 'مهر');
      await enter(tester, 'sDay', '21');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الثلاثاء'));
      await tapVisible(tester, find.text('30 يوماً'));
      await tapVisible(
        tester,
        find.ancestor(
          of: find.text('إنشاء الأيام'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );

      // Step 2.
      await tester.tap(find.byKey(const ValueKey('step-1')));
      await settleIO(tester);
      const d1 = ['418', '535', '1125', '527'];
      const d2 = ['418', '535', '1125', '526'];
      const slots = ['fajr', 'shurooq', 'zuhr', 'maghrib'];
      for (var i = 0; i < 4; i++) {
        await tester.enterText(
          find.byKey(ValueKey('time-0-${slots[i]}')),
          d1[i],
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(ValueKey('time-1-${slots[i]}')),
          d2[i],
        );
        await tester.pump();
      }
      await tester.enterText(find.byKey(const ValueKey('note-0')), 'ولادة');
      await settleIO(tester);

      // Step 3.
      await tester.tap(find.byKey(const ValueKey('step-2')));
      await settleIO(tester);
      await tester.enterText(
        find.byKey(const ValueKey('txt-title')),
        'عنوان E2E',
      );
      await settleIO(tester);

      // Step 4: pick Mosque Blue from the template chip strip (by registry
      // index, so reordering the registry cannot break this flow).
      await tester.tap(find.byKey(const ValueKey('step-3')));
      await settleIO(tester);
      final mosqueIndex = allTemplates.indexWhere((t) => t.id == 'mosque_blue');
      expect(mosqueIndex, isNonNegative);
      await tester.ensureVisible(find.byKey(ValueKey('template-chip-$mosqueIndex')));
      await tester.tap(find.byKey(ValueKey('template-chip-$mosqueIndex')));
      await settleIO(tester);
      await tapVisible(tester, find.byKey(const ValueKey('export-png')));
      await settleIO(tester);
      expect(find.text('تصدير'), findsOneWidget); // validation dialog
      await tester.tap(find.text('تصدير'));
      await settleIO(tester);
      expect(exporter.calls, ['png', 'save']);
      expect(exporter.ratios, [3.0]);
      expect(exporter.names, ['taqweem-1448-m5-mosque_blue.png']);

      // Leave the editor.
      await tester.tap(find.byType(BackButton));
      await settleIO(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleIO(tester);
      expect(find.byType(DraftCard), findsOneWidget);
      expect(find.text('جمادى الأول 1448'), findsWidgets);

      // Persisted on disk.
      final onDisk = (await tester.runAsync(diskPosters))!;
      expect(onDisk, hasLength(1));
      void check(MonthPoster p) {
        expect(p.templateId, 'mosque_blue');
        expect(p.texts.title, 'عنوان E2E');
        expect(p.hijriMonthIndex, 4);
        expect(p.days, hasLength(30));
        expect(p.days[0].times.fajr, 4 * 60 + 18);
        expect(p.days[0].note, 'ولادة');
        expect(p.days[1].times.maghrib, 5 * 60 + 26);
      }

      check(onDisk.single);

      // Second app start sees it and reopens with the same data.
      await pumpApp(tester);
      for (
        var i = 0;
        i < 20 && find.byKey(const ValueKey('loading')).evaluate().isNotEmpty;
        i++
      ) {
        await settleIO(tester);
      }
      expect(find.byType(DraftCard), findsOneWidget);
      await tester.tap(find.byType(DraftCard));
      await settleIO(tester);
      await tester.tap(find.byKey(const ValueKey('step-1')));
      await settleIO(tester);
      expect(find.text('4:18'), findsWidgets);
    },
  );

  testWidgets(
    'autosave failure shows the error chip; retry saves and clears it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);
      var fail = true;
      final saved = <MonthPoster>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            posterSaverProvider.overrideWithValue((p) async {
              if (fail) throw StateError('disk full');
              saved.add(p);
            }),
            posterExporterProvider.overrideWithValue(exporter),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: EditorShell(initial: newBlankPoster()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('hijriYear')), '1449');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.textContaining('تعذّر الحفظ'), findsOneWidget);
      // Arabic-only: a fixed reason, never the raw exception text.
      expect(find.textContaining('disk full'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      expect(
        find.text('تعذّر الحفظ — تحقق من المساحة المتاحة ثم أعد المحاولة'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('تعذّر الحفظ'), findsNothing);
      expect(saved, isNotEmpty);
      expect(saved.last.hijriYear, 1449);
      await tester.pumpAndSettle();
    },
  );
}
