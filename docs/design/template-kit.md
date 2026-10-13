# Template kit (`lib/templates/kit/`)

A poster template is a `PosterTemplate` whose `build(MonthPoster)` may return
**any widget** drawn on the fixed 1000 x 2200 canvas (`kPosterSize`). The five
original templates (navy_gold, cream_gold, minimal_modern, deep_green,
mosque_blue) still use the shared `PosterLayout` (header / brace / table +
side strips / footer / article), which is itself composed from this kit.
New templates can ignore that structure and compose their own page from the
same building blocks. Import everything with:

```dart
import 'package:taqweem/templates/kit/kit.dart';
```

## Building blocks

| Block | What it is |
|---|---|
| `PosterPage` | The canvas: RTL, text scaling off, a `DefaultTextStyle`, and a Stack of layers: `color` → `backgroundPainter(size)` → `background` widgets → `child` (inside `padding`) → `positioned` widgets → `foregroundPainter(size)` → `foreground` widgets (no pointer events). |
| `PosterPanel(style: PanelStyle(...))` | A decorated container. `PanelShape.rect()`, `.rounded(r)`, `.arch(rise, pointed, radius)` (mihrab), `.ribbon(depth, notched)`, `.cartouche(cut, concave)`. Fill colour or `gradient`, `border` and optional `innerBorder` (double frame, `innerBorderGap`), `shadows`, `padding`. Content is clipped to the outline and pushed out of the non-rectangular parts (`PanelShape.safeInsets`). `rotation` tilts the panel. `PanelShape.pathFor(rect)` gives the same outline to painters. |
| `TitleBlock.text(title, style:)` / `TitleBlock.image(AssetImage('assets/logos/…'), tint:)` | Title as fitted text in a heading font (shadows via `TextStyle.shadows`), or as an image logo (`fit`, optional `srcIn` tint). A missing image renders nothing instead of throwing. |
| `QuoteBlock(quote, panel:, textStyle:, attributionStyle:)` | Header quote: wrapping text + one-line attribution; renders nothing (panel included) when empty. |
| `BraceQuote(text, style:)` | The `{ " … " }` line; braces are bidi-isolated (`braced()`), so `{` prints on the right. Empty text prints nothing. |
| `FooterNote(text)` | One-line, start-aligned notes line. |
| `SideQaStrip.of(poster, PosterSide.right)` | Rotated `سؤال : … / الجواب : …` strip (`width`, `quarterTurns`, labels, styles). |
| `ClosingArticleBlock.of(poster, …)` | `:: author ::` heading, braced justified body, fatiha line; fixed heights or `bodyHeight: null` to fill. |
| `PosterTableView(poster:, spec: TableSpec(...))` | The calendar table (see below). |
| `SectionLayout.vertical/horizontal(rect, [Section('id', h), Section.flex('id')], gap:)` | Deterministic slicing of the page into named rects. Place widgets with `Positioned.fromRect(rect: layout['id'])`, give painters the same rects. |
| `TableGeometry.compute(spec, tableRect, rowCount)` | Where the table's panels, inner rects, columns, header bottom and rows are — the same arithmetic as the widget layout (tested). |
| `LayoutMetricsLike` | Painter-facing interface (`contentRect`, `tableRect`, `tableHeaderBottom`, `rowRect(i)`, `section(id)`). Implemented by `LayoutMetrics` (shared layout) and `KitMetrics` (sections + `TableGeometry`). |
| `KitDefaults` | The kit's sizes and FitText caps (column widths 60/46/54, header 84, strip 52, grid 1, tight line 1.2, …). |

### The table: `TableSpec`

* `groups`: ordered column groups, right → left. Columns: `TableColumn.weekday()`,
  `.hijri()`, `.gregorian()`, `.solar()`, `.time(PrayerSlot.fajr)`, `.notes()`;
  each with `width` (null = share remaining width by `flex`), body `style`,
  `headerStyle`, `header` text override. `TableSpec.referenceGroups` is the
  reference order.
* `split: true` renders every group as its own panel (`panel` style each,
  `gap` between) — e.g. the glass layout dates | times | notes. Otherwise one
  panel.
* `headerHeight` (0 = no header row); `rowHeight` null = rows share the height
  equally (default), or a fixed height.
* Styling (`CellStyle`: background, foreground, fontFamily, fontWeight,
  lineHeight (`kFontLineHeight` = font default), maxSize, minSize, wrap,
  padding, align, `badge`, text shadows) is layered, later non-null wins:
  `body` → `normalRow` / `altRow` / `highlightRow` → column `style` →
  `labelCell` (month-name cells, not on highlighted rows) → `cellHook(CellRef)`.
  Header: `header` → column `headerStyle`.
* `CellBadge(color, border, radius)` draws a pill (stadium) or rounded badge
  behind the text — the day-number pills of the mock-ups. Not drawn on empty
  cells.
* A filled date column = a column `style` with `background`/`foreground`.
* `grid: GridLines(horizontal:, vertical:, headerBottom:)`, `outerBorder`
  (rect border above the content), `panel` (any `PanelStyle`).
* `referenceTableSpec(theme)` is the spec of the shared layout — a good start.

## Example

```dart
class EmeraldArchTemplate extends PosterTemplate {
  const EmeraldArchTemplate();
  @override String get id => 'emerald_arch';
  @override String get nameAr => 'المحراب الأخضر';
  @override PosterTheme get theme => _theme; // palette for editor/contrast tests

  @override
  Widget build(MonthPoster p) => PosterPage(
    textStyle: const TextStyle(inherit: false, fontFamily: 'Amiri',
        fontSize: 20, color: _ivory),
    color: _emerald,
    foregroundPainter: (size) => _Frame(_metrics(size, p.days.length)),
    child: LayoutBuilder(builder: (context, c) {
      final m = _metrics(c.biggest, p.days.length);
      Widget at(String id, Widget w) =>
          Positioned.fromRect(rect: m.sections[id]!, child: w);
      return Stack(children: [
        at('title', TitleBlock.image(const AssetImage('assets/logos/title.png'),
            tint: _gold)),
        at('brace', PosterPanel(
            style: const PanelStyle(shape: PanelShape.ribbon(notched: true),
                color: _cream, padding: EdgeInsets.all(8)),
            child: BraceQuote(p.texts.braceQuote, maxLines: 1))),
        at('main', PosterPanel(
            style: const PanelStyle(
                shape: PanelShape.arch(rise: 140, pointed: true),
                color: _panel, border: BorderSide(color: _gold, width: 3)),
            child: PosterTableView(poster: p, spec: _spec))),
        at('article', ClosingArticleBlock.of(p, bodyHeight: null)),
      ]);
    }),
  );
}
```

`test/templates/kit_demo_template.dart` is a complete, tested example (arch
panel, three-panel split table, ribbon, cartouche, rounded, pills, filled
column, frame painter aligned via `KitMetrics`); its render is
`test/templates/goldens/kit_demo.png`.

## Design rules

1. **No literal sizes in widget code.** Take sizes from `KitDefaults` or from
   the template's own named constants at the top of its file; the widgets and
   the painters must read the *same* constants (`SectionLayout`,
   `TableGeometry`, `KitMetrics`) so ornaments never drift from the content.
2. **FitText everywhere.** Every variable text goes through the kit blocks /
   `FitText`: it shrinks (0.5 steps down to `kFitTextFloor`), wraps only at
   word boundaries, never clips or ellipsises. Do not put raw `Text` on the
   poster. Give single-line cells a tight `lineHeight` (`KitDefaults.tightLine`).
3. **Deterministic.** No randomness, clocks, network or platform branches in
   build or paint; same poster → same pixels (goldens depend on it).
4. **Contrast.** Every text colour on its fill (panel, row, stripe, highlight,
   label, badge) must reach 4.5:1; supply a `PosterTheme` whose pairs reflect
   the template (contrast_test checks registered templates), and check the
   painted panels you add.
5. **Data rules.** Null times render empty, empty texts render nothing (no
   stray braces/labels), uncertain flags are never drawn on the poster.
6. **Assets.** Logos come from `assets/logos/` via `AssetImage`; tests must
   not depend on them (use a text title or a `MemoryImage`).

## Registering a new template

1. Create `lib/templates/<id>.dart` with a `PosterTemplate` subclass: `id`,
   `nameAr`, `theme` (palette; used by tests and as fallback), and override
   `build(MonthPoster)` to compose the kit.
2. Add it to `allTemplates` in `lib/templates/registry.dart` (navy_gold stays
   first: it is the default for unknown ids).
3. It then automatically runs through golden_test (add
   `goldens/<id>.png` with `--update-goldens` and inspect it),
   header_wordbreak_test (12 months), overflow_test (extreme/empty data) and
   contrast_test.

## Not configurable (known limits)

* The shared `PosterLayout`'s section order and heights (`_kBraceHeight`,
  `_kFooterHeight`, article heights) stay fixed for the five original
  templates — byte-identical output is required; new templates compose their
  own structure instead.
* Table: one header row only (no multi-row/merged headers), no row spans, no
  week-separator lines (use a painter with `TableGeometry.rowRect`), columns
  are the fixed set (weekday, three day columns, four prayer times, notes).
* Panel borders are solid strokes (no dashed/ornamental borders — paint those
  with `PanelShape.pathFor`); shadows ignore `BlurStyle`; the arch has one
  pointed-arch profile (rise and corner radius are configurable, the curve
  shape is not).
* `PanelShape.safeInsets` are approximations (e.g. cartouche corners), so
  very tight panels may need extra `padding`.
* A rotated panel's bounding box is not reflected in `SectionLayout` rects.
