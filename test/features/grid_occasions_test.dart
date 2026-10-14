import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/core/arabic_days.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/shia_occasions_lookup.dart';
import 'package:taqweem/domain/weekday.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';

import '../test_helpers/instant_thumbnails.dart';
import '../test_helpers/load_fonts.dart';

MonthPoster withDays(MonthPoster p, DayRow Function(int i, DayRow d) f) =>
    p.copyWith(days: [for (var i = 0; i < p.days.length; i++) f(i, p.days[i])]);

/// Jumada I 1448 (seed) with the notes of days 5, 10, 13, 15 and 2 emptied.
MonthPoster jumada() => withDays(
  seedReferenceMonth(),
  (i, d) => const {1, 4, 9, 12, 14}.contains(i) ? d.copyWith(note: '') : d,
);

List<String> texts(MonthPoster p, int i, {bool onlyVerifiedMains = false}) => [
  for (final o in occasionsFor(
    hijriMonthIndex: p.hijriMonthIndex,
    day: p.days[i].hijriDay,
    daysInMonth: p.days.length,
  ))
    if (!onlyVerifiedMains || (o.verified && !o.isAlternate)) o.noteText,
];

void main() {
  setUpAll(loadAppFonts);
  useInstantThumbnails();

  Future<ProviderContainer> pumpGrid(
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
  Finder occRow(int i) => find.byKey(ValueKey('occasions-$i'));
  Finder chip(int i, int k) => find.byKey(ValueKey('occ-$i-$k'));
  Finder note(int i) => find.byKey(ValueKey('note-$i'));
  final autofill = find.byKey(const ValueKey('autofill-occasions'));

  Future<void> reveal(WidgetTester tester, int i) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('row-$i')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('grid-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey('row-$i')));
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(WidgetTester tester, int i, int k) async {
    await tester.ensureVisible(chip(i, k));
    await tester.pumpAndSettle();
    await tester.tap(chip(i, k));
    await tester.pumpAndSettle();
  }

  Text chipText(WidgetTester tester, int i, int k) => tester.widget<Text>(
    find.descendant(of: chip(i, k), matching: find.byType(Text)).last,
  );

  testWidgets('1) a day with a main and an alternate shows both, styled', (
    tester,
  ) async {
    final p = jumada();
    final expected = texts(p, 14);
    expect(expected, hasLength(2));
    await pumpGrid(tester, p);
    await reveal(tester, 14);
    expect(occRow(14), findsOneWidget);
    expect(
      find.descendant(of: occRow(14), matching: find.text('مناسبات هذا اليوم')),
      findsOneWidget,
    );
    expect(chipText(tester, 14, 0).data, expected[0]);
    expect(chipText(tester, 14, 1).data, expected[1]);
    expect(chipText(tester, 14, 0).style?.fontStyle, isNot(FontStyle.italic));
    expect(chipText(tester, 14, 1).style?.fontStyle, FontStyle.italic);
    expect(find.bySemanticsLabel('مناسبة: ${expected[0]}'), findsOneWidget);
    expect(tester.getSize(chip(14, 0)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(chip(14, 1)).height, greaterThanOrEqualTo(48));
    // Long-press shows the full research note and sources.
    await tester.longPress(chip(14, 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('المصادر:'), findsOneWidget);
    expect(find.textContaining('على رواية الشيخ المفيد'), findsOneWidget);
  });

  testWidgets('2) tap inserts into an empty note, appends with " - "', (
    tester,
  ) async {
    final p = withDays(
      jumada(),
      (i, d) => i == 4 ? d.copyWith(note: 'مولد السيدة زينب(ع)') : d,
    );
    final c = await pumpGrid(tester, p);
    final t4 = texts(p, 4).first;
    await reveal(tester, 4);
    await tapChip(tester, 4, 0);
    expect(posterOf(c).days[4].note, 'مولد السيدة زينب(ع) - $t4');
    c.read(editorProvider.notifier).undo();
    await tester.pumpAndSettle();
    expect(posterOf(c).days[4].note, 'مولد السيدة زينب(ع)');
    expect(c.read(editorProvider).canUndo, isFalse);

    final t9 = texts(p, 9).first;
    await reveal(tester, 9);
    await tapChip(tester, 9, 0);
    expect(posterOf(c).days[9].note, t9);
    expect(c.read(editorProvider).canUndo, isTrue);
    c.read(editorProvider.notifier).undo();
    await tester.pumpAndSettle();
    expect(posterOf(c).days[9].note, '');
    expect(c.read(editorProvider).canUndo, isFalse);
  });

  testWidgets('3) a chip already in the note does nothing', (tester) async {
    final p0 = jumada();
    final t = texts(p0, 9).first;
    final p = withDays(p0, (i, d) => i == 9 ? d.copyWith(note: 'قبل - $t') : d);
    final c = await pumpGrid(tester, p);
    await reveal(tester, 9);
    await tapChip(tester, 9, 0);
    expect(posterOf(c).days[9].note, 'قبل - $t');
    expect(c.read(editorProvider).canUndo, isFalse);
  });

  testWidgets('4) a day without occasions shows no chips row', (tester) async {
    final p = jumada();
    expect(texts(p, 1), isEmpty);
    await pumpGrid(tester, p);
    expect(find.byKey(const ValueKey('row-1')), findsOneWidget);
    expect(occRow(1), findsNothing);
    expect(note(1), findsOneWidget);
  });

  testWidgets('5+8) auto-fill: only empty notes, verified mains, one undo', (
    tester,
  ) async {
    final p = jumada();
    final expected = <int, String>{
      for (var i = 0; i < p.days.length; i++)
        if (p.days[i].note.trim().isEmpty &&
            texts(p, i, onlyVerifiedMains: true).isNotEmpty)
          i: texts(p, i, onlyVerifiedMains: true).join(' - '),
    };
    expect(expected, isNotEmpty);
    expect(
      expected[12],
      'ذكرى استشهاد السيدة فاطمة الزهراء (س)',
      reason: 'day 13: Fatima is now the main (R24)',
    );
    final c = await pumpGrid(tester, p);
    await tester.tap(autofill);
    await tester.pumpAndSettle();
    final n = expected.length;
    expect(
      find.text(
        'سيتم ملء ${arabicDays(n)} بالمناسبات الموثّقة (الأيام التي فيها ملاحظات لن تتغير). متابعة؟',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'المصدر: قاعدة بيانات المناسبات الشيعية المدمجة — تحقق منها قبل الطباعة',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('تعبئة'));
    await tester.pumpAndSettle();
    final after = posterOf(c);
    var changed = 0;
    for (var i = 0; i < p.days.length; i++) {
      final want = expected[i] ?? p.days[i].note;
      expect(after.days[i].note, want, reason: 'day ${i + 1}');
      expect(after.days[i].highlighted, p.days[i].highlighted);
      expect(after.days[i].times, p.days[i].times);
      if (after.days[i].note != p.days[i].note) changed++;
      if (expected.containsKey(i)) {
        for (final o in occasionsFor(
          hijriMonthIndex: 4,
          day: p.days[i].hijriDay,
          daysInMonth: 30,
        ).where((o) => o.isAlternate || !o.verified)) {
          expect(after.days[i].note.contains(o.noteText), isFalse);
        }
      }
    }
    expect(changed, n);
    expect(find.text('تمت تعبئة ${arabicDays(n)}'), findsOneWidget);
    // SnackBar undo reverts everything in one step.
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(
      [for (final d in posterOf(c).days) d.note],
      [for (final d in p.days) d.note],
    );
    expect(c.read(editorProvider).canUndo, isFalse);
  });

  testWidgets('5b) auto-fill cancel changes nothing; nothing to fill', (
    tester,
  ) async {
    final c = await pumpGrid(tester, jumada());
    await tester.tap(autofill);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(c.read(editorProvider).canUndo, isFalse);

    c
        .read(editorProvider.notifier)
        .update((p) => withDays(p, (i, d) => d.copyWith(note: 'ملاحظة')));
    await tester.pumpAndSettle();
    await tester.tap(autofill);
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مناسبات جاهزة للتعبئة'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('5c) a note being typed is committed before auto-fill', (
    tester,
  ) async {
    final c = await pumpGrid(tester, jumada());
    await reveal(tester, 1);
    await tester.enterText(note(1), 'نص يكتب');
    await tester.tap(autofill);
    await tester.pumpAndSettle();
    expect(posterOf(c).days[1].note, 'نص يكتب');
    await tester.tap(find.text('تعبئة'));
    await tester.pumpAndSettle();
    expect(posterOf(c).days[1].note, 'نص يكتب');
  });

  testWidgets('6) 29-day month: day-30 items appear on day 29', (tester) async {
    final f = CalendarFill.generate(
      MonthSetup(
        hijriMonthIndex: 10,
        hijriYear: 1448,
        firstWeekday: Weekday.monday,
        dayCount: 29,
        gregorianStart: const DateParts(2027, 4, 7),
        solarStart: const DateParts(1406, 1, 18),
      ),
    );
    final p = MonthPoster(
      id: 'p-29',
      updatedAt: DateTime(2026, 10, 13),
      hijriMonthIndex: 10,
      hijriYear: 1448,
      days: f.days,
      gregorianHeader: f.gregorianHeader,
      solarHeader: f.solarHeader,
    );
    final t = texts(p, 28);
    expect(t.any((s) => s.contains('الإمام محمد الجواد')), isTrue);
    await pumpGrid(tester, p);
    await reveal(tester, 28);
    expect(
      find.descendant(
        of: occRow(28),
        matching: find.textContaining('الإمام محمد الجواد'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('6b) an unverified entry is marked and its tooltip says so', (
    tester,
  ) async {
    final f = CalendarFill.generate(
      MonthSetup(
        hijriMonthIndex: 9,
        hijriYear: 1448,
        firstWeekday: Weekday.monday,
        dayCount: 30,
        gregorianStart: const DateParts(2027, 3, 8),
        solarStart: const DateParts(1405, 12, 17),
      ),
    );
    final p = MonthPoster(
      id: 'p-shawwal',
      updatedAt: DateTime(2026, 10, 13),
      hijriMonthIndex: 9,
      hijriYear: 1448,
      days: f.days,
    );
    // First day of the month with an unverified entry, from the data.
    final day = [
      for (var i = 0; i < 30; i++)
        if (occasionsFor(
          hijriMonthIndex: 9,
          day: i + 1,
          daysInMonth: 30,
        ).any((o) => !o.verified))
          i,
    ].first;
    final k = occasionsFor(
      hijriMonthIndex: 9,
      day: day + 1,
      daysInMonth: 30,
    ).indexWhere((o) => !o.verified);
    await pumpGrid(tester, p);
    await reveal(tester, day);
    expect(
      find.descendant(of: chip(day, k), matching: find.text('للتحقق')),
      findsOneWidget,
    );
    await tester.longPress(chip(day, k));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('يحتاج تأكيداً من حقيبة المؤمن'),
      findsOneWidget,
    );
  });

  testWidgets('7) text scale 1.3: chips and tools bar do not overflow', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpGrid(tester, jumada(), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(autofill).height, greaterThanOrEqualTo(48));
    await reveal(tester, 14);
    expect(tester.takeException(), isNull);
    for (final k in [0, 1]) {
      final r = tester.getRect(chip(14, k));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(390));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
