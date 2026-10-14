import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/shia_occasions.dart';
import 'package:taqweem/domain/shia_occasion.dart';

Map<String, dynamic> convention() =>
    jsonDecode(File('docs/shia-occasions/convention.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  const denylist = [
    'معاوية',
    'الحرب العالمية',
    'الخميني',
    'السيستاني',
    'الخوئي',
    'مطهري',
    'بهجت',
    'الصدر',
  ];

  test('non-empty and every month 1..12 has an entry', () {
    expect(shiaOccasions, isNotEmpty);
    for (var m = 1; m <= 12; m++) {
      expect(
        shiaOccasions.where((o) => o.month == m),
        isNotEmpty,
        reason: 'month $m',
      );
    }
  });

  test('field sanity', () {
    for (final o in shiaOccasions) {
      expect(o.month, inInclusiveRange(1, 12));
      expect(o.day, inInclusiveRange(1, 30));
      expect(o.titleAr.trim(), isNotEmpty);
      expect(o.titleAr, o.titleAr.trim());
      expect(o.sourceNames, isNotEmpty, reason: o.titleAr);
      if (o.isAlternate) {
        expect(o.alternateNoteAr?.trim() ?? '', isNotEmpty, reason: o.titleAr);
      }
    }
  });

  test('no duplicate (month, day, title, isAlternate)', () {
    final seen = <String>{};
    for (final o in shiaOccasions) {
      expect(
        seen.add('${o.month}|${o.day}|${o.titleAr}|${o.isAlternate}'),
        isTrue,
        reason: o.titleAr,
      );
    }
  });

  test('no denylisted word in titles', () {
    for (final o in shiaOccasions) {
      for (final w in denylist) {
        // Allowlist: «معاوية» is fine in a «صلح …» (peace-treaty) title.
        if (w == 'معاوية' && o.titleAr.contains('صلح')) continue;
        expect(o.titleAr.contains(w), isFalse, reason: '${o.titleAr} / $w');
      }
    }
  });

  const userCal = 'تقويم أهل البيت (المرجع)';
  const weak = 'العتبة العباسية'; // alkafeel.net

  test('verified = >= 2 families and one that is not the weak alkafeel', () {
    for (final o in shiaOccasions.where((o) => o.verified)) {
      expect(o.sourceNames.length, greaterThanOrEqualTo(2), reason: o.titleAr);
      expect(o.sourceNames.any((n) => n != weak), isTrue, reason: o.titleAr);
    }
    for (final o in shiaOccasions.where((o) => !o.verified)) {
      expect(
        o.sourceNames.length < 2 || o.sourceNames.every((n) => n == weak),
        isTrue,
        reason: o.titleAr,
      );
    }
  });

  test('scan-only entries cite the user calendar and are single-family', () {
    final c = convention();
    final fixes = (c['titleFixes'] as List).cast<Map<String, dynamic>>();
    for (final e in (c['scanOnly'] as List).cast<Map<String, dynamic>>()) {
      var title = e['titleAr'] as String;
      for (final f in fixes) {
        if (f['month'] == e['month'] && f['day'] == e['day']) {
          title = title.replaceFirst(f['from'] as String, f['to'] as String);
        }
      }
      final matches = shiaOccasions.where(
        (o) =>
            o.month == e['month'] &&
            o.day == e['day'] &&
            o.titleAr == title &&
            o.isAlternate == (e['variant'] == 'alternate'),
      );
      expect(matches, hasLength(1), reason: '${e['titleAr']}');
      final o = matches.single;
      expect(o.sourceNames, contains(userCal));
      expect(o.verified, o.sourceNames.length >= 2);
      expect(o.titleAr, o.titleAr.trim());
    }
  });

  test('addSources: the user calendar is a source of every listed entry', () {
    final c = convention();
    for (final a in (c['addSources'] as List).cast<Map<String, dynamic>>()) {
      final hits = shiaOccasions.where(
        (o) =>
            o.month == a['month'] &&
            o.day == a['day'] &&
            o.titleAr.contains(a['titleContains'] as String),
      );
      expect(hits, hasLength(1), reason: '${a['titleContains']}');
      expect(hits.single.sourceNames, contains(userCal));
    }
  });

  test('convention swaps: scan date is main, the old date an alternate', () {
    final c = convention();
    final swaps = (c['swaps'] as List).cast<Map<String, dynamic>>();
    expect(swaps, isNotEmpty);
    ShiaOccasion one(Map<String, dynamic> s) {
      final hits = shiaOccasions.where(
        (o) =>
            o.month == s['month'] &&
            o.day == s['day'] &&
            o.titleAr.contains(s['titleContains'] as String),
      );
      expect(hits, hasLength(1), reason: '$s');
      return hits.single;
    }

    for (final w in swaps) {
      final m = one(w['main'] as Map<String, dynamic>);
      final a = one(w['alternate'] as Map<String, dynamic>);
      expect(m.isAlternate, isFalse, reason: '${w['event']}');
      expect(a.isAlternate, isTrue, reason: '${w['event']}');
      expect(a.alternateNoteAr, startsWith('على'), reason: '${w['event']}');
    }
  });

  test('R24 anchors: scans define the main dates', () {
    ShiaOccasion find(int m, int d, String s) => shiaOccasions.singleWhere(
      (o) => o.month == m && o.day == d && o.titleAr.contains(s),
    );
    // al-Hasan al-Mujtaba: 7 Safar main, 28 Safar alternate.
    expect(find(2, 7, 'الحسن المجتبى').isAlternate, isFalse);
    expect(find(2, 28, 'الحسن المجتبى').isAlternate, isTrue);
    // al-Ridha: 17 Safar main, 30 Safar («آخر صفر») alternate.
    expect(find(2, 17, 'الرضا').isAlternate, isFalse);
    expect(find(2, 30, 'الرضا').titleAr, contains('آخر صفر'));
    expect(find(2, 30, 'الرضا').isAlternate, isTrue);
    // Fatima al-Zahra: 13 Jumada I main; 3 Jumada II and 8 Rabi II alternates.
    expect(find(5, 13, 'فاطمة الزهراء').isAlternate, isFalse);
    expect(find(5, 13, 'فاطمة الزهراء').titleAr, isNot(contains('على')));
    expect(find(6, 3, 'فاطمة الزهراء').isAlternate, isTrue);
    expect(find(4, 8, 'فاطمة الزهراء').isAlternate, isTrue);
    // second deputy: 28 main, 29 alternate.
    expect(find(5, 28, 'محمد بن عثمان').isAlternate, isFalse);
    expect(find(5, 29, 'محمد بن عثمان').isAlternate, isTrue);
    // Abd al-Muttalib: 10 Rabi I main, 27 Jumada I alternate.
    expect(find(3, 10, 'عبدالمطلب').isAlternate, isFalse);
    expect(find(5, 27, 'عبد المطلب').isAlternate, isTrue);
    // the Prophet's birth: 17 main, 12 alternate «على رواية».
    expect(find(3, 17, 'مولد النبي').isAlternate, isFalse);
    final b12 = find(3, 12, 'مولد النبي');
    expect(b12.isAlternate, isTrue);
    expect(b12.alternateNoteAr, 'على رواية');
    // unchanged by ruling: arrival in Medina (B7) and Mab'ath (B8).
    expect(find(3, 12, 'وصول النبي').isAlternate, isFalse);
    expect(
      shiaOccasions.where(
        (o) => o.month == 7 && o.day == 27 && o.titleAr.contains('المبعث'),
      ),
      everyElement(predicate<ShiaOccasion>((o) => !o.isAlternate)),
    );
  });

  test('honorific brackets and the neutral 6 Rajab note (review fixes)', () {
    expect(
      shiaOccasions.any((o) => o.titleAr.contains('(والدي النبي (ص))')),
      isTrue,
    );
    expect(shiaOccasions.any((o) => o.titleAr.contains('(عج))')), isTrue);
    expect(shiaOccasions.any((o) => o.titleAr.contains('النبي ص)')), isFalse);
    final k = shiaOccasions.singleWhere(
      (o) => o.month == 7 && o.day == 6 && o.isAlternate,
    );
    expect(k.alternateNoteAr, 'على قول');
  });

  test("Imam al-Hasan's peace treaty is present (denylist allowlist)", () {
    final t = shiaOccasions.singleWhere(
      (o) => o.month == 3 && o.day == 26 && o.titleAr.contains('صلح'),
    );
    expect(t.titleAr, 'صلح الإمام الحسن(ع)مع معاوية بن أبي سفيان41هـ');
    expect(t.isAlternate, isFalse);
    expect(t.sourceNames, ['تقويم أهل البيت (المرجع)']);
    expect(t.verified, isFalse);
    expect(t.confidence, OccasionConfidence.medium);
  });

  test('Mi\'raj alternate prints clean, attribution only in the tooltip', () {
    final m = shiaOccasions.singleWhere(
      (o) => o.month == 3 && o.day == 16 && o.isAlternate,
    );
    expect(m.noteText, 'عروج النبي(ص)الى السماء على رواية');
    expect(m.noteText, isNot(contains('برواية')));
    expect(m.fullNoteAr, 'على رواية ابن طاووس');
  });

  test('entry counts (generated: 140 / 111 verified / 29 unverified)', () {
    expect(shiaOccasions, hasLength(140));
    expect(shiaOccasions.where((o) => o.verified), hasLength(111));
    expect(shiaOccasions.where((o) => !o.verified), hasLength(29));
  });

  test('excluded self-contradicting scan items are absent', () {
    for (final s in [
      'ذات الرقاع',
      'مسلم بن عقبة',
      'زيد بن صوحان',
      'ابن الحنفية',
    ]) {
      expect(
        shiaOccasions.any((o) => o.titleAr.contains(s)),
        isFalse,
        reason: s,
      );
    }
  });

  test('source names are display names, never a raw saraer.org domain', () {
    for (final o in shiaOccasions) {
      expect(o.sourceNames, isNot(contains('saraer.org')), reason: o.titleAr);
      expect(o.sourceNames.toSet().length, o.sourceNames.length);
    }
    // 4/5 alternate cites Sha'aer magazine only.
    final a = shiaOccasions.firstWhere(
      (o) => o.month == 4 && o.day == 5 && o.isAlternate,
    );
    expect(a.sourceNames, ['مجلة شعائر']);
  });

  test('sorted by month, day', () {
    for (var i = 1; i < shiaOccasions.length; i++) {
      final a = shiaOccasions[i - 1], b = shiaOccasions[i];
      expect(a.month * 100 + a.day <= b.month * 100 + b.day, isTrue);
    }
  });

  test('anchor occasions present (checked against research data)', () {
    bool has(int m, int d, String s, {bool? alt}) => shiaOccasions.any(
      (o) =>
          o.month == m &&
          o.day == d &&
          o.titleAr.contains(s) &&
          (alt == null || o.isAlternate == alt),
    );
    expect(has(1, 10, 'عاشوراء', alt: false), isTrue);
    expect(has(1, 10, 'استشهاد الإمام الحسين'), isTrue);
    expect(has(2, 20, 'الأربعين'), isTrue);
    expect(has(3, 17, 'مولد النبي'), isTrue);
    expect(has(7, 27, 'المبعث'), isTrue);
    expect(has(8, 15, 'الإمام المهدي'), isTrue);
    expect(has(9, 21, 'استشهاد أمير المؤمنين'), isTrue);
    expect(has(10, 1, 'عيد الفطر'), isTrue);
    expect(has(12, 10, 'عيد الأضحى'), isTrue);
    expect(has(12, 18, 'الغدير', alt: false), isTrue);
  });
}
