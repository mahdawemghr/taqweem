enum OccasionCategory {
  birth,
  martyrdom,
  eid,
  battle,
  event,
  night,
  other;

  /// Maps a research-data category string; unknown values become [other].
  static OccasionCategory fromName(String? name) {
    for (final c in OccasionCategory.values) {
      if (c.name == name) return c;
    }
    return OccasionCategory.other;
  }
}

enum OccasionConfidence { high, medium }

class ShiaOccasion {
  const ShiaOccasion({
    required this.month,
    required this.day,
    required this.isNight,
    required this.titleAr,
    required this.category,
    required this.isAlternate,
    this.alternateNoteAr,
    required this.confidence,
    required this.verified,
    required this.sourceNames,
  });

  /// Hijri month 1..12.
  final int month;

  /// Hijri day 1..30.
  final int day;
  final bool isNight;
  final String titleAr;
  final OccasionCategory category;
  final bool isAlternate;
  final String? alternateNoteAr;
  final OccasionConfidence confidence;

  /// True when the entry cites at least two distinct source families.
  final bool verified;
  final List<String> sourceNames;

  /// The original alternate note (may cite sources), for tooltips only;
  /// null for a main entry or when the research data gave none.
  String? get fullNoteAr {
    final n = alternateNoteAr?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  /// Text inserted into a day note (printed on the poster): clean and
  /// short. A main entry is its title. An alternate is its title (without
  /// a trailing «على قول» / «على رواية», bracketed or not) plus one tag
  /// — «على رواية» when the note starts with it, else «على قول». Source
  /// commentary from the note is never included; a title that already
  /// carries a tag mid-text (e.g. «على رواية الأربعين يوماً») gets none.
  String get noteText {
    final title = titleAr.trim();
    if (!isAlternate) return title;
    final base = title.replaceFirst(_trailingTag, '').trim();
    if (base.contains('على قول') || base.contains('على رواية')) return base;
    final note = alternateNoteAr?.trim() ?? '';
    final tag = note.startsWith('على رواية') ? 'على رواية' : 'على قول';
    return '$base $tag';
  }

  static final _trailingTag = RegExp(r'\s*\(?\s*على\s+(قول|رواية)\s*\)?\s*$');
}
