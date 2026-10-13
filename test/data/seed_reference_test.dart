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
    expect(flagged, [10]);
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
    expect(p.days[24].note, '');
    expect(defaultFooterNotes, contains('ان يعمل على حسب فتوى مرجعه'));
    expect(p.texts.footerNotes, defaultFooterNotes);
  });

  test('search finds occasions by substring', () {
    expect(searchOccasions('الزهراء'), isNotEmpty);
  });

  test(
    'search is capped at 8, empty query gives nothing, suggestions unique',
    () {
      expect(searchOccasions('ال').length, 8);
      expect(searchOccasions('   '), isEmpty);
      expect(searchOccasions('لا يوجد شيء كهذا'), isEmpty);
      expect(occasionSuggestions.toSet().length, occasionSuggestions.length);
      for (final n in seedReferenceMonth().days.map((d) => d.note)) {
        if (n.isNotEmpty) expect(occasionSuggestions, contains(n));
      }
    },
  );

  group('Shia-only cleanup (S4b)', () {
    const removedMarkers = [
      'اصفهاني', 'ميثم', 'الخميني', 'الخونساري', 'الوائلي', 'الفخر الرازي',
      'الطباطبائي', 'الشهيد الأول', 'المسجد الأقصى', 'الهندي', 'ابن شاذان',
      'بهجت', 'محمد تقي القمي', 'النائيني', 'معاوية', 'الحرب العالمية',
      'هيروشيما', 'النسائي', 'الاسترابادي',
    ];
    const keptByIndex = <int, String>{
      1: 'بدأ نزول الوحي على النبي محمد(ص)',
      4: 'مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة',
      5: 'غزوة مؤته8هـ',
      8: 'هدم مسجد رد الشمس لأمير المؤمنين(ع)في المدينة1422هـ',
      9: 'حرب الجمل 36هـ - اعطاء الزهراء القميص لأبنتها حتى تعطيه الحسين(ع)',
      10: 'وفاة النبي شيث(ع)',
      11: 'وفاة عبدا... بن عبدالمطلب والد الرسول الأكرم(ص)',
      12: 'ذكرى استشهاد سيدة نساء العالمين فاطمة الزهراء(ع)11هـ',
      14: 'فتح البصرة على يدالإمام علي بن أبي طالب(ع)',
      15: 'غزوة ذات الرقاع 4هـ',
      17: 'ولادة ذوالقرنين - بدء نزول الألواح على النبي موسى(ع)',
      18: 'مقتل زيد بن صوحان36هـ',
      20: 'استشهاد الصحابي الجليل زيد بن صوحان',
      21: 'وفاة القاسم ابن الامام موسى الكاظم(ع)192هـ',
      25: 'ولادة النبي صالح (ع)',
      26: 'تفجير ماذنتي حرم الامامين الهادي والعسكري1428هـ',
      27: 'وفاة السفير الثاني محمد بن عثمان304هـ',
      28: 'ولادة النبي إسماعيل(ع)',
    };
    const blankIdx = [0, 2, 3, 6, 7, 13, 16, 19, 22, 23, 24, 29];

    test('no seed note or suggestion contains a removed marker', () {
      final all = [
        ...seedReferenceMonth().days.map((d) => d.note),
        ...occasionSuggestions,
      ];
      for (final s in all) {
        for (final m in removedMarkers) {
          expect(s.contains(m), isFalse, reason: '"$m" in "$s"');
        }
      }
    });

    test('kept notes are present verbatim, removed rows are blank', () {
      final d = seedReferenceMonth().days;
      keptByIndex.forEach((i, text) {
        expect(d[i].note, text, reason: 'row ${i + 1}');
        expect(occasionSuggestions, contains(text));
      });
      for (final i in blankIdx) {
        expect(d[i].note, '', reason: 'row ${i + 1}');
        expect(d[i].uncertain, isEmpty, reason: 'row ${i + 1}');
      }
      expect(d[9].uncertain, {DayField.note});
    });

    test('Safar block keeps only Imam / companion lines', () {
      expect(occasionSuggestions, contains(
          'ذكرى استشهاد الإمام المجتبى (ع)50هـ ومولد الإمام الكاظم (ع)128هـ'));
      expect(occasionSuggestions,
          contains('شهادة محمد بن أبي بكر(رض)في مصر38هـ'));
      expect(occasionSuggestions,
          contains('ذكرى استشهاد الإمام علي بن موسى الرضا (ع) 203هـ'));
      expect(occasionSuggestions, contains('شهادة أويس القرني(رض)في صفين'));
    });

    test('highlights unchanged and no hard validation issues', () {
      final p = seedReferenceMonth();
      expect(
        [for (var i = 0; i < 30; i++) if (p.days[i].highlighted) i],
        [4, 12, 21],
      );
      expect(validatePoster(p), isEmpty);
    });
  });
}
