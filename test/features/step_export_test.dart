import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/time_format.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/export/poster_exporter_api.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/editor/invalid_times.dart';
import 'package:taqweem/features/editor/step_export.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';
import 'package:taqweem/templates/navy_gold.dart';
import 'package:taqweem/templates/poster_template.dart';

import '../test_helpers/instant_thumbnails.dart';
import '../test_helpers/load_fonts.dart';

class _FakeTemplate extends PosterTemplate {
  const _FakeTemplate(this.id, this.nameAr);
  @override
  final String id;
  @override
  final String nameAr;
  @override
  PosterTheme get theme => const NavyGoldTemplate().theme;
}

/// A template whose [precache] waits for [gate] (simulates logos that are
/// still decoding) and logs when it starts / finishes.
class _GatedTemplate extends _FakeTemplate {
  _GatedTemplate(this.log) : super('gated', 'قالب بشعار');
  final List<String> log;
  final gate = Completer<void>();

  @override
  Future<void> precache(BuildContext context) async {
    log.add('precache');
    await gate.future;
    log.add('precached');
  }
}

class FakeExporter implements PosterExporterApi {
  final calls = <String>[];
  final ratios = <double>[];
  final sizes = <PdfPageSize>[];
  final names = <String>[];
  final keys = <GlobalKey>[];
  Object? shareError;
  final shared = <File>[];
  final shareOrigins = <Rect?>[];

  /// Errors thrown by successive `toPng` calls (null = succeed).
  final List<Object?> failures = [];

  /// When set, `toPng` waits for it.
  Completer<void>? gate;

  @override
  Future<Uint8List> toPng(GlobalKey key, {double pixelRatio = 3}) async {
    calls.add('png');
    keys.add(key);
    ratios.add(pixelRatio);
    await gate?.future;
    if (failures.isNotEmpty) {
      final f = failures.removeAt(0);
      if (f != null) throw f;
    }
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Uint8List> toPdf(
    Uint8List png, {
    PdfPageSize size = PdfPageSize.a4,
  }) async {
    calls.add('pdf');
    sizes.add(size);
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
    if (shareError != null) throw shareError!;
    shared.add(file);
    shareOrigins.add(sharePositionOrigin);
  }

  @override
  String fileNameFor(MonthPoster p, String ext, {String? suffix}) =>
      PosterExporter.fileNameFor(p, ext, suffix: suffix);
}

void main() {
  setUpAll(loadAppFonts);
  useInstantThumbnails();

  Future<ProviderContainer> pumpExport(
    WidgetTester tester,
    FakeExporter fake, {
    MonthPoster? poster,
    List<PosterTemplate>? templates,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    int goToStep = 3,
  }) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posterSaverProvider.overrideWithValue((p) async {}),
          posterExporterProvider.overrideWithValue(fake),
          if (templates != null) templatesProvider.overrideWithValue(templates),
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
          home: EditorShell(initial: poster ?? seedReferenceMonth()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('step-$goToStep')));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(EditorShell)));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapKey(WidgetTester tester, String k) async {
    final f = find.byKey(ValueKey(k));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await settle(tester);
  }

  int undoCount(ProviderContainer c) {
    final ctl = c.read(editorProvider.notifier);
    var n = 0;
    while (c.read(editorProvider).canUndo) {
      ctl.undo();
      n++;
    }
    for (var i = 0; i < n; i++) {
      ctl.redo();
    }
    return n;
  }

  MonthPoster withMissingTime(MonthPoster p) => p.copyWith(
    days: [
      for (var i = 0; i < p.days.length; i++)
        i == 0
            ? p.days[i].copyWith(
                times: p.days[i].times.withSlot(PrayerSlot.zuhr, null),
              )
            : p.days[i],
    ],
  );

  const three = [
    _FakeTemplate('t1', 'القالب الأول'),
    _FakeTemplate('t2', 'القالب الثاني'),
    _FakeTemplate('t3', 'القالب الثالث'),
  ];

  testWidgets('seed poster is clean (precondition)', (tester) async {
    final fake = FakeExporter();
    final c = await pumpExport(tester, fake);
    expect(c.read(editorProvider).poster.days, isNotEmpty);
  });

  testWidgets('swiping selects the next template; one undo entry', (
    tester,
  ) async {
    final fake = FakeExporter();
    final c = await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    final handle = tester.ensureSemantics();
    final before = undoCount(c);
    expect(find.text('القالب الأول'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(c.read(editorProvider).poster.templateId, 't2');
    expect(find.text('القالب الثاني'), findsOneWidget);
    expect(undoCount(c), before + 1);
    expect(find.bySemanticsLabel('القالب 2 من 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('next/previous arrows change the template', (tester) async {
    final fake = FakeExporter();
    final c = await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    await tester.tap(find.byTooltip('القالب التالي'));
    await tester.pumpAndSettle();
    expect(c.read(editorProvider).poster.templateId, 't2');
    await tester.tap(find.byTooltip('القالب السابق'));
    await tester.pumpAndSettle();
    expect(c.read(editorProvider).poster.templateId, 't1');
  });

  testWidgets('starts on the poster template; undo moves the page back', (
    tester,
  ) async {
    final fake = FakeExporter();
    final c = await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't2'),
    );
    expect(find.text('القالب الثاني'), findsOneWidget);
    expect(c.read(editorProvider).canUndo, isFalse);
    await tester.tap(find.byTooltip('القالب التالي'));
    await tester.pumpAndSettle();
    c.read(editorProvider.notifier).undo();
    await tester.pumpAndSettle();
    expect(find.text('القالب الثاني'), findsOneWidget);
  });

  testWidgets('single template hides dots and arrows', (tester) async {
    final fake = FakeExporter();
    // Explicit single template: the real registry now has more than one.
    await pumpExport(
      tester,
      fake,
      templates: const [_FakeTemplate('t1', 'القالب الأول')],
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    expect(find.byTooltip('القالب التالي'), findsNothing);
    expect(find.byKey(const ValueKey('template-dots')), findsNothing);
  });

  testWidgets('PNG with clean data: ratio 3, saved with suffix name', (
    tester,
  ) async {
    final fake = FakeExporter();
    final c = await pumpExport(tester, fake);
    final p = c.read(editorProvider).poster;
    await tapKey(tester, 'export-png');
    expect(fake.calls, ['png', 'save']);
    expect(fake.ratios, [3.0]);
    expect(
      fake.names.single,
      PosterExporter.fileNameFor(p, 'png', suffix: p.templateId),
    );
    expect(find.textContaining('تم الحفظ:'), findsOneWidget);
    expect(find.textContaining(fake.names.single), findsOneWidget);
  });

  testWidgets('resolution segments set the pixel ratio', (tester) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake);
    await tester.ensureVisible(find.text('طباعة ×4'));
    await tester.tap(find.text('طباعة ×4'));
    await tester.pump();
    await tapKey(tester, 'export-png');
    await tester.ensureVisible(find.text('عادية ×2'));
    await tester.tap(find.text('عادية ×2'));
    await tester.pump();
    await tapKey(tester, 'export-png');
    expect(fake.ratios, [4.0, 2.0]);
  });

  testWidgets('PDF: png at chosen ratio, then A4 pdf, then save', (
    tester,
  ) async {
    final fake = FakeExporter();
    final c = await pumpExport(tester, fake);
    final p = c.read(editorProvider).poster;
    await tapKey(tester, 'export-pdf');
    expect(fake.calls, ['png', 'pdf', 'save']);
    expect(fake.ratios, [3.0]);
    expect(fake.sizes, [PdfPageSize.a4]);
    expect(
      fake.names.single,
      PosterExporter.fileNameFor(p, 'pdf', suffix: p.templateId),
    );
    await tester.ensureVisible(find.text('A3'));
    await tester.tap(find.text('A3'));
    await tester.pump();
    await tapKey(tester, 'export-pdf');
    expect(fake.sizes.last, PdfPageSize.a3);
    await tester.tap(find.text('حجم الملصق'));
    await tester.pump();
    await tapKey(tester, 'export-pdf');
    expect(fake.sizes.last, PdfPageSize.poster);
  });

  testWidgets('share exports a PNG then shares the saved file', (tester) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake);
    await tapKey(tester, 'export-share');
    expect(fake.calls, ['png', 'save', 'share']);
    expect(fake.shared.single.path, endsWith('.png'));
    expect(fake.shareOrigins.single, isNotNull);
  });

  testWidgets('snackbar action shares the saved file', (tester) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake);
    await tapKey(tester, 'export-png');
    await tester.tap(find.text('مشاركة').last);
    await tester.pump();
    expect(fake.calls.last, 'share');
    expect(fake.shared.single.path, endsWith('.png'));
  });

  testWidgets('missing time: warning dialog; تصدير proceeds', (tester) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      poster: withMissingTime(seedReferenceMonth()),
    );
    await tapKey(tester, 'export-png');
    expect(fake.calls, isEmpty);
    expect(
      find.text('يوجد 1 تنبيهات في البيانات. هل تريد التصدير رغم ذلك؟'),
      findsOneWidget,
    );
    expect(find.textContaining('اليوم 1'), findsOneWidget);
    await tester.tap(find.text('تصدير'));
    await tester.pump();
    await settle(tester);
    expect(fake.calls, ['png', 'save']);
  });

  testWidgets('missing time: مراجعة goes to step index 1', (tester) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      poster: withMissingTime(seedReferenceMonth()),
    );
    await tapKey(tester, 'export-png');
    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty);
    expect(find.byKey(const ValueKey('grid-list')), findsOneWidget);
  });

  testWidgets('invalid typed times are counted; list capped at 5', (
    tester,
  ) async {
    final fake = FakeExporter();
    final c = await pumpExport(tester, fake);
    final inv = c.read(invalidTimesProvider.notifier);
    for (var i = 0; i < 7; i++) {
      inv.put(i, PrayerSlot.fajr, 'xx');
    }
    await tester.pump();
    await tapKey(tester, 'export-png');
    expect(
      find.text('يوجد 7 تنبيهات في البيانات. هل تريد التصدير رغم ذلك؟'),
      findsOneWidget,
    );
    expect(find.textContaining('غير صالح'), findsNWidgets(5));
    expect(find.textContaining('…و 2 أخرى'), findsOneWidget);
  });

  testWidgets('no rows: snackbar, no export; الشهر goes to step 0', (
    tester,
  ) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      poster: seedReferenceMonth().copyWith(days: const []),
    );
    await tapKey(tester, 'export-png');
    expect(fake.calls, isEmpty);
    expect(
      find.text('لا توجد أيام للتصدير — أنشئ الأيام أولاً'),
      findsOneWidget,
    );
    await tester.tap(find.text('الشهر').last);
    await tester.pumpAndSettle();
    expect(find.text('الشهر'), findsWidgets);
    expect(find.byKey(const ValueKey('export-png')), findsNothing);
  });

  testWidgets('failure: retry dialog; إعادة المحاولة calls again', (
    tester,
  ) async {
    final fake = FakeExporter()..failures.add(const ExportException('boom'));
    await pumpExport(tester, fake);
    await tapKey(tester, 'export-png');
    expect(find.text('تعذّر التصدير'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(
      find.text('تعذّر إنشاء الصورة بهذه الدقة — جرّب جودة أقل'),
      findsOneWidget,
    );
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await settle(tester);
    expect(fake.ratios, [3.0, 3.0]);
    expect(fake.calls.last, 'save');
    expect(find.textContaining('تم الحفظ:'), findsOneWidget);
  });

  testWidgets('failure at ratio > 2 offers جرّب ×2', (tester) async {
    final fake = FakeExporter()..failures.add(StateError('oom'));
    await pumpExport(tester, fake);
    await tapKey(tester, 'export-png');
    await tester.tap(find.text('جرّب ×2'));
    await tester.pump();
    await settle(tester);
    expect(fake.ratios, [3.0, 2.0]);
    expect(fake.calls.last, 'save');
  });

  testWidgets('failure at ratio 2 has no جرّب ×2', (tester) async {
    final fake = FakeExporter()..failures.add(StateError('oom'));
    await pumpExport(tester, fake);
    await tester.ensureVisible(find.text('عادية ×2'));
    await tester.tap(find.text('عادية ×2'));
    await tester.pump();
    await tapKey(tester, 'export-png');
    expect(find.text('تعذّر التصدير'), findsOneWidget);
    expect(find.text('جرّب ×2'), findsNothing);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر التصدير'), findsNothing);
  });

  testWidgets('buttons are disabled and progress shown during export', (
    tester,
  ) async {
    final fake = FakeExporter()..gate = Completer<void>();
    await pumpExport(tester, fake);
    final png = find.byKey(const ValueKey('export-png'));
    await tester.ensureVisible(png);
    await tester.tap(png);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('جارٍ التصدير…'), findsOneWidget);
    for (final k in ['export-png', 'export-pdf', 'export-share']) {
      final b = tester.widget<ButtonStyleButton>(find.byKey(ValueKey(k)));
      expect(b.onPressed, isNull, reason: k);
    }
    await tester.tap(png, warnIfMissed: false);
    await tester.pump();
    expect(fake.calls.where((e) => e == 'png').length, 1);
    fake.gate!.complete();
    await tester.pump();
    await settle(tester);
    expect(find.text('جارٍ التصدير…'), findsNothing);
    final b = tester.widget<ButtonStyleButton>(png);
    expect(b.onPressed, isNotNull);
  });

  testWidgets('zoom route opens and closes', (tester) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tapKey(tester, 'zoom-button');
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('tapping the preview opens the zoom route', (tester) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake);
    await tester.tap(find.byKey(const ValueKey('preview-tap-0')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('failure messages are fixed Arabic lines, never raw text', (
    tester,
  ) async {
    final fake = FakeExporter()
      ..failures.add(
        const ExportException('Poster is not on screen; cannot export.'),
      );
    await pumpExport(tester, fake);
    await tapKey(tester, 'export-png');
    expect(find.text('الملصق غير ظاهر — أعد المحاولة'), findsOneWidget);
    expect(find.textContaining('Poster is not'), findsNothing);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    fake.failures.add(
      const ExportException('Could not render the poster at 3.0x resolution'),
    );
    await tapKey(tester, 'export-png');
    expect(find.textContaining('Could not'), findsNothing);
    expect(
      find.text('تعذّر إنشاء الصورة بهذه الدقة — جرّب جودة أقل'),
      findsOneWidget,
    );
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('عادية ×2'));
    await tester.tap(find.text('عادية ×2'));
    await tester.pump();
    fake.failures.add(StateError('secret detail'));
    await tapKey(tester, 'export-png');
    expect(find.text('حدث خطأ أثناء التصدير — أعد المحاولة'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('picker is inert while exporting', (tester) async {
    final fake = FakeExporter()..gate = Completer<void>();
    final c = await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    final png = find.byKey(const ValueKey('export-png'));
    await tester.ensureVisible(png);
    await tester.tap(png);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.ensureVisible(find.byType(PageView));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(editorProvider).poster.templateId, 't1');
    await tester.tap(find.byTooltip('القالب التالي'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(editorProvider).poster.templateId, 't1');
    final zoom = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('zoom-button')),
    );
    expect(zoom.onPressed, isNull);
    fake.gate!.complete();
    await tester.pump();
    await settle(tester);
    await tester.ensureVisible(find.byType(PageView));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(c.read(editorProvider).poster.templateId, 't2');
  });

  testWidgets('no templates: hint, disabled actions, no exception', (
    tester,
  ) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake, templates: const []);
    expect(find.text('لا توجد قوالب متاحة'), findsOneWidget);
    for (final k in [
      'export-png',
      'export-pdf',
      'export-share',
      'zoom-button',
    ]) {
      final b = tester.widget<ButtonStyleButton>(find.byKey(ValueKey(k)));
      expect(b.onPressed, isNull, reason: k);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown stored templateId syncs to the first template', (
    tester,
  ) async {
    final fake = FakeExporter();
    final c = await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 'gone'),
    );
    expect(c.read(editorProvider).poster.templateId, 't1');
    expect(undoCount(c), 1);
    await tapKey(tester, 'export-png');
    expect(fake.names.single, endsWith('-t1.png'));
  });

  testWidgets('snackbar share failure shows an Arabic error', (tester) async {
    final fake = FakeExporter()..shareError = StateError('x');
    await pumpExport(tester, fake);
    await tapKey(tester, 'export-png');
    await tester.tap(find.text('مشاركة').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تعذّرت المشاركة'), findsOneWidget);
  });

  testWidgets('export awaits the template precache (logos) before capture', (
    tester,
  ) async {
    final fake = FakeExporter();
    final log = <String>[];
    final gated = _GatedTemplate(log);
    await pumpExport(
      tester,
      fake,
      templates: [gated],
      poster: seedReferenceMonth().copyWith(templateId: 'gated'),
    );
    // Preview + picker warm-up started precaching; the gate is still shut.
    expect(log, contains('precache'));
    expect(log, isNot(contains('precached')));
    log.clear();
    await tapKey(tester, 'export-png');
    expect(log, ['precache'], reason: 'export asked for the logos');
    expect(fake.calls, isEmpty, reason: 'no capture before logos decode');
    gated.gate.complete();
    await settle(tester);
    expect(fake.calls, ['png', 'save']);
    expect(log.indexOf('precached'), greaterThanOrEqualTo(0));
  });

  testWidgets('capture uses the displayed template key and name suffix', (
    tester,
  ) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    await tapKey(tester, 'export-png');
    await tester.ensureVisible(find.byType(PageView));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tapKey(tester, 'export-png');
    expect(fake.keys.length, 2);
    expect(fake.keys[0], isNot(equals(fake.keys[1])));
    expect(fake.names[0], endsWith('-t1.png'));
    expect(fake.names[1], endsWith('-t2.png'));
    // The key of the second capture is on the displayed page's boundary.
    expect(fake.keys[1].currentContext, isNotNull);
  });

  testWidgets('text scale 1.3: no overflow, targets >= 48', (tester) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake, textScale: 1.3, templates: three);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('export-share')));
    await tester.pump();
    for (final k in ['export-png', 'export-pdf', 'export-share']) {
      final s = tester.getSize(find.byKey(ValueKey(k)));
      expect(s.height, greaterThanOrEqualTo(48), reason: k);
    }
    expect(tester.takeException(), isNull);
  });

  // ---- picker usability with many templates --------------------------------
  final ten = [
    for (var i = 1; i <= 10; i++) _FakeTemplate('t$i', 'قالب رقم $i'),
  ];

  testWidgets('counter shows n / N next to the name chip', (tester) async {
    final fake = FakeExporter();
    final c = await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    final counter = find.byKey(const ValueKey('template-counter'));
    expect(tester.widget<Text>(counter).data, '1 / 3');
    await tester.tap(find.byTooltip('القالب التالي'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(counter).data, '2 / 3');
    expect(c.read(editorProvider).poster.templateId, 't2');
  });

  testWidgets('template arrows point the right way in RTL', (tester) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      templates: three,
      poster: seedReferenceMonth().copyWith(templateId: 't2'),
    );
    final prev = find.byTooltip('القالب السابق');
    final next = find.byTooltip('القالب التالي');
    // Previous sits on the right (reading start), next on the left.
    expect(tester.getCenter(prev).dx, greaterThan(tester.getCenter(next).dx));
    // Chevron icons are mirrored in RTL: "left" glyph shows pointing right.
    IconData glyph(Finder f) => tester
        .widget<Icon>(find.descendant(of: f, matching: find.byType(Icon)))
        .icon!;
    expect(glyph(prev), Icons.chevron_left_rounded);
    expect(glyph(next), Icons.chevron_right_rounded);
    expect(
      Directionality.of(tester.element(prev)),
      TextDirection.rtl,
    );
  });

  testWidgets('chip strip: shown for 10 templates (no dots), not for <= 6', (
    tester,
  ) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      templates: ten,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    expect(find.byKey(const ValueKey('template-chips')), findsOneWidget);
    expect(find.byKey(const ValueKey('template-dots')), findsNothing);
    expect(find.byTooltip('القالب التالي'), findsOneWidget);
    for (final i in [0, 1]) {
      final s = tester.getSize(find.byKey(ValueKey('template-chip-$i')));
      expect(s.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('chip strip absent with 6 templates (dots kept)', (tester) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      templates: ten.sublist(0, 6),
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    expect(find.byKey(const ValueKey('template-chips')), findsNothing);
    expect(find.byKey(const ValueKey('template-dots')), findsOneWidget);
  });

  testWidgets(
    'tapping a chip selects it: one undo entry, file suffix matches',
    (tester) async {
      final fake = FakeExporter();
      final c = await pumpExport(
        tester,
        fake,
        templates: ten,
        poster: seedReferenceMonth().copyWith(templateId: 't1'),
      );
      final before = undoCount(c);
      final chip = find.byKey(const ValueKey('template-chip-2'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(c.read(editorProvider).poster.templateId, 't3');
      expect(find.text('3 / 10'), findsOneWidget);
      expect(undoCount(c), before + 1);
      await tapKey(tester, 'export-png');
      expect(fake.names.single, endsWith('-t3.png'));
    },
  );

  testWidgets('chips are inert while an export is pending', (tester) async {
    final fake = FakeExporter()..gate = Completer<void>();
    final c = await pumpExport(
      tester,
      fake,
      templates: ten,
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('export-png')));
    await tester.tap(find.byKey(const ValueKey('export-png')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final chip = find.byKey(const ValueKey('template-chip-4'));
    await tester.ensureVisible(chip);
    await tester.tap(chip, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(editorProvider).poster.templateId, 't1');
    fake.gate!.complete();
    await tester.pumpAndSettle();
    expect(fake.names.single, endsWith('-t1.png'));
  });

  testWidgets('selected chip scrolls into view (small surface)', (
    tester,
  ) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      templates: ten,
      size: const Size(320, 700),
      poster: seedReferenceMonth().copyWith(templateId: 't1'),
    );
    final strip = find.byKey(const ValueKey('template-chips'));
    final stripRect = tester.getRect(strip);
    Rect chipRect(int i) =>
        tester.getRect(find.byKey(ValueKey('template-chip-$i')));
    // The last chip starts outside the strip (not built or off screen).
    final lastBefore = find.byKey(const ValueKey('template-chip-9'));
    expect(
      lastBefore.evaluate().isEmpty ||
          !stripRect.contains(tester.getCenter(lastBefore)),
      isTrue,
    );
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byTooltip('القالب التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.text('10 / 10'), findsOneWidget);
    final r = chipRect(9);
    expect(r.left, greaterThanOrEqualTo(stripRect.left - 0.5));
    expect(r.right, lessThanOrEqualTo(stripRect.right + 0.5));
  });

  testWidgets('10 templates at text scale 1.3 on 390x844: no overflow', (
    tester,
  ) async {
    final fake = FakeExporter();
    await pumpExport(tester, fake, textScale: 1.3, templates: ten);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip semantics: label, selected state', (tester) async {
    final fake = FakeExporter();
    await pumpExport(
      tester,
      fake,
      templates: ten,
      poster: seedReferenceMonth().copyWith(templateId: 't2'),
    );
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('القالب 2 من 10'), findsWidgets);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('template-chip-1'))),
      matchesSemantics(
        label: 'قالب رقم 2',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
