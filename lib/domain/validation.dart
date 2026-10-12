import 'models.dart';
import 'time_format.dart';

enum IssueKind { missingTime, timeOrder, weekdayBreak, hijriBreak, dayCount }

class PosterIssue {
  final int? dayIndex;
  final IssueKind kind;
  final String messageAr;
  const PosterIssue({
    this.dayIndex,
    required this.kind,
    required this.messageAr,
  });
}

DayField _fieldOf(PrayerSlot s) {
  switch (s) {
    case PrayerSlot.fajr:
      return DayField.fajr;
    case PrayerSlot.shurooq:
      return DayField.shurooq;
    case PrayerSlot.zuhr:
      return DayField.zuhr;
    case PrayerSlot.maghrib:
      return DayField.maghrib;
  }
}

List<PosterIssue> validatePoster(MonthPoster p) {
  final issues = <PosterIssue>[];
  final days = p.days;

  if (days.length != 29 && days.length != 30) {
    issues.add(
      PosterIssue(
        kind: IssueKind.dayCount,
        messageAr: 'عدد الأيام ${days.length} — يجب أن يكون 29 أو 30',
      ),
    );
  }
  if (days.isEmpty) return issues;

  final first = days.first.weekday;
  for (var i = 0; i < days.length; i++) {
    final d = days[i];
    var expected = first;
    for (var k = 0; k < i; k++) {
      expected = expected.next;
    }
    final n = i + 1;
    if (d.weekday != expected) {
      issues.add(
        PosterIssue(
          dayIndex: i,
          kind: IssueKind.weekdayBreak,
          messageAr:
              'اليوم $n: اليوم ${d.weekday.ar} لا يتبع التسلسل (المتوقع ${expected.ar})',
        ),
      );
    }
    if (d.hijriDay != n) {
      issues.add(
        PosterIssue(
          dayIndex: i,
          kind: IssueKind.hijriBreak,
          messageAr:
              'اليوم $n: التاريخ الهجري ${d.hijriDay} لا يطابق ترتيب اليوم',
        ),
      );
    }
    var allPresent = true;
    for (final slot in PrayerSlot.values) {
      if (d.times[slot] == null) {
        allPresent = false;
        if (!d.uncertain.contains(_fieldOf(slot))) {
          issues.add(
            PosterIssue(
              dayIndex: i,
              kind: IssueKind.missingTime,
              messageAr: 'اليوم $n: وقت ${slot.labelAr} غير مُدخَل',
            ),
          );
        }
      }
    }
    if (allPresent) {
      final v = [for (final s in PrayerSlot.values) to24h(s, d.times[s]!)];
      var ok = true;
      for (var k = 1; k < v.length; k++) {
        if (v[k] <= v[k - 1]) ok = false;
      }
      if (!ok) {
        issues.add(
          PosterIssue(
            dayIndex: i,
            kind: IssueKind.timeOrder,
            messageAr:
                'اليوم $n: ترتيب الأوقات غير صحيح (الفجر، الشروق، الظهر، المغرب)',
          ),
        );
      }
    }
  }
  return issues;
}
