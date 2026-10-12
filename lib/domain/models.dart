import 'month_names.dart';
import 'time_format.dart';
import 'weekday.dart';

const defaultFooterNotes =
    'ملاحظات: 1- على كل شخص ان يعمل على حسب فتوى مرجعه . 2- الأوقات مأخوذة من تقويم الهادي .';
const defaultFatiha = 'الفاتحة لأرواح المؤمنين والمؤمنات من الأولين والآخرين';
const defaultTitle = 'تقويم أهل البيت';
const defaultTemplateId = 'navy_gold';

// Total (never-throwing) JSON readers: wrong-typed values fall back to defaults.
Map<String, dynamic> _map(Object? o) => o is Map
    ? {for (final e in o.entries) e.key.toString(): e.value}
    : const {};
List<Object?> _list(Object? o) => o is List ? o : const [];
String _str(Object? o, String d) => o is String ? o : d;
int _int(Object? o, int d) => o is num && o.isFinite ? o.toInt() : d;
int? _intOrNull(Object? o) => o is num && o.isFinite ? o.toInt() : null;

enum DayField {
  weekday,
  hijri,
  gregorian,
  solar,
  fajr,
  shurooq,
  zuhr,
  maghrib,
  note,
}

class DayCell {
  final int? number;
  final String? label;
  const DayCell.number(int n) : number = n, label = null;
  const DayCell.label(String l) : label = l, number = null;

  bool get isLabel => label != null;

  Map<String, dynamic> toJson() => isLabel ? {'l': label} : {'n': number};

  factory DayCell.fromJson(Map<String, dynamic> j) {
    final l = j['l'];
    if (l is String) return DayCell.label(l);
    // Wrong-typed or missing 'n' yields number cell 0.
    return DayCell.number(_int(j['n'], 0));
  }

  @override
  bool operator ==(Object other) =>
      other is DayCell && other.number == number && other.label == label;

  @override
  int get hashCode => Object.hash(number, label);
}

class PrayerTimes {
  final int? fajr, shurooq, zuhr, maghrib;
  const PrayerTimes({this.fajr, this.shurooq, this.zuhr, this.maghrib});

  int? operator [](PrayerSlot s) {
    switch (s) {
      case PrayerSlot.fajr:
        return fajr;
      case PrayerSlot.shurooq:
        return shurooq;
      case PrayerSlot.zuhr:
        return zuhr;
      case PrayerSlot.maghrib:
        return maghrib;
    }
  }

  PrayerTimes withSlot(PrayerSlot s, int? v) => PrayerTimes(
    fajr: s == PrayerSlot.fajr ? v : fajr,
    shurooq: s == PrayerSlot.shurooq ? v : shurooq,
    zuhr: s == PrayerSlot.zuhr ? v : zuhr,
    maghrib: s == PrayerSlot.maghrib ? v : maghrib,
  );

  Map<String, dynamic> toJson() => {
    'fajr': fajr,
    'shurooq': shurooq,
    'zuhr': zuhr,
    'maghrib': maghrib,
  };

  factory PrayerTimes.fromJson(Map<String, dynamic> j) => PrayerTimes(
    fajr: _intOrNull(j['fajr']),
    shurooq: _intOrNull(j['shurooq']),
    zuhr: _intOrNull(j['zuhr']),
    maghrib: _intOrNull(j['maghrib']),
  );

  @override
  bool operator ==(Object other) =>
      other is PrayerTimes &&
      other.fajr == fajr &&
      other.shurooq == shurooq &&
      other.zuhr == zuhr &&
      other.maghrib == maghrib;

  @override
  int get hashCode => Object.hash(fajr, shurooq, zuhr, maghrib);
}

class DayRow {
  final Weekday weekday;
  final int hijriDay;
  final DayCell gregorian, solar;
  final PrayerTimes times;
  final String note;
  final bool highlighted;
  final Set<DayField> uncertain;

  const DayRow({
    required this.weekday,
    required this.hijriDay,
    required this.gregorian,
    required this.solar,
    this.times = const PrayerTimes(),
    this.note = '',
    this.highlighted = false,
    this.uncertain = const {},
  });

  DayRow copyWith({
    Weekday? weekday,
    int? hijriDay,
    DayCell? gregorian,
    DayCell? solar,
    PrayerTimes? times,
    String? note,
    bool? highlighted,
    Set<DayField>? uncertain,
  }) => DayRow(
    weekday: weekday ?? this.weekday,
    hijriDay: hijriDay ?? this.hijriDay,
    gregorian: gregorian ?? this.gregorian,
    solar: solar ?? this.solar,
    times: times ?? this.times,
    note: note ?? this.note,
    highlighted: highlighted ?? this.highlighted,
    uncertain: uncertain ?? this.uncertain,
  );

  Map<String, dynamic> toJson() => {
    'weekday': weekday.name,
    'hijriDay': hijriDay,
    'gregorian': gregorian.toJson(),
    'solar': solar.toJson(),
    'times': times.toJson(),
    'note': note,
    'highlighted': highlighted,
    'uncertain': uncertain.map((f) => f.name).toList(),
  };

  factory DayRow.fromJson(Map<String, dynamic> j) {
    final wd = Weekday.values.where((w) => w.name == j['weekday']);
    final unc = <DayField>{};
    for (final n in _list(j['uncertain'])) {
      if (n is! String) continue;
      for (final f in DayField.values) {
        if (f.name == n) unc.add(f);
      }
    }
    return DayRow(
      weekday: wd.isEmpty ? Weekday.saturday : wd.first,
      hijriDay: _int(j['hijriDay'], 1),
      gregorian: DayCell.fromJson(_map(j['gregorian'])),
      solar: DayCell.fromJson(_map(j['solar'])),
      times: PrayerTimes.fromJson(_map(j['times'])),
      note: _str(j['note'], ''),
      highlighted: j['highlighted'] == true,
      uncertain: unc,
    );
  }
}

class HeaderQuote {
  final String text, attribution;
  const HeaderQuote({required this.text, required this.attribution});
  const HeaderQuote.empty() : text = '', attribution = '';

  HeaderQuote copyWith({String? text, String? attribution}) => HeaderQuote(
    text: text ?? this.text,
    attribution: attribution ?? this.attribution,
  );

  Map<String, dynamic> toJson() => {'text': text, 'attribution': attribution};
  factory HeaderQuote.fromJson(Map<String, dynamic> j) => HeaderQuote(
    text: _str(j['text'], ''),
    attribution: _str(j['attribution'], ''),
  );
}

class ClosingArticle {
  final String author, body;
  const ClosingArticle({required this.author, required this.body});
  const ClosingArticle.empty() : author = '', body = '';

  ClosingArticle copyWith({String? author, String? body}) =>
      ClosingArticle(author: author ?? this.author, body: body ?? this.body);

  Map<String, dynamic> toJson() => {'author': author, 'body': body};
  factory ClosingArticle.fromJson(Map<String, dynamic> j) =>
      ClosingArticle(author: _str(j['author'], ''), body: _str(j['body'], ''));
}

class SideQa {
  final String question, answer;
  const SideQa({required this.question, required this.answer});
  const SideQa.empty() : question = '', answer = '';

  SideQa copyWith({String? question, String? answer}) => SideQa(
    question: question ?? this.question,
    answer: answer ?? this.answer,
  );

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
  factory SideQa.fromJson(Map<String, dynamic> j) =>
      SideQa(question: _str(j['question'], ''), answer: _str(j['answer'], ''));
}

class PosterTexts {
  final String title;
  final HeaderQuote rightQuote, leftQuote;
  final String braceQuote;
  final ClosingArticle article;
  final SideQa sideRight, sideLeft;
  final String footerNotes, fatiha;

  const PosterTexts({
    required this.title,
    required this.rightQuote,
    required this.leftQuote,
    required this.braceQuote,
    required this.article,
    required this.sideRight,
    required this.sideLeft,
    required this.footerNotes,
    required this.fatiha,
  });

  const PosterTexts.empty()
    : title = defaultTitle,
      rightQuote = const HeaderQuote.empty(),
      leftQuote = const HeaderQuote.empty(),
      braceQuote = '',
      article = const ClosingArticle.empty(),
      sideRight = const SideQa.empty(),
      sideLeft = const SideQa.empty(),
      footerNotes = defaultFooterNotes,
      fatiha = defaultFatiha;

  PosterTexts copyWith({
    String? title,
    HeaderQuote? rightQuote,
    HeaderQuote? leftQuote,
    String? braceQuote,
    ClosingArticle? article,
    SideQa? sideRight,
    SideQa? sideLeft,
    String? footerNotes,
    String? fatiha,
  }) => PosterTexts(
    title: title ?? this.title,
    rightQuote: rightQuote ?? this.rightQuote,
    leftQuote: leftQuote ?? this.leftQuote,
    braceQuote: braceQuote ?? this.braceQuote,
    article: article ?? this.article,
    sideRight: sideRight ?? this.sideRight,
    sideLeft: sideLeft ?? this.sideLeft,
    footerNotes: footerNotes ?? this.footerNotes,
    fatiha: fatiha ?? this.fatiha,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'rightQuote': rightQuote.toJson(),
    'leftQuote': leftQuote.toJson(),
    'braceQuote': braceQuote,
    'article': article.toJson(),
    'sideRight': sideRight.toJson(),
    'sideLeft': sideLeft.toJson(),
    'footerNotes': footerNotes,
    'fatiha': fatiha,
  };

  factory PosterTexts.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(String k) => _map(j[k]);
    return PosterTexts(
      title: _str(j['title'], defaultTitle),
      rightQuote: HeaderQuote.fromJson(m('rightQuote')),
      leftQuote: HeaderQuote.fromJson(m('leftQuote')),
      braceQuote: _str(j['braceQuote'], ''),
      article: ClosingArticle.fromJson(m('article')),
      sideRight: SideQa.fromJson(m('sideRight')),
      sideLeft: SideQa.fromJson(m('sideLeft')),
      footerNotes: _str(j['footerNotes'], defaultFooterNotes),
      fatiha: _str(j['fatiha'], defaultFatiha),
    );
  }
}

class MonthPoster {
  final String id;
  final DateTime updatedAt;
  final int hijriMonthIndex;
  final int hijriYear;
  final String gregorianHeader, solarHeader;
  final List<DayRow> days;
  final PosterTexts texts;
  final String templateId;

  const MonthPoster({
    required this.id,
    required this.updatedAt,
    required this.hijriMonthIndex,
    required this.hijriYear,
    this.gregorianHeader = '',
    this.solarHeader = '',
    this.days = const [],
    this.texts = const PosterTexts.empty(),
    this.templateId = defaultTemplateId,
  });

  /// Out-of-range [hijriMonthIndex] yields an empty month name, so the header
  /// is just the year line (no throw).
  String get hijriHeader {
    if (hijriMonthIndex < 0 || hijriMonthIndex >= hijriMonthsAr.length) {
      return '$hijriYear';
    }
    return '${hijriMonthsAr[hijriMonthIndex]}\n$hijriYear';
  }

  MonthPoster copyWith({
    String? id,
    DateTime? updatedAt,
    int? hijriMonthIndex,
    int? hijriYear,
    String? gregorianHeader,
    String? solarHeader,
    List<DayRow>? days,
    PosterTexts? texts,
    String? templateId,
  }) => MonthPoster(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    hijriMonthIndex: hijriMonthIndex ?? this.hijriMonthIndex,
    hijriYear: hijriYear ?? this.hijriYear,
    gregorianHeader: gregorianHeader ?? this.gregorianHeader,
    solarHeader: solarHeader ?? this.solarHeader,
    days: days ?? this.days,
    texts: texts ?? this.texts,
    templateId: templateId ?? this.templateId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'hijriMonthIndex': hijriMonthIndex,
    'hijriYear': hijriYear,
    'gregorianHeader': gregorianHeader,
    'solarHeader': solarHeader,
    'days': days.map((d) => d.toJson()).toList(),
    'texts': texts.toJson(),
    'templateId': templateId,
  };

  factory MonthPoster.fromJson(Map<String, dynamic> j) => MonthPoster(
    id: _str(j['id'], ''),
    updatedAt:
        DateTime.tryParse(_str(j['updatedAt'], '')) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    hijriMonthIndex: _monthIndex(j['hijriMonthIndex']),
    hijriYear: _int(j['hijriYear'], 1446),
    gregorianHeader: _str(j['gregorianHeader'], ''),
    solarHeader: _str(j['solarHeader'], ''),
    days: [
      for (final d in _list(j['days']))
        if (d is Map) DayRow.fromJson(_map(d)),
    ],
    texts: PosterTexts.fromJson(_map(j['texts'])),
    templateId: _str(j['templateId'], defaultTemplateId),
  );
}

int _monthIndex(Object? o) {
  final i = _int(o, 0);
  return i >= 0 && i < hijriMonthsAr.length ? i : 0;
}
