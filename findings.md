# Findings — Islamic Calendar Poster Generator (taqweem)

## Environment
- Flutter 3.47.6 stable, Dart ^3.13.5. Project is the untouched `flutter create` counter template (lib/main.dart only).
- Platforms scaffolded: android, ios, linux, macos, windows, web. Linux desktop is available for local run/screenshots.
- git: branch master, 1 commit ("started"), `templates/` untracked. No commits by me (global rule).

## Reference calendars (5 images in templates/) — "تقويم أهل البيت" (Shia monthly calendar)
Each image = ONE month = one poster (portrait, ~1:2.2 aspect, black/white scan).

### Poster anatomy (top → bottom)
1. Logo/title: calligraphic "تقويم أهل البيت" with a dome/mosque emblem in centre.
2. Two framed quote boxes flanking the logo (left box: a saying of an Imam; right box: a saying of the Prophet / Fatima).
   Each box = quote text + attributed name with honorific e.g. (ع) (ص) (س).
3. Quote line in braces `{ " ... " }` under the header (a saying of Imam Khomeini / similar).
4. MAIN TABLE, 2 parts: right = date/prayer columns, left = wide "ملاحظات" (notes/occasions) column.
   Columns right→left: اليوم (weekday) | Hijri month+year (e.g. جمادى الأول 1448) | Gregorian month(s)+year (e.g. أكتوبر/نوفمبر 2026) | Solar-Hijri (Persian) month+year (e.g. مهر/آبان 1405) | الفجر | الشروق | الظهر | المغرب | ملاحظات.
   - Month-header cells hold 2 month names when the month changes mid-table; the day cell on the change row shows the new month NAME instead of a number (e.g. "نوفمبر", "آبان", "أغسطس", "مرداد", "اغسطس").
   - Solar-Hijri month names seen: مهر, آبان, آذر, تير, مرداد, شهريور.
   - Gregorian names seen: أكتوبر, نوفمبر, ديسمبر, يوليو, أغسطس, سبتمبر.
   - Hijri months seen: جمادى الأول 1448, صفر 1448, ربيع الأول 1448, جمادى الأول 1446, محرم 1446.
   - Some images show 4 prayer columns (Fajr, Shurooq, Zuhr, Maghrib) — no Isha/Dhuhr-split. Times 12h-style "4:18", "11:25", no AM/PM, no leading zero.
   - 29–30 rows per month. Weekday column contains Arabic names: السبت الأحد الأثنين الثلاثاء الأربعاء الخميس الجمعة (spelled "الأثنين").
   - Highlighted rows: dark/black fill with white text = major occasions (births/martyrdoms of Imams, Fatima etc.), and individual day-number cells are black = Fridays/special/month-boundary markers. Some rows blank notes (empty) and some notes are very long (shrunk to fit with smaller font).
   - Notes use inline honorifics (ع) (ص) (س) (رض), years with ه / م suffix.
   - Some weekday cells appear truncated in the scans ("الأ") — uncertain data, treat as uncertain (user's rule: do not guess).
5. Footer note line: "ملاحظات: 1- على كل شخص ان يعمل حسب فتوى مرجعه. 2- الأوقات مأخوذة من تقويم الهادي".
6. Closing article: heading with underline `:: الشهيد مرتضى مطهري ::` (or السيد القائد الإمام الخامنئي / آية ا... بهجت) + paragraph in braces, then "الفاتحة لأرواح المؤمنين والمؤمنات من الأولين والآخرين".
7. Side margins (rotated 90° text) on both left and right: a Q&A fiqh pair: "سؤال: ... الجواب: ...". Right edge text and left edge text are separate Q&As. (Present on all pages, some partially cropped.)

### Per-month variable data (must be user-editable)
- Hijri month name + year, start weekday, number of days (29/30).
- Gregorian month(s)/year; Solar-Hijri month(s)/year; per-row day numbers (3 calendars).
- 4 prayer times × days.
- Note text per row + highlight flag per row; per-cell highlight of day number.
- Two header quotes (text + speaker), top braces quote, closing article (author + text), 2 side Q&As, footer notes.

### Months in the sample set
| Image | Hijri | Gregorian | Solar |
|---|---|---|---|
| 9.09.58 | جمادى الأول 1448 (30d) | Oct/Nov 2026 | مهر/آبان 1405 |
| 9.09.59(1) | صفر 1448 (30d) | Jul/Aug 2026 | تير/مرداد 1405 |
| 9.09.59(2) | جمادى الأول 1446 (30d) | Nov/Dec 2024 | آبان/آذر 1403 |
| 9.09.59(3) | محرم 1446 (29d) | Jul/Aug 2024 | تير/مرداد 1403 |
| 9.09.59 | ربيع الأول 1448 (29d) | Aug/Sep 2026 | مرداد/شهريور 1405 |

### Data-accuracy plan
- No OCR pipeline. I will transcribe seed data (jamadi-1 1448 etc.) only where it is clearly legible, flag unreadable cells as `uncertain` (shown with a warning marker in editor), never auto-fill.
- Seed one fully transcribed reference month so templates can be verified against the original image.

## Task 2 note (month/weekday names)
- Names for ربيع الثاني / جمادى الثانية and dates not in the 5 reference images (e.g. the Arabic weekday spelling الأثنين, solar month names) are conventional spellings taken from the brief, not verified against the reference images. Note: the standard spelling of Monday is الإثنين; the brief uses الأثنين verbatim.

## Task 6 — seed transcription (Jumada I 1448, 9.09.58 PM image)
- All 120 prayer-time cells were clearly legible at 3x zoom (grid-aligned crops) and follow the monthly trend; none set null.
- Weekday / Hijri / Gregorian / Solar columns match CalendarFill.generate (آبان label row 11, نوفمبر label row 20, ends 11 Nov / 20 Aban). Highlighted rows: 5, 13, 22.
- `DayField.note` flagged uncertain (small print, letters not fully confirmable): row 10 (diacritic marks over اعطاء/حتى not determinable; kept undiacritised), row 19 (آيةا...قاضي الطباطبائي…1979م), row 21 ("69هـ" suffix after اليهود), row 24 (القمي / استبعادالامام).
- Notes kept with the scan's own spelling/spacing (e.g. شهيدالمحراب، البحرانى، الدكتوراحمدالوائلي، ماذنتي، عبدا...).
