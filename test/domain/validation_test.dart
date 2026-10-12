import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/time_format.dart';
import 'package:taqweem/domain/validation.dart';
import 'package:taqweem/domain/weekday.dart';

MonthPoster poster({int count = 30, List<DayRow> Function(List<DayRow>)? tweak}) {
  final filled = CalendarFill.generate(MonthSetup(
    hijriMonthIndex: 0,
    hijriYear: 1447,
    firstWeekday: Weekday.saturday,
    dayCount: count,
    gregorianStart: const DateParts(2025, 7, 1),
    solarStart: const DateParts(1404, 4, 10),
  ));
  final days = [
    for (final d in filled.days)
      d.copyWith(
          times: const PrayerTimes(
              fajr: 4 * 60 + 18, shurooq: 5 * 60 + 35, zuhr: 11 * 60 + 25, maghrib: 5 * 60 + 27)),
  ];
  return MonthPoster(
    id: 't',
    updatedAt: DateTime(2025),
    hijriMonthIndex: 0,
    hijriYear: 1447,
    days: tweak == null ? days : tweak(days),
  );
}

void main() {
  test('valid poster yields no issues', () {
    expect(validatePoster(poster()), isEmpty);
  });

  test('null zuhr gives one missingTime at dayIndex 0', () {
    final p = poster(tweak: (d) {
      d[0] = d[0].copyWith(times: d[0].times.withSlot(PrayerSlot.zuhr, null));
      return d;
    });
    final issues = validatePoster(p);
    expect(issues, hasLength(1));
    expect(issues.single.kind, IssueKind.missingTime);
    expect(issues.single.dayIndex, 0);
  });

  test('uncertain slot suppresses missingTime', () {
    final p = poster(tweak: (d) {
      d[0] = d[0].copyWith(
          times: d[0].times.withSlot(PrayerSlot.zuhr, null),
          uncertain: {DayField.zuhr});
      return d;
    });
    expect(validatePoster(p), isEmpty);
  });

  test('fajr after shurooq gives timeOrder', () {
    final p = poster(tweak: (d) {
      d[3] = d[3].copyWith(
          times: d[3].times
              .withSlot(PrayerSlot.fajr, 6 * 60)
              .withSlot(PrayerSlot.shurooq, 5 * 60));
      return d;
    });
    final issues = validatePoster(p);
    expect(issues, hasLength(1));
    expect(issues.single.kind, IssueKind.timeOrder);
    expect(issues.single.dayIndex, 3);
  });

  test('swapped weekday on row 2 gives weekdayBreak', () {
    final p = poster(tweak: (d) {
      d[2] = d[2].copyWith(weekday: Weekday.friday);
      return d;
    });
    final issues = validatePoster(p);
    expect(issues.where((i) => i.kind == IssueKind.weekdayBreak).single.dayIndex, 2);
  });

  test('hijri day mismatch gives hijriBreak', () {
    final p = poster(tweak: (d) {
      d[4] = d[4].copyWith(hijriDay: 9);
      return d;
    });
    final issues = validatePoster(p);
    expect(issues, hasLength(1));
    expect(issues.single.kind, IssueKind.hijriBreak);
    expect(issues.single.dayIndex, 4);
  });

  test('28 rows gives dayCount issue', () {
    final issues = validatePoster(poster(count: 28));
    expect(issues, hasLength(1));
    expect(issues.single.kind, IssueKind.dayCount);
    expect(issues.single.dayIndex, isNull);
  });

  test('empty days yields exactly one dayCount issue', () {
    final issues = validatePoster(poster(count: 0));
    expect(issues, hasLength(1));
    expect(issues.single.kind, IssueKind.dayCount);
  });
}
