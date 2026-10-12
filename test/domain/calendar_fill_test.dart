import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/weekday.dart';

MonthSetup oct2026() => MonthSetup(
    hijriMonthIndex: 4, hijriYear: 1448, firstWeekday: Weekday.tuesday,
    dayCount: 30, gregorianStart: const DateParts(2026, 10, 13),
    solarStart: const DateParts(1405, 7, 21));

void main() {
  test('reference month: Oct 13 2026 start rolls to Nov and Aban', () {
    final f = CalendarFill.generate(oct2026());
    expect(f.days.length, 30);
    expect(f.days[0].weekday, Weekday.tuesday);
    expect(f.days[1].weekday, Weekday.wednesday);
    expect(f.days[0].gregorian.number, 13);
    expect(f.days[18].gregorian.number, 31);      // day 19 = Oct 31
    expect(f.days[19].gregorian.label, 'نوفمبر');   // day 20 = Nov 1 label
    expect(f.days[20].gregorian.number, 2);
    expect(f.days[9].solar.number, 30);           // Mehr has 30 days
    expect(f.days[10].solar.label, 'آبان');
    expect(f.days[11].solar.number, 2);
    expect(f.gregorianHeader, 'أكتوبر\nنوفمبر\n2026');
    expect(f.solarHeader, 'مهر\nآبان\n1405');
  });

  test('year rollover in header and Dec->Jan label', () {
    final f = CalendarFill.generate(MonthSetup(
        hijriMonthIndex: 5, hijriYear: 1446, firstWeekday: Weekday.monday,
        dayCount: 30, gregorianStart: const DateParts(2024, 12, 25),
        solarStart: const DateParts(1403, 10, 5)));
    expect(f.gregorianHeader, 'ديسمبر\nيناير\n2024/2025');
    expect(f.days.any((d) => d.gregorian.label == 'يناير'), isTrue);
  });

  test('Esfand uses solarEsfandLength and rolls the solar year', () {
    final f = CalendarFill.generate(MonthSetup(
        hijriMonthIndex: 8, hijriYear: 1446, firstWeekday: Weekday.saturday,
        dayCount: 30, gregorianStart: const DateParts(2025, 3, 1),
        solarStart: const DateParts(1403, 12, 11), solarEsfandLength: 30));
    expect(f.days.any((d) => d.solar.label == 'فروردين'), isTrue);
    expect(f.solarHeader.endsWith('1403/1404'), isTrue);
  });

  test('resize 29 -> 30 -> 29 keeps data of surviving rows', () {
    final s = oct2026();
    var rows = CalendarFill.generate(MonthSetup(
        hijriMonthIndex: s.hijriMonthIndex, hijriYear: s.hijriYear,
        firstWeekday: s.firstWeekday, dayCount: 29,
        gregorianStart: s.gregorianStart, solarStart: s.solarStart)).days;
    rows[3] = rows[3].copyWith(note: 'حفظ');
    final r30 = CalendarFill.resize(rows, 30, s);
    expect(r30.length, 30);
    expect(r30[3].note, 'حفظ');
    expect(r30[29].hijriDay, 30);
    expect(CalendarFill.resize(r30, 29, s).length, 29);
  });

  group('day helpers', () {
    test('nextGregorianDay handles month length, leap Feb, year rollover', () {
      expect(nextGregorianDay(const DateParts(2026, 10, 13)),
          const DateParts(2026, 10, 14));
      expect(nextGregorianDay(const DateParts(2026, 10, 31)),
          const DateParts(2026, 11, 1));
      expect(nextGregorianDay(const DateParts(2024, 2, 28)),
          const DateParts(2024, 2, 29));
      expect(nextGregorianDay(const DateParts(2025, 2, 28)),
          const DateParts(2025, 3, 1));
      expect(nextGregorianDay(const DateParts(2024, 12, 31)),
          const DateParts(2025, 1, 1));
    });

    test('nextSolarDay handles 31/30/esfand lengths and year rollover', () {
      expect(nextSolarDay(const DateParts(1405, 6, 31)),
          const DateParts(1405, 7, 1));
      expect(nextSolarDay(const DateParts(1405, 6, 30)),
          const DateParts(1405, 6, 31));
      expect(nextSolarDay(const DateParts(1405, 7, 30)),
          const DateParts(1405, 8, 1));
      expect(nextSolarDay(const DateParts(1403, 12, 29)),
          const DateParts(1404, 1, 1));
      expect(nextSolarDay(const DateParts(1403, 12, 29), esfandLength: 30),
          const DateParts(1403, 12, 30));
      expect(nextSolarDay(const DateParts(1403, 12, 30), esfandLength: 30),
          const DateParts(1404, 1, 1));
    });
  });
}
