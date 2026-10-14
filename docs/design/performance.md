# Performance: why it felt heavy, and what changed

## Diagnosis
- A poster is about 290 `FitText` widgets. Each one binary-searches a font size
  with repeated text layouts (plus a second unconstrained layout per candidate
  for the no-mid-word guard). One poster build costs about 560-650 text layouts.
- Home built one LIVE poster per draft card.
- The editor AppBar mini preview re-laid-out a full live poster after every
  committed edit.
- Day-grid commits had to be checked for stray row rebuilds.

## What changed
1. **FitText LRU cache** (`lib/templates/shared/fit_text.dart`): the fitted
   result is memoised by (text, style, constraints, ...). Results are identical,
   so goldens are unchanged. A warm rebuild does no text layout at all.
2. **Thumbnail cache** (`lib/features/preview/poster_thumbnail.dart`): Home
   cards and the editor mini preview show a low-resolution raster (LRU, 16
   drafts, keyed by draft id and a content stamp). Rendering is serial (one
   off-screen poster at a time), de-duplicated per id, and debounced (900 ms)
   for the editor preview. A stale raster stays visible while a fresh one is
   produced. We do not use Flutter's `SchedulerBinding.scheduleTask(Priority.idle)`
   for the queue: while any animation runs it re-arms zero-delay timers in a
   busy loop, and in a test it ran away to 13 GB of memory. A short fixed delay
   (48 ms) after the requesting frame is used instead.
3. **Row isolation** (`lib/features/editor/step_grid.dart`, `day_row.dart`):
   each day row is a keyed widget that selects only its own data from the
   provider (its `DayRow`, last-row flag, its issues, its invalid-time entries),
   is cached per index and wrapped in a `RepaintBoundary`; the list stays lazy
   (`ListView.builder`). Editing one day rebuilds exactly that row
   (`debugGridRowBuilds` counts builds in debug).
4. **Step 4 template picker**: already a `PageView.builder` (viewport fraction
   1, no extra cache extent), so only the visible page builds a live poster
   (two while a swipe is in progress). No change needed.

## Measured (debug test harness, `flutter test`, same machine; not device numbers)
| Measure | Before | After |
|---|---|---|
| FitText text layouts per warm poster rebuild | 563 | 0 (-100%) |
| Warm poster build+layout+paint, median | 88-113 ms | 55-85 ms |
| Live poster, one note edited: layouts | 651 | 1 |
| Home, 12 drafts, first frame | 862-1165 ms, 12 live posters | 120-201 ms, 0 live posters |
| Home thumbnails: max concurrent off-screen posters | n/a | 1 (8 rendered: the visible ones) |
| Home, 12 drafts, warm cache | n/a | 52-80 ms, nothing re-rendered |
| Editor commit (grid step), frame median | 60-79 ms (live mini preview, 651 layouts) | 25-31 ms, 0 layouts |
| Rows rebuilt per grid commit | n/a | 1 |

Ranges are across runs; timings are noisy, layout counts are deterministic.

## Run the benchmark
```
systemd-run --user --scope -p MemoryMax=5G -p MemorySwapMax=0 \
  flutter test --run-skipped -t perf test/perf/perf_benchmark_test.dart
```
Results print as `PERF ...` lines. The `perf` tag is skipped by default
(`dart_test.yaml`). Assertions: warm rebuild needs at least 80% fewer layouts;
Home has no live posters and at most one concurrent render; a grid commit
rebuilds one row and lays out no poster.
