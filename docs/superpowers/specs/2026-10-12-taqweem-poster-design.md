# Taqweem — Islamic Calendar Poster Generator: Design Spec

Date: 2026-10-12 · Status: approved in conversation · Reference data: `findings.md`, images in `templates/`

## 1. Goal
A Flutter app (Arabic-only, RTL UI) in which a user enters one month of Islamic calendar data and gets a complete, print-quality poster (PNG/PDF) in one of five visual templates. The reference is the "تقويم أهل البيت" monthly calendar. Data accuracy outranks everything: no invented or guessed content; unreadable data is marked uncertain.

## 2. Scope
In: manual data entry, drafts storage, 5 templates, live preview, PNG/PDF export + share, occasions library seeded from reference, seeded reference month.
Out (YAGNI): computing prayer times, Hijri conversion authority, accounts/cloud sync, OCR of images, UI localization other than Arabic.

## 3. Rendering approach
Each template is a Flutter widget drawn at fixed logical size 1000×2200. Export = RepaintBoundary → PNG at pixelRatio 2–4; PDF = `pdf` package page embedding that PNG (A3 / A4 / poster ratio). Rejected: native vector PDF per template (poor Arabic shaping, double work), HTML/webview.

## 4. Architecture (feature-first)
```
lib/
  main.dart, app.dart            # MaterialApp, RTL, theme, routes
  core/                          # theme tokens, fonts, arabic_text utils, widgets
  domain/                        # pure Dart
    month_poster.dart            # MonthPoster, DayRow, PrayerTimes, PosterTexts, HeaderQuote, SideQA
    calendar_fill.dart           # generate rows from month setup
    time_format.dart             # "4:18" parse/format/shift
    validation.dart              # time order, missing fields -> warnings
    occasions_library.dart       # seeded suggestions
  data/
    poster_repository.dart       # JSON drafts on disk (path_provider), CRUD, duplicate-next-month
    seed_reference.dart          # transcribed reference month (+ default texts)
  templates/
    poster_template.dart         # interface: id, nameAr, build(MonthPoster, Size)
    registry.dart
    shared/                      # table, header, footer, auto-fit text, side-margin text, painters
    navy_gold/ cream_gold/ minimal_modern/ deep_green/ mosque_blue/
  export/
    poster_exporter.dart         # png, pdf, share
  features/
    home/ editor/ preview_export/
```
State: Riverpod. Units communicate via the `MonthPoster` value object (immutable, `copyWith`, `toJson/fromJson`).

## 4a. Data model
- `MonthPoster`: id, updatedAt, hijriMonth (enum of 12), hijriYear, gregorian label (1–2 months + year), solar label (1–2 months + year), `List<DayRow> days` (29–30), `PosterTexts texts`, `templateId`.
- `DayRow`: weekday (enum, Arabic spelling as reference "الأثنين"), hijriDay, gregorianDay (int or monthNameLabel), solarDay (int or monthNameLabel), `PrayerTimes? ` (fajr, shurooq, zuhr, maghrib as minutes-since-midnight, nullable), note String, highlighted bool, uncertain Set<field>.
- `PosterTexts`: headerQuoteRight/Left (text + attribution), braceQuote, closingArticle (author, body), sideQaRight/sideQaLeft (question, answer), footerNotes, logo title.
- Times displayed as `h:mm` (no leading zero, no AM/PM).

## 5. Editor UX (4 steps, autosave, undo)
1. Month setup: Hijri month/year, first weekday, 29/30 days, Gregorian + Solar anchor → rows generated; all overridable (moon-sighting).
2. Day grid: spreadsheet-like, numeric time keypad, auto-advance, column shift ±N min, per-row note with occasions suggestions, highlight toggle, uncertain marker, honorific buttons (ع)(ص)(س)(رض) above keyboard, validation chips.
3. Texts: quotes, article, Q&As, footer — prefilled from reference defaults, editable.
4. Template + export: swipeable live preview with real data, PNG/PDF/share, size choice.
Home: draft thumbnails (live render), new, duplicate-as-next-month, delete (confirm).

## 6. Templates
Common interface; shared blocks for table/header/footer/side text; each supplies palette, fonts (Amiri / Cairo / Noto Naskh Arabic bundled as assets), border + ornament painters, table styling. Vector `CustomPainter` ornaments only. Long notes use auto-fit (shrink to min size, then ellipsis-free wrap) — never clipped. Templates: (1) Navy & Gold, (2) Cream & Gold, (3) Minimal Modern, (4) Deep Green, (5) Dark Blue + mosque silhouette.

## 7. Error handling
- Missing/invalid times: warn, allow export with explicit confirmation; blank cells render blank.
- Storage failure: surface snackbar, keep in-memory state.
- Export failure (permission/path): retry dialog with reason.
- Fonts bundled, no network.

## 8. Testing
Unit: CalendarFill, time_format, validation, JSON round-trip. Widget: editor steps. Golden: all 5 templates × seeded month. Overflow test: extreme note lengths and 30-day months in every template. Manual: run on Linux desktop, screenshot, compare to reference image.

## 9. Delivery order
Foundation+domain → data/storage → editor → Template 1 + export → Templates 2–5 → polish (accessibility, empty states, onboarding hints). All left uncommitted for user review.

## 10. Open assumptions
Prayer times are user-typed. Reference text (quotes/articles) is user-owned content used as editable defaults. Unreadable scan cells (e.g. truncated weekday "الأ") are seeded as uncertain/empty.
