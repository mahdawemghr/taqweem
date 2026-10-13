import '../data/shia_occasions.dart';
import 'models.dart';
import 'shia_occasion.dart';

/// Occasions for a Hijri month (0..11) and day. Day-30 items also match day
/// 29 when the month has 29 days. Mains come before alternates (stable);
/// entries printing the same note are shown once ([dedupeOccasions]).
List<ShiaOccasion> occasionsFor({
  required int hijriMonthIndex,
  required int day,
  required int daysInMonth,
}) {
  final month = hijriMonthIndex + 1;
  final matches = shiaOccasions.where((o) {
    if (o.month != month) return false;
    if (o.day == day) return true;
    return o.day == 30 && day == 29 && daysInMonth == 29;
  }).toList();
  return dedupeOccasions([
    ...matches.where((o) => !o.isAlternate),
    ...matches.where((o) => o.isAlternate),
  ]);
}

/// [list] with entries of identical normalised [ShiaOccasion.noteText]
/// merged into one: the best of them (verified main > main > verified >
/// other) takes the place of the first of the group; order otherwise kept.
List<ShiaOccasion> dedupeOccasions(List<ShiaOccasion> list) {
  int rank(ShiaOccasion o) => (o.isAlternate ? 0 : 2) + (o.verified ? 1 : 0);
  final best = <String, ShiaOccasion>{};
  for (final o in list) {
    final k = normalizeArabic(o.noteText);
    final cur = best[k];
    if (cur == null || rank(o) > rank(cur)) best[k] = o;
  }
  final seen = <String>{};
  return [
    for (final o in list)
      if (seen.add(normalizeArabic(o.noteText)))
        best[normalizeArabic(o.noteText)]!,
  ];
}

/// Arabic normalisation for matching only.
String normalizeArabic(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    switch (r) {
      case 0x0623:
      case 0x0625:
      case 0x0622:
        b.writeCharCode(0x0627);
      case 0x0649:
        b.writeCharCode(0x064A);
      case 0x0629:
        b.writeCharCode(0x0647);
      default:
        b.writeCharCode(r);
    }
  }
  return b.toString().toLowerCase();
}

List<ShiaOccasion> searchShiaOccasions(String query, {int limit = 8}) {
  final q = normalizeArabic(query.trim());
  if (q.isEmpty || limit <= 0) return const [];
  final hits = shiaOccasions
      .where((o) => normalizeArabic(o.titleAr).contains(q))
      .toList();
  final ordered = [
    ...hits.where((o) => !o.isAlternate),
    ...hits.where((o) => o.isAlternate),
  ];
  final seen = <String>{};
  final out = <ShiaOccasion>[];
  for (final o in ordered) {
    if (seen.add(o.titleAr)) out.add(o);
    if (out.length >= limit) break;
  }
  return out;
}

/// The notes «تعبئة المناسبات تلقائياً» would write, by day index: only days
/// whose note is empty, only VERIFIED MAIN occasions (never alternates or
/// unverified entries), several joined with « - ». A night entry is skipped
/// when the same day already has a selected (verified, non-night) main, to
/// avoid «المبعث… - ليلة المبعث…». Days with nothing to write are absent.
Map<int, String> autofillOccasionNotes(MonthPoster p) => {
  for (var i = 0; i < p.days.length; i++)
    if (p.days[i].note.trim().isEmpty)
      if (_verifiedMains(p, i) case final t when t.isNotEmpty) i: t,
};

String _verifiedMains(MonthPoster p, int i) {
  final mains = [
    for (final o in occasionsFor(
      hijriMonthIndex: p.hijriMonthIndex,
      day: p.days[i].hijriDay,
      daysInMonth: p.days.length,
    ))
      if (o.verified && !o.isAlternate) o,
  ];
  final hasDayMain = mains.any((o) => !o.isNight);
  return [
    for (final o in mains)
      if (!(o.isNight && hasDayMain)) o.noteText,
  ].join(' - ');
}
