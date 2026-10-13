import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/weekday.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/editor/step_setup.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';

import '../test_helpers/load_fonts.dart';

MonthPoster blank() => MonthPoster(
  id: 'poster-test',
  updatedAt: DateTime(2026, 10, 13),
  hijriMonthIndex: 0,
  hijriYear: 1448,
);

MonthSetup referenceSetup({int dayCount = 30}) => MonthSetup(
  hijriMonthIndex: 4,
  hijriYear: 1448,
  firstWeekday: Weekday.tuesday,
  dayCount: dayCount,
  gregorianStart: const DateParts(2026, 10, 13),
  solarStart: const DateParts(1405, 7, 21),
);

/// A poster whose rows were generated from [referenceSetup] (no times/notes).
MonthPoster generated({int dayCount = 29}) {
  final f = CalendarFill.generate(referenceSetup(dayCount: dayCount));
  return blank().copyWith(
    hijriMonthIndex: 4,
    days: f.days,
    gregorianHeader: f.gregorianHeader,
    solarHeader: f.solarHeader,
  );
}

void main() {
  setUpAll(loadAppFonts);

  late List<MonthPoster> saved;
  late Future<void> Function(MonthPoster) saver;

  setUp(() {
    saved = [];
    saver = (p) async => saved.add(p);
  });

  /// Pushes the shell on top of a launcher route (so it can be left) and
  /// returns the provider container.
  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    MonthPoster poster, {
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [posterSaverProvider.overrideWithValue((p) => saver(p))],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditorShell(initial: poster),
                    ),
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(EditorShell)));
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String key, String item) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Finder createButton(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  );

  Future<void> fillReference(
    WidgetTester tester, {
    String gYear = '2026',
    String gDay = '13',
    String sYear = '1405',
    String sDay = '21',
  }) async {
    await pick(tester, 'hijriMonth', 'جمادى الأول');
    await enter(tester, 'hijriYear', '1448');
    await enter(tester, 'gYear', gYear);
    await pick(tester, 'gMonth', 'أكتوبر');
    await enter(tester, 'gDay', gDay);
    await enter(tester, 'sYear', sYear);
    await pick(tester, 'sMonth', 'مهر');
    await enter(tester, 'sDay', sDay);
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الثلاثاء'));
    await tapVisible(tester, find.text('30 يوماً'));
  }

  MonthPoster posterOf(ProviderContainer c) => c.read(editorProvider).poster;

  testWidgets('a) reference setup + create -> 30 rows, row 19 is نوفمبر', (
    tester,
  ) async {
    final c = await pumpShell(tester, blank());
    expect(createButton('إنشاء الأيام'), findsOneWidget);
    await fillReference(tester);
    expect(
      find.text('سيُنشأ 30 يوماً من الثلاثاء 13 أكتوبر 2026'),
      findsOneWidget,
    );
    await tapVisible(tester, createButton('إنشاء الأيام'));
    expect(find.byType(AlertDialog), findsNothing);
    final p = posterOf(c);
    expect(p.days, hasLength(30));
    expect(p.days[19].gregorian, const DayCell.label('نوفمبر'));
    expect(p.days.first.weekday, Weekday.tuesday);
    expect(p.hijriMonthIndex, 4);
    expect(p.hijriYear, 1448);
    expect(p.gregorianHeader, 'أكتوبر\nنوفمبر\n2026');
    expect(p.solarHeader, 'مهر\nآبان\n1405');
    // The button now offers an update.
    expect(createButton('تحديث الأيام'), findsOneWidget);
  });

  testWidgets('b) 29 -> 30 with a note keeps it, adds a row, no dialog', (
    tester,
  ) async {
    final c = await pumpShell(tester, generated(dayCount: 29));
    c
        .read(editorProvider.notifier)
        .update(
          (p) => p.copyWith(
            days: [
              for (var i = 0; i < p.days.length; i++)
                i == 3 ? p.days[i].copyWith(note: 'ملاحظة') : p.days[i],
            ],
          ),
        );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('30 يوماً'));
    expect(find.byType(AlertDialog), findsNothing);
    final p = posterOf(c);
    expect(p.days, hasLength(30));
    expect(p.days[3].note, 'ملاحظة');
    expect(p.days[29].gregorian, const DayCell.number(11));
    expect(p.days[29].weekday, Weekday.wednesday);
    // And back to 29 drops the last row only.
    await tapVisible(tester, find.text('29 يوماً'));
    expect(posterOf(c).days, hasLength(29));
    expect(posterOf(c).days[3].note, 'ملاحظة');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('c) regenerate with data asks; cancel keeps, confirm replaces', (
    tester,
  ) async {
    final c = await pumpShell(tester, seedReferenceMonth());
    final before = posterOf(c).days;
    expect(before.first.times.fajr, isNotNull);
    await tapVisible(tester, createButton('تحديث الأيام'));
    expect(find.text('سيتم استبدال بيانات الأيام. متابعة؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(identical(posterOf(c).days, before), isTrue);

    await tapVisible(tester, createButton('تحديث الأيام'));
    await tester.tap(find.widgetWithText(FilledButton, 'استبدال'));
    await tester.pumpAndSettle();
    final after = posterOf(c).days;
    expect(after, hasLength(30));
    expect(after.first.times.fajr, isNull);
    expect(after[19].gregorian, const DayCell.label('نوفمبر'));
  });

  testWidgets('c2) regenerate without data does not ask', (tester) async {
    final c = await pumpShell(tester, generated(dayCount: 30));
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الأربعاء'));
    await tapVisible(tester, createButton('تحديث الأيام'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(posterOf(c).days.first.weekday, Weekday.wednesday);
  });

  testWidgets('d) Feb 30 disables create and shows تاريخ غير صالح', (
    tester,
  ) async {
    final c = await pumpShell(tester, blank());
    await fillReference(tester);
    await pick(tester, 'gMonth', 'فبراير');
    await enter(tester, 'gDay', '30');
    expect(find.text('تاريخ غير صالح'), findsOneWidget);
    final btn = tester.widget<FilledButton>(createButton('إنشاء الأيام'));
    expect(btn.onPressed, isNull);
    // Solar Mehr 31 is invalid too (month 7 has 30 days).
    await enter(tester, 'gDay', '28');
    expect(find.text('تاريخ غير صالح'), findsNothing);
    await enter(tester, 'sDay', '31');
    expect(find.text('تاريخ غير صالح'), findsOneWidget);
    expect(posterOf(c).days, isEmpty);
  });

  testWidgets('d2) missing inputs are named and block create', (tester) async {
    await pumpShell(tester, blank());
    // The solar date has no default: the user is told it is required.
    final btn = tester.widget<FilledButton>(createButton('إنشاء الأيام'));
    expect(btn.onPressed, isNull);
    expect(find.textContaining('التاريخ الشمسي'), findsWidgets);
    expect(find.textContaining('أكمل'), findsOneWidget);
  });

  testWidgets('e) Arabic-Indic digits are accepted', (tester) async {
    final c = await pumpShell(tester, blank());
    await fillReference(
      tester,
      gYear: '٢٠٢٦',
      gDay: '١٣',
      sYear: '۱۴۰۵',
      sDay: '٢١',
    );
    await tapVisible(tester, createButton('إنشاء الأيام'));
    final p = posterOf(c);
    expect(p.days, hasLength(30));
    expect(p.days.first.gregorian, const DayCell.number(13));
    expect(p.days.first.solar, const DayCell.number(21));
    expect(p.days[19].gregorian, const DayCell.label('نوفمبر'));
  });

  testWidgets('f) stepper chips navigate; السابق returns', (tester) async {
    await pumpShell(tester, blank());
    for (final s in ['الشهر', 'الأيام', 'النصوص', 'التصدير']) {
      expect(find.text(s), findsWidgets);
    }
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أيام بعد'), findsOneWidget);
    expect(createButton('إنشاء الأيام'), findsNothing);
    await tester.tap(find.text('السابق'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أيام بعد'), findsNothing);
    expect(createButton('إنشاء الأيام'), findsOneWidget);
    // التالي walks forward.
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أيام بعد'), findsOneWidget);
  });

  testWidgets('f2) the setup draft survives a round trip to another step', (
    tester,
  ) async {
    await pumpShell(tester, blank());
    await enter(tester, 'sDay', '21');
    await tester.tap(find.byKey(const ValueKey('step-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-0')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('sDay')),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    );
    expect(field.controller!.text, '21');
  });

  testWidgets('g) leaving the shell flushes the latest poster', (tester) async {
    final c = await pumpShell(tester, generated());
    c
        .read(editorProvider.notifier)
        .update((p) => p.copyWith(days: [p.days.first.copyWith(note: 'أخير')]));
    await tester.pump();
    expect(saved, isEmpty); // debounce still pending
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(saved, isNotEmpty);
    expect(saved.last.days.single.note, 'أخير');
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell), findsNothing);
  });

  testWidgets('h) undo reverts a generate, redo reapplies it', (tester) async {
    final c = await pumpShell(tester, blank());
    await fillReference(tester);
    await tapVisible(tester, createButton('إنشاء الأيام'));
    expect(posterOf(c).days, hasLength(30));
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days, isEmpty);
    await tester.tap(find.byTooltip('إعادة'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days, hasLength(30));
  });

  for (final p in [('blank', blank()), ('seed', seedReferenceMonth())]) {
    testWidgets('i) text scale 1.3 on 390x844 has no overflow (${p.$1})', (
      tester,
    ) async {
      await pumpShell(tester, p.$2, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('step-3')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('j) Esfand length toggle only for solar month 12', (
    tester,
  ) async {
    await pumpShell(tester, blank());
    expect(find.text('طول إسفند'), findsNothing);
    await pick(tester, 'sMonth', 'اسفند');
    expect(find.text('طول إسفند'), findsOneWidget);
    await pick(tester, 'sMonth', 'مهر');
    expect(find.text('طول إسفند'), findsNothing);
  });

  testWidgets('j2) Esfand 30 is honoured by create', (tester) async {
    final c = await pumpShell(tester, blank());
    await fillReference(tester);
    await pick(tester, 'sMonth', 'اسفند');
    await enter(tester, 'sDay', '29');
    await tapVisible(tester, find.byKey(const ValueKey('esfand-30')));
    await tapVisible(tester, createButton('إنشاء الأيام'));
    final days = posterOf(c).days;
    expect(days[1].solar, const DayCell.number(30));
    expect(days[2].solar, const DayCell.label('فروردين'));
  });

  testWidgets('save indicator: saving, saved, error with retry', (
    tester,
  ) async {
    var fail = true;
    saver = (p) async {
      if (fail) throw StateError('القرص ممتلئ');
      saved.add(p);
    };
    final c = await pumpShell(tester, generated());
    expect(find.text('تم الحفظ ✓'), findsNothing);
    c.read(editorProvider.notifier).update((p) => p.copyWith(hijriYear: 1449));
    await tester.pump();
    expect(find.text('جارٍ الحفظ…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.textContaining('القرص ممتلئ'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(saved.last.hijriYear, 1449);
    expect(find.text('تم الحفظ ✓'), findsOneWidget);
    expect(find.textContaining('القرص ممتلئ'), findsNothing);
  });

  testWidgets('prefills the form from existing rows', (tester) async {
    await pumpShell(tester, seedReferenceMonth());
    String text(String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
            matchRoot: true,
          ),
        )
        .controller!
        .text;
    expect(text('hijriYear'), '1448');
    expect(text('gYear'), '2026');
    expect(text('gDay'), '13');
    expect(text('sYear'), '1405');
    expect(text('sDay'), '21');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'الثلاثاء'))
          .selected,
      isTrue,
    );
  });

  testWidgets('mini preview opens a zoomable full-screen preview', (
    tester,
  ) async {
    await pumpShell(tester, seedReferenceMonth());
    await tester.tap(find.byTooltip('معاينة الملصق'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  // ------------------------------------------------------------------
  // Fix round 1
  // ------------------------------------------------------------------

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  bool fieldInError(WidgetTester tester, String key) {
    final d = tester.widget<TextField>(find.byKey(ValueKey(key))).decoration!;
    return d.error != null || d.errorText != null;
  }

  testWidgets('R1-1) undo re-prefills the draft from the restored rows', (
    tester,
  ) async {
    final c = await pumpShell(tester, blank());
    await fillReference(tester);
    await tapVisible(tester, createButton('إنشاء الأيام'));
    await enter(tester, 'gDay', '14');
    await tapVisible(tester, createButton('تحديث الأيام'));
    expect(posterOf(c).days.first.gregorian, const DayCell.number(14));
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days.first.gregorian, const DayCell.number(13));
    expect(fieldText(tester, 'gDay'), '13');
    expect(fieldText(tester, 'gYear'), '2026');
    expect(fieldText(tester, 'sDay'), '21');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'الثلاثاء'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('الأيام جاهزة'), findsOneWidget);
  });

  testWidgets('R1-1b) undo back to an empty poster keeps the typed draft', (
    tester,
  ) async {
    final c = await pumpShell(tester, blank());
    await fillReference(tester);
    await tapVisible(tester, createButton('إنشاء الأيام'));
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days, isEmpty);
    expect(fieldText(tester, 'sDay'), '21');
    expect(fieldText(tester, 'gDay'), '13');
  });

  testWidgets('R1-2) only the current step is built; blank draft survives', (
    tester,
  ) async {
    await pumpShell(tester, blank());
    expect(find.text('قريباً', skipOffstage: false), findsNothing);
    await enter(tester, 'sYear', '1405');
    await pick(tester, 'sMonth', 'مهر');
    await enter(tester, 'sDay', '21');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الخميس'));
    await enter(tester, 'gDay', '1');
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    expect(find.byType(StepSetup, skipOffstage: false), findsNothing);
    expect(find.text('لا توجد أيام بعد'), findsOneWidget);
    await tester.tap(find.text('السابق'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'sYear'), '1405');
    expect(fieldText(tester, 'sDay'), '21');
    expect(fieldText(tester, 'gDay'), '1');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'الخميس'))
          .selected,
      isTrue,
    );
    expect(find.text('مهر'), findsWidgets);
  });

  testWidgets('R1-3a) growing underivable rows extends from the last row', (
    tester,
  ) async {
    final base = generated(dayCount: 29);
    // Row 0's day is unreadable, so the rows' setup cannot be derived, but
    // the last row and the headers still give the next day.
    final p = base.copyWith(
      days: [
        base.days.first.copyWith(gregorian: const DayCell.number(0)),
        ...base.days.skip(1),
      ],
    );
    expect(deriveRowsSetup(p), isNull);
    final c = await pumpShell(tester, p);
    await tapVisible(tester, find.text('30 يوماً'));
    final days = posterOf(c).days;
    expect(days, hasLength(30));
    expect(days[29].gregorian, const DayCell.number(11));
    expect(days[29].solar, const DayCell.number(20));
    expect(days[29].weekday, Weekday.wednesday);
    expect(days[29].hijriDay, 30);
    expect(days.first.gregorian, const DayCell.number(0)); // untouched
  });

  testWidgets('R1-3b) growing rows with no derivable next day is blocked', (
    tester,
  ) async {
    final c = await pumpShell(
      tester,
      generated(dayCount: 29).copyWith(gregorianHeader: 'x'),
    );
    await tapVisible(tester, find.text('30 يوماً'));
    expect(posterOf(c).days, hasLength(29));
    expect(
      find.text(
        'تعذّر تحديد تاريخ اليوم التالي — اضغط «تحديث الأيام» لإعادة الإنشاء',
      ),
      findsOneWidget,
    );
  });

  testWidgets('R1-3c) shrinking underivable rows still works', (tester) async {
    final c = await pumpShell(
      tester,
      generated(dayCount: 30).copyWith(gregorianHeader: 'x'),
    );
    await tapVisible(tester, find.text('29 يوماً'));
    expect(posterOf(c).days, hasLength(29));
  });

  testWidgets('R1-4) the confirm dialog mentions highlights', (tester) async {
    await pumpShell(tester, seedReferenceMonth());
    await tapVisible(tester, createButton('تحديث الأيام'));
    expect(find.textContaining('والتمييز'), findsOneWidget);
    expect(find.text('سيتم استبدال بيانات الأيام. متابعة؟'), findsOneWidget);
  });

  testWidgets('R1-5) no error flash while the year is being typed', (
    tester,
  ) async {
    await pumpShell(tester, blank());
    await fillReference(tester);
    await enter(tester, 'gYear', '20');
    expect(find.text('تاريخ غير صالح'), findsNothing);
    expect(fieldInError(tester, 'gYear'), isFalse);
    expect(
      tester.widget<FilledButton>(createButton('إنشاء الأيام')).onPressed,
      isNull,
    );
    expect(find.textContaining('أكمل الحقول المطلوبة'), findsOneWidget);
    await enter(tester, 'hijriYear', '14');
    expect(find.text('سنة غير صالحة'), findsNothing);
    // A complete but impossible year marks the year field.
    await enter(tester, 'gYear', '1800');
    expect(find.text('تاريخ غير صالح'), findsOneWidget);
    expect(fieldInError(tester, 'gYear'), isTrue);
    expect(fieldInError(tester, 'gDay'), isFalse);
    // Feb 30 marks the day field.
    await enter(tester, 'gYear', '2026');
    await pick(tester, 'gMonth', 'فبراير');
    await enter(tester, 'gDay', '30');
    expect(fieldInError(tester, 'gDay'), isTrue);
    expect(fieldInError(tester, 'gYear'), isFalse);
  });

  testWidgets('R1-9) Esfand 30 with a 29-day Esfand points at the toggle', (
    tester,
  ) async {
    await pumpShell(tester, blank());
    await fillReference(tester);
    await pick(tester, 'sMonth', 'اسفند');
    await enter(tester, 'sDay', '30');
    expect(
      find.text('يوم 30 في إسفند يتطلب تفعيل «طول إسفند»'),
      findsOneWidget,
    );
    expect(find.text('تاريخ غير صالح'), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('esfand-30')));
    expect(find.text('يوم 30 في إسفند يتطلب تفعيل «طول إسفند»'), findsNothing);
    expect(
      tester.widget<FilledButton>(createButton('إنشاء الأيام')).onPressed,
      isNotNull,
    );
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('R1-11) weekday chips are balanced (scale $scale)', (
      tester,
    ) async {
      await pumpShell(tester, blank(), textScale: scale);
      final rows = <double, int>{};
      for (final e in find.byType(ChoiceChip).evaluate()) {
        final top = tester.getTopLeft(find.byWidget(e.widget)).dy;
        rows[top] = (rows[top] ?? 0) + 1;
      }
      final counts = rows.values.toList()..sort((a, b) => b - a);
      expect(counts, anyOf(equals([7]), equals([4, 3])));
      expect(tester.takeException(), isNull);
    });
  }

  // ------------------------------------------------------------------
  // Fix round 2: re-prefill only when the rows' derived start changes
  // ------------------------------------------------------------------

  bool chipSelected(WidgetTester tester, String day) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, day)).selected;

  MonthPoster withNote(MonthPoster p, int i, String note) => p.copyWith(
    days: [
      for (var k = 0; k < p.days.length; k++)
        k == i ? p.days[k].copyWith(note: note) : p.days[k],
    ],
  );

  testWidgets('R2-a) unapplied weekday edit survives 29 -> 30', (tester) async {
    final c = await pumpShell(
      tester,
      withNote(generated(dayCount: 29), 3, 'ن'),
    );
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الجمعة'));
    await tapVisible(tester, find.text('30 يوماً'));
    final p = posterOf(c);
    expect(p.days, hasLength(30));
    expect(p.days[3].note, 'ن');
    expect(p.days.first.weekday, Weekday.tuesday);
    expect(chipSelected(tester, 'الجمعة'), isTrue);
  });

  testWidgets('R2-b) unapplied date edit survives 30 -> 29', (tester) async {
    final c = await pumpShell(tester, generated(dayCount: 30));
    await enter(tester, 'sDay', '22');
    await tapVisible(tester, find.text('29 يوماً'));
    expect(posterOf(c).days, hasLength(29));
    expect(fieldText(tester, 'sDay'), '22');
  });

  testWidgets('R2-b2) unapplied edit survives the extend-from-last-row path', (
    tester,
  ) async {
    final base = generated(dayCount: 29);
    final p = base.copyWith(
      days: [
        base.days.first.copyWith(gregorian: const DayCell.number(0)),
        ...base.days.skip(1),
      ],
    );
    final c = await pumpShell(tester, p);
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الجمعة'));
    await tapVisible(tester, find.text('30 يوماً'));
    expect(posterOf(c).days, hasLength(30));
    expect(chipSelected(tester, 'الجمعة'), isTrue);
  });

  testWidgets('R2-c) a note edit elsewhere keeps the unapplied draft', (
    tester,
  ) async {
    final c = await pumpShell(tester, generated(dayCount: 30));
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الجمعة'));
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    c.read(editorProvider.notifier).update((p) => withNote(p, 2, 'ملاحظة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-0')));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, 'الجمعة'), isTrue);
    // And while Step 1 is shown.
    c.read(editorProvider.notifier).update((p) => withNote(p, 4, 'أخرى'));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, 'الجمعة'), isTrue);
  });

  testWidgets('R2-d) undo on another step re-fills the draft on return', (
    tester,
  ) async {
    final c = await pumpShell(tester, blank());
    await fillReference(tester);
    await tapVisible(tester, createButton('إنشاء الأيام'));
    await enter(tester, 'gDay', '14');
    await tapVisible(tester, createButton('تحديث الأيام'));
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days.first.gregorian, const DayCell.number(13));
    await tester.tap(find.byKey(const ValueKey('step-0')));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'gDay'), '13');
    expect(chipSelected(tester, 'الثلاثاء'), isTrue);
  });

  testWidgets('R2-e) an updatedAt-only change does not re-prefill', (
    tester,
  ) async {
    final c = await pumpShell(tester, generated(dayCount: 30));
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'الجمعة'));
    c
        .read(editorProvider.notifier)
        .update((p) => p.copyWith(updatedAt: DateTime(2030)));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, 'الجمعة'), isTrue);
  });

  testWidgets('R2-f) returning to Step 1 re-syncs the Hijri year', (
    tester,
  ) async {
    final c = await pumpShell(tester, generated(dayCount: 30));
    await enter(tester, 'hijriYear', '1449');
    expect(posterOf(c).hijriYear, 1449);
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    expect(posterOf(c).hijriYear, 1448);
    await tester.tap(find.byKey(const ValueKey('step-0')));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'hijriYear'), '1448');
  });

  group('deriveSetup', () {
    test('from the seed rows', () {
      final s = deriveRowsSetup(seedReferenceMonth())!;
      expect(s.firstWeekday, Weekday.tuesday);
      expect(s.gregorianStart, const DateParts(2026, 10, 13));
      expect(s.solarStart, const DateParts(1405, 7, 21));
      expect(s.dayCount, 30);
    });
    test('empty rows or a garbled header -> null', () {
      expect(deriveRowsSetup(blank()), isNull);
      expect(
        deriveRowsSetup(seedReferenceMonth().copyWith(gregorianHeader: 'x')),
        isNull,
      );
    });
  });
}
