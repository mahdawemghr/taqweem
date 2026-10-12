import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/poster_repository.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/weekday.dart';

void main() {
  late Directory dir;
  late PosterRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('taqweem_repo_');
    repo = PosterRepository(dir);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('save/loadAll round trip, newest first', () async {
    final a = seedReferenceMonth().copyWith(
      id: 'a',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final b = seedReferenceMonth().copyWith(
      id: 'b',
      updatedAt: DateTime.utc(2026, 3, 1),
    );
    await repo.save(a);
    await repo.save(b);
    final all = await repo.loadAll();
    expect(all.map((p) => p.id), ['b', 'a']);
    expect(all.first.toJson(), b.toJson());
    expect(dir.listSync().any((e) => e.path.endsWith('.tmp')), isFalse);
  });

  test('save creates missing directory and overwrites', () async {
    final nested = Directory('${dir.path}/x/y');
    final r = PosterRepository(nested);
    await r.save(seedReferenceMonth().copyWith(id: 'a'));
    await r.save(seedReferenceMonth().copyWith(id: 'a', hijriYear: 1500));
    final all = await r.loadAll();
    expect(all.length, 1);
    expect(all.single.hijriYear, 1500);
  });

  test('loadAll on missing directory returns empty', () async {
    expect(
      await PosterRepository(Directory('${dir.path}/nope')).loadAll(),
      isEmpty,
    );
  });

  test('corrupt json file is skipped, others load', () async {
    await repo.save(seedReferenceMonth().copyWith(id: 'good'));
    File('${dir.path}/bad.json').writeAsStringSync('{not json');
    File('${dir.path}/list.json').writeAsStringSync('[]');
    File('${dir.path}/badid.json').writeAsStringSync('{"id": 5}');
    File('${dir.path}/left.json.tmp').writeAsStringSync('{}');
    File('${dir.path}/notes.txt').writeAsStringSync('{}');
    final all = await repo.loadAll();
    expect(all.map((p) => p.id), ['good']);
  });

  test('save rejects unsafe ids', () async {
    for (final id in ['', '../x', 'a/b', r'a\b', '..']) {
      expect(
        () => repo.save(seedReferenceMonth().copyWith(id: id)),
        throwsArgumentError,
        reason: id,
      );
    }
  });

  test('delete removes the file, absent is fine', () async {
    await repo.save(seedReferenceMonth().copyWith(id: 'a'));
    await repo.delete('a');
    expect(await repo.loadAll(), isEmpty);
    await repo.delete('a');
  });

  test('delete rejects unsafe ids', () async {
    expect(() => repo.delete('../x'), throwsArgumentError);
    expect(() => repo.delete('a/b'), throwsArgumentError);
  });

  test(
    'loadAll skips files whose stem differs from id or id is unsafe',
    () async {
      final p = seedReferenceMonth();
      File('${dir.path}/other.json')
          .writeAsStringSync(jsonEncode(p.copyWith(id: 'good2').toJson()));
      File('${dir.path}/x.json')
          .writeAsStringSync(jsonEncode(p.copyWith(id: '../x').toJson()));
      await repo.save(p.copyWith(id: 'ok'));
      expect((await repo.loadAll()).map((e) => e.id), ['ok']);
    },
  );

  test('overlapping saves of one id: last call wins, no tmp left', () async {
    final base = seedReferenceMonth().copyWith(id: 'a');
    final f1 = repo.save(
      base.copyWith(texts: base.texts.copyWith(braceQuote: 'first')),
    );
    final f2 = repo.save(
      base.copyWith(texts: base.texts.copyWith(braceQuote: 'second')),
    );
    await Future.wait([f1, f2]);
    final all = await repo.loadAll();
    expect(all.single.texts.braceQuote, 'second');
    expect(dir.listSync().any((e) => e.path.endsWith('.tmp')), isFalse);
  });

  group('duplicate date derivation failure', () {
    test('unparseable header throws CannotDeriveNextMonthDates', () {
      final src = seedReferenceMonth().copyWith(gregorianHeader: 'garbage');
      expect(
        () => repo.duplicateAsNextMonth(src),
        throwsA(isA<CannotDeriveNextMonthDates>()),
      );
      final src2 = seedReferenceMonth().copyWith(solarHeader: '');
      expect(
        () => repo.duplicateAsNextMonth(src2),
        throwsA(isA<CannotDeriveNextMonthDates>()),
      );
      expect(const CannotDeriveNextMonthDates().toString(), isNotEmpty);
    });

    test('overrides replace derived values independently', () {
      final src = seedReferenceMonth().copyWith(
        gregorianHeader: 'garbage',
        solarHeader: 'garbage',
      );
      final d = repo.duplicateAsNextMonth(
        src,
        gregorianStart: const DateParts(2026, 11, 12),
        solarStart: const DateParts(1405, 8, 21),
      );
      expect(d.days.first.gregorian, const DayCell.number(12));
      expect(d.days.first.solar, const DayCell.number(21));
      final d2 = repo.duplicateAsNextMonth(
        seedReferenceMonth().copyWith(gregorianHeader: 'garbage'),
        gregorianStart: const DateParts(2026, 11, 15),
      );
      expect(d2.days.first.gregorian, const DayCell.number(15));
      expect(d2.days.first.solar, const DayCell.number(21));
    });
  });

  group('duplicateAsNextMonth', () {
    test('increments month, keeps template/texts, new id and time', () {
      final src = seedReferenceMonth().copyWith(templateId: 'minimal');
      final d = repo.duplicateAsNextMonth(src, newId: 'n');
      expect(d.id, 'n');
      expect(d.hijriMonthIndex, 5);
      expect(d.hijriYear, 1448);
      expect(d.templateId, 'minimal');
      expect(d.texts.toJson(), src.texts.toJson());
      expect(d.updatedAt.isAfter(src.updatedAt), isTrue);
      expect(repo.duplicateAsNextMonth(src).id, isNot(src.id));
    });

    test('wraps Dhul-Hijja to Muharram with year+1', () {
      final src = seedReferenceMonth().copyWith(
        hijriMonthIndex: 11,
        hijriYear: 1448,
      );
      final d = repo.duplicateAsNextMonth(src);
      expect(d.hijriMonthIndex, 0);
      expect(d.hijriYear, 1449);
    });

    test('continues weekday and dates from the last row', () {
      final src = seedReferenceMonth();
      final last = src.days.last; // 11 Nov 2026, Aban 20
      final d = repo.duplicateAsNextMonth(src);
      expect(d.days.length, 30);
      expect(d.days.first.weekday, last.weekday.next);
      expect(d.days.first.gregorian, const DayCell.number(12));
      expect(d.days.first.solar, const DayCell.number(21));
      expect(
        [for (final r in d.days) r.hijriDay],
        [for (var i = 1; i <= 30; i++) i],
      );
      expect(d.gregorianHeader, 'نوفمبر\nديسمبر\n2026');
    });

    test('29-day source gives 30 rows', () {
      final src = seedReferenceMonth().copyWith(
        days: seedReferenceMonth().days.sublist(0, 29),
      );
      expect(repo.duplicateAsNextMonth(src).days.length, 30);
    });

    test('notes cleared, times copied by index', () {
      final src = seedReferenceMonth();
      final d = repo.duplicateAsNextMonth(src);
      for (var i = 0; i < 30; i++) {
        expect(d.days[i].times, src.days[i].times);
        expect(d.days[i].note, '');
        expect(d.days[i].highlighted, isFalse);
        expect(d.days[i].uncertain, isEmpty);
      }
    });

    test('gregorian label row as last row is day 1 of that month', () {
      final filled = CalendarFill.generate(
        MonthSetup(
          hijriMonthIndex: 0,
          hijriYear: 1448,
          firstWeekday: Weekday.saturday,
          dayCount: 30,
          gregorianStart: const DateParts(2026, 12, 3),
          solarStart: const DateParts(1405, 9, 12),
        ),
      );
      // Dec 3 + 29 = Jan 1 -> last row is the label 'يناير'.
      expect(filled.days.last.gregorian, const DayCell.label('يناير'));
      final src = MonthPoster(
        id: 's',
        updatedAt: DateTime.utc(2026),
        hijriMonthIndex: 0,
        hijriYear: 1448,
        gregorianHeader: filled.gregorianHeader,
        solarHeader: filled.solarHeader,
        days: filled.days,
      );
      final d = repo.duplicateAsNextMonth(src);
      expect(d.days.first.gregorian, const DayCell.number(2));
      expect(d.gregorianHeader, 'يناير\n2027');
    });
  });

  group('dayAfterLastRow', () {
    test('label last row on year boundary uses last year of header', () {
      final filled = CalendarFill.generate(
        MonthSetup(
          hijriMonthIndex: 0,
          hijriYear: 1448,
          firstWeekday: Weekday.saturday,
          dayCount: 30,
          gregorianStart: const DateParts(2026, 12, 3),
          solarStart: const DateParts(1405, 9, 12),
        ),
      );
      expect(
        dayAfterLastRow(filled.days, filled.gregorianHeader, solar: false),
        const DateParts(2027, 1, 2),
      );
    });

    test('numeric last row', () {
      final p = seedReferenceMonth();
      expect(
        dayAfterLastRow(p.days, p.gregorianHeader, solar: false),
        const DateParts(2026, 11, 12),
      );
      expect(
        dayAfterLastRow(p.days, p.solarHeader, solar: true),
        const DateParts(1405, 8, 21),
      );
    });

    test('unparseable input returns null', () {
      expect(dayAfterLastRow(const [], '', solar: false), isNull);
      final p = seedReferenceMonth();
      expect(dayAfterLastRow(p.days, 'garbage', solar: false), isNull);
    });
  });
}
