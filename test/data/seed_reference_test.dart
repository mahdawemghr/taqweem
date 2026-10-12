import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/occasions_library.dart';
import 'package:taqweem/domain/validation.dart';
import 'package:taqweem/domain/weekday.dart';

void main() {
  test('seed month is structurally valid', () {
    final p = seedReferenceMonth();
    expect(p.days.length, 30);
    expect(p.hijriHeader, 'جمادى الأول\n1448');
    expect(p.days.first.weekday.ar, 'الثلاثاء');
    expect(p.days.first.times.fajr, 4 * 60 + 18);
    final hard = validatePoster(p)
        .where((i) => i.kind != IssueKind.missingTime);
    expect(
      hard,
      isEmpty,
    ); // order/weekday/hijri must be right; missing = flagged uncertain
  });

  test('seed month identity, template and date columns', () {
    final p = seedReferenceMonth();
    expect(p.id, 'seed-jumada1-1448');
    expect(p.templateId, 'navy_gold');
    expect(p.updatedAt, DateTime.utc(2026, 10, 12));
    expect(p.hijriMonthIndex, 4);
    expect(p.hijriYear, 1448);
    expect(p.gregorianHeader, 'أكتوبر\nنوفمبر\n2026');
    expect(p.solarHeader, 'مهر\nآبان\n1405');
    expect(p.days[10].solar.label, 'آبان');
    expect(p.days[19].gregorian.label, 'نوفمبر');
    expect(p.days.last.weekday, Weekday.wednesday);
    expect(p.days.last.gregorian.number, 11);
    expect(p.days.last.solar.number, 20);
  });

  test('transcribed rows match the scan (spot checks)', () {
    final d = seedReferenceMonth().days;
    expect(
      d[0].times,
      const PrayerTimes(fajr: 258, shurooq: 335, zuhr: 685, maghrib: 327),
    );
    expect(
      d[29].times,
      const PrayerTimes(fajr: 273, shurooq: 352, zuhr: 683, maghrib: 305),
    );
    expect(d[4].note, 'مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة');
    expect(d[2].note, '');
    expect(d[16].note, '');
    expect(
      [
        for (var i = 0; i < 30; i++)
          if (d[i].highlighted) i,
      ],
      [4, 12, 21],
    );
  });

  test('prayer times follow the monthly trend and nothing is missing', () {
    final d = seedReferenceMonth().days;
    for (var i = 0; i < d.length; i++) {
      final t = d[i].times;
      expect(
        [t.fajr, t.shurooq, t.zuhr, t.maghrib],
        everyElement(isNotNull),
        reason: 'row ${i + 1}',
      );
      if (i > 0) {
        final p = d[i - 1].times;
        expect(t.fajr! >= p.fajr!, isTrue, reason: 'fajr row ${i + 1}');
        expect(
          t.shurooq! >= p.shurooq!,
          isTrue,
          reason: 'shurooq row ${i + 1}',
        );
        expect(
          t.maghrib! <= p.maghrib!,
          isTrue,
          reason: 'maghrib row ${i + 1}',
        );
      }
    }
    expect(validatePoster(seedReferenceMonth()), isEmpty);
  });

  test('doubtful small-print notes are flagged uncertain', () {
    final d = seedReferenceMonth().days;
    final flagged = [
      for (var i = 0; i < 30; i++)
        if (d[i].uncertain.isNotEmpty) i + 1,
    ];
    expect(flagged, [10, 19, 21, 24]);
    for (final n in flagged) {
      expect(d[n - 1].uncertain, {DayField.note});
    }
  });

  test('default texts come from the reference scan', () {
    final t = defaultTexts();
    expect(t.rightQuote.attribution, 'فاطمة الزهراء(س)');
    expect(t.leftQuote.attribution, 'الإمام الكاظم(ع)');
    expect(t.braceQuote, startsWith('إذا عرضتم الإسلام'));
    expect(t.article.body, contains('ضمان ضد الذنوب'));
    expect(t.sideRight.answer, 'نعم هي محكومة بالطهارة.');
    expect(t.sideLeft.question, contains('ذكر الأئمة'));
    expect(t.fatiha, defaultFatiha);
    expect(seedReferenceMonth().texts.article.author, t.article.author);
  });

  test('highlighted rows 5, 13, 22 keep their exact times', () {
    final d = seedReferenceMonth().days;
    expect(
      d[4].times,
      const PrayerTimes(fajr: 260, shurooq: 337, zuhr: 684, maghrib: 323),
    );
    expect(
      d[12].times,
      const PrayerTimes(fajr: 264, shurooq: 341, zuhr: 683, maghrib: 316),
    );
    expect(
      d[21].times,
      const PrayerTimes(fajr: 268, shurooq: 347, zuhr: 682, maghrib: 309),
    );
  });

  test('Arabic text is reproduced exactly as printed in the scan', () {
    final p = seedReferenceMonth();
    expect(p.texts.article.author, 'الشهيد مرتضى مطهرى');
    expect(p.days[6].note, contains('الخميني(ر ض)'));
    expect(p.days[18].note, contains('آيةا...قاضي'));
    expect(p.days[22].note, contains('آيةا... محمد'));
    expect(defaultFooterNotes, contains('ان يعمل على حسب فتوى مرجعه'));
    expect(p.texts.footerNotes, defaultFooterNotes);
  });

  test('search finds occasions by substring', () {
    expect(searchOccasions('الزهراء'), isNotEmpty);
  });

  test(
    'search is capped at 8, empty query gives nothing, suggestions unique',
    () {
      expect(searchOccasions('وفاة').length, 8);
      expect(searchOccasions('   '), isEmpty);
      expect(searchOccasions('لا يوجد شيء كهذا'), isEmpty);
      expect(occasionSuggestions.toSet().length, occasionSuggestions.length);
      for (final n in seedReferenceMonth().days.map((d) => d.note)) {
        if (n.isNotEmpty) expect(occasionSuggestions, contains(n));
      }
    },
  );
}
