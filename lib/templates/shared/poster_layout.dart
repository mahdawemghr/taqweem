import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../../domain/time_format.dart';
import '../kit/kit.dart';
import '../poster_template.dart';
import 'painters.dart';

// ---------------------------------------------------------------------------
// Layout constants — the ONE place every section size and column width is
// defined. Both [PosterLayout] and [LayoutMetrics.compute] read these, so the
// metrics handed to the frame painter cannot drift from the real layout.
// Proportions follow the reference scan (controller ruling R11).
// ---------------------------------------------------------------------------

/// Default [PosterTheme.contentPadding]: 40 left/right, 48 top/bottom.
const EdgeInsets kDefaultContentPadding = EdgeInsets.fromLTRB(40, 48, 40, 48);

// Fixed section heights (logical px). The table body takes what is left.
const double _kBraceHeight = 90;
const double _kFooterHeight = 50;
const double _kArticleHeadingHeight = 48;
const double _kArticleBodyHeight = 200;
const double _kFatihaHeight = 46;
const double _kTableHeaderHeight = KitDefaults.tableHeaderHeight;

/// Width of each rotated side Q&A strip (R12).
const double _kSideStripWidth = KitDefaults.sideStripWidth;

// Table column widths (right -> left) come from [KitDefaults]: weekday 60,
// hijri/gregorian/solar 46, the four times 54; notes takes the remaining
// width (≈ 402 px ≈ 49 % of the 816 px table with the default padding).

/// Line-height factor for single-line cells and the side strips, so the row
/// height (not Amiri's tall default line box) bounds the glyph size.
const double _kTightLine = KitDefaults.tightLine;

/// Absolute positions (poster coordinates, origin top-left) of the poster's
/// sections, handed to [PosterTheme.framePainter] so ornaments can follow
/// the real layout.
///
/// Vertical order inside [contentRect]:
/// header (`contentRect.top` .. [headerBottom]) → brace quote
/// (.. [braceBottom]) → main area = table + side Q&A strips ([tableTop] ..
/// [tableBottom]; the table's header row ends at [tableHeaderBottom]) →
/// footer notes (.. [articleTop]) → closing article ([articleTop] ..
/// [articleBottom] == `contentRect.bottom`).
@immutable
class LayoutMetrics implements LayoutMetricsLike {
  const LayoutMetrics({
    required this.size,
    required this.contentRect,
    required this.headerBottom,
    required this.braceBottom,
    required this.tableTop,
    required this.tableHeaderBottom,
    required this.tableBottom,
    required this.articleTop,
    required this.articleBottom,
    required this.tableRect,
    required this.rightStripRect,
    required this.leftStripRect,
    required this.rowCount,
  });

  /// Computes the metrics [PosterLayout] produces for a poster of [size]
  /// with [rowCount] day rows.
  factory LayoutMetrics.compute(Size size, PosterTheme theme, int rowCount) {
    final content = theme.contentPadding.deflateRect(Offset.zero & size);
    final headerBottom = content.top + theme.headerHeight;
    final braceBottom = headerBottom + _kBraceHeight;
    final articleBottom = content.bottom;
    final articleTop =
        articleBottom -
        _kArticleHeadingHeight -
        _kArticleBodyHeight -
        _kFatihaHeight;
    final tableBottom = articleTop - _kFooterHeight;
    final tableTop = braceBottom;
    return LayoutMetrics(
      size: size,
      contentRect: content,
      headerBottom: headerBottom,
      braceBottom: braceBottom,
      tableTop: tableTop,
      tableHeaderBottom: tableTop + _kTableHeaderHeight,
      tableBottom: tableBottom,
      articleTop: articleTop,
      articleBottom: articleBottom,
      tableRect: Rect.fromLTRB(
        content.left + _kSideStripWidth,
        tableTop,
        content.right - _kSideStripWidth,
        tableBottom,
      ),
      rightStripRect: Rect.fromLTRB(
        content.right - _kSideStripWidth,
        tableTop,
        content.right,
        tableBottom,
      ),
      leftStripRect: Rect.fromLTRB(
        content.left,
        tableTop,
        content.left + _kSideStripWidth,
        tableBottom,
      ),
      rowCount: rowCount,
    );
  }

  /// Whole poster size.
  @override
  final Size size;

  /// Poster rect minus [PosterTheme.contentPadding].
  @override
  final Rect contentRect;

  /// Bottom of the header band (title, emblem, two quote boxes).
  final double headerBottom;

  /// Bottom of the `{ " ... " }` brace-quote line.
  final double braceBottom;

  /// Top of the main area (table and side strips); equals [braceBottom].
  final double tableTop;

  /// Bottom of the table's column-header row.
  @override
  final double tableHeaderBottom;

  /// Bottom of the last table row.
  final double tableBottom;

  /// Top of the closing article (bottom of the footer-notes line).
  final double articleTop;

  /// Bottom of the closing article (= `contentRect.bottom`).
  final double articleBottom;

  /// The table itself, without the side strips.
  @override
  final Rect tableRect;

  /// Rotated side Q&A strips on the right / left edge of the main area.
  final Rect rightStripRect, leftStripRect;

  /// Number of day rows in the table.
  @override
  final int rowCount;

  /// Height of one day row.
  @override
  double get rowHeight =>
      rowCount == 0 ? 0 : (tableBottom - tableHeaderBottom) / rowCount;

  /// Day row [i] across the table (side strips excluded).
  @override
  Rect rowRect(int i) => Rect.fromLTWH(
    tableRect.left,
    tableHeaderBottom + rowHeight * i,
    tableRect.width,
    rowHeight,
  );

  /// Sections: 'header', 'brace', 'main' (table + strips), 'table',
  /// 'rightStrip', 'leftStrip', 'footer', 'article'.
  @override
  Rect? section(String id) => switch (id) {
    'header' => Rect.fromLTRB(
      contentRect.left,
      contentRect.top,
      contentRect.right,
      headerBottom,
    ),
    'brace' => Rect.fromLTRB(
      contentRect.left,
      headerBottom,
      contentRect.right,
      braceBottom,
    ),
    'main' => Rect.fromLTRB(
      contentRect.left,
      tableTop,
      contentRect.right,
      tableBottom,
    ),
    'table' => tableRect,
    'rightStrip' => rightStripRect,
    'leftStrip' => leftStripRect,
    'footer' => Rect.fromLTRB(
      contentRect.left,
      tableBottom,
      contentRect.right,
      articleTop,
    ),
    'article' => Rect.fromLTRB(
      contentRect.left,
      articleTop,
      contentRect.right,
      articleBottom,
    ),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is LayoutMetrics &&
      other.size == size &&
      other.contentRect == contentRect &&
      other.headerBottom == headerBottom &&
      other.braceBottom == braceBottom &&
      other.tableTop == tableTop &&
      other.tableHeaderBottom == tableHeaderBottom &&
      other.tableBottom == tableBottom &&
      other.articleTop == articleTop &&
      other.articleBottom == articleBottom &&
      other.tableRect == tableRect &&
      other.rightStripRect == rightStripRect &&
      other.leftStripRect == leftStripRect &&
      other.rowCount == rowCount;

  @override
  int get hashCode => Object.hash(
    size,
    contentRect,
    headerBottom,
    braceBottom,
    tableTop,
    tableHeaderBottom,
    tableBottom,
    articleTop,
    articleBottom,
    tableRect,
    rightStripRect,
    leftStripRect,
    rowCount,
  );
}

/// The structure shared by the five original templates, modelled on the
/// reference "تقويم أهل البيت" poster, composed from the template kit
/// (`lib/templates/kit/`). All colours and fonts come from [theme];
/// ornaments come only from the theme's painters. Every piece of variable
/// text goes through [FitText], so nothing can overflow or be clipped.
///
/// New templates that want their own structure compose the kit blocks
/// directly in `PosterTemplate.build` instead.
class PosterLayout extends StatelessWidget {
  const PosterLayout({super.key, required this.poster, required this.theme});

  final MonthPoster poster;
  final PosterTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return PosterPage(
      textStyle: TextStyle(
        inherit: false,
        fontFamily: t.bodyFont,
        fontSize: 20,
        color: t.bodyText,
        fontWeight: FontWeight.w400,
        decoration: TextDecoration.none,
      ),
      color: t.background,
      backgroundPainter: (_) => t.backgroundPainter(),
      padding: t.contentPadding,
      foregroundPainter: (size) =>
          t.framePainter(LayoutMetrics.compute(size, t, poster.days.length)),
      child: _content(),
    );
  }

  TextStyle get _body => TextStyle(fontFamily: theme.bodyFont);
  TextStyle get _heading => TextStyle(fontFamily: theme.headingFont);

  /// Bold body text in [color].
  TextStyle _bold(Color color) =>
      _body.copyWith(color: color, fontWeight: FontWeight.w700);

  Widget _content() {
    final texts = poster.texts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: theme.headerHeight, child: _header()),
        SizedBox(
          height: _kBraceHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
            child: BraceQuote(texts.braceQuote, style: _bold(theme.bodyText)),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // RTL: first child is the right edge.
              _sideStrip(texts.sideRight),
              Expanded(
                child: PosterTableView(
                  key: const ValueKey('poster-table'),
                  poster: poster,
                  spec: referenceTableSpec(theme),
                ),
              ),
              _sideStrip(texts.sideLeft),
            ],
          ),
        ),
        SizedBox(
          key: const ValueKey('poster-footer'),
          height: _kFooterHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: FooterNote(texts.footerNotes, style: _bold(theme.bodyText)),
          ),
        ),
        ClosingArticleBlock.of(
          poster,
          key: const ValueKey('poster-article'),
          headingStyle: _bold(theme.titleColor).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: theme.titleColor,
          ),
          bodyStyle: _bold(theme.bodyText),
          fatihaStyle: _bold(theme.titleColor),
          headingHeight: _kArticleHeadingHeight,
          bodyHeight: _kArticleBodyHeight,
          fatihaHeight: _kFatihaHeight,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- header

  Widget _header() {
    final texts = poster.texts;
    final emblem =
        theme.emblemPainter?.call() ??
        StarMedallionPainter(color: theme.accent, fill: theme.background);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 30, child: _quoteBox(texts.rightQuote)),
        Expanded(
          flex: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: theme.headerHeight * 0.48,
                child: TitleBlock.text(
                  texts.title,
                  style: _heading.copyWith(
                    color: theme.titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(painter: emblem),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(flex: 30, child: _quoteBox(texts.leftQuote)),
      ],
    );
  }

  Widget _quoteBox(HeaderQuote q) {
    if (q.text.isEmpty && q.attribution.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(
        top: theme.headerHeight * 0.17,
        bottom: theme.headerHeight * 0.06,
      ),
      child: QuoteBlock(
        q,
        textStyle: _bold(theme.quoteText),
        attributionStyle: _bold(theme.accent),
        panel: PanelStyle(
          color: theme.quoteBoxBg,
          border: BorderSide(
            color: theme.quoteBoxBorder,
            width: theme.quoteBoxBorderWidth,
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- side strips

  /// Side Q&A, rotated so it reads top → bottom like the reference (both
  /// margins in the reference run the same way: quarterTurns 3).
  Widget _sideStrip(SideQa qa) => SideQaStrip(
    qa,
    width: _kSideStripWidth,
    style: _bold(theme.bodyText).copyWith(height: _kTightLine),
  );
}

/// The [TableSpec] of the shared layout for [theme]: the reference column
/// order and widths, one panel with a rectangular outer border, zebra rows,
/// highlighted rows and month-label cells in the theme's colours.
///
/// A good starting point for kit templates too (`copyWith`-style: build a
/// new [TableSpec] reusing its parts).
TableSpec referenceTableSpec(PosterTheme theme) {
  final head = theme.tableFont ?? theme.headingFont;
  final cellFont = theme.tableFont ?? theme.bodyFont;
  final grid = BorderSide(color: theme.gridLine, width: KitDefaults.gridWidth);
  const calHeader = CellStyle(
    lineHeight: kFontLineHeight,
    maxSize: KitDefaults.headerCalendarMax,
    wrap: true,
  );
  const timeHeader = CellStyle(maxSize: KitDefaults.headerTimeMax);
  final calHeaderFont = CellStyle(fontFamily: cellFont).merge(calHeader);
  return TableSpec(
    groups: [
      [
        const TableColumn.weekday(
          style: CellStyle(maxSize: KitDefaults.weekdayMax),
        ),
        TableColumn.hijri(headerStyle: calHeaderFont),
        TableColumn.gregorian(headerStyle: calHeaderFont),
        TableColumn.solar(headerStyle: calHeaderFont),
        for (final s in PrayerSlot.values)
          TableColumn.time(s, headerStyle: timeHeader),
        const TableColumn.notes(
          style: CellStyle(
            lineHeight: kFontLineHeight,
            maxSize: KitDefaults.noteMax,
            wrap: true,
          ),
          headerStyle: CellStyle(maxSize: KitDefaults.headerNotesMax),
        ),
      ],
    ],
    headerHeight: _kTableHeaderHeight,
    header: CellStyle(
      background: theme.tableHeaderBg,
      foreground: theme.tableHeaderFg,
      fontFamily: head,
      fontWeight: FontWeight.w700,
      lineHeight: _kTightLine,
      maxSize: KitDefaults.headerLabelMax,
      wrap: false,
    ),
    body: CellStyle(
      fontFamily: cellFont,
      fontWeight: FontWeight.w700,
      lineHeight: _kTightLine,
      maxSize: KitDefaults.cellMax,
      minSize: KitDefaults.cellMin,
      wrap: false,
    ),
    normalRow: CellStyle(background: theme.rowBg, foreground: theme.rowText),
    altRow: CellStyle(background: theme.rowAltBg, foreground: theme.rowText),
    highlightRow: CellStyle(
      background: theme.highlightBg,
      foreground: theme.highlightFg,
    ),
    labelCell: CellStyle(
      background: theme.labelCellBg,
      foreground: theme.labelCellFg,
    ),
    grid: GridLines(
      horizontal: grid,
      vertical: theme.verticalGridLines ? grid : null,
    ),
    outerBorder: BorderSide(
      color: theme.gridLine,
      width: theme.tableBorderWidth,
    ),
  );
}
