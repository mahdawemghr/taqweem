import 'dart:convert';
import 'dart:io';

import '../domain/calendar_fill.dart';
import '../domain/models.dart';
import '../domain/weekday.dart';

/// Thrown when the next month's Gregorian/solar start date cannot be derived
/// from the poster and no explicit override was supplied.
class CannotDeriveNextMonthDates implements Exception {
  const CannotDeriveNextMonthDates();
  @override
  String toString() =>
      'CannotDeriveNextMonthDates: could not derive the next month start dates';
}

/// Drafts stored as `<dir>/<id>.json`. Never throws on corrupt files.
class PosterRepository {
  final Directory dir;
  PosterRepository(this.dir);

  static final _idRe = RegExp(r'^[A-Za-z0-9_-]+$');
  static bool _isSafe(String id) => _idRe.hasMatch(id);

  static String _safeId(String id) {
    if (!_isSafe(id)) {
      throw ArgumentError.value(id, 'id', 'unsafe poster id');
    }
    return id;
  }

  File _file(String id) => File('${dir.path}/${_safeId(id)}.json');

  /// Newest first by `updatedAt`. Bad files are skipped silently. A file is
  /// accepted only if its embedded id is safe and equals the file name stem.
  Future<List<MonthPoster>> loadAll() async {
    final out = <MonthPoster>[];
    try {
      if (!await dir.exists()) return out;
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        try {
          final decoded = jsonDecode(await e.readAsString());
          if (decoded is! Map) continue;
          final p = MonthPoster.fromJson({
            for (final kv in decoded.entries) kv.key.toString(): kv.value,
          });
          if (!_isSafe(p.id)) continue;
          final name = e.uri.pathSegments.last;
          if (name != '${p.id}.json') continue;
          out.add(p);
        } catch (_) {
          // Corrupt or unreadable file: skip.
        }
      }
    } catch (_) {
      // Directory listing failure: return what we have.
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  final Map<String, Future<void>> _pending = {};
  int _counter = 0;

  /// Atomic (unique tmp then rename). Saves of the same id are chained so
  /// overlapping calls complete in call order and the last call wins.
  Future<void> save(MonthPoster p) {
    final target = _file(p.id);
    final json = jsonEncode(p.toJson());
    final prev = _pending[p.id] ?? Future<void>.value();
    final run = prev.catchError((_) {}).then((_) async {
      await dir.create(recursive: true);
      final tmp = File(
        '${target.path}.${DateTime.now().microsecondsSinceEpoch}.${_counter++}.tmp',
      );
      try {
        await tmp.writeAsString(json, flush: true);
        await tmp.rename(target.path);
      } catch (_) {
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
        rethrow;
      }
    });
    _pending[p.id] = run;
    return run.whenComplete(() {
      if (identical(_pending[p.id], run)) _pending.remove(p.id);
    });
  }

  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }

  /// Next hijri month (wraps 11 -> 0 with year+1), 30 regenerated rows.
  /// First weekday = last row's weekday.next; dates continue from the day
  /// after the last row (see [dayAfterLastRow] for derivation rules). Prayer
  /// times are copied from the same-index old row; notes/highlights/uncertain
  /// are reset. If a start date cannot be derived and no override is given,
  /// throws [CannotDeriveNextMonthDates].
  MonthPoster duplicateAsNextMonth(
    MonthPoster p, {
    String? newId,
    DateParts? gregorianStart,
    DateParts? solarStart,
  }) {
    final wrap = p.hijriMonthIndex >= 11;
    final now = DateTime.now();
    final g =
        gregorianStart ??
        dayAfterLastRow(p.days, p.gregorianHeader, solar: false) ??
        (throw const CannotDeriveNextMonthDates());
    final s =
        solarStart ??
        dayAfterLastRow(p.days, p.solarHeader, solar: true) ??
        (throw const CannotDeriveNextMonthDates());
    final nextIndex = wrap ? 0 : p.hijriMonthIndex + 1;
    final nextYear = wrap ? p.hijriYear + 1 : p.hijriYear;
    final filled = CalendarFill.generate(
      MonthSetup(
        hijriMonthIndex: nextIndex,
        hijriYear: nextYear,
        firstWeekday: p.days.isEmpty
            ? Weekday.saturday
            : p.days.last.weekday.next,
        dayCount: 30,
        gregorianStart: g,
        solarStart: s,
      ),
    );
    final days = [
      for (var i = 0; i < filled.days.length; i++)
        filled.days[i].copyWith(
          times: i < p.days.length ? p.days[i].times : const PrayerTimes(),
        ),
    ];
    return MonthPoster(
      id: newId ?? 'poster-${now.microsecondsSinceEpoch}',
      updatedAt: now,
      hijriMonthIndex: nextIndex,
      hijriYear: nextYear,
      gregorianHeader: filled.gregorianHeader,
      solarHeader: filled.solarHeader,
      days: days,
      texts: p.texts,
      templateId: p.templateId,
    );
  }
}
