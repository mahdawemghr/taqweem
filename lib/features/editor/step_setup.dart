import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/arabic_digits.dart';
import '../../domain/calendar_fill.dart';
import '../../domain/models.dart';
import '../../domain/month_names.dart';
import '../../domain/weekday.dart';
import '../../state/editor_controller.dart';

// ---------------------------------------------------------------------------
// Pure helpers (no widgets)
// ---------------------------------------------------------------------------

/// Parses a typed number; Arabic-Indic / Persian digits are accepted.
/// Returns null for empty or non-digit input.
int? parseTypedNumber(String s) {
  final t = normalizeDigits(s.trim());
  if (!RegExp(r'^\d{1,6}$').hasMatch(t)) return null;
  return int.parse(t);
}

int solarMonthLength(int month, int esfandLength) =>
    month <= 6 ? 31 : (month <= 11 ? 30 : esfandLength);

bool isValidGregorian(int y, int m, int d) =>
    y >= 1900 &&
    y <= 2200 &&
    m >= 1 &&
    m <= 12 &&
    d >= 1 &&
    d <= DateTime(y, m + 1, 0).day;

bool isValidSolar(int y, int m, int d, int esfandLength) =>
    y >= 1300 &&
    y <= 1600 &&
    m >= 1 &&
    m <= 12 &&
    d >= 1 &&
    d <= solarMonthLength(m, esfandLength);

bool isValidHijriYear(int? y) => y != null && y >= 1300 && y <= 1700;

/// The real weekday of a Gregorian date.
Weekday weekdayOfGregorian(DateParts g) =>
    Weekday.values[(DateTime(g.year, g.month, g.day).weekday + 1) % 7];

/// Best-effort start date of row 0 for one calendar: the year comes from the
/// header's last line (first year of `y0/y1`), the month from row 0's label
/// or the header's first month name, the day from row 0's number (a label
/// row is day 1). Parts that cannot be recovered are null.
({int? year, int? month, int? day}) deriveStartParts(
  DayCell cell,
  String header,
  List<String> monthNames,
) {
  final lines = header
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final year = lines.length >= 2
      ? int.tryParse(normalizeDigits(lines.last.split('/').first.trim()))
      : null;
  int? month;
  int? day;
  if (cell.isLabel) {
    final i = monthNames.indexOf(cell.label!);
    month = i < 0 ? null : i + 1;
    day = 1;
  } else {
    final i = lines.isEmpty ? -1 : monthNames.indexOf(lines.first);
    month = i < 0 ? null : i + 1;
    final n = cell.number;
    day = n != null && n >= 1 ? n : null;
  }
  return (year: year, month: month, day: day);
}

/// Esfand length implied by the rows (the day before the `فروردين` label),
/// when the solar start month is 12; null otherwise.
int? _esfandFromRows(List<DayRow> rows, DateParts solarStart) {
  if (solarStart.month != 12) return null;
  final k = rows.indexWhere(
    (r) => r.solar.isLabel && r.solar.label == solarMonthsAr.first,
  );
  if (k <= 0) return null;
  final len = solarStart.day + k - 1;
  return len == 29 || len == 30 ? len : null;
}

/// The [MonthSetup] the poster's existing rows were generated from, or null
/// when the rows are empty or their start dates cannot be recovered.
MonthSetup? deriveRowsSetup(MonthPoster p, {int? esfandLength}) {
  if (p.days.isEmpty) return null;
  final first = p.days.first;
  final g = deriveStartParts(
    first.gregorian,
    p.gregorianHeader,
    gregorianMonthsAr,
  );
  final s = deriveStartParts(first.solar, p.solarHeader, solarMonthsAr);
  if (g.year == null || g.month == null || g.day == null) return null;
  if (s.year == null || s.month == null || s.day == null) return null;
  final solarStart = DateParts(s.year!, s.month!, s.day!);
  final esf = _esfandFromRows(p.days, solarStart) ?? esfandLength ?? 29;
  if (!isValidGregorian(g.year!, g.month!, g.day!)) return null;
  if (!isValidSolar(s.year!, s.month!, s.day!, esf)) return null;
  return MonthSetup(
    hijriMonthIndex: p.hijriMonthIndex,
    hijriYear: p.hijriYear,
    firstWeekday: first.weekday,
    dayCount: p.days.length,
    gregorianStart: DateParts(g.year!, g.month!, g.day!),
    solarStart: solarStart,
    solarEsfandLength: esf,
  );
}

bool _rowHasData(DayRow r) =>
    r.note.trim().isNotEmpty ||
    r.highlighted ||
    r.times.fajr != null ||
    r.times.shurooq != null ||
    r.times.zuhr != null ||
    r.times.maghrib != null;

String _dateText(Weekday w, DateParts g) =>
    '${w.ar} ${g.day} ${gregorianMonthsAr[g.month - 1]} ${g.year}';

// ---------------------------------------------------------------------------
// Step 1 widget
// ---------------------------------------------------------------------------

/// Step 1 "month setup": the inputs that generate the day rows.
///
/// The Hijri month/year and the day count are applied to the poster at once
/// (they never discard data: the count uses [CalendarFill.resize]). The start
/// dates and first weekday form a draft that is applied with
/// `إنشاء الأيام` / `تحديث الأيام` ([CalendarFill.generate]); a confirmation
/// is asked only when some row already holds times, notes or a highlight.
class StepSetup extends ConsumerStatefulWidget {
  const StepSetup({required this.poster, this.session, this.today, super.key});

  /// The poster being edited (live editor state).
  final MonthPoster poster;

  /// Identifies one editor session (one [EditorShell] instance). A draft kept
  /// in [setupDraftProvider] is reused only by the same session and poster,
  /// so leaving Step 1 and coming back keeps what the user typed.
  final Object? session;

  /// "Today" for the default Gregorian start of a blank poster.
  final DateTime? today;

  @override
  ConsumerState<StepSetup> createState() => _StepSetupState();
}

/// The Step 1 inputs that are not (yet) part of the poster.
class SetupDraft {
  SetupDraft({required this.session, required this.posterId});

  final Object? session;
  final String posterId;
  String hijriYear = '', gYear = '', gDay = '', sYear = '', sDay = '';
  int? gMonth, sMonth;
  Weekday weekday = Weekday.saturday;
  int dayCount = 30, esfand = 29;

  /// The rows' start the draft was last synced with ([rowsStartKey]).
  RowsStartKey? synced;
}

/// What the form is synced from: the first weekday and the Gregorian and
/// solar start dates derived from the rows. Edits that keep these (notes,
/// times, resizing the month, autosave timestamps) never re-fill the draft.
typedef RowsStartKey = (Weekday, DateParts, DateParts);

/// [RowsStartKey] of [p]'s rows, or null when empty / underivable.
RowsStartKey? rowsStartKey(MonthPoster p) {
  final s = deriveRowsSetup(p);
  return s == null ? null : (s.firstWeekday, s.gregorianStart, s.solarStart);
}

/// Holder of the Step 1 draft for the current editor session. A plain
/// mutable holder: Step 1 reads it when it is built and writes it back when
/// it is disposed (e.g. when the user moves to another step), so nothing
/// needs to rebuild when it changes.
class SetupDraftStore {
  SetupDraft? draft;
}

final setupDraftProvider = Provider<SetupDraftStore>(
  (ref) => SetupDraftStore(),
);

/// Rows appended after the last row of [p] up to [n] rows, with the
/// dates continuing from [dayAfterLastRow]; null when the next day cannot be
/// derived. Month-change rows get the month-name label and the headers gain
/// the new month names / end year.
({List<DayRow> days, String gregorianHeader, String solarHeader})?
extendFromLastRow(MonthPoster p, int n, {int esfandLength = 29}) {
  var g = dayAfterLastRow(p.days, p.gregorianHeader, solar: false);
  var s = dayAfterLastRow(
    p.days,
    p.solarHeader,
    solar: true,
    esfandLength: esfandLength,
  );
  if (g == null || s == null || n <= p.days.length) return null;
  final days = [...p.days];
  final gNew = <String>[], sNew = <String>[];
  var wd = p.days.last.weekday;
  var gLast = g, sLast = s;
  for (var i = p.days.length; i < n; i++) {
    wd = wd.next;
    final DayCell gCell, sCell;
    if (g!.day == 1) {
      gNew.add(gregorianMonthsAr[g.month - 1]);
      gCell = DayCell.label(gNew.last);
    } else {
      gCell = DayCell.number(g.day);
    }
    if (s!.day == 1) {
      sNew.add(solarMonthsAr[s.month - 1]);
      sCell = DayCell.label(sNew.last);
    } else {
      sCell = DayCell.number(s.day);
    }
    days.add(
      DayRow(weekday: wd, hijriDay: i + 1, gregorian: gCell, solar: sCell),
    );
    gLast = g;
    sLast = s;
    g = nextGregorianDay(g);
    s = nextSolarDay(s, esfandLength: esfandLength);
  }
  return (
    days: days,
    gregorianHeader: _extendHeader(p.gregorianHeader, gNew, gLast.year),
    solarHeader: _extendHeader(p.solarHeader, sNew, sLast.year),
  );
}

String _extendHeader(String header, List<String> newMonths, int endYear) {
  final lines = header
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return header;
  final years = lines.last.split('/').map((y) => y.trim()).toList();
  final lastYear = int.tryParse(normalizeDigits(years.last));
  if (newMonths.isEmpty && lastYear == endYear) return header;
  final y0 = years.first;
  final yearLine = int.tryParse(normalizeDigits(y0)) == endYear
      ? y0
      : '$y0/$endYear';
  return [
    ...lines.sublist(0, lines.length - 1),
    ...newMonths,
    yearLine,
  ].join('\n');
}

class _StepSetupState extends ConsumerState<StepSetup> {
  final _hijriYear = TextEditingController();
  final _gYear = TextEditingController();
  final _gDay = TextEditingController();
  final _sYear = TextEditingController();
  final _sDay = TextEditingController();
  int? _gMonth;
  int? _sMonth;
  Weekday _weekday = Weekday.saturday;
  int _dayCount = 30;
  int _esfand = 29;
  late final SetupDraftStore _store;
  RowsStartKey? _synced;

  @override
  void initState() {
    super.initState();
    _store = ref.read(setupDraftProvider);
    final p = widget.poster;
    final d = _store.draft;
    if (d != null &&
        identical(d.session, widget.session) &&
        d.posterId == p.id) {
      _load(d);
      _synced = d.synced;
      // The Hijri month/year are applied at once: the poster is the truth.
      if (parseTypedNumber(_hijriYear.text) != p.hijriYear) {
        _hijriYear.text = '${p.hijriYear}';
      }
      // The rows' start changed while Step 1 was not shown (e.g. undo on
      // another step): follow it.
      _syncFromRows(p);
      return;
    }
    _prefillFromPoster(p);
    _synced = rowsStartKey(p);
  }

  /// Re-fills the draft only when the rows' derived start differs from the
  /// one last synced.
  void _syncFromRows(MonthPoster p) {
    final key = rowsStartKey(p);
    if (key == _synced) return;
    _synced = key;
    if (key != null) _followRows(p);
  }

  void _load(SetupDraft d) {
    _hijriYear.text = d.hijriYear;
    _gYear.text = d.gYear;
    _gDay.text = d.gDay;
    _sYear.text = d.sYear;
    _sDay.text = d.sDay;
    _gMonth = d.gMonth;
    _sMonth = d.sMonth;
    _weekday = d.weekday;
    _dayCount = d.dayCount;
    _esfand = d.esfand;
  }

  void _prefillFromPoster(MonthPoster p) {
    _hijriYear.text = '${p.hijriYear}';
    if (p.days.isEmpty) {
      final t = widget.today ?? DateTime.now();
      final g = DateParts(t.year, t.month, t.day);
      _gYear.text = '${g.year}';
      _gMonth = g.month;
      _gDay.text = '${g.day}';
      _weekday = weekdayOfGregorian(g);
      return;
    }
    final first = p.days.first;
    _weekday = first.weekday;
    _dayCount = p.days.length == 29 ? 29 : 30;
    final g = deriveStartParts(
      first.gregorian,
      p.gregorianHeader,
      gregorianMonthsAr,
    );
    _gYear.text = g.year?.toString() ?? '';
    _gMonth = g.month;
    _gDay.text = g.day?.toString() ?? '';
    final s = deriveStartParts(first.solar, p.solarHeader, solarMonthsAr);
    _sYear.text = s.year?.toString() ?? '';
    _sMonth = s.month;
    _sDay.text = s.day?.toString() ?? '';
    final setup = deriveRowsSetup(p);
    if (setup != null) _esfand = setup.solarEsfandLength;
  }

  /// Re-prefills the weekday / start dates / Esfand from the rows (called
  /// when their derived start changed, e.g. undo/redo of a generate).
  /// Empty or underivable rows keep the draft.
  void _followRows(MonthPoster p) {
    if (p.days.isEmpty) return;
    final s = deriveRowsSetup(p, esfandLength: _esfand);
    if (s == null) return;
    _weekday = s.firstWeekday;
    _dayCount = s.dayCount == 29 ? 29 : 30;
    _esfand = s.solarEsfandLength;
    _gYear.text = '${s.gregorianStart.year}';
    _gMonth = s.gregorianStart.month;
    _gDay.text = '${s.gregorianStart.day}';
    _sYear.text = '${s.solarStart.year}';
    _sMonth = s.solarStart.month;
    _sDay.text = '${s.solarStart.day}';
  }

  @override
  void didUpdateWidget(StepSetup old) {
    super.didUpdateWidget(old);
    // Keep the Hijri year field in step with undo/redo.
    final y = widget.poster.hijriYear;
    if (old.poster.hijriYear != y && parseTypedNumber(_hijriYear.text) != y) {
      _hijriYear.text = '$y';
    }
    if (!identical(old.poster.days, widget.poster.days)) {
      _syncFromRows(widget.poster);
    }
  }

  @override
  void dispose() {
    // Keep the draft for this session (e.g. while another step is shown).
    _store.draft =
        SetupDraft(session: widget.session, posterId: widget.poster.id)
          ..hijriYear = _hijriYear.text
          ..gYear = _gYear.text
          ..gDay = _gDay.text
          ..sYear = _sYear.text
          ..sDay = _sDay.text
          ..gMonth = _gMonth
          ..sMonth = _sMonth
          ..weekday = _weekday
          ..dayCount = _dayCount
          ..esfand = _esfand
          ..synced = _synced;
    for (final c in [_hijriYear, _gYear, _gDay, _sYear, _sDay]) {
      c.dispose();
    }
    super.dispose();
  }

  EditorController get _ctl => ref.read(editorProvider.notifier);

  // --- derived form values -------------------------------------------------

  static bool _fourDigits(TextEditingController c) =>
      normalizeDigits(c.text.trim()).length == 4 &&
      parseTypedNumber(c.text) != null;

  DateParts? get _gDate {
    final y = parseTypedNumber(_gYear.text), d = parseTypedNumber(_gDay.text);
    final m = _gMonth;
    if (y == null || d == null || m == null) return null;
    return isValidGregorian(y, m, d) ? DateParts(y, m, d) : null;
  }

  DateParts? get _sDate {
    final y = parseTypedNumber(_sYear.text), d = parseTypedNumber(_sDay.text);
    final m = _sMonth;
    if (y == null || d == null || m == null) return null;
    return isValidSolar(y, m, d, _esfand) ? DateParts(y, m, d) : null;
  }

  /// Complete enough to be judged: a 4-digit year, a month and a day.
  /// Until then no error is shown (no flashing while typing).
  bool get _gComplete =>
      _fourDigits(_gYear) && _gDay.text.trim().isNotEmpty && _gMonth != null;

  bool get _sComplete =>
      _fourDigits(_sYear) && _sDay.text.trim().isNotEmpty && _sMonth != null;

  /// Which part of a complete Gregorian date is wrong (null if none).
  ({bool year, bool day})? get _gErrors {
    if (!_gComplete || _gDate != null) return null;
    final y = parseTypedNumber(_gYear.text)!;
    if (y < 1900 || y > 2200) return (year: true, day: false);
    return (year: false, day: true);
  }

  ({bool year, bool day, bool esfand})? get _sErrors {
    if (!_sComplete || _sDate != null) return null;
    final y = parseTypedNumber(_sYear.text)!;
    if (y < 1300 || y > 1600) return (year: true, day: false, esfand: false);
    final d = parseTypedNumber(_sDay.text)!;
    return (
      year: false,
      day: true,
      esfand: _sMonth == 12 && d == 30 && _esfand == 29,
    );
  }

  int get _effectiveCount =>
      widget.poster.days.isEmpty ? _dayCount : widget.poster.days.length;

  MonthSetup? get _formSetup {
    final g = _gDate, s = _sDate;
    if (g == null || s == null) return null;
    return MonthSetup(
      hijriMonthIndex: widget.poster.hijriMonthIndex,
      hijriYear: widget.poster.hijriYear,
      firstWeekday: _weekday,
      dayCount: _effectiveCount,
      gregorianStart: g,
      solarStart: s,
      solarEsfandLength: _esfand,
    );
  }

  // --- actions -------------------------------------------------------------

  void _snack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  void _onGregorianChanged() {
    setState(() {
      // The first weekday follows a valid Gregorian start date.
      final g = _gDate;
      if (g != null) _weekday = weekdayOfGregorian(g);
    });
  }

  void _onHijriYearChanged(String v) {
    setState(() {});
    final y = parseTypedNumber(v);
    if (isValidHijriYear(y) && y != widget.poster.hijriYear) {
      _ctl.update((p) => p.copyWith(hijriYear: y));
    }
  }

  void _setDayCount(int n) {
    final p = widget.poster;
    if (p.days.isEmpty) {
      setState(() => _dayCount = n);
      return;
    }
    if (p.days.length == n) return;
    // The setup the rows came from (ruling: resize only with that setup).
    final base = deriveRowsSetup(p, esfandLength: _esfand);
    if (base != null) {
      final f = CalendarFill.generate(base.copyWith(dayCount: n));
      _ctl.update(
        (cur) => cur.copyWith(
          days: CalendarFill.resize(cur.days, n, base),
          gregorianHeader: f.gregorianHeader,
          solarHeader: f.solarHeader,
        ),
      );
    } else if (n < p.days.length) {
      // Shrinking needs no setup (rows are only dropped).
      _ctl.update((cur) => cur.copyWith(days: cur.days.sublist(0, n)));
    } else {
      // Never drive new rows from the (possibly unrelated) draft: continue
      // from the last row, or refuse.
      final ext = extendFromLastRow(p, n, esfandLength: _esfand);
      if (ext == null) {
        _snack(
          'تعذّر تحديد تاريخ اليوم التالي — اضغط «تحديث الأيام» لإعادة الإنشاء',
        );
        return;
      }
      _ctl.update(
        (cur) => cur.copyWith(
          days: ext.days,
          gregorianHeader: ext.gregorianHeader,
          solarHeader: ext.solarHeader,
        ),
      );
    }
    setState(() => _dayCount = n);
  }

  Future<void> _generate() async {
    final setup = _formSetup;
    if (setup == null) return;
    if (widget.poster.days.any(_rowHasData)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => const _ConfirmReplaceDialog(),
      );
      if (ok != true || !mounted) return;
    }
    final f = CalendarFill.generate(setup);
    _ctl.update(
      (p) => p.copyWith(
        days: f.days,
        gregorianHeader: f.gregorianHeader,
        solarHeader: f.solarHeader,
      ),
    );
    _snack(
      'تم إنشاء ${f.days.length} يوماً',
      action: SnackBarAction(label: 'تراجع', onPressed: () => _ctl.undo()),
    );
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = widget.poster;
    final hasRows = p.days.isNotEmpty;
    final setup = _formSetup;
    final rowsSetup = deriveRowsSetup(p, esfandLength: _esfand);
    final gErr = _gErrors;
    final sErr = _sErrors;
    final missing = [
      if (!_gComplete) 'التاريخ الميلادي',
      if (!_sComplete) 'التاريخ الشمسي',
    ];
    final differs =
        setup != null &&
        rowsSetup != null &&
        (setup.firstWeekday != rowsSetup.firstWeekday ||
            setup.gregorianStart != rowsSetup.gregorianStart ||
            setup.solarStart != rowsSetup.solarStart ||
            (setup.solarStart.month == 12 &&
                setup.solarEsfandLength != rowsSetup.solarEsfandLength));
    final g = _gDate;
    final realWeekday = g == null ? null : weekdayOfGregorian(g);
    final hijriYearValue = parseTypedNumber(_hijriYear.text);
    final hijriYearError =
        _fourDigits(_hijriYear) && !isValidHijriYear(hijriYearValue)
        ? 'سنة غير صالحة'
        : null;
    final createLabel = hasRows ? 'تحديث الأيام' : 'إنشاء الأيام';
    // Rows exist and match the form: updating is possible but not the
    // suggested next step, so the button is quieter.
    final upToDate = hasRows && rowsSetup != null && !differs;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        // Not lazy: every field stays built (finders, focus traversal and
        // text-field state never depend on the scroll position).
        child: SingleChildScrollView(
          key: const PageStorageKey('step-setup'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasRows
                    ? 'عدّل بداية الشهر ثم اضغط «$createLabel».'
                    : 'حدّد بداية الشهر ثم اضغط «$createLabel».',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.nightlight_round,
                title: 'الشهر الهجري',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: KeyedSubtree(
                          // Recreated when undo/redo changes the month.
                          key: ValueKey('hijri-${p.hijriMonthIndex}'),
                          child: _MonthDropdown(
                            fieldKey: const ValueKey('hijriMonth'),
                            label: 'الشهر',
                            names: hijriMonthsAr,
                            value: p.hijriMonthIndex + 1,
                            onChanged: (m) {
                              if (m - 1 == p.hijriMonthIndex) return;
                              _ctl.update(
                                (cur) => cur.copyWith(hijriMonthIndex: m - 1),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _NumberField(
                          fieldKey: const ValueKey('hijriYear'),
                          controller: _hijriYear,
                          label: 'السنة',
                          errorText: hijriYearError,
                          onChanged: _onHijriYearChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(
                    'التاريخ الهجري يعتمد على رؤية الهلال — يمكنك تعديل أي يوم لاحقاً',
                  ),
                ],
              ),
              _SectionCard(
                icon: Icons.today_rounded,
                title: 'أول يوم في الشهر',
                children: [
                  _WeekdayChips(
                    selected: _weekday,
                    onSelected: (w) => setState(() => _weekday = w),
                  ),
                  if (realWeekday != null && realWeekday != _weekday) ...[
                    const SizedBox(height: 8),
                    _WarningLine(
                      text:
                          'تنبيه: ${g!.day} ${gregorianMonthsAr[g.month - 1]} '
                          '${g.year} يوافق يوم ${realWeekday.ar}',
                      actionLabel: 'اعتمده',
                      onAction: () => setState(() => _weekday = realWeekday),
                    ),
                  ],
                ],
              ),
              _SectionCard(
                icon: Icons.format_list_numbered_rtl_rounded,
                title: 'عدد أيام الشهر',
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 29, label: Text('29 يوماً')),
                        ButtonSegment(value: 30, label: Text('30 يوماً')),
                      ],
                      selected: {
                        if (_effectiveCount == 29 || _effectiveCount == 30)
                          _effectiveCount,
                      },
                      emptySelectionAllowed: true,
                      onSelectionChanged: (s) {
                        if (s.isNotEmpty) _setDayCount(s.first);
                      },
                    ),
                  ),
                  if (hasRows) ...[
                    const SizedBox(height: 8),
                    _InfoLine('تغيير العدد يحتفظ ببيانات الأيام الحالية'),
                  ],
                ],
              ),
              _SectionCard(
                icon: Icons.calendar_month_rounded,
                title: 'التاريخ الميلادي لأول يوم',
                required: !_gComplete,
                children: [
                  _DateRow(
                    keyPrefix: 'g',
                    dayController: _gDay,
                    yearController: _gYear,
                    month: _gMonth,
                    monthNames: gregorianMonthsAr,
                    yearError: gErr?.year ?? false,
                    dayError: gErr?.day ?? false,
                    onMonth: (m) {
                      _gMonth = m;
                      _onGregorianChanged();
                    },
                    onText: (_) => _onGregorianChanged(),
                  ),
                  if (gErr != null) const _ErrorLine('تاريخ غير صالح'),
                ],
              ),
              _SectionCard(
                icon: Icons.wb_sunny_outlined,
                title: 'التاريخ الشمسي لأول يوم',
                required: !_sComplete,
                children: [
                  _DateRow(
                    keyPrefix: 's',
                    dayController: _sDay,
                    yearController: _sYear,
                    month: _sMonth,
                    monthNames: solarMonthsAr,
                    yearError: sErr?.year ?? false,
                    dayError: sErr?.day ?? false,
                    onMonth: (m) => setState(() => _sMonth = m),
                    onText: (_) => setState(() {}),
                  ),
                  if (sErr != null)
                    _ErrorLine(
                      sErr.esfand
                          ? 'يوم 30 في إسفند يتطلب تفعيل «طول إسفند»'
                          : 'تاريخ غير صالح',
                    ),
                  if (_sMonth == 12) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'طول إسفند',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 29,
                              label: Text('29', key: ValueKey('esfand-29')),
                            ),
                            ButtonSegment(
                              value: 30,
                              label: Text('30', key: ValueKey('esfand-30')),
                            ),
                          ],
                          selected: {_esfand},
                          onSelectionChanged: (s) =>
                              setState(() => _esfand = s.first),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _Summary(
                setup: setup,
                hasRows: hasRows,
                upToDate: upToDate,
                differs: differs,
                createLabel: createLabel,
                missing: missing,
              ),
              const SizedBox(height: 12),
              (upToDate ? FilledButton.tonalIcon : FilledButton.icon)(
                onPressed: setup == null ? null : _generate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: Icon(
                  hasRows ? Icons.refresh_rounded : Icons.auto_awesome_rounded,
                ),
                label: Text(createLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

// Soft amber "مطلوب" tag that sits with the green/cream palette
// (contrast about 7:1).
const _requiredTagBg = Color(0xFFFBEFD0);
const _requiredTagFg = Color(0xFF6A4A00);

/// The 7 weekdays as evenly sized chips: one row when they fit, otherwise
/// a balanced 4 + 3 (never an orphan chip).
class _WeekdayChips extends StatelessWidget {
  const _WeekdayChips({required this.selected, required this.onSelected});
  final Weekday selected;
  final ValueChanged<Weekday> onSelected;

  static const _gap = 8.0;
  static const _chipPad = 4.0;
  // Horizontal chip padding plus border and rounding slack.
  static const _overhead = 2 * _chipPad + 8;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    var widest = 0.0;
    for (final w in Weekday.values) {
      final tp = TextPainter(
        text: TextSpan(text: w.ar, style: style),
        textDirection: dir,
        textScaler: scaler,
      )..layout();
      if (tp.width > widest) widest = tp.width;
      tp.dispose();
    }
    return LayoutBuilder(
      builder: (context, c) {
        final n = Weekday.values.length;
        final fitsOneRow =
            n * (widest + _overhead + 8) + (n - 1) * _gap <= c.maxWidth;
        final cols = fitsOneRow ? n : 4;
        final cw = (c.maxWidth - _gap * (cols - 1)) / cols;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final w in Weekday.values)
              SizedBox(
                width: cw,
                child: Center(
                  child: ChoiceChip(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _chipPad,
                      vertical: 8,
                    ),
                    labelPadding: EdgeInsets.zero,
                    label: SizedBox(
                      width: cw - _overhead,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(w.ar, maxLines: 1),
                      ),
                    ),
                    selected: selected == w,
                    showCheckmark: false,
                    onSelected: (_) => onSelected(w),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.required = false,
  });

  final IconData icon;
  final String title;

  /// Shows a "مطلوب" tag while the section still needs input.
  final bool required;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (required)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _requiredTagBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'مطلوب',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _requiredTagFg,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.errorText,
    this.error = false,
    this.maxLength = 4,
  });

  /// Error state without a message (the card shows one message below).
  final bool error;

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final int maxLength;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    textInputAction: TextInputAction.next,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
      LengthLimitingTextInputFormatter(maxLength),
    ],
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      error: errorText == null && error ? const SizedBox.shrink() : null,
      isDense: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    onChanged: onChanged,
  );
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({
    required this.fieldKey,
    required this.label,
    required this.names,
    required this.value,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final List<String> names;

  /// 1-based month, or null when unknown.
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: fieldKey,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'اختر',
      isDense: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    items: [
      for (var i = 0; i < names.length; i++)
        DropdownMenuItem(
          value: i + 1,
          child: Text(names[i], overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (m) {
      if (m != null) onChanged(m);
    },
  );
}

/// Day · month · year, in Arabic reading order (day on the right).
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.keyPrefix,
    required this.dayController,
    required this.yearController,
    required this.month,
    required this.monthNames,
    required this.onMonth,
    required this.onText,
    this.yearError = false,
    this.dayError = false,
  });

  final bool yearError, dayError;
  final String keyPrefix;
  final TextEditingController dayController, yearController;
  final int? month;
  final List<String> monthNames;
  final ValueChanged<int> onMonth;
  final ValueChanged<String> onText;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: _NumberField(
          fieldKey: ValueKey('${keyPrefix}Day'),
          controller: dayController,
          label: 'اليوم',
          maxLength: 2,
          error: dayError,
          onChanged: onText,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 4,
        child: _MonthDropdown(
          fieldKey: ValueKey('${keyPrefix}Month'),
          label: 'الشهر',
          names: monthNames,
          value: month,
          onChanged: onMonth,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 3,
        child: _NumberField(
          fieldKey: ValueKey('${keyPrefix}Year'),
          controller: yearController,
          label: 'السنة',
          error: yearError,
          onChanged: onText,
        ),
      ),
    ],
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: cs.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

/// What the create button will do, or what is still missing.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.setup,
    required this.hasRows,
    required this.upToDate,
    required this.differs,
    required this.createLabel,
    required this.missing,
  });

  final MonthSetup? setup;
  final bool hasRows, upToDate, differs;
  final String createLabel;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = setup;
    final lines = <Widget>[];
    if (s == null) {
      if (missing.isNotEmpty) {
        lines.add(
          Text(
            'أكمل الحقول المطلوبة: ${missing.join('، ')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      }
    } else {
      var end = s.gregorianStart;
      var endWd = s.firstWeekday;
      for (var i = 1; i < s.dayCount; i++) {
        end = nextGregorianDay(end);
        endWd = endWd.next;
      }
      final verb = hasRows ? 'سيُعاد إنشاء' : 'سيُنشأ';
      if (upToDate) {
        lines.add(
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الأيام جاهزة (${s.dayCount} يوماً) — تابع إلى «الأيام»',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        lines.add(
          Text(
            '$verb ${s.dayCount} يوماً من ${_dateText(s.firstWeekday, s.gregorianStart)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        );
        lines.add(
          Text(
            'حتى ${_dateText(endWd, end)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        );
        if (differs) {
          lines.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'اضغط «$createLabel» لتطبيق التغييرات',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.tertiary),
              ),
            ),
          );
        }
      }
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines,
        ),
      ),
    );
  }
}

class _ConfirmReplaceDialog extends StatelessWidget {
  const _ConfirmReplaceDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: cs.error),
      title: const Text('سيتم استبدال بيانات الأيام. متابعة؟'),
      content: const Text(
        'ستُحذف الأوقات والملاحظات والتمييز. يمكنك التراجع بعد ذلك.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('استبدال'),
        ),
      ],
    );
  }
}
