# Shia Occasions Database — Design Spec

Date: 2026-10-13 · Status: proceeding on user's "continue" after the compiled list (docs/shia-occasions/COMPILED.md) and four questions; defaults below are the recommended ones and are reversible data choices.
Requirement source: user (see project memory `shia-only-content`): the app is for Twelver Shia users; all religious dates/occasions come from Shia sources only; remove non-Shia/irrelevant entries; show main date + marked alternates where Shia sources differ; never invent.

## 1. Data (built-in, read-only)
- `lib/data/shia_occasions.dart` — generated, `const List<ShiaOccasion> shiaOccasions` (do not hand-edit). Generator: `tool/gen_shia_occasions.py` (reads `docs/shia-occasions/research/months-*.json`, deterministic, sorted by month/day/main-first, validates schema, fails loudly on bad data).
- `lib/domain/shia_occasion.dart`:
  `class ShiaOccasion { int month /*1..12*/; int day /*1..30*/; bool isNight; String titleAr; OccasionCategory category; bool isAlternate; String? alternateNoteAr; Confidence confidence /*high|medium*/; bool verified /*>= 2 independent Shia sources*/; List<String> sourceNames; }`
- Included in the app: every research entry in `occasions` (main + alternates). Entries from `unconfirmed` (single Shia source) are NOT included (defaults: leave out until verified; the user may later supply Haqibat al-Mu'min pages to promote them). `excluded` entries are never included (scholars/marja'/modern martyrs, Sunni-only figures, unrelated history; undecided items such as Eid al-Zahra stay out until the user decides).
- Sources are kept as short names only (e.g. "ويكي شيعة") for transparency in the suggestion UI; never printed on the poster.

## 2. Lookup
`List<ShiaOccasion> occasionsFor({required int hijriMonthIndex /*0..11*/, required int day, required int daysInMonth})`:
- matches `month == hijriMonthIndex+1 && day == day`;
- "last day" rule: items on day 30 also match day 29 when the month has 29 days (rows.length == 29), since Shia sources say «آخر الشهر»;
- order: main first, then alternates; stable.
`searchShiaOccasions(String query, {int limit = 8})` — substring over titles (replaces the old generic `searchOccasions`).

## 3. App integration (day grid, Step 2)
- Each day's note field shows a chip row «مناسبات هذا اليوم» built from `occasionsFor(...)` for that row's Hijri month/day (month = poster.hijriMonthIndex, day = row.hijriDay). Tapping a chip inserts its text into the note: main → title; alternate → `title + ' ' + alternateNoteAr` (e.g. «… على رواية»), matching the printed-calendar convention. Alternate chips are visually marked (dashed/italic + the note text).
- `verified == false` entries (none by default, since only ≥2-source items are included; the field exists for future promotion) would show a ⚠ and need an extra tap — implemented but unused by default data.
- Bulk action in the tools bar: `تعبئة المناسبات تلقائياً` → fills ONLY empty notes with the MAIN occasion(s) of each day (multiple mains on one day are joined with « - »), never overwrites existing text, never inserts alternates; one editor update (one undo entry); SnackBar `تمت تعبئة N يوماً` with `تراجع`; confirm dialog first stating how many days will be filled.
- The generic suggestion list (`lib/domain/occasions_library.dart`) becomes Shia-only: titles from the DB + the Shia-relevant notes already in it; all scholar/Sunni/unrelated entries are removed. `searchOccasions` keeps its signature but searches only Shia-relevant titles.

## 4. Existing data cleanup
- `seedReferenceMonth()` (Jumada I 1448 from the user's scan): keep Shia-relevant notes verbatim; remove (blank, flag nothing) notes about scholars/marja'/modern martyrs, Sunni figures and non-religious history; where a note mixes relevant and irrelevant parts keep only the relevant part verbatim. Time/date columns untouched. Specific removals decided in the cleanup task (list reported to the user for borderline cases).
- `defaultTexts()` unchanged (the user's own header quotes/article).

## 5. Quality / testing
- Generator test (python or dart): schema validation; counts; no duplicate (month, day, title, variant).
- Dart unit tests: `occasionsFor` incl. last-day rule and alternates order; `searchShiaOccasions`; data sanity (every day 1..30, month 1..12, titleAr non-empty and contains a Shia honorific marker for Infallibles where the research data had one is NOT required; no title mentions excluded names (Mu'awiya etc.) — a denylist test).
- Widget tests: chips appear for a row, tap inserts main/alternate text, autofill only fills empty notes, one undo, confirm dialog, SnackBar undo; seed cleanup test (removed notes absent, kept notes present).
- Accuracy review: an independent agent spot-checks ≥ 20 generated entries against the research JSON and re-verifies ≥ 10 high-impact dates (Ashura, Arbaeen, Ghadir, Eids, Fatima's martyrdom, births/martyrdoms of the Imams) against two Shia sources.

## 6. Non-goals / open items for the user
- No Hijri↔Gregorian conversion; no auto date generation.
- Pending user decisions (data stays excluded until decided): Eid al-Zahra (9 Rabi' I), earlier-scripture revelation days, Unity Week, Laylat al-Raghaib, single-source items (106), Haqibat al-Mu'min verification pages.

## 7. Addendum — honest `verified` flag (decided while planning)
`verified` = the entry cites >= 2 DISTINCT source families, where a family is the registrable domain of each source URL (e.g. all `*.wikishia.net` pages = one family; `alkafeel.net` = one; `wikifeqh.ir` = one). So "WikiShia AR + WikiShia FA" is NOT verified. All research entries that passed the agents' own >= 2-source test are INCLUDED in the data; `verified` is computed by the generator. UI rules: unverified entries show a ⚠ «للتحقق» marker on their chip (still tappable); the bulk auto-fill (`تعبئة المناسبات تلقائياً`) uses ONLY verified MAIN entries; a summary in the app/report states how many entries are verified vs flagged so the user knows what still needs Haqibat/Mafatih confirmation.
