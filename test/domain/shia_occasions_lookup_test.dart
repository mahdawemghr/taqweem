import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/data/shia_occasions.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/shia_occasion.dart';
import 'package:taqweem/domain/shia_occasions_lookup.dart';

void main() {
  group('ShiaOccasion.noteText', () {
    test('main uses title only', () {
      const o = ShiaOccasion(
        month: 1,
        day: 1,
        isNight: false,
        titleAr: 'عنوان',
        category: OccasionCategory.other,
        isAlternate: false,
        confidence: OccasionConfidence.high,
        verified: true,
        sourceNames: ['a', 'b'],
      );
      expect(o.noteText, 'عنوان');
    });
    test('alternate appends note, or default phrase when empty', () {
      const a = ShiaOccasion(
        month: 1,
        day: 1,
        isNight: false,
        titleAr: 'عنوان',
        category: OccasionCategory.other,
        isAlternate: true,
        alternateNoteAr: 'على رواية',
        confidence: OccasionConfidence.medium,
        verified: false,
        sourceNames: ['a'],
      );
      expect(a.noteText, 'عنوان على رواية');
      const b = ShiaOccasion(
        month: 1,
        day: 1,
        isNight: false,
        titleAr: 'عنوان',
        category: OccasionCategory.other,
        isAlternate: true,
        alternateNoteAr: '  ',
        confidence: OccasionConfidence.medium,
        verified: false,
        sourceNames: ['a'],
      );
      expect(b.noteText, 'عنوان على قول');
    });
  });

  group('noteText on real data (clean, no source commentary)', () {
    ShiaOccasion alt(int m, int d) => shiaOccasions.firstWhere(
      (o) => o.month == m && o.day == d && o.isAlternate,
    );

    test('4/5: trailing «(على قول)» in the title is not doubled', () {
      final o = alt(4, 5);
      expect(o.titleAr, endsWith('(على قول)'));
      expect(
        o.noteText,
        'خروج التوابين من الكوفة بقيادة سليمان بن صرد على قول',
      );
      expect(o.fullNoteAr, o.alternateNoteAr);
    });

    test('4/10: trailing «على رواية» in the title is not doubled', () {
      final o = alt(4, 10);
      expect(o.titleAr, endsWith('على رواية'));
      expect(o.noteText, 'ولادة الإمام الحسن العسكري (ع) على رواية');
    });

    test('10/15: long parenthetical source note is never printed', () {
      final o = alt(10, 15);
      expect(o.alternateNoteAr, contains('('));
      expect(o.noteText, 'غزوة أحد واستشهاد حمزة سيد الشهداء (رض) على قول');
      expect(o.fullNoteAr, contains('مكتبة العتبة الحسينية'));
    });

    test('12/23: Mubahala alternate reads «… على رواية»', () {
      expect(
        alt(12, 23).noteText,
        'يوم المباهلة (المباهلة مع نصارى نجران) على رواية',
      );
      final main = shiaOccasions.firstWhere(
        (o) => o.month == 12 && o.day == 24 && !o.isAlternate,
      );
      expect(main.noteText, 'يوم المباهلة (المباهلة مع نصارى نجران)');
      expect(main.fullNoteAr, isNull);
    });

    test('4/8: a title already carrying «على رواية …» gets no second tag', () {
      final o = alt(4, 8);
      expect(
        o.noteText,
        'ذكرى استشهاد السيدة فاطمة الزهراء (س) على رواية الأربعين يوماً',
      );
    });

    test('no printed note of any entry contains source commentary', () {
      for (final o in shiaOccasions) {
        final t = o.noteText;
        expect(t, t.trim());
        if (o.isAlternate) {
          expect(
            t.endsWith(' على قول') ||
                t.endsWith(' على رواية') ||
                t.contains('على رواية') ||
                t.contains('على قول'),
            isTrue,
            reason: t,
          );
          for (final n in o.sourceNames) {
            expect(t.contains(n), isFalse, reason: '$t / $n');
          }
          expect(
            RegExp(r'(على قول|على رواية).*على').hasMatch(t),
            isFalse,
            reason: t,
          );
        } else {
          expect(t, o.titleAr.trim());
        }
      }
    });
  });

  group('dedupeOccasions', () {
    ShiaOccasion mk(String t, {bool alt = false, bool v = true}) =>
        ShiaOccasion(
          month: 1,
          day: 1,
          isNight: false,
          titleAr: t,
          category: OccasionCategory.other,
          isAlternate: alt,
          alternateNoteAr: alt ? 'على قول' : null,
          confidence: OccasionConfidence.medium,
          verified: v,
          sourceNames: const ['a'],
        );

    test(
      'identical normalised noteText keeps one, preferring verified main',
      () {
        final unverified = mk('الإمام علي (ع)', v: false);
        final verified = mk('الامام علي (ع)');
        final other = mk('شيء آخر');
        expect(dedupeOccasions([unverified, other, verified]), [
          verified,
          other,
        ]);
      },
    );

    test('a main and an alternate never collide (different note text)', () {
      final m = mk('عنوان'), a = mk('عنوان', alt: true);
      expect(dedupeOccasions([m, a]), [m, a]);
    });
  });

  group('occasionsFor', () {
    test('matches month index + day from data, mains before alternates', () {
      for (final o in shiaOccasions) {
        final r = occasionsFor(
          hijriMonthIndex: o.month - 1,
          day: o.day,
          daysInMonth: 30,
        );
        expect(r, contains(o));
        final firstAlt = r.indexWhere((e) => e.isAlternate);
        if (firstAlt >= 0) {
          expect(r.skip(firstAlt).every((e) => e.isAlternate), isTrue);
        }
        expect(r.every((e) => e.month == o.month && e.day == o.day), isTrue);
      }
    });

    test('empty for a day with nothing and month index out of range', () {
      expect(
        occasionsFor(hijriMonthIndex: 12, day: 1, daysInMonth: 30),
        isEmpty,
      );
    });

    test('last-day rule: day 30 items also match day 29 only if 29 days', () {
      final d30 = shiaOccasions.where((o) => o.day == 30).toList();
      expect(d30, isNotEmpty);
      final o = d30.first;
      final on29of29 = occasionsFor(
        hijriMonthIndex: o.month - 1,
        day: 29,
        daysInMonth: 29,
      );
      final on29of30 = occasionsFor(
        hijriMonthIndex: o.month - 1,
        day: 29,
        daysInMonth: 30,
      );
      expect(on29of29, contains(o));
      expect(on29of30, isNot(contains(o)));
      expect(
        occasionsFor(hijriMonthIndex: o.month - 1, day: 30, daysInMonth: 30),
        contains(o),
      );
    });
  });

  group('searchShiaOccasions', () {
    test('normalises hamza so الامام الحسين finds الإمام الحسين', () {
      final r = searchShiaOccasions('الامام الحسين', limit: 100);
      expect(r, isNotEmpty);
      expect(r.any((o) => o.titleAr.contains('الإمام الحسين')), isTrue);
    });
    test('empty and blank query return empty', () {
      expect(searchShiaOccasions(''), isEmpty);
      expect(searchShiaOccasions('   '), isEmpty);
    });
    test('limit is respected and titles are unique', () {
      final r = searchShiaOccasions('ال', limit: 3);
      expect(r.length, lessThanOrEqualTo(3));
      final all = searchShiaOccasions('ال', limit: 1000);
      expect(all.map((o) => o.titleAr).toSet().length, all.length);
    });
    test('mains first', () {
      final all = searchShiaOccasions('ال', limit: 1000);
      final i = all.indexWhere((o) => o.isAlternate);
      if (i >= 0) expect(all.skip(i).every((o) => o.isAlternate), isTrue);
    });
    test('ignores diacritics', () {
      expect(searchShiaOccasions('عَاشُورَاء'), isNotEmpty);
    });
  });

  group('autofillOccasionNotes', () {
    test('only empty notes, only verified mains, joined with " - "', () {
      final seed = seedReferenceMonth();
      final p = seed.copyWith(
        days: [
          for (final (i, d) in seed.days.indexed)
            i.isEven ? d.copyWith(note: '  ') : d.copyWith(note: 'x'),
        ],
      );
      final m = autofillOccasionNotes(p);
      for (final e in m.entries) {
        expect(e.key.isEven, isTrue);
        final want = [
          for (final o in occasionsFor(
            hijriMonthIndex: 4,
            day: p.days[e.key].hijriDay,
            daysInMonth: 30,
          ))
            if (o.verified && !o.isAlternate && !o.isNight) o.noteText,
        ];
        expect(e.value, want.join(' - '));
      }
      expect(m, isNotEmpty);
    });

    test('a night entry is skipped when a selected day main exists', () {
      // 15 Sha'ban has the birth of al-Mahdi (day main) and its night.
      final nights = shiaOccasions.where(
        (o) => o.isNight && !o.isAlternate && o.verified,
      );
      expect(nights, isNotEmpty);
      final seed = seedReferenceMonth();
      var checked = 0;
      for (final n in nights) {
        final all = occasionsFor(
          hijriMonthIndex: n.month - 1,
          day: n.day,
          daysInMonth: 30,
        );
        final hasDayMain = all.any(
          (o) => o.verified && !o.isAlternate && !o.isNight,
        );
        final p30 = MonthPoster(
          id: 'x',
          updatedAt: DateTime(2026),
          hijriMonthIndex: n.month - 1,
          hijriYear: 1448,
          days: [
            for (var d = 1; d <= 30; d++)
              seed.days.first.copyWith(hijriDay: d, note: ''),
          ],
        );
        final text = autofillOccasionNotes(p30)[n.day - 1] ?? '';
        if (hasDayMain) {
          expect(text, isNot(contains(n.noteText)), reason: n.titleAr);
          checked++;
        } else {
          expect(text, contains(n.noteText), reason: n.titleAr);
        }
      }
      expect(checked, greaterThan(0));
    });

    test('a night-only day still gets its night entry', () {
      final nightOnly = shiaOccasions.where((o) {
        if (!o.isNight || o.isAlternate || !o.verified) return false;
        return !shiaOccasions.any(
          (x) =>
              x.month == o.month &&
              x.day == o.day &&
              !x.isNight &&
              !x.isAlternate &&
              x.verified,
        );
      });
      // Not every dataset has one; when it does it must be written.
      final seed = seedReferenceMonth();
      for (final n in nightOnly) {
        final p = MonthPoster(
          id: 'x',
          updatedAt: DateTime(2026),
          hijriMonthIndex: n.month - 1,
          hijriYear: 1448,
          days: [
            for (var d = 1; d <= 30; d++)
              seed.days.first.copyWith(hijriDay: d, note: ''),
          ],
        );
        expect(autofillOccasionNotes(p)[n.day - 1], contains(n.noteText));
      }
    });

    test('a poster without days gives nothing', () {
      final p = MonthPoster(
        id: 'x',
        updatedAt: DateTime(2026),
        hijriMonthIndex: 0,
        hijriYear: 1448,
      );
      expect(autofillOccasionNotes(p), isEmpty);
    });
  });
}
