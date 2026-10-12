# Taqweem Poster Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter app (Arabic-only, RTL) where a user enters one month of Islamic calendar data and exports a print-quality poster (PNG/PDF) in one of five visual templates.

**Architecture:** Pure-Dart domain (`MonthPoster` value object, calendar fill, time formatting, validation) → JSON drafts repository → Riverpod state → feature screens (home, 4-step editor, preview/export). Every template is a `PosterTemplate` = a `PosterTheme` (palette, fonts, background/frame painters) rendered by ONE shared `PosterLayout` at fixed 1000×2200, so all templates show identical data. Export captures that widget via `RepaintBoundary.toImage` and wraps it in a PDF page.

**Tech Stack:** Flutter 3.47.6 / Dart ^3.13.5, flutter_riverpod, path_provider, pdf, share_plus, bundled fonts (Amiri, Tajawal, Aref Ruqaa).

**Spec:** `docs/superpowers/specs/2026-10-12-taqweem-poster-design.md` (reference data analysis: `findings.md`, images: `templates/`).

## Global Constraints

- UI is Arabic only, RTL (`Directionality(textDirection: TextDirection.rtl)` at app root, `Locale('ar')`).
- Poster logical size is exactly `Size(1000, 2200)`; export pixelRatio 2–4.
- Times display as `h:mm` — no leading zero, no AM/PM (e.g. `4:18`, `11:25`, `5:27`).
- Weekday spelling follows the reference: السبت الأحد الأثنين الثلاثاء الأربعاء الخميس الجمعة.
- 4 prayer columns only: الفجر, الشروق, الظهر, المغرب. Month length 29 or 30 days.
- Footer default: `ملاحظات: 1- على كل شخص ان يعمل حسب فتوى مرجعه . 2- الأوقات مأخوذة من تقويم الهادي .`
- No invented data: empty stays empty; unreadable seed cells are flagged `uncertain`, never guessed.
- Fonts are bundled assets (no runtime network). No cloud/accounts. No prayer-time calculation.
- **GIT RULE (user's global instruction):** never `git add`/`commit`/`push`. Every "checkpoint" step below means: run tests + `flutter analyze`, leave changes uncommitted, tell the user. Do not add commit steps.
- Per `planning-with-files`: keep `task_plan.md` (project root) current: one line per task, status updated after each.

## Review Focus

1. Month change mid-table (e.g. Oct→Nov, Dec→Jan year rollover; Esfand 29/30): header shows both months, label cell appears on the right row, year shown `2026/2027` when crossing years. Tests in Task 4.
2. Typing times with Arabic-Indic digits (`٤١٨`), no colon (`418`, `1125`), or garbage (`4:75`, `abc`): parsed or rejected, never crash. Task 2.
3. A 400-character note, a note with only honorifics, and an empty note in a 30-row poster: no overflow/clipping in every template. Task 9 + each template task.
4. Corrupt/partial JSON draft file on disk: app lists the rest, skips the bad one, does not crash. Task 7.
5. 29-day month, then user switches to 30 (and back): rows added/removed without losing existing entries. Task 4 + Task 13.

## File Structure

```
pubspec.yaml                          deps + fonts
assets/fonts/*.ttf
lib/main.dart                         ProviderScope + runApp
lib/app.dart                          MaterialApp (RTL, theme, routes)
lib/core/app_theme.dart               Material theme tokens (UI chrome)
lib/core/arabic_digits.dart           normalizeDigits()
lib/domain/weekday.dart               Weekday enum
lib/domain/month_names.dart           hijri/gregorian/solar Arabic month names
lib/domain/time_format.dart           PrayerSlot, parse/format/shift/to24h
lib/domain/models.dart                DayCell, PrayerTimes, DayRow, PosterTexts..., MonthPoster (+json)
lib/domain/calendar_fill.dart         MonthSetup, DateParts, CalendarFill
lib/domain/validation.dart            PosterIssue, validatePoster
lib/domain/occasions_library.dart     seeded occasion suggestions
lib/data/poster_repository.dart       JSON drafts CRUD
lib/data/seed_reference.dart          default texts + transcribed reference month
lib/state/providers.dart              repositoryProvider, postersProvider, editorProvider
lib/state/editor_controller.dart      EditorController (undo, autosave)
lib/templates/poster_template.dart    PosterTemplate, PosterTheme, kPosterSize
lib/templates/registry.dart           allTemplates, templateById
lib/templates/shared/fit_text.dart    FitText (auto-shrink, never clip)
lib/templates/shared/poster_layout.dart  shared layout (header/table/footer/side Q&A)
lib/templates/shared/painters.dart    pattern/border/mosque helper painters
lib/templates/{navy_gold,cream_gold,minimal_modern,deep_green,mosque_blue}.dart
lib/export/poster_exporter.dart       toPng, toPdf, save, share
lib/features/home/home_screen.dart
lib/features/editor/editor_shell.dart + step_setup.dart + step_grid.dart + step_texts.dart + step_export.dart
lib/features/preview/poster_preview.dart  FittedBox + RepaintBoundary wrapper
test/... mirrors lib/
```

---

### Task 1: Project foundation (deps, fonts, RTL app shell)

**Files:**
- Modify: `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart`, `analysis_options.yaml` (keep defaults)
- Create: `lib/app.dart`, `lib/core/app_theme.dart`, `lib/core/arabic_digits.dart`, `assets/fonts/*`, `task_plan.md`

**Interfaces:**
- Produces: `class TaqweemApp extends ConsumerWidget`; `String normalizeDigits(String)`; `ThemeData buildAppTheme()`.

- [ ] **Step 1: Add dependencies**

Run: `cd /home/mahdi/Desktop/projects/taqweem && flutter pub add flutter_riverpod path_provider pdf share_plus && flutter pub add --dev flutter_test --sdk=flutter`
Expected: `pubspec.yaml` lists the four packages; `flutter pub get` succeeds.

- [ ] **Step 2: Download bundled fonts**

```bash
mkdir -p assets/fonts && cd assets/fonts
B=https://github.com/google/fonts/raw/main/ofl
curl -fL -o Amiri-Regular.ttf  $B/amiri/Amiri-Regular.ttf
curl -fL -o Amiri-Bold.ttf     $B/amiri/Amiri-Bold.ttf
curl -fL -o Tajawal-Regular.ttf $B/tajawal/Tajawal-Regular.ttf
curl -fL -o Tajawal-Bold.ttf    $B/tajawal/Tajawal-Bold.ttf
curl -fL -o ArefRuqaa-Regular.ttf $B/arefruqaa/ArefRuqaa-Regular.ttf
curl -fL -o ArefRuqaa-Bold.ttf    $B/arefruqaa/ArefRuqaa-Bold.ttf
ls -l   # every file must be > 50 KB
```
Expected: 6 files, each >50 KB. If a URL 404s, find the correct file name with `curl -s https://api.github.com/repos/google/fonts/contents/ofl/<family>` and retry (do not substitute a different family silently; log it in `findings.md`).

- [ ] **Step 3: Register fonts in `pubspec.yaml`** (under `flutter:`)

```yaml
  fonts:
    - family: Amiri
      fonts:
        - asset: assets/fonts/Amiri-Regular.ttf
        - asset: assets/fonts/Amiri-Bold.ttf
          weight: 700
    - family: Tajawal
      fonts:
        - asset: assets/fonts/Tajawal-Regular.ttf
        - asset: assets/fonts/Tajawal-Bold.ttf
          weight: 700
    - family: ArefRuqaa
      fonts:
        - asset: assets/fonts/ArefRuqaa-Regular.ttf
        - asset: assets/fonts/ArefRuqaa-Bold.ttf
          weight: 700
```

- [ ] **Step 4: Write failing test** `test/core/arabic_digits_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/arabic_digits.dart';

void main() {
  test('normalizes Arabic-Indic and Persian digits', () {
    expect(normalizeDigits('٤١٨'), '418');
    expect(normalizeDigits('۱۱:۲۵'), '11:25');
    expect(normalizeDigits('5:27'), '5:27');
  });
}
```

- [ ] **Step 5: Run — expect FAIL** (`flutter test test/core/arabic_digits_test.dart`: uri doesn't exist)

- [ ] **Step 6: Implement** `lib/core/arabic_digits.dart`

```dart
/// Converts Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII.
String normalizeDigits(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(r - 0x0660 + 0x30);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(r - 0x06F0 + 0x30);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}
```

- [ ] **Step 7: App shell.** `lib/core/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF0B3D2E);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: const Color(0xFFF7F4EC),
    appBarTheme: const AppBarTheme(centerTitle: true),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(), isDense: true),
    visualDensity: VisualDensity.standard,
  );
}
```
`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_theme.dart';
import 'features/home/home_screen.dart';

class TaqweemApp extends StatelessWidget {
  const TaqweemApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'تقويم',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      );
}
```
Add `flutter_localizations: {sdk: flutter}` to pubspec dependencies. `lib/main.dart`: `runApp(const ProviderScope(child: TaqweemApp()));`. Create a temporary `HomeScreen` stub (`Scaffold(body: Center(child: Text('تقويم')))`) in `lib/features/home/home_screen.dart`; Task 12 replaces it. Replace `test/widget_test.dart` with a smoke test that pumps `ProviderScope(child: TaqweemApp())` and finds `'تقويم'`.

- [ ] **Step 8: Create `task_plan.md`** at project root listing Tasks 1–21 with status `pending`; mark Task 1 `in_progress`.

- [ ] **Step 9: Checkpoint:** `flutter test && flutter analyze` → all pass, no issues. Do NOT commit.

---

### Task 2: Time parsing / formatting / shifting

**Files:**
- Create: `lib/domain/time_format.dart`, `lib/domain/weekday.dart`, `lib/domain/month_names.dart`
- Test: `test/domain/time_format_test.dart`

**Interfaces:**
- Consumes: `normalizeDigits` (Task 1).
- Produces:
```dart
enum PrayerSlot { fajr, shurooq, zuhr, maghrib }  // .labelAr
String? formatTime(int? minutes);          // 267 -> "4:27"; null -> null
int? parseTimeInput(String raw);           // "418" "4:18" "٤١٨" -> 258 ; invalid -> null
int shiftMinutes(int minutes, int delta);  // wraps inside 1:00..12:59
int to24h(PrayerSlot slot, int minutes);   // for ordering checks
enum Weekday { saturday..friday }          // .ar, .next, static Weekday fromIndex
const List<String> hijriMonthsAr, gregorianMonthsAr, solarMonthsAr;
```
Stored minutes = `hour*60+minute` exactly as displayed (hour 1–12).

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/time_format.dart';

void main() {
  group('formatTime', () {
    test('no leading zero', () {
      expect(formatTime(4 * 60 + 18), '4:18');
      expect(formatTime(11 * 60 + 5), '11:05');
      expect(formatTime(null), isNull);
    });
  });
  group('parseTimeInput', () {
    test('colon, digits only, arabic digits', () {
      expect(parseTimeInput('4:18'), 4 * 60 + 18);
      expect(parseTimeInput('418'), 4 * 60 + 18);
      expect(parseTimeInput('1125'), 11 * 60 + 25);
      expect(parseTimeInput('٤١٨'), 4 * 60 + 18);
    });
    test('rejects garbage', () {
      expect(parseTimeInput('4:75'), isNull);
      expect(parseTimeInput('abc'), isNull);
      expect(parseTimeInput(''), isNull);
      expect(parseTimeInput('0:30'), isNull);
      expect(parseTimeInput('13:00'), isNull);
      expect(parseTimeInput('12345'), isNull);
    });
  });
  group('shiftMinutes', () {
    test('adds and wraps in 12h window', () {
      expect(shiftMinutes(4 * 60 + 58, 5), 5 * 60 + 3);
      expect(shiftMinutes(12 * 60 + 58, 5), 1 * 60 + 3);
      expect(shiftMinutes(1 * 60 + 2, -5), 12 * 60 + 57);
    });
  });
  group('to24h', () {
    test('zuhr 11:25 stays AM, 1:05 becomes PM; maghrib is PM', () {
      expect(to24h(PrayerSlot.fajr, 4 * 60 + 18), 4 * 60 + 18);
      expect(to24h(PrayerSlot.zuhr, 11 * 60 + 25), 11 * 60 + 25);
      expect(to24h(PrayerSlot.zuhr, 12 * 60 + 5), 12 * 60 + 5);
      expect(to24h(PrayerSlot.zuhr, 1 * 60 + 5), 13 * 60 + 5);
      expect(to24h(PrayerSlot.maghrib, 5 * 60 + 27), 17 * 60 + 27);
    });
  });
}
```

- [ ] **Step 2: Run** `flutter test test/domain/time_format_test.dart` → FAIL (missing file).

- [ ] **Step 3: Implement** `lib/domain/time_format.dart`

```dart
import '../core/arabic_digits.dart';

enum PrayerSlot {
  fajr('الفجر'),
  shurooq('الشروق'),
  zuhr('الظهر'),
  maghrib('المغرب');

  const PrayerSlot(this.labelAr);
  final String labelAr;
}

String? formatTime(int? minutes) {
  if (minutes == null) return null;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

int? parseTimeInput(String raw) {
  final s = normalizeDigits(raw.trim());
  if (s.isEmpty) return null;
  int h, m;
  if (s.contains(':')) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null || parts[1].length != 2) return null;
    h = hh;
    m = mm;
  } else {
    if (!RegExp(r'^\d{3,4}$').hasMatch(s)) return null;
    m = int.parse(s.substring(s.length - 2));
    h = int.parse(s.substring(0, s.length - 2));
  }
  if (h < 1 || h > 12 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

int shiftMinutes(int minutes, int delta) {
  const lo = 60, span = 720; // 1:00 .. 12:59
  return (((minutes + delta - lo) % span) + span) % span + lo;
}

int to24h(PrayerSlot slot, int minutes) {
  final h = minutes ~/ 60;
  switch (slot) {
    case PrayerSlot.fajr:
    case PrayerSlot.shurooq:
      return minutes;
    case PrayerSlot.zuhr:
      return h < 10 ? minutes + 720 : minutes; // 1:05 -> 13:05, 12:05 stays
    case PrayerSlot.maghrib:
      return h < 12 ? minutes + 720 : minutes;
  }
}
```

- [ ] **Step 4: Weekday + month names.** `lib/domain/weekday.dart`:

```dart
enum Weekday {
  saturday('السبت'), sunday('الأحد'), monday('الأثنين'), tuesday('الثلاثاء'),
  wednesday('الأربعاء'), thursday('الخميس'), friday('الجمعة');
  const Weekday(this.ar);
  final String ar;
  Weekday get next => Weekday.values[(index + 1) % 7];
}
```
`lib/domain/month_names.dart`:

```dart
const hijriMonthsAr = ['محرم','صفر','ربيع الأول','ربيع الثاني','جمادى الأول','جمادى الثانية','رجب','شعبان','رمضان','شوال','ذو القعدة','ذو الحجة'];
const gregorianMonthsAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
const solarMonthsAr = ['فروردين','أرديبهشت','خرداد','تير','مرداد','شهريور','مهر','آبان','آذر','دي','بهمن','اسفند'];
```
(Names for ربيع الثاني / جمادى الثانية / dates not in the 5 reference images are conventional spellings — note in `findings.md`.)

- [ ] **Step 5: Run tests → PASS. Checkpoint** (`flutter analyze`; no commit).

---

### Task 3: Domain models + JSON round-trip

**Files:**
- Create: `lib/domain/models.dart`
- Test: `test/domain/models_test.dart`

**Interfaces:**
- Consumes: `Weekday`, `PrayerSlot`.
- Produces (all immutable, `copyWith`, `toJson()`, `fromJson`):

```dart
enum DayField { weekday, hijri, gregorian, solar, fajr, shurooq, zuhr, maghrib, note }
class DayCell { final int? number; final String? label; const DayCell.number(int n); const DayCell.label(String l); bool get isLabel; }
class PrayerTimes { final int? fajr, shurooq, zuhr, maghrib; int? operator [](PrayerSlot s); PrayerTimes withSlot(PrayerSlot s, int? v); }
class DayRow { Weekday weekday; int hijriDay; DayCell gregorian, solar; PrayerTimes times; String note; bool highlighted; Set<DayField> uncertain; DayRow copyWith({...}); }
class HeaderQuote { String text, attribution; }
class ClosingArticle { String author, body; }
class SideQa { String question, answer; }
class PosterTexts { String title; HeaderQuote rightQuote, leftQuote; String braceQuote; ClosingArticle article; SideQa sideRight, sideLeft; String footerNotes, fatiha; }
class MonthPoster { String id; DateTime updatedAt; int hijriMonthIndex; int hijriYear; String gregorianHeader, solarHeader; List<DayRow> days; PosterTexts texts; String templateId;
  String get hijriHeader; // "جمادى الأول\n1448"
  MonthPoster copyWith({...}); }
```

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/weekday.dart';

void main() {
  test('MonthPoster JSON round trip keeps every field', () {
    final p = MonthPoster(
      id: 'a1', updatedAt: DateTime.utc(2026, 10, 12),
      hijriMonthIndex: 4, hijriYear: 1448,
      gregorianHeader: 'أكتوبر\nنوفمبر\n2026', solarHeader: 'مهر\nآبان\n1405',
      days: [
        DayRow(weekday: Weekday.tuesday, hijriDay: 1,
          gregorian: const DayCell.number(13), solar: const DayCell.label('آبان'),
          times: const PrayerTimes(fajr: 258, shurooq: 335, zuhr: 685, maghrib: 327),
          note: 'ملاحظة (ع)', highlighted: true, uncertain: {DayField.note}),
      ],
      texts: PosterTexts.empty(), templateId: 'navy_gold');
    final back = MonthPoster.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    expect(back.days.single.solar.label, 'آبان');
    expect(back.days.single.uncertain, {DayField.note});
    expect(back.hijriHeader, 'جمادى الأول\n1448');
  });

  test('fromJson tolerates missing optional keys', () {
    final p = MonthPoster.fromJson({'id': 'x', 'hijriMonthIndex': 0, 'hijriYear': 1446});
    expect(p.days, isEmpty);
    expect(p.templateId, 'navy_gold');
  });

  test('PrayerTimes.withSlot replaces one slot only', () {
    const t = PrayerTimes(fajr: 1, shurooq: 2, zuhr: 3, maghrib: 4);
    final u = t.withSlot(PrayerSlot.zuhr, 9);
    expect([u.fajr, u.shurooq, u.zuhr, u.maghrib], [1, 2, 9, 4]);
  });
}
```
(import `time_format.dart` too for `PrayerSlot`.)

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement `lib/domain/models.dart`.** Write all classes listed in Interfaces. Rules: `fromJson` uses `?? default` for every key (`templateId` default `'navy_gold'`, `days` default `[]`, `updatedAt` default `DateTime.fromMillisecondsSinceEpoch(0)`); `uncertain` serialized as list of `DayField.name`, unknown names ignored; `DayCell` json `{'n': int}` or `{'l': String}`; `PosterTexts.empty()` returns all-empty strings with `title: 'تقويم أهل البيت'`, `footerNotes` = the Global Constraints footer string, `fatiha: 'الفاتحة لأرواح المؤمنين والمؤمنات من الأولين والآخرين'`. `hijriHeader` = `'${hijriMonthsAr[hijriMonthIndex]}\n$hijriYear'`. `MonthPoster.toJson` writes `updatedAt.toIso8601String()`.

- [ ] **Step 4: Run → PASS. Checkpoint.**

---

### Task 4: CalendarFill (rows from month setup)

**Files:**
- Create: `lib/domain/calendar_fill.dart`
- Test: `test/domain/calendar_fill_test.dart`

**Interfaces:**
- Consumes: models, `Weekday`, month names.
- Produces:
```dart
class DateParts { final int year, month, day; const DateParts(this.year, this.month, this.day); }
class MonthSetup { int hijriMonthIndex, hijriYear; Weekday firstWeekday; int dayCount; DateParts gregorianStart, solarStart; int solarEsfandLength; /*default 29*/ }
class FilledMonth { List<DayRow> days; String gregorianHeader, solarHeader; }
class CalendarFill {
  static FilledMonth generate(MonthSetup s);
  /// Resize keeping existing rows' data; new rows continue weekday/dates.
  static List<DayRow> resize(List<DayRow> rows, int newCount, MonthSetup s);
}
```
Rules: Gregorian/solar day numbers increment; at a month boundary the row's cell is `DayCell.label(<new month name>)` (the day number is NOT shown on that row, as in the reference) and the following row continues numbering from 2. Header = month names involved joined `\n` + `\n` + year (`2026` or `2026/2027` when the year changes). Solar months 1–6 have 31 days, 7–11 have 30, 12 has `solarEsfandLength`; solar year increments after month 12.

- [ ] **Step 1: Write failing tests** (cover Review Focus 1 & 5)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/calendar_fill.dart';
import 'package:taqweem/domain/weekday.dart';

MonthSetup oct2026() => MonthSetup(
    hijriMonthIndex: 4, hijriYear: 1448, firstWeekday: Weekday.tuesday,
    dayCount: 30, gregorianStart: const DateParts(2026, 10, 13),
    solarStart: const DateParts(1405, 7, 21));

void main() {
  test('reference month: Oct 13 2026 start rolls to Nov and Aban', () {
    final f = CalendarFill.generate(oct2026());
    expect(f.days.length, 30);
    expect(f.days[0].weekday, Weekday.tuesday);
    expect(f.days[1].weekday, Weekday.wednesday);
    expect(f.days[0].gregorian.number, 13);
    expect(f.days[18].gregorian.number, 31);      // day 19 = Oct 31
    expect(f.days[19].gregorian.label, 'نوفمبر');   // day 20 = Nov 1 label
    expect(f.days[20].gregorian.number, 2);
    expect(f.days[9].solar.number, 30);           // Mehr has 30 days
    expect(f.days[10].solar.label, 'آبان');
    expect(f.days[11].solar.number, 2);
    expect(f.gregorianHeader, 'أكتوبر\nنوفمبر\n2026');
    expect(f.solarHeader, 'مهر\nآبان\n1405');
  });

  test('year rollover in header and Dec->Jan label', () {
    final f = CalendarFill.generate(MonthSetup(
        hijriMonthIndex: 5, hijriYear: 1446, firstWeekday: Weekday.monday,
        dayCount: 30, gregorianStart: const DateParts(2024, 12, 25),
        solarStart: const DateParts(1403, 10, 5)));
    expect(f.gregorianHeader, 'ديسمبر\nيناير\n2024/2025');
    expect(f.days.any((d) => d.gregorian.label == 'يناير'), isTrue);
  });

  test('Esfand uses solarEsfandLength and rolls the solar year', () {
    final f = CalendarFill.generate(MonthSetup(
        hijriMonthIndex: 8, hijriYear: 1446, firstWeekday: Weekday.saturday,
        dayCount: 30, gregorianStart: const DateParts(2025, 3, 1),
        solarStart: const DateParts(1403, 12, 11), solarEsfandLength: 30));
    expect(f.days.any((d) => d.solar.label == 'فروردين'), isTrue);
    expect(f.solarHeader.endsWith('1403/1404'), isTrue);
  });

  test('resize 29 -> 30 -> 29 keeps data of surviving rows', () {
    final s = oct2026();
    var rows = CalendarFill.generate(MonthSetup(
        hijriMonthIndex: s.hijriMonthIndex, hijriYear: s.hijriYear,
        firstWeekday: s.firstWeekday, dayCount: 29,
        gregorianStart: s.gregorianStart, solarStart: s.solarStart)).days;
    rows[3] = rows[3].copyWith(note: 'حفظ');
    final r30 = CalendarFill.resize(rows, 30, s);
    expect(r30.length, 30);
    expect(r30[3].note, 'حفظ');
    expect(r30[29].hijriDay, 30);
    expect(CalendarFill.resize(r30, 29, s).length, 29);
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.** Algorithm in `generate`: iterate `i in 0..dayCount-1` with running `(gy,gm,gd)` and `(sy,sm,sd)`; row 0 uses the start parts as numbers. For `i>0`: `gd++`; if `gd > DateTime(gy, gm + 1, 0).day` → `gm++` (if 13 → `gm=1, gy++`), `gd=1`, cell = `DayCell.label(gregorianMonthsAr[gm-1])`, and record month change; next iteration the number shown is `gd+1`… i.e. after a label row, `gd` is 1 and the following row's number is 2 (so the label row consumes day 1). Same for solar with `solarMonthLength(sm)`; after `sm` 12 overflow set `sm=1, sy++`. `weekday` advances via `.next`. `hijriDay = i+1`. Headers: ordered distinct month names touched (start month + each label month), joined `\n`, then year string (`'$startYear'` or `'$startYear/$endYear'`). `resize`: if `newCount <= rows.length` return `rows.sublist(0,newCount)` with hijriDay intact; else regenerate with `generate(s with dayCount:newCount)` and for `i < rows.length` keep `rows[i]` (existing data wins), taking only the new tail rows from the generated list.

- [ ] **Step 4: Run → PASS. Checkpoint.**

---

### Task 5: Validation

**Files:**
- Create: `lib/domain/validation.dart`
- Test: `test/domain/validation_test.dart`

**Interfaces:**
- Produces:
```dart
enum IssueKind { missingTime, timeOrder, weekdayBreak, hijriBreak, dayCount }
class PosterIssue { final int? dayIndex; final IssueKind kind; final String messageAr; }
List<PosterIssue> validatePoster(MonthPoster p);
```
Rules: day count not 29/30 → `dayCount`; row `i` weekday must equal row 0 weekday advanced `i` times → `weekdayBreak`; `hijriDay != i+1` → `hijriBreak`; any slot null on a row (unless that slot is in `uncertain`) → `missingTime`; for rows with all four times, `to24h` sequence must be strictly increasing fajr<shurooq<zuhr<maghrib → `timeOrder`. Arabic messages e.g. `'اليوم ${i+1}: وقت ${slot.labelAr} غير مُدخَل'`.

- [ ] **Step 1: Failing tests:** (a) valid row (4:18, 5:35, 11:25, 5:27) yields no issues; (b) null zuhr → one `missingTime` with `dayIndex` 0; (c) maghrib 11:05 (24h 23:05 is > zuhr, fine) vs shurooq 6:00 and zuhr 5:00 (to24h → 17:00 > shurooq? 17:00 > 6:00 ok) — use clearly bad: fajr 6:00, shurooq 5:00 → `timeOrder`; (d) swapped weekday on row 2 → `weekdayBreak`; (e) 28 rows → `dayCount`. Build posters with a small helper using `CalendarFill.generate`.
- [ ] **Step 2: Run → FAIL. Step 3: Implement. Step 4: Run → PASS. Checkpoint.**

---

### Task 6: Seed data — default texts, occasions library, transcribed reference month

**Files:**
- Create: `lib/data/seed_reference.dart`, `lib/domain/occasions_library.dart`
- Test: `test/data/seed_reference_test.dart`

**Interfaces:**
- Produces: `PosterTexts defaultTexts()`; `MonthPoster seedReferenceMonth()`; `const List<String> occasionSuggestions`; `List<String> searchOccasions(String query)` (substring match, max 8).

**Why this task has a procedure instead of 30 pasted rows:** the data must be exact and I can only read the scan at limited resolution; guessing digits violates the accuracy rule. So transcribe from zoomed crops and flag doubt.

- [ ] **Step 1: Crop the source table into readable strips** (scratchpad dir, not the project):

```bash
S=/tmp/claude-1000/-home-mahdi-Desktop-projects-taqweem/324928d2-35bd-48cd-a591-4d5cfcdf8bd1/scratchpad
mkdir -p $S/crops
python3 -I - <<'EOF'
from PIL import Image
src="/home/mahdi/Desktop/projects/taqweem/templates/WhatsApp Image 2026-10-12 at 9.09.58 PM.jpeg"
im=Image.open(src); w,h=im.size
top,bot=int(h*0.335),int(h*0.555)   # table band; adjust after viewing
band=im.crop((0,top,w,bot))
n=5; step=band.height//n
for i in range(n):
    c=band.crop((0,i*step,w,(i+1)*step if i<n-1 else band.height))
    c=c.resize((c.width*2,c.height*2),Image.LANCZOS); c.save(f"{'/tmp/claude-1000/-home-mahdi-Desktop-projects-taqweem/324928d2-35bd-48cd-a591-4d5cfcdf8bd1/scratchpad'}/crops/p{i}.png")
EOF
```
(If PIL is missing: `pip install --user pillow`; if the band is off, adjust fractions after Read-ing the first crop.) Then `Read` each `p*.png` and transcribe 6 rows per strip.

- [ ] **Step 2: Write the seed** in `seedReferenceMonth()` for Jumada I 1448 (Oct 13 – Nov 11 2026, starts Tuesday): build rows via `CalendarFill.generate(...)` with the Task-4 `oct2026()` setup, then override per row `times`, `note`, `highlighted` from the transcription. Row format (first rows, verified against the scan at planning time — re-verify):

```dart
DayRow r(int i, int f, int s, int z, int m, String note, {bool hl = false, Set<DayField> u = const {}}) // helper, times as h*60+m
// i=0  Tue: 4:18 5:35 11:25 5:27  note 'غداً استشهاد شهيد المحراب الخامس آية الله اشرف اصفهاني 1982م'
// i=1  Wed: 4:18 5:35 11:25 5:26  note 'بدأ نزول الوحي على النبي محمد(ص)'
// i=2  Thu: 4:19 5:36 11:25 5:25  note ''
// i=4  Sat: 4:20 5:37 11:24 5:23  highlighted, 'مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة'
```
Any cell not clearly legible → add to `uncertain` and leave the value `null` (do NOT guess). Highlight = row rendered black in the scan (rows 5, 13, 22 in this image at planning time). Texts from the same image: right quote `نحن وسيلته في خلقه، ونحن خاصته، ومحل قدسه، ونحن حجته في غيبه، ونحن ورثة أنبيائه` — `فاطمة الزهراء(س)`; left quote `صلاة النوافل قربان والى ا... لكل مؤمن` — `الإمام الكاظم(ع)`; brace quote `إذا عرضتم الإسلام على حقيقته للعالم، وإذا طبقتموه كما هو، فإن السيادة والرفعة ستكون من نصيبكم.`; article author `الشهيد مرتضى مطهري`, body = the paragraph in the scan; Q&As from the margins (transcribe fully, mark partially cropped words with `…`).

- [ ] **Step 3: Failing→passing tests** `seed_reference_test.dart`:

```dart
test('seed month is structurally valid', () {
  final p = seedReferenceMonth();
  expect(p.days.length, 30);
  expect(p.hijriHeader, 'جمادى الأول\n1448');
  expect(p.days.first.weekday.ar, 'الثلاثاء');
  expect(p.days.first.times.fajr, 4 * 60 + 18);
  final hard = validatePoster(p).where((i) => i.kind != IssueKind.missingTime);
  expect(hard, isEmpty);   // order/weekday/hijri must be right; missing = flagged uncertain
});
test('search finds occasions by substring', () {
  expect(searchOccasions('الزهراء'), isNotEmpty);
});
```
`occasionSuggestions`: seed with every distinct note string from the 5 reference images' legible rows (transcribe at least the 30 notes of the seed month plus any other clearly legible ones; no invented occasions).

- [ ] **Step 4: Run tests until PASS. Checkpoint.** Record in `findings.md` which cells were marked uncertain.

---

### Task 7: Drafts repository (JSON on disk)

**Files:**
- Create: `lib/data/poster_repository.dart`
- Test: `test/data/poster_repository_test.dart`

**Interfaces:**
- Produces:
```dart
class PosterRepository {
  PosterRepository(Directory dir);
  Future<List<MonthPoster>> loadAll();        // newest first; skips corrupt files
  Future<void> save(MonthPoster p);           // atomic: write .tmp then rename
  Future<void> delete(String id);
  MonthPoster duplicateAsNextMonth(MonthPoster p, {String? newId});
}
```
`duplicateAsNextMonth`: hijriMonthIndex+1 (12→0 and year+1), keeps texts/templateId/notes cleared (`note: ''`, `highlighted:false`), keeps prayer times (user edits), re-runs weekday sequence starting at last weekday.next, and `dayCount` 30. Gregorian/solar day cells are carried forward via `CalendarFill` from the day after the last row (needs a helper `DateParts` continuation — compute from last row numbers; if the last row is a label cell use its month).

- [ ] **Step 1: Failing tests** (use `Directory.systemTemp.createTempSync()`):

```dart
test('save/loadAll round trip, newest first', () async {...});
test('corrupt json file is skipped, others load', () async {
  File('${dir.path}/bad.json').writeAsStringSync('{not json');
  expect((await repo.loadAll()).length, 1);
});
test('delete removes the file', () async {...});
test('duplicateAsNextMonth increments month and wraps year', () {...});
```
- [ ] **Step 2: Run → FAIL. Step 3: Implement** (`<dir>/<id>.json`, `jsonEncode`, `try/catch` around each decode). **Step 4: PASS. Checkpoint.**

---

### Task 8: Riverpod state (drafts list + editor controller with undo/autosave)

**Files:**
- Create: `lib/state/providers.dart`, `lib/state/editor_controller.dart`
- Test: `test/state/editor_controller_test.dart`

**Interfaces:**
- Produces:
```dart
final repositoryProvider = FutureProvider<PosterRepository>(...);   // path_provider docs dir/posters
final postersProvider = AsyncNotifierProvider<PostersNotifier, List<MonthPoster>>(...); // reload(), upsert(p), remove(id)
class EditorState { final MonthPoster poster; final bool canUndo; final bool canRedo; final bool saving; }
final editorProvider = NotifierProvider<EditorController, EditorState>(...);
class EditorController extends Notifier<EditorState> {
  void open(MonthPoster p);
  void update(MonthPoster Function(MonthPoster) change);  // pushes undo, schedules autosave (600ms debounce)
  void undo(); void redo();
  Future<void> flush();                                   // save now
}
```
Undo stack max 100 entries; `update` sets `updatedAt = DateTime.now()`. Editor controller takes a `PosterSaver` function (`Future<void> Function(MonthPoster)`) via an overridable `posterSaverProvider` so tests inject a fake and assert debounce → exactly one save after rapid updates.

- [ ] **Step 1: Failing tests** with `ProviderContainer(overrides:[posterSaverProvider.overrideWithValue(fake)])` and `fakeAsync`: (a) 3 rapid `update`s → 1 save after 600 ms; (b) `undo` restores previous poster; `redo` re-applies; (c) update after undo clears redo; (d) `flush` saves immediately.
- [ ] **Step 2–4: FAIL → implement → PASS. Checkpoint.**

---

### Task 9: Template foundation — theme, shared layout, FitText, registry

**Files:**
- Create: `lib/templates/poster_template.dart`, `lib/templates/registry.dart`, `lib/templates/shared/fit_text.dart`, `lib/templates/shared/poster_layout.dart`, `lib/templates/shared/painters.dart`, `lib/features/preview/poster_preview.dart`
- Test: `test/templates/fit_text_test.dart`, `test/templates/poster_layout_test.dart`, `test/test_helpers/load_fonts.dart`

**Interfaces:**
- Produces:
```dart
const kPosterSize = Size(1000, 2200);
class PosterTheme {
  final Color background, frameColor, accent, titleColor, bodyText,
      tableHeaderBg, tableHeaderFg, rowBg, rowAltBg, rowText, gridLine,
      highlightBg, highlightFg, labelCellBg, labelCellFg, quoteBoxBg, quoteBoxBorder, quoteText;
  final String headingFont, bodyFont;          // 'ArefRuqaa' | 'Amiri' | 'Tajawal'
  final CustomPainter Function() backgroundPainter; // full-poster pattern/silhouette
  final CustomPainter Function() framePainter;      // borders/ornaments above content
  final EdgeInsets contentPadding;                  // default EdgeInsets.fromLTRB(70,48,70,48)
  final double headerHeight;                        // default 250
}
abstract class PosterTemplate { String get id; String get nameAr; PosterTheme get theme; Widget build(MonthPoster p) => PosterLayout(poster: p, theme: theme); }
class FitText extends StatelessWidget { FitText(String text, {TextStyle style, double maxSize, double minSize = 7, TextAlign align, int? maxLines}) }
class PosterLayout extends StatelessWidget { PosterLayout({required MonthPoster poster, required PosterTheme theme}) }
List<PosterTemplate> get allTemplates; PosterTemplate templateById(String id); // unknown id -> navy gold
class PosterPreview extends StatelessWidget { PosterPreview({required MonthPoster poster, GlobalKey? boundaryKey, double? width}) }
```
`PosterPreview` = `FittedBox(child: RepaintBoundary(key: boundaryKey, child: SizedBox.fromSize(size: kPosterSize, child: template.build(poster))))` inside `Directionality(rtl)` + a `MediaQuery` override of `textScaler: TextScaler.noScaling` (so system font scaling never breaks the poster).

**Layout contract of `PosterLayout`** (top→bottom inside `contentPadding`, all in a `Directionality(rtl)` `Stack`: backgroundPainter, content Column, framePainter):
1. Header (height `headerHeight`): `Row` = right quote box (`texts.rightQuote`) | centre emblem + `texts.title` (`headingFont`, 64px) | left quote box. Quote text uses `FitText` inside a bordered box.
2. Brace quote: `FitText('{ " ${braceQuote} " }')`, height 90, centred.
3. Main area `Expanded`: a `Row`: [left side Q&A rotated `RotatedBox(quarterTurns: 1)`, width 56] [table `Expanded`] [right side Q&A rotated `quarterTurns: 3`, width 56] — right/left follow the reference (`sideRight` on the right edge).
4. Table: header row (fixed 70px) then `days.length` rows each `Expanded` (equal height). Columns right→left with widths: weekday 92, hijri 64, gregorian 64, solar 64, fajr 74, shurooq 74, zuhr 74, maghrib 74, notes `Expanded`. Header cells: `اليوم`, `poster.hijriHeader`, `gregorianHeader`, `solarHeader`, الفجر…المغرب, `ملاحظات`. Row cell colour: highlighted → `highlightBg/Fg`; label cells (`DayCell.isLabel`) → `labelCellBg/Fg`; otherwise alternating `rowBg/rowAltBg`. All cell text via `FitText` (notes: `maxSize 22, minSize 7`, multi-line allowed; other cells `maxSize 24`).
5. Footer notes (`texts.footerNotes`, height 50, `FitText`).
6. Closing article: underlined heading `:: ${author} ::` + `{ ${body} }` via `FitText` (flex area, height 250) + `texts.fatiha` line.
All strings are used verbatim; empty strings render empty (no placeholders).

- [ ] **Step 1: Test helper** `test/test_helpers/load_fonts.dart`:

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fam = {
    'Amiri': ['Amiri-Regular.ttf', 'Amiri-Bold.ttf'],
    'Tajawal': ['Tajawal-Regular.ttf', 'Tajawal-Bold.ttf'],
    'ArefRuqaa': ['ArefRuqaa-Regular.ttf', 'ArefRuqaa-Bold.ttf'],
  };
  for (final e in fam.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }
}
```
- [ ] **Step 2: Failing FitText tests:** (a) short text in a 300×40 box keeps `maxSize`; (b) 400-char Arabic text in 200×60 box: the rendered `Text` font size is `< maxSize` and `tester.takeException()` is null and the Text's laid-out height ≤ 60; (c) empty string renders `SizedBox.shrink`. Pump with `Directionality(rtl)` + `loadAppFonts()` in `setUpAll`.
- [ ] **Step 3: Implement `FitText`** (LayoutBuilder; for `size` from `maxSize` down to 6 step 0.5: `TextPainter(text, textDirection: rtl, maxLines: maxLines, textAlign: align)..layout(maxWidth: c.maxWidth)`; first size where `!tp.didExceedMaxLines && tp.height <= c.maxHeight` wins; return `Text(text, style: style.copyWith(fontSize: size), textAlign: align, textDirection: rtl, softWrap: true)` with `overflow: TextOverflow.visible`. Never use ellipsis. If even 6 fails, use 6.)
- [ ] **Step 4: Painters + layout + registry** per the contract above. `painters.dart` provides reusable painters: `GeometricPatternPainter({color, opacity, cell})` (repeating 8-point-star lattice drawn with `Path`), `DoubleBorderPainter({color, inset, gap, stroke, cornerSize})` (outer + inner rule with corner notches), `MosqueSilhouettePainter({color})` (dome + 2 minarets + arches, drawn at a given rect), `StarMedallionPainter` (emblem fallback). `registry.dart` initially registers only what exists; each template task appends its class to `allTemplates`.
- [ ] **Step 5: Layout test** `poster_layout_test.dart`: pump `PosterPreview(poster: seedReferenceMonth())` with a temporary minimal theme (white/black) in a 1000×2200 `SizedBox`; assert `tester.takeException()` is null; `find.text('تقويم أهل البيت')` finds one; `find.text('4:18')` finds one; then pump a poster whose every note is 400 chars + 30 rows → still no exception. Add the same poster to Review Focus 3 (empty notes poster also).
- [ ] **Step 6: Run all tests → PASS; `flutter analyze`. Checkpoint.**

---

### Task 10: Template 1 — Navy & Gold + first golden

**Files:**
- Create: `lib/templates/navy_gold.dart`
- Modify: `lib/templates/registry.dart`
- Test: `test/templates/golden_test.dart`, `test/templates/goldens/` (generated)

**Interfaces:**
- Produces: `class NavyGoldTemplate extends PosterTemplate` with `id 'navy_gold'`, `nameAr 'كحلي وذهبي'`.

Theme values: `background 0xFF0B1B3F`, `frameColor/accent 0xFFC9A24B`, `titleColor 0xFFF1D78A`, `bodyText 0xFFF4EBD0`, `tableHeaderBg 0xFF14295C`, `tableHeaderFg 0xFFF1D78A`, `rowBg 0xFFF7F0DC`, `rowAltBg 0xFFEDE3C7`, `rowText 0xFF0B1B3F`, `gridLine 0xFFC9A24B`, `highlightBg 0xFF0B1B3F`, `highlightFg 0xFFF1D78A`, `labelCellBg 0xFFC9A24B`, `labelCellFg 0xFF0B1B3F`, `quoteBoxBg 0xFF102552`, `quoteBoxBorder 0xFFC9A24B`, `quoteText 0xFFF4EBD0`; `headingFont 'ArefRuqaa'`, `bodyFont 'Amiri'`; background = flat navy + `GeometricPatternPainter(color gold, opacity 0.07)`; frame = `DoubleBorderPainter(gold, inset 18, gap 8, stroke 3)`.

- [ ] **Step 1: Golden test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/templates/registry.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import '../test_helpers/load_fonts.dart';
import 'package:flutter/material.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final t in allTemplates) {
    testWidgets('golden ${t.id}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final poster = seedReferenceMonth().copyWith(templateId: t.id);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PosterPreview(poster: poster, width: 1000))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(PosterPreview), matchesGoldenFile('goldens/${t.id}.png'));
    });
  }
}
```
- [ ] **Step 2: Implement template, register it, run** `flutter test test/templates/golden_test.dart --update-goldens`.
- [ ] **Step 3: LOOK at the result:** `Read` `test/templates/goldens/navy_gold.png` and compare against the reference image `templates/WhatsApp Image 2026-10-12 at 9.09.58 PM.jpeg` for: column order right→left, month-change label cells, highlighted rows, side Q&As, footer, article. Fix layout/theme issues; regenerate. Also run with `loadAppFonts` removed once to confirm failure is only fonts (sanity) — skip if time-constrained.
- [ ] **Step 4: Overflow test** `test/templates/overflow_test.dart` (loop all templates): poster with 30 rows, every note 400 Arabic chars, hijri header long, all-null times; assert no exception and `FitText` found. Run → PASS. **Checkpoint.**

---

### Task 11: Exporter (PNG, PDF, save, share)

**Files:**
- Create: `lib/export/poster_exporter.dart`
- Test: `test/export/poster_exporter_test.dart`

**Interfaces:**
- Consumes: `kPosterSize`, a `GlobalKey` bound to the `RepaintBoundary` from `PosterPreview`.
- Produces:
```dart
enum PdfPageSize { a4, a3, poster }
class PosterExporter {
  static Future<Uint8List> toPng(GlobalKey boundaryKey, {double pixelRatio = 3});
  static Future<Uint8List> toPdf(Uint8List png, {PdfPageSize size = PdfPageSize.a4});
  static Future<File> saveBytes(Uint8List bytes, String fileName); // <docs>/exports/
  static Future<void> share(File file);                            // share_plus
  static String fileNameFor(MonthPoster p, String ext);            // e.g. "taqweem-1448-جمادى-الأول.png" -> ascii-safe: "taqweem-1448-m5.png"
}
```
Rules: `pixelRatio` clamped to 1–4. PDF page: a4 = `PdfPageFormat.a4`, a3 = `PdfPageFormat.a3`, poster = custom `PdfPageFormat(1000*0.75, 2200*0.75)`; the image is placed with `BoxFit.contain`, centred, zero margins. File name uses ASCII only (`taqweem-<year>-m<monthIndex+1>.<ext>`).

- [ ] **Step 1: Failing tests:** `fileNameFor` returns `taqweem-1448-m5.png`; `toPdf` of a 2×2 PNG (build via `ui.Image`/hand-encoded bytes in `tester.runAsync`) returns bytes starting with `%PDF`; `toPng` on a pumped `PosterPreview` with `boundaryKey` returns a PNG (first 8 bytes `89 50 4E 47 0D 0A 1A 0A`) with width `3000` at pixelRatio 3 (decode via `instantiateImageCodec`, use `tester.runAsync`).
- [ ] **Step 2–4: FAIL → implement (`boundary.toImage(pixelRatio:)`, `ByteFormat.png`; `pw.Document` + `pw.MemoryImage`) → PASS.**
- [ ] **Step 5: Checkpoint.**

---

### Task 12: Home screen

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Create: `lib/features/home/draft_card.dart`
- Test: `test/features/home_screen_test.dart`

**Behaviour:** `AppBar` title `تقاويمي`. Body: `postersProvider` → grid (2 columns phone / 3+ wide) of `DraftCard` (thumbnail = `PosterPreview` scaled, title `جمادى الأول 1448`, subtitle template name + `آخر تعديل`), empty state (big icon + `لا توجد تقاويم بعد` + button `ابدأ تقويماً جديداً` + secondary `جرّب مثالاً جاهزاً` which inserts `seedReferenceMonth()` with a fresh id). `FloatingActionButton.extended` `تقويم جديد` → editor step 1 with a blank poster. Card `PopupMenu`: `تعديل`, `نسخ كشهر تالٍ` (uses `duplicateAsNextMonth`), `حذف` (confirm dialog `هل تريد حذف هذا التقويم؟` — حذف/إلغاء). Loading → skeleton cards; error → message + `إعادة المحاولة`.

- [ ] **Step 1: Failing widget tests** (override `postersProvider` with fixed lists): empty state shows `لا توجد تقاويم بعد`; with one seed poster shows `جمادى الأول 1448`; tapping `حذف` then confirming calls remove (fake notifier records id); cancelling does not.
- [ ] **Step 2–4: FAIL → implement → PASS. Step 5: Checkpoint.**

---

### Task 13: Editor shell + Step 1 (month setup)

**Files:**
- Create: `lib/features/editor/editor_shell.dart`, `lib/features/editor/step_setup.dart`
- Test: `test/features/step_setup_test.dart`

**Behaviour:** `EditorShell` = `Scaffold` with `AppBar` (title = hijri header text, undo/redo icon buttons bound to `editorProvider`), a 4-segment stepper header (`الشهر` · `الأيام` · `النصوص` · `التصدير`) that is tappable, body = current step, bottom bar with `السابق` / `التالي` and a saving indicator (`تم الحفظ ✓`). Leaving flushes the autosave. Step 1 fields: Hijri month dropdown (12 names), Hijri year (number), first weekday chips (7), day count segmented `29 | 30`, Gregorian start date (year/month/day pickers: dropdown month + two numeric fields), Solar start (same), `طول إسفند` toggle 29/30 shown only if solar start month is 12. Button `إنشاء الأيام` regenerates all rows with a confirm dialog **only if any row already has times or notes** (`سيتم استبدال بيانات الأيام. متابعة؟`); changing only `dayCount` calls `CalendarFill.resize` (no dialog, data kept — Review Focus 5). Helper text under Hijri start: `التاريخ الهجري يعتمد على رؤية الهلال — يمكنك تعديل أي يوم لاحقاً`.

- [ ] **Step 1: Failing tests:** (a) pick الثلاثاء + Gregorian 2026/10/13 + solar 1405/7/21 + 30 days + tap `إنشاء الأيام` → `editorProvider` poster has 30 rows with row 19 gregorian label `نوفمبر`; (b) with a note typed in row 3, switching 29→30 keeps the note and adds a row without showing the confirm dialog; (c) regenerate with data present shows confirm; `إلغاء` keeps rows.
- [ ] **Step 2–4: FAIL → implement → PASS. Checkpoint.**

---

### Task 14: Step 2 — day grid (the main data-entry UX)

**Files:**
- Create: `lib/features/editor/step_grid.dart`, `lib/features/editor/time_cell.dart`, `lib/features/editor/honorific_bar.dart`
- Test: `test/features/step_grid_test.dart`

**Behaviour:**
- A horizontally-scrollable-free, vertical list of 29–30 compact row cards (phone-friendly) AND on wide screens (≥ 900 px) a true table with the same cells. Each row: weekday + Hijri day chip, 3 date cells (tappable to override; label cells shown as month chips), 4 `TimeCell`s, a note field, a `مناسبة مهمة` highlight toggle, a ⚠ marker when `uncertain` contains the field or validation reports an issue for that row.
- `TimeCell`: numeric keypad (`TextInputType.number`), accepts `418`/`4:18`/Arabic digits via `parseTimeInput`, shows `formatTime` on blur, invalid input → red border + helper `وقت غير صالح`, `textInputAction.next` moves to the next cell then to next row's first cell.
- Column tools bar: `إزاحة عمود` → choose slot + `±` minutes stepper → applies `shiftMinutes` to all non-null cells in that column (single undo step). `نسخ اليوم السابق` per row copies the previous row's times.
- Note field: `TextField` (RTL, multiline up to 3 lines) with suggestions overlay from `searchOccasions` (tap inserts) and `HonorificBar` above the keyboard inserting `(ع)` `(ص)` `(س)` `(رض)` `ه` `م` at the caret.
- Top summary chip row driven by `validatePoster`: `3 تنبيهات` (tap → scrolls to first problem). Warnings never block navigation.
- Row `uncertain` toggle: long-press a cell → `تحديد كغير مؤكد`.

- [ ] **Step 1: Failing tests:** (a) typing `418` into row 0 fajr then focus change → editor state `fajr == 258` and field shows `4:18`; (b) `4:75` → error text `وقت غير صالح`, state unchanged; (c) column shift +2 on fajr changes all non-null fajr by 2 minutes and one `undo` reverts all; (d) honorific button inserts `(ع)` at caret; (e) occasion suggestion tap fills the note.
- [ ] **Step 2–4: FAIL → implement → PASS. Step 5: Checkpoint.**

---

### Task 15: Step 3 — texts

**Files:**
- Create: `lib/features/editor/step_texts.dart`
- Test: `test/features/step_texts_test.dart`

**Behaviour:** grouped `ExpansionTile` sections (`العنوان`, `الاقتباس الأيمن`, `الاقتباس الأيسر`, `الاقتباس تحت الشعار`, `المقال الختامي`, `سؤال وجواب (يمين)`, `سؤال وجواب (يسار)`, `الملاحظات السفلية`, `الفاتحة`), each field a multiline `TextField` writing to `editorProvider` on change. Above the list a `استعادة النصوص الافتراضية` button (confirm) → `defaultTexts()`. Live char counter; a gentle hint `النص الطويل سيُصغَّر تلقائياً` when a field exceeds 300 chars. HonorificBar reused.

- [ ] **Step 1: Failing tests:** edit title updates poster text; restore defaults after confirm resets texts; cancel keeps.
- [ ] **Step 2–4: FAIL → implement → PASS. Checkpoint.**

---

### Task 16: Step 4 — template picker, live preview, export

**Files:**
- Create: `lib/features/editor/step_export.dart`
- Test: `test/features/step_export_test.dart`

**Behaviour:** top: `PageView` (swipe) of the registered templates showing the real poster at ~screen width with template name chip + dots; selecting changes `templateId` (debounced autosave). Below: tap-to-zoom (`InteractiveViewer` full-screen route). Actions: `حفظ PNG` (resolution segmented `عادية ×2 | عالية ×3 | طباعة ×4`), `حفظ PDF` (size segmented `A4 | A3 | حجم الملصق`), `مشاركة`. Before export, if `validatePoster` has issues: dialog `يوجد N تنبيهات في البيانات. هل تريد التصدير رغم ذلك؟` listing the first 5 (`تصدير`/`مراجعة` → jumps to step 2). Export shows progress, then a snackbar `تم الحفظ: <path>` with `فتح`/`مشاركة` actions; failure → dialog with the reason and `إعادة المحاولة`.

- [ ] **Step 1: Failing tests** (override exporter via an injectable `PosterExporterApi` provider so tests don't touch disk): swiping selects the next template id; tapping `حفظ PNG` with clean data calls `toPng` once with pixelRatio 3 by default; with a missing-time poster a confirm dialog appears and `مراجعة` navigates to step index 1; export exception shows the retry dialog.
- [ ] **Step 2–4: FAIL → implement → PASS. Checkpoint.**

---

### Tasks 17–20: Templates 2–5

Each follows Task 10's pattern: new file, register in `registry.dart`, golden regenerated and **visually inspected** against the spec's description and the reference, overflow test (Task 10 Step 4) already loops `allTemplates` so it covers them automatically. Provide `backgroundPainter`/`framePainter` per below; palette values are exact.

#### Task 17: Cream & Gold — `lib/templates/cream_gold.dart`
`id 'cream_gold'`, `nameAr 'كريمي وذهبي'`. `background 0xFFFBF5E6`, `frameColor/accent 0xFFB8892B`, `titleColor 0xFF7A5710`, `bodyText 0xFF2B2416`, `tableHeaderBg 0xFFB8892B`, `tableHeaderFg 0xFFFFFFFF`, `rowBg 0xFFFFFDF6`, `rowAltBg 0xFFF5EBD0`, `rowText 0xFF2B2416`, `gridLine 0xFFD9C08A`, `highlightBg 0xFF7A5710`, `highlightFg 0xFFFFF4D6`, `labelCellBg 0xFFE6CF94`, `labelCellFg 0xFF2B2416`, `quoteBoxBg 0xFFFFF8E5`, `quoteBoxBorder 0xFFB8892B`, `quoteText 0xFF2B2416`; fonts ArefRuqaa/Amiri; background = cream + `GeometricPatternPainter(gold, opacity 0.06)`; frame = `DoubleBorderPainter(gold, inset 16, gap 6, stroke 2.5)`. Contrast rule: every text/bg pair ≥ 4.5:1 — add a test `test/templates/contrast_test.dart` computing WCAG contrast for (`rowText`/`rowBg`, `rowText`/`rowAltBg`, `highlightFg`/`highlightBg`, `labelCellFg`/`labelCellBg`, `tableHeaderFg`/`tableHeaderBg`, `bodyText`/`background`, `quoteText`/`quoteBoxBg`) for **all** templates (create it in this task; Tasks 18–20 must keep it green).

#### Task 18: Minimal Modern — `lib/templates/minimal_modern.dart`
`id 'minimal_modern'`, `nameAr 'عصري بسيط'`. `background 0xFFFFFFFF`, `frameColor 0xFF111827`, `accent 0xFF0F766E`, `titleColor 0xFF111827`, `bodyText 0xFF1F2937`, `tableHeaderBg 0xFF111827`, `tableHeaderFg 0xFFFFFFFF`, `rowBg 0xFFFFFFFF`, `rowAltBg 0xFFF3F4F6`, `rowText 0xFF111827`, `gridLine 0xFFE5E7EB`, `highlightBg 0xFF0F766E`, `highlightFg 0xFFFFFFFF`, `labelCellBg 0xFFE5E7EB`, `labelCellFg 0xFF111827`, `quoteBoxBg 0xFFF9FAFB`, `quoteBoxBorder 0xFFD1D5DB`, `quoteText 0xFF1F2937`; `headingFont 'Tajawal'`, `bodyFont 'Tajawal'`; `contentPadding` 56 all sides; background = plain; frame = single thin rule (`stroke 1.5`) at inset 24 plus a short teal accent bar under the title. No ornament pattern. Table rows `gridLine` hairlines only (no vertical lines).

#### Task 19: Deep Green — `lib/templates/deep_green.dart`
`id 'deep_green'`, `nameAr 'أخضر إسلامي'`. `background 0xFF0A3B2C`, `frameColor/accent 0xFFD4AF37`, `titleColor 0xFFF3E3A1`, `bodyText 0xFFF6F1DC`, `tableHeaderBg 0xFF0F5A43`, `tableHeaderFg 0xFFF3E3A1`, `rowBg 0xFFF4F1E1`, `rowAltBg 0xFFE6E3CE`, `rowText 0xFF0A3B2C`, `gridLine 0xFFB9A24A`, `highlightBg 0xFF0A3B2C`, `highlightFg 0xFFF3E3A1`, `labelCellBg 0xFFD4AF37`, `labelCellFg 0xFF0A3B2C`, `quoteBoxBg 0xFF0F4A38`, `quoteBoxBorder 0xFFD4AF37`, `quoteText 0xFFF6F1DC`; fonts ArefRuqaa/Amiri; background = green + `GeometricPatternPainter(gold, opacity 0.08, cell 90)`; frame = `DoubleBorderPainter` with larger `cornerSize` plus section dividers (thin gold rule with centred diamond) between header / table / article drawn by the frame painter at the layout's section y-offsets (`PosterLayout` exposes `sectionOffsets` to `framePainter` via an optional `LayoutMetrics` argument — add it in this task and keep default `null` for other templates).

#### Task 20: Dark Blue with Mosque Silhouette — `lib/templates/mosque_blue.dart`
`id 'mosque_blue'`, `nameAr 'أزرق ليلي ومسجد'`. `background 0xFF08122B` with a vertical gradient painted by the background painter to `0xFF123A6F` at the bottom, `frameColor/accent 0xFFE8C766`, `titleColor 0xFFFFE9A8`, `bodyText 0xFFEAF0FF`, `tableHeaderBg 0xFF0E2A57`, `tableHeaderFg 0xFFFFE9A8`, `rowBg 0xFFEEF3FF`, `rowAltBg 0xFFDCE6FB`, `rowText 0xFF08122B`, `gridLine 0xFF7F9ACB`, `highlightBg 0xFF08122B`, `highlightFg 0xFFFFE9A8`, `labelCellBg 0xFFE8C766`, `labelCellFg 0xFF08122B`, `quoteBoxBg 0xFF0E2A57`, `quoteBoxBorder 0xFFE8C766`, `quoteText 0xFFEAF0FF`; headingFont ArefRuqaa. Background painter draws: gradient, a faint crescent + stars (deterministic positions from a fixed seed, ≤ 40 stars) in the header region, and `MosqueSilhouettePainter` (`0xFF0B2350` at 90% opacity) across the **top 300 px** behind the header (dome + two minarets + arches) and a low skyline strip behind the article (bottom 220 px). Illustration must stay behind content: table rows keep opaque `rowBg`, header quote boxes keep opaque `quoteBoxBg`, so readability is never reduced. Test: a golden pixel probe confirming `rowBg` pixels inside a table row equal the opaque colour (no silhouette bleed).

For each of Tasks 17–20: **Step 1** implement + register; **Step 2** `flutter test test/templates --update-goldens`; **Step 3** `Read` the new golden PNG and judge against the spec description and the reference (columns, contrast, nothing clipped); iterate; **Step 4** run the whole template test folder; **Step 5** checkpoint.

---

### Task 21: Polish, accessibility, and end-to-end verification

**Files:** modify as needed across `lib/features/**`; Test: `test/features/e2e_flow_test.dart`; no new product files unless a fix demands.

- [ ] **Step 1: Accessibility pass** (invoke the `fixing-accessibility` skill's checklist): tap targets ≥ 48 dp, `Semantics` labels on icon-only buttons (undo/redo/menu), visible focus, contrast of UI chrome ≥ 4.5:1, support text scale 1.3 without overflow in editor steps (add a widget test pumping Step 1–4 at `textScaler: TextScaler.linear(1.3)` asserting no exception). Poster itself ignores text scale (Task 9).
- [ ] **Step 2: Empty/loading/error states** audited on Home, Editor (`جارٍ التحميل…`, retry on repository failure), Export.
- [ ] **Step 3: E2E widget test:** create new → Step 1 (reference setup) → Step 2 enter times for 2 rows → Step 4 choose `mosque_blue` → export PNG with fake exporter → draft appears on Home with title `جمادى الأول 1448`.
- [ ] **Step 4: Full verification:** `flutter analyze` (0 issues), `flutter test` (all green, goldens committed unchanged), `flutter build linux --debug` succeeds.
- [ ] **Step 5: Run the real app on Linux** (`flutter run -d linux`, drive it via the `run` skill), create the seed month, open all five templates, export PNG + PDF, open the exported PNG with `Read` and compare with `templates/WhatsApp Image 2026-10-12 at 9.09.58 PM.jpeg` row by row (dates, weekdays, times, notes of at least 10 rows). Record mismatches in `findings.md` and fix.
- [ ] **Step 6: Final report:** update `task_plan.md` (all complete), write `progress.md`, summarise to the user: what was built, list of `uncertain` seed cells needing human check, and that **nothing is committed** (ready for their review). Use `superpowers:verification-before-completion` before claiming done.

---

## Self-Review (spec ↔ plan)

- Spec §3 rendering → Tasks 9, 11. §4 architecture → File Structure + Tasks 2–9. §4a data model → Task 3 (+4 for month-name labels). §5 editor steps → Tasks 13–16; home/drafts/duplicate → Tasks 7, 12; undo + autosave → Task 8. §6 templates → Tasks 9–10, 17–20. §7 error handling → Tasks 7 (corrupt JSON), 14 (invalid time), 16 (export failure/warnings), 21 (states). §8 testing → unit (2–8), golden (10, 17–20), overflow (9, 10), manual Linux run (21). §9 delivery order matches task order.
- Type names checked across tasks: `PosterTheme`, `PosterTemplate`, `PosterLayout`, `PosterPreview(boundaryKey)`, `PosterExporter.toPng/toPdf/saveBytes/share/fileNameFor`, `EditorController.update/undo/redo/flush`, `CalendarFill.generate/resize`, `validatePoster`, `PrayerSlot`, `DayField`, `DayCell`.
- Known deviations from the spec: Aref Ruqaa/Tajawal/Amiri replace "Cairo/Noto Naskh" (static TTFs bundle cleanly; fallback logged in findings if a download fails); ربيع الثاني / جمادى الثانية spellings are conventional (not in reference images).
