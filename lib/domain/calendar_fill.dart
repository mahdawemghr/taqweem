import 'models.dart';
import 'month_names.dart';
import 'weekday.dart';

class DateParts {
  final int year, month, day;
  const DateParts(this.year, this.month, this.day);

  @override
  bool operator ==(Object other) =>
      other is DateParts &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'DateParts($year, $month, $day)';
}

/// Day after [d] in the Gregorian calendar (month length + year rollover).
DateParts nextGregorianDay(DateParts d) {
  final len = DateTime(d.year, d.month + 1, 0).day;
  if (d.day < len) return DateParts(d.year, d.month, d.day + 1);
  if (d.month == 12) return DateParts(d.year + 1, 1, 1);
  return DateParts(d.year, d.month + 1, 1);
}

int _solarMonthLength(int month, int esfandLength) =>
    month <= 6 ? 31 : (month <= 11 ? 30 : esfandLength);

/// Day after [d] in the solar (Persian) calendar; months 1-6 have 31 days,
/// 7-11 have 30, month 12 has [esfandLength].
DateParts nextSolarDay(DateParts d, {int esfandLength = 29}) {
  if (d.day < _solarMonthLength(d.month, esfandLength)) {
    return DateParts(d.year, d.month, d.day + 1);
  }
  if (d.month == 12) return DateParts(d.year + 1, 1, 1);
  return DateParts(d.year, d.month + 1, 1);
}

class MonthSetup {
  int hijriMonthIndex, hijriYear;
  Weekday firstWeekday;
  int dayCount;
  DateParts gregorianStart, solarStart;
  int solarEsfandLength;

  MonthSetup({
    required this.hijriMonthIndex,
    required this.hijriYear,
    required this.firstWeekday,
    required this.dayCount,
    required this.gregorianStart,
    required this.solarStart,
    this.solarEsfandLength = 29,
  });

  MonthSetup copyWith({int? dayCount}) => MonthSetup(
    hijriMonthIndex: hijriMonthIndex,
    hijriYear: hijriYear,
    firstWeekday: firstWeekday,
    dayCount: dayCount ?? this.dayCount,
    gregorianStart: gregorianStart,
    solarStart: solarStart,
    solarEsfandLength: solarEsfandLength,
  );
}

class FilledMonth {
  final List<DayRow> days;
  final String gregorianHeader, solarHeader;
  const FilledMonth({
    required this.days,
    required this.gregorianHeader,
    required this.solarHeader,
  });
}

class CalendarFill {
  static FilledMonth generate(MonthSetup s) {
    final days = <DayRow>[];
    var g = s.gregorianStart;
    var sol = s.solarStart;
    var wd = s.firstWeekday;
    final gMonths = <String>[gregorianMonthsAr[g.month - 1]];
    final sMonths = <String>[solarMonthsAr[sol.month - 1]];
    var gEndYear = g.year, sEndYear = sol.year;

    for (var i = 0; i < s.dayCount; i++) {
      DayCell gCell, sCell;
      if (i == 0) {
        gCell = DayCell.number(g.day);
        sCell = DayCell.number(sol.day);
      } else {
        wd = wd.next;
        final ng = nextGregorianDay(g);
        if (ng.month != g.month) {
          final name = gregorianMonthsAr[ng.month - 1];
          gMonths.add(name);
          gCell = DayCell.label(name);
        } else {
          gCell = DayCell.number(ng.day);
        }
        g = ng;
        final ns = nextSolarDay(sol, esfandLength: s.solarEsfandLength);
        if (ns.month != sol.month) {
          final name = solarMonthsAr[ns.month - 1];
          sMonths.add(name);
          sCell = DayCell.label(name);
        } else {
          sCell = DayCell.number(ns.day);
        }
        sol = ns;
      }
      gEndYear = g.year;
      sEndYear = sol.year;
      days.add(
        DayRow(weekday: wd, hijriDay: i + 1, gregorian: gCell, solar: sCell),
      );
    }

    String header(List<String> months, int y0, int y1) =>
        '${months.join('\n')}\n${y0 == y1 ? '$y0' : '$y0/$y1'}';

    return FilledMonth(
      days: days,
      gregorianHeader: header(gMonths, s.gregorianStart.year, gEndYear),
      solarHeader: header(sMonths, s.solarStart.year, sEndYear),
    );
  }

  /// Resize keeping existing rows' data; new rows continue weekday/dates.
  static List<DayRow> resize(List<DayRow> rows, int newCount, MonthSetup s) {
    if (newCount <= rows.length) return rows.sublist(0, newCount);
    final gen = generate(s.copyWith(dayCount: newCount)).days;
    return [...rows, ...gen.sublist(rows.length)];
  }
}

/// Date of the day AFTER the last row of a poster, for continuing into the
/// next month. Pure; returns null when the data cannot be interpreted.
///
/// Derivation rules (the stored rows carry no month/year numbers, so they are
/// recovered from the header text):
///  * [header] is `<month names, one per line>\n<year>` or `...\n<y0>/<y1>`.
///    The last row's year is the LAST `/`-separated year; its month is the
///    LAST month name in the header (months are listed chronologically).
///  * If the last row's cell is a label (month-change row) it IS day 1 of the
///    month named by the label, so the next day is day 2 of that month.
///  * If it is a number, the next day is `nextGregorianDay`/`nextSolarDay` of
///    (year, month, number).
DateParts? dayAfterLastRow(
  List<DayRow> days,
  String header, {
  required bool solar,
  int esfandLength = 29,
}) {
  if (days.isEmpty) return null;
  final names = solar ? solarMonthsAr : gregorianMonthsAr;
  final lines = header
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  final year = int.tryParse(lines.last.split('/').last.trim());
  if (year == null) return null;
  final cell = solar ? days.last.solar : days.last.gregorian;
  int monthIdx;
  int day;
  if (cell.isLabel) {
    monthIdx = names.indexOf(cell.label!);
    day = 1;
  } else {
    monthIdx = names.indexOf(lines[lines.length - 2]);
    day = cell.number!;
  }
  if (monthIdx < 0 || day < 1) return null;
  final d = DateParts(year, monthIdx + 1, day);
  return solar
      ? nextSolarDay(d, esfandLength: esfandLength)
      : nextGregorianDay(d);
}
