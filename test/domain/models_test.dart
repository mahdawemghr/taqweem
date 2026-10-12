import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/time_format.dart';
import 'package:taqweem/domain/weekday.dart';

void main() {
  test('MonthPoster JSON round trip keeps every field', () {
    final p = MonthPoster(
      id: 'a1', updatedAt: DateTime.utc(2026, 10, 12),
      hijriMonthIndex: 4, hijriYear: 1448,
      gregorianHeader: 'أكتوبر\nنوفمبر\n2026', solarHeader: 'مهر\nآبان\n1405',
      days: [
        DayRow(weekday: Weekday.tuesday, hijriDay: 1,
          gregorian: const DayCell.number(13), solar: const DayCell.label('آبان'),
          times: const PrayerTimes(fajr: 258, shurooq: 335, zuhr: 685, maghrib: 327),
          note: 'ملاحظة (ع)', highlighted: true, uncertain: {DayField.note}),
      ],
      texts: PosterTexts.empty(), templateId: 'navy_gold');
    final back = MonthPoster.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    expect(back.days.single.solar.label, 'آبان');
    expect(back.days.single.uncertain, {DayField.note});
    expect(back.hijriHeader, 'جمادى الأول\n1448');
  });

  test('fromJson tolerates missing optional keys', () {
    final p = MonthPoster.fromJson({'id': 'x', 'hijriMonthIndex': 0, 'hijriYear': 1446});
    expect(p.days, isEmpty);
    expect(p.templateId, 'navy_gold');
  });

  test('PrayerTimes.withSlot replaces one slot only', () {
    const t = PrayerTimes(fajr: 1, shurooq: 2, zuhr: 3, maghrib: 4);
    final u = t.withSlot(PrayerSlot.zuhr, 9);
    expect([u.fajr, u.shurooq, u.zuhr, u.maghrib], [1, 2, 9, 4]);
    expect(u[PrayerSlot.zuhr], 9);
  });

  test('withSlot can clear a slot to null', () {
    const t = PrayerTimes(fajr: 1, shurooq: 2, zuhr: 3, maghrib: 4);
    expect(t.withSlot(PrayerSlot.fajr, null).fajr, isNull);
  });

  test('unknown uncertain names are ignored; DayCell variants', () {
    final r = DayRow.fromJson({
      'weekday': 'friday', 'hijriDay': 2,
      'gregorian': {'n': 5}, 'solar': {'l': 'مهر'},
      'uncertain': ['note', 'bogus'],
    });
    expect(r.uncertain, {DayField.note});
    expect(r.gregorian.isLabel, false);
    expect(r.solar.isLabel, true);
    expect(r.times.fajr, isNull);
    expect(r.note, '');
  });

  test('copyWith changes only given fields', () {
    final r = DayRow(weekday: Weekday.monday, hijriDay: 3,
        gregorian: const DayCell.number(1), solar: const DayCell.number(2));
    final c = r.copyWith(highlighted: true, hijriDay: 4);
    expect(c.highlighted, true);
    expect(c.hijriDay, 4);
    expect(c.weekday, Weekday.monday);
    final t = PosterTexts.empty().copyWith(title: 'x');
    expect(t.title, 'x');
    expect(t.fatiha, PosterTexts.empty().fatiha);
  });

  group('robustness', () {
    MonthPoster make(int idx) => MonthPoster(
        id: 'x', updatedAt: DateTime.utc(2026), hijriMonthIndex: idx, hijriYear: 1448);

    test('hijriHeader out-of-range index does not throw', () {
      for (final i in [12, -1, 99]) {
        expect(make(i).hijriHeader, '1448');
      }
      expect(make(11).hijriHeader, 'ذو الحجة\n1448');
    });

    test('fromJson clamps out-of-range month index to 0', () {
      for (final i in [12, -1, 99]) {
        expect(MonthPoster.fromJson({'hijriMonthIndex': i}).hijriMonthIndex, 0);
      }
    });

    test('garbage JSON never throws and yields sane defaults', () {
      final cases = <Map<String, dynamic>>[
        {'days': 'x'},
        {'days': [1]},
        {'days': [null]},
        {'days': [{'uncertain': 'note'}]},
        {'days': [{'uncertain': [1, null, 'note']}]},
        {'texts': 'x'},
        {'texts': {'rightQuote': 'x', 'article': 5, 'title': 3}},
        {'id': 5},
        {'hijriMonthIndex': 'a', 'hijriYear': 'b', 'updatedAt': 5},
        {'templateId': 7, 'gregorianHeader': 1, 'solarHeader': []},
        {'days': [{'gregorian': {'n': '5'}, 'solar': 'x', 'times': 'y', 'weekday': 3, 'note': 4, 'highlighted': 'yes'}]},
        {'days': [{1: 2}]},
      ];
      for (final c in cases) {
        final p = MonthPoster.fromJson(c);
        expect(p.hijriHeader, isNotEmpty);
        expect(MonthPoster.fromJson(p.toJson()).toJson(), p.toJson());
      }
      expect(MonthPoster.fromJson({'days': 'x'}).days, isEmpty);
      expect(MonthPoster.fromJson({'days': [1]}).days, isEmpty);
      expect(MonthPoster.fromJson({'days': [null]}).days, isEmpty);
      expect(MonthPoster.fromJson({'id': 5}).id, '');
      expect(MonthPoster.fromJson({'texts': 'x'}).texts.title, 'تقويم أهل البيت');
      final d = DayRow.fromJson({'uncertain': 'note'});
      expect(d.uncertain, isEmpty);
      expect(DayRow.fromJson({'uncertain': [1, 'note']}).uncertain, {DayField.note});
      expect(DayCell.fromJson({'n': '5'}).number, 0);
    });
  });
}
