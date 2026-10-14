import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/occasions_library.dart';
import 'package:taqweem/domain/time_format.dart';
import 'package:taqweem/domain/weekday.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/editor/invalid_times.dart';
import 'package:taqweem/features/editor/step_grid.dart';
import 'package:taqweem/features/editor/time_cell.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';

import '../test_helpers/instant_thumbnails.dart';
import '../test_helpers/load_fonts.dart';

MonthPoster blank() => MonthPoster(
  id: 'poster-grid',
  updatedAt: DateTime(2026, 10, 13),
  hijriMonthIndex: 4,
  hijriYear: 1448,
);

/// 30 generated rows (no times / notes).
MonthPoster generated() {
  final f = CalendarFill.generate(
    MonthSetup(
      hijriMonthIndex: 4,
      hijriYear: 1448,
      firstWeekday: Weekday.tuesday,
      dayCount: 30,
      gregorianStart: const DateParts(2026, 10, 13),
      solarStart: const DateParts(1405, 7, 21),
    ),
  );
  return blank().copyWith(
    days: f.days,
    gregorianHeader: f.gregorianHeader,
    solarHeader: f.solarHeader,
  );
}

MonthPoster withDays(MonthPoster p, DayRow Function(int i, DayRow d) f) =>
    p.copyWith(days: [for (var i = 0; i < p.days.length; i++) f(i, p.days[i])]);

void main() {
  setUpAll(loadAppFonts);
  useInstantThumbnails();

  /// Opens [poster] in the editor shell and goes to Step 2.
  Future<ProviderContainer> pumpGrid(
    WidgetTester tester,
    MonthPoster poster, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [posterSaverProvider.overrideWithValue((p) async {})],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: EditorShell(initial: poster),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(EditorShell)));
  }

  MonthPoster posterOf(ProviderContainer c) => c.read(editorProvider).poster;

  Finder cell(int row, PrayerSlot s) =>
      find.byKey(ValueKey('time-$row-${s.name}'));
  Finder note(int row) => find.byKey(ValueKey('note-$row'));

  TextField fieldIn(WidgetTester tester, Finder f) => tester.widget<TextField>(
    find.descendant(of: f, matching: find.byType(TextField)),
  );

  bool hasFocus(WidgetTester tester, Finder f) =>
      fieldIn(tester, f).focusNode!.hasFocus;

  Future<void> blur(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('a) typing 418 then leaving the field stores 4:18', (
    tester,
  ) async {
    final c = await pumpGrid(tester, generated());
    await tester.enterText(cell(0, PrayerSlot.fajr), '418');
    await tester.pump();
    // Not committed per keystroke.
    expect(posterOf(c).days[0].times.fajr, isNull);
    await tester.tap(cell(0, PrayerSlot.shurooq));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.fajr, 258);
    expect(fieldIn(tester, cell(0, PrayerSlot.fajr)).controller!.text, '4:18');
  });

  testWidgets('b) 4:75 shows وقت غير صالح and leaves the state', (
    tester,
  ) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    final before = posterOf(c).days[0].times.fajr;
    await tester.enterText(cell(0, PrayerSlot.fajr), '4:75');
    await blur(tester);
    expect(find.text('وقت غير صالح'), findsOneWidget);
    expect(posterOf(c).days[0].times.fajr, before);
    expect(c.read(editorProvider).canUndo, isFalse);
    // Typed text is kept so it can be fixed.
    expect(fieldIn(tester, cell(0, PrayerSlot.fajr)).controller!.text, '4:75');
  });

  testWidgets('c) column shift +2 on fajr, one undo reverts all', (
    tester,
  ) async {
    final seed = withDays(
      seedReferenceMonth(),
      (i, d) => i == 4
          ? d.copyWith(times: d.times.withSlot(PrayerSlot.fajr, null))
          : d,
    );
    final c = await pumpGrid(tester, seed);
    final before = [for (final d in posterOf(c).days) d.times.fajr];
    final shurooqBefore = [for (final d in posterOf(c).days) d.times.shurooq];
    await tester.tap(find.text('إزاحة عمود'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shift-slot-fajr')));
    await tester.tap(find.byKey(const ValueKey('shift-plus')));
    await tester.pump();
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();
    final after = posterOf(c).days;
    for (var i = 0; i < after.length; i++) {
      expect(
        after[i].times.fajr,
        before[i] == null ? isNull : before[i]! + 2,
        reason: 'row $i',
      );
      expect(after[i].times.shurooq, shurooqBefore[i]);
    }
    expect(find.text('تم إزاحة الفجر بمقدار 2 دقيقة'), findsOneWidget);
    c.read(editorProvider.notifier).undo();
    await tester.pumpAndSettle();
    expect([for (final d in posterOf(c).days) d.times.fajr], before);
    expect(c.read(editorProvider).canUndo, isFalse);
  });

  testWidgets('c2) the snackbar تراجع undoes the shift', (tester) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    final before = [for (final d in posterOf(c).days) d.times.zuhr];
    await tester.tap(find.text('إزاحة عمود'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shift-slot-zuhr')));
    await tester.tap(find.byKey(const ValueKey('shift-minus')));
    await tester.pump();
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.zuhr, before[0]! - 1);
    expect(
      find.text('تم إزاحة الظهر بمقدار ${signedMinutes(-1)} دقيقة'),
      findsOneWidget,
    );
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect([for (final d in posterOf(c).days) d.times.zuhr], before);
  });

  testWidgets('d) honorific button inserts (ع) at the caret', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.enterText(note(0), 'علي');
    await tester.pump();
    final ctl = fieldIn(tester, note(0)).controller!;
    ctl.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    expect(find.byKey(const ValueKey('honorific-bar')), findsOneWidget);
    await tester.tap(find.text('(ع)'));
    await tester.pump();
    expect(ctl.text, 'ع(ع)لي');
    expect(ctl.selection.baseOffset, 4);
    expect(hasFocus(tester, note(0)), isTrue);
    await blur(tester);
    expect(posterOf(c).days[0].note, 'ع(ع)لي');
    expect(find.byKey(const ValueKey('honorific-bar')), findsNothing);
  });

  testWidgets('e) occasion suggestion tap fills the note', (tester) async {
    final c = await pumpGrid(tester, generated());
    // The built-in Shia database comes first while typing.
    await tester.enterText(note(0), 'الزهراء');
    await tester.pump();
    expect(find.text(searchNoteSuggestions('الزهراء').first), findsOneWidget);
    // The cleaned library still follows for its own wording.
    await tester.enterText(note(0), 'نساء العالمين');
    await tester.pump();
    const s = 'ذكرى استشهاد سيدة نساء العالمين فاطمة الزهراء(ع)11هـ';
    expect(find.text(s), findsOneWidget);
    await tester.tap(find.text(s));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].note, s);
    expect(fieldIn(tester, note(0)).controller!.text, s);
  });

  testWidgets('Arabic-Indic digits are accepted', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.enterText(cell(2, PrayerSlot.maghrib), '٥:٠٦');
    await blur(tester);
    expect(posterOf(c).days[2].times.maghrib, 5 * 60 + 6);
    await tester.enterText(cell(2, PrayerSlot.zuhr), '١١٢٣');
    await blur(tester);
    expect(posterOf(c).days[2].times.zuhr, 11 * 60 + 23);
  });

  testWidgets('an empty commit clears the slot (one undo entry)', (
    tester,
  ) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    final before = posterOf(c).days[1].times.shurooq;
    expect(before, isNotNull);
    await tester.enterText(cell(1, PrayerSlot.shurooq), '');
    await blur(tester);
    expect(posterOf(c).days[1].times.shurooq, isNull);
    c.read(editorProvider.notifier).undo();
    await tester.pumpAndSettle();
    expect(posterOf(c).days[1].times.shurooq, before);
    expect(c.read(editorProvider).canUndo, isFalse);
    expect(
      fieldIn(tester, cell(1, PrayerSlot.shurooq)).controller!.text,
      formatTime(before),
    );
  });

  testWidgets('نسخ اليوم السابق copies the four times only', (tester) async {
    final base = withDays(
      generated(),
      (i, d) => i == 0
          ? d.copyWith(
              times: const PrayerTimes(
                fajr: 258,
                shurooq: 340,
                zuhr: 683,
                maghrib: 316,
              ),
              note: 'ملاحظة',
            )
          : d,
    );
    final c = await pumpGrid(tester, base);
    expect(find.byKey(const ValueKey('copy-prev-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('copy-prev-1')));
    await tester.pumpAndSettle();
    final p = posterOf(c);
    expect(p.days[1].times, p.days[0].times);
    expect(p.days[1].note, '');
    expect(fieldIn(tester, cell(1, PrayerSlot.zuhr)).controller!.text, '11:23');
  });

  testWidgets('مناسبة مهمة toggles highlighted', (tester) async {
    final c = await pumpGrid(tester, generated());
    expect(find.text('مناسبة مهمة'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('highlight-0')));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].highlighted, isTrue);
    await tester.tap(find.byKey(const ValueKey('highlight-0')));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].highlighted, isFalse);
  });

  testWidgets('long-press → تحديد كغير مؤكد shows a marker', (tester) async {
    final c = await pumpGrid(tester, generated());
    final marker = find.byKey(const ValueKey('uncertain-0-fajr'));
    expect(marker, findsNothing);
    await tester.longPress(cell(0, PrayerSlot.fajr));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحديد كغير مؤكد'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].uncertain, contains(DayField.fajr));
    expect(marker, findsOneWidget);
    // And back.
    await tester.longPress(cell(0, PrayerSlot.fajr));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء التحديد'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].uncertain, isNot(contains(DayField.fajr)));
    expect(marker, findsNothing);
  });

  testWidgets('the row menu toggles the note as uncertain', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.tap(find.byKey(const ValueKey('row-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المناسبة: تحديد كغير مؤكد'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].uncertain, contains(DayField.note));
    expect(find.byKey(const ValueKey('uncertain-0-note')), findsOneWidget);
  });

  testWidgets('a clean poster shows كل شيء سليم', (tester) async {
    await pumpGrid(tester, seedReferenceMonth());
    expect(find.text('كل شيء سليم'), findsOneWidget);
  });

  testWidgets('validation chip counts issues; the sheet jumps to the day', (
    tester,
  ) async {
    final seed = withDays(
      seedReferenceMonth(),
      (i, d) => i == 5 || i == 12 || i == 20
          ? d.copyWith(times: d.times.withSlot(PrayerSlot.fajr, null))
          : d,
    );
    await pumpGrid(tester, seed);
    expect(find.text('3 تنبيهات'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-issue-0')), findsNothing);
    await tester.tap(find.text('3 تنبيهات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اليوم 21: وقت الفجر غير مُدخَل'));
    await tester.pumpAndSettle();
    expect(cell(20, PrayerSlot.fajr), findsOneWidget);
    expect(hasFocus(tester, cell(20, PrayerSlot.fajr)), isTrue);
    final r = tester.getRect(cell(20, PrayerSlot.fajr));
    expect(r.top, greaterThan(0));
    expect(r.bottom, lessThan(844));
    expect(find.byKey(const ValueKey('row-issue-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-issue-19')), findsNothing);
  });

  testWidgets('next moves along the row, then to the next day fajr', (
    tester,
  ) async {
    await pumpGrid(tester, generated(), size: const Size(390, 2400));
    await tester.tap(cell(0, PrayerSlot.fajr));
    await tester.pumpAndSettle();
    final order = [
      cell(0, PrayerSlot.shurooq),
      cell(0, PrayerSlot.zuhr),
      cell(0, PrayerSlot.maghrib),
      cell(1, PrayerSlot.fajr),
      cell(1, PrayerSlot.shurooq),
    ];
    for (final next in order) {
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, next), isTrue);
    }
  });

  testWidgets('next from a typed time commits it and moves on', (tester) async {
    final c = await pumpGrid(tester, generated(), size: const Size(390, 2400));
    await tester.enterText(cell(0, PrayerSlot.maghrib), '506');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.maghrib, 306);
    expect(hasFocus(tester, cell(1, PrayerSlot.fajr)), isTrue);
  });

  testWidgets('rows are lazy on a phone', (tester) async {
    await pumpGrid(tester, seedReferenceMonth());
    final n = find.byType(TimeCell).evaluate().length;
    expect(n, greaterThan(0));
    expect(n, lessThan(30));
  });

  testWidgets('wide screens show a table with a header row', (tester) async {
    await pumpGrid(tester, seedReferenceMonth(), size: const Size(1200, 800));
    final header = find.byKey(const ValueKey('grid-table-header'));
    expect(header, findsOneWidget);
    for (final t in [
      'اليوم',
      'هجري',
      'ميلادي',
      'شمسي',
      'الفجر',
      'الشروق',
      'الظهر',
      'المغرب',
      'المناسبة',
    ]) {
      expect(
        find.descendant(of: header, matching: find.text(t)),
        findsOneWidget,
      );
    }
    expect(cell(0, PrayerSlot.fajr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty poster: الذهاب إلى الشهر goes to step 0', (tester) async {
    await pumpGrid(tester, blank());
    expect(find.text('لا توجد أيام بعد'), findsOneWidget);
    await tester.tap(find.text('الذهاب إلى الشهر'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أيام بعد'), findsNothing);
    expect(find.text('إنشاء الأيام'), findsWidgets);
  });

  testWidgets('text scale 1.3 on 390x844 does not overflow', (tester) async {
    await pumpGrid(tester, seedReferenceMonth(), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const ValueKey('grid-list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('إزاحة عمود'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing day 3 does not rebuild day 4', (tester) async {
    final c = await pumpGrid(
      tester,
      seedReferenceMonth(),
      size: const Size(390, 2400),
    );
    debugGridRowBuilds.clear();
    c
        .read(editorProvider.notifier)
        .update(
          (p) => withDays(p, (i, d) => i == 2 ? d.copyWith(note: 'جديد') : d),
        );
    await tester.pumpAndSettle();
    expect(debugGridRowBuilds[2], greaterThanOrEqualTo(1));
    // Row 3 exists (is built), it just was not rebuilt.
    expect(find.byKey(const ValueKey('row-3')), findsOneWidget);
    expect(debugGridRowBuilds[3], isNull);
    expect(debugGridRowBuilds[0], isNull);
  });

  testWidgets('tapping a date chip overrides it', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.tap(find.byKey(const ValueKey('date-0-gregorian')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('date-dialog-field')),
      '14',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].gregorian, const DayCell.number(14));
    await tester.tap(find.byKey(const ValueKey('date-0-solar')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('date-dialog-field')),
      'آبان',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].solar, const DayCell.label('آبان'));
  });

  testWidgets('leaving the step with a typed time keeps it', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.enterText(cell(0, PrayerSlot.zuhr), '1123');
    await tester.enterText(note(0), 'ملاحظة');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.zuhr, 11 * 60 + 23);
    expect(posterOf(c).days[0].note, 'ملاحظة');
  });

  // -------------------------------------------------------------------------
  // Fix round 1
  // -------------------------------------------------------------------------

  Future<void> openIssues(WidgetTester tester) async {
    await tester.tap(
      find
          .byWidgetPredicate((w) => w is ActionChip && w.onPressed != null)
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('I1 invalid text survives scrolling the card away and back', (
    tester,
  ) async {
    await pumpGrid(tester, seedReferenceMonth());
    await tester.enterText(cell(0, PrayerSlot.fajr), '4:75');
    await blur(tester);
    final list = find.byKey(const ValueKey('grid-list'));
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(cell(0, PrayerSlot.fajr), findsNothing);
    await tester.drag(list, const Offset(0, 4000));
    await tester.pumpAndSettle();
    expect(fieldIn(tester, cell(0, PrayerSlot.fajr)).controller!.text, '4:75');
    expect(find.text('وقت غير صالح'), findsOneWidget);
  });

  testWidgets('I1 leaving the step with an invalid time shows a SnackBar', (
    tester,
  ) async {
    await pumpGrid(tester, seedReferenceMonth());
    await tester.enterText(cell(0, PrayerSlot.fajr), '4:75');
    // No blur: leaving the step commits (and records) first.
    await tester.tap(find.text('التالي').last);
    await tester.pumpAndSettle();
    expect(
      find.text('تم تجاهل أوقات غير صالحة (1) — راجعها في الأيام'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    expect(find.text('تنبيه واحد'), findsOneWidget);
    expect(fieldIn(tester, cell(0, PrayerSlot.fajr)).controller!.text, '4:75');
    expect(find.text('وقت غير صالح'), findsOneWidget);
  });

  testWidgets('I1 invalid entries are listed; fixing one drops the count', (
    tester,
  ) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    expect(find.text('كل شيء سليم'), findsOneWidget);
    await tester.enterText(cell(0, PrayerSlot.zuhr), '99');
    await blur(tester);
    expect(find.text('تنبيه واحد'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-issue-0')), findsOneWidget);
    await openIssues(tester);
    expect(find.text('اليوم 1: وقت الظهر غير صالح'), findsOneWidget);
    // M2: the chevron points toward the end of the line in RTL.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.text('اليوم 1: وقت الظهر غير صالح'));
    await tester.pumpAndSettle();
    expect(hasFocus(tester, cell(0, PrayerSlot.zuhr)), isTrue);
    await tester.enterText(cell(0, PrayerSlot.zuhr), '11:30');
    await blur(tester);
    expect(posterOf(c).days[0].times.zuhr, 11 * 60 + 30);
    expect(find.text('كل شيء سليم'), findsOneWidget);
    // Clearing an invalid cell removes the entry too (now it is missing).
    await tester.enterText(cell(0, PrayerSlot.zuhr), '0');
    await blur(tester);
    expect(find.text('تنبيه واحد'), findsOneWidget);
    await tester.enterText(cell(0, PrayerSlot.zuhr), '');
    await blur(tester);
    await openIssues(tester);
    expect(find.text('اليوم 1: وقت الظهر غير صالح'), findsNothing);
    expect(find.text('اليوم 1: وقت الظهر غير مُدخَل'), findsOneWidget);
  });

  testWidgets('I2 undo with an uncommitted edit commits it first', (
    tester,
  ) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    await tester.tap(find.byKey(const ValueKey('highlight-1')));
    await tester.pumpAndSettle();
    await tester.enterText(cell(0, PrayerSlot.fajr), '430');
    await tester.pump();
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    // The typed edit was committed, then undone: back to 4:18.
    expect(posterOf(c).days[0].times.fajr, 258);
    expect(posterOf(c).days[1].highlighted, isTrue);
    expect(fieldIn(tester, cell(0, PrayerSlot.fajr)).controller!.text, '4:18');
    await tester.tap(find.byTooltip('إعادة'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.fajr, 270);
  });

  testWidgets('I2/M9 popping the editor flushes an uncommitted edit', (
    tester,
  ) async {
    final saved = <MonthPoster>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posterSaverProvider.overrideWithValue((p) async => saved.add(p)),
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
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditorShell(initial: generated()),
                  ),
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    await tester.enterText(cell(0, PrayerSlot.fajr), '418');
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell), findsNothing);
    expect(saved, isNotEmpty);
    expect(saved.last.days[0].times.fajr, 258);
  });

  testWidgets('I3 keyboard accessory: الحقل التالي advances, تم commits', (
    tester,
  ) async {
    final c = await pumpGrid(tester, generated());
    final bar = find.byKey(const ValueKey('time-accessory'));
    expect(bar, findsNothing);
    await tester.tap(cell(0, PrayerSlot.fajr));
    await tester.pumpAndSettle();
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('الفجر – اليوم 1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('accessory-next')));
    await tester.pumpAndSettle();
    expect(hasFocus(tester, cell(0, PrayerSlot.shurooq)), isTrue);
    await tester.enterText(cell(0, PrayerSlot.shurooq), '540');
    await tester.tap(find.byKey(const ValueKey('accessory-done')));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.shurooq, 340);
    expect(hasFocus(tester, cell(0, PrayerSlot.shurooq)), isFalse);
    expect(bar, findsNothing);
    // Notes get the honorific bar, not the accessory.
    await tester.tap(note(0));
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    expect(find.byKey(const ValueKey('honorific-bar')), findsOneWidget);
  });

  testWidgets('N1 an outside value change resolves a recorded invalid entry', (
    tester,
  ) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    await tester.enterText(cell(0, PrayerSlot.fajr), '4:75');
    await blur(tester);
    expect(find.text('وقت غير صالح'), findsOneWidget);
    await tester.tap(cell(0, PrayerSlot.fajr));
    await tester.pump();
    await tester.enterText(cell(0, PrayerSlot.fajr), '4:3');
    await tester.pump();
    c
        .read(editorProvider.notifier)
        .update(
          (p) => withDays(
            p,
            (i, d) => i == 0
                ? d.copyWith(times: d.times.withSlot(PrayerSlot.fajr, 300))
                : d,
          ),
        );
    await tester.pumpAndSettle();
    expect(fieldIn(tester, cell(0, PrayerSlot.fajr)).controller!.text, '5:00');
    expect(find.text('وقت غير صالح'), findsNothing);
    expect(c.read(invalidTimesProvider), isEmpty);
    await blur(tester);
    expect(find.text('وقت غير صالح'), findsNothing);
    expect(c.read(invalidTimesProvider), isEmpty);
  });

  testWidgets('I3 tapping outside a time cell commits it', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.enterText(cell(0, PrayerSlot.fajr), '418');
    await tester.pump();
    await tester.tap(find.text('الثلاثاء').first);
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.fajr, 258);
    expect(hasFocus(tester, cell(0, PrayerSlot.fajr)), isFalse);
  });

  testWidgets('M1 the stepper shows +2 as one isolated LTR run', (
    tester,
  ) async {
    await pumpGrid(tester, seedReferenceMonth());
    await tester.tap(find.text('إزاحة عمود'));
    await tester.pumpAndSettle();
    expect(find.text('\u2066+1\u2069 دقيقة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shift-plus')));
    await tester.pump();
    expect(find.text('\u2066+2\u2069 دقيقة'), findsOneWidget);
    expect(signedMinutes(2, plus: true), '\u2066+2\u2069');
    expect(signedMinutes(-3), '\u2066-3\u2069');
    expect(signedMinutes(2), '2');
  });

  testWidgets('M3 jumping to a missing time focuses that slot', (tester) async {
    const missing = {
      8: PrayerSlot.shurooq,
      14: PrayerSlot.zuhr,
      22: PrayerSlot.maghrib,
      27: PrayerSlot.fajr,
    };
    final seed = withDays(
      seedReferenceMonth(),
      (i, d) => missing.containsKey(i)
          ? d.copyWith(times: d.times.withSlot(missing[i]!, null))
          : d,
    );
    await pumpGrid(tester, seed);
    for (final e in missing.entries) {
      await openIssues(tester);
      await tester.tap(
        find.text('اليوم ${e.key + 1}: وقت ${e.value.labelAr} غير مُدخَل'),
      );
      await tester.pumpAndSettle();
      expect(hasFocus(tester, cell(e.key, e.value)), isTrue, reason: '$e');
      await blur(tester);
    }
  });

  testWidgets('M4 the error line does not change the card height', (
    tester,
  ) async {
    await pumpGrid(tester, seedReferenceMonth());
    final row = find.byKey(const ValueKey('row-0'));
    final before = tester.getSize(row);
    await tester.enterText(cell(0, PrayerSlot.fajr), '4:75');
    await blur(tester);
    expect(find.text('وقت غير صالح'), findsOneWidget);
    expect(tester.getSize(row), before);
  });

  testWidgets('M6/M9 next into an unbuilt row; spent pending is cleared', (
    tester,
  ) async {
    final c = await pumpGrid(tester, generated(), size: const Size(390, 600));
    // "Built" includes rows in the cache area (offstage for finders).
    Finder built(int r, PrayerSlot s) =>
        find.byKey(ValueKey('time-$r-${s.name}'), skipOffstage: false);
    FocusNode nodeOf(int r, PrayerSlot s) {
      TextField? tf;
      void visit(Element e) {
        final w = e.widget;
        if (w is TextField) {
          tf = w;
        } else {
          e.visitChildren(visit);
        }
      }

      tester.element(built(r, s)).visitChildren(visit);
      return tf!.focusNode!;
    }

    int lastBuilt() {
      var k = 0;
      while (built(k + 1, PrayerSlot.fajr).evaluate().isNotEmpty) {
        k++;
      }
      return k;
    }

    final grid = tester.element(find.byType(StepGrid));

    /// Focuses the last built row's maghrib without letting the list scroll
    /// and presses "next"; returns that row.
    Future<int> nextFromLastBuilt() async {
      final b = lastBuilt();
      nodeOf(b, PrayerSlot.maghrib).requestFocus();
      await tester.pump(Duration.zero);
      expect(built(b + 1, PrayerSlot.fajr), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      expect(debugGridPendingFocus(grid), (b + 1, PrayerSlot.fajr));
      return b;
    }

    // M9: the next row is built on demand and focused.
    var b = await nextFromLastBuilt();
    expect(b, lessThan(28));
    await tester.pumpAndSettle();
    expect(nodeOf(b + 1, PrayerSlot.fajr).hasFocus, isTrue);
    expect(debugGridPendingFocus(grid), isNull);

    // M6: the target row disappears before it can be built; the spent
    // pending focus is dropped, so the row does not grab the focus later.
    b = await nextFromLastBuilt();
    c
        .read(editorProvider.notifier)
        .update((p) => p.copyWith(days: p.days.sublist(0, b + 1)));
    for (var n = 0; n < 12; n++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(debugGridPendingFocus(grid), isNull);
    c.read(editorProvider.notifier).undo();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('grid-list')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(built(b + 1, PrayerSlot.fajr), findsOneWidget);
    expect(nodeOf(b + 1, PrayerSlot.fajr).hasFocus, isFalse);
  });

  testWidgets('M7 newlines in a note become single spaces', (tester) async {
    final c = await pumpGrid(tester, generated());
    await tester.enterText(note(0), 'سطر أول\n\nسطر ثانٍ');
    await blur(tester);
    expect(posterOf(c).days[0].note, 'سطر أول سطر ثانٍ');
  });

  testWidgets('M8 focusing a note with stray spaces adds no undo step', (
    tester,
  ) async {
    final seed = withDays(
      generated(),
      (i, d) => i == 0 ? d.copyWith(note: ' مناسبة  ') : d,
    );
    final c = await pumpGrid(tester, seed);
    await tester.tap(note(0));
    await tester.pumpAndSettle();
    await blur(tester);
    expect(c.read(editorProvider).canUndo, isFalse);
    expect(posterOf(c).days[0].note, ' مناسبة  ');
  });

  testWidgets('M9 done on day 30 maghrib unfocuses', (tester) async {
    final c = await pumpGrid(tester, generated());
    final f = find.byKey(const ValueKey('grid-list'));
    // Rows carry occasion chips: one fling may stop short of the end.
    for (
      var k = 0;
      k < 4 && cell(29, PrayerSlot.maghrib).evaluate().isEmpty;
      k++
    ) {
      await tester.drag(f, const Offset(0, -20000));
      await tester.pumpAndSettle();
    }
    await tester.enterText(cell(29, PrayerSlot.maghrib), '505');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(posterOf(c).days[29].times.maghrib, 305);
    expect(hasFocus(tester, cell(29, PrayerSlot.maghrib)), isFalse);
  });

  testWidgets('M9 blurring an unchanged valid cell adds no undo step', (
    tester,
  ) async {
    final c = await pumpGrid(tester, seedReferenceMonth());
    await tester.tap(cell(0, PrayerSlot.fajr));
    await tester.pumpAndSettle();
    await blur(tester);
    expect(c.read(editorProvider).canUndo, isFalse);
    // Retyping the same value is not a change either.
    await tester.enterText(cell(0, PrayerSlot.fajr), '418');
    await blur(tester);
    expect(c.read(editorProvider).canUndo, isFalse);
  });

  testWidgets('M9 honorific replaces a selection', (tester) async {
    await pumpGrid(tester, generated());
    await tester.enterText(note(0), 'علي xx');
    await tester.pump();
    final ctl = fieldIn(tester, note(0)).controller!;
    ctl.selection = const TextSelection(baseOffset: 4, extentOffset: 6);
    await tester.pump();
    await tester.tap(find.text('(ع)'));
    await tester.pump();
    expect(ctl.text, 'علي (ع)');
    expect(ctl.selection, const TextSelection.collapsed(offset: 7));
  });

  testWidgets('M9 shifting a column keeps uncertain flags', (tester) async {
    final seed = withDays(
      seedReferenceMonth(),
      (i, d) => i == 0 ? d.copyWith(uncertain: {DayField.fajr}) : d,
    );
    final c = await pumpGrid(tester, seed);
    await tester.tap(find.text('إزاحة عمود'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[0].times.fajr, 259);
    expect(posterOf(c).days[0].uncertain, {DayField.fajr});
    expect(find.byKey(const ValueKey('uncertain-0-fajr')), findsOneWidget);
  });

  testWidgets('M12 the shift preview includes a pending edit', (tester) async {
    await pumpGrid(tester, seedReferenceMonth());
    await tester.enterText(cell(0, PrayerSlot.fajr), '500');
    await tester.tap(find.text('إزاحة عمود'));
    await tester.pumpAndSettle();
    expect(find.textContaining('مثال: 5:00 تصبح 5:01'), findsOneWidget);
  });
}
