import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../../domain/time_format.dart';
import '../poster_template.dart';
import 'fit_text.dart';
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
const double _kTableHeaderHeight = 84;

/// Width of each rotated side Q&A strip (R12).
const double _kSideStripWidth = 52;

// Table column widths, right -> left; notes takes the remaining width
// (≈ 402 px ≈ 49 % of the 816 px table with the default padding).
const double _kWeekdayW = 60;
const double _kDateW = 46; // hijri, gregorian, solar
const double _kTimeW = 54; // fajr, shurooq, zuhr, maghrib

const double _kGrid = 1;
const double _kOuterGrid = 2.5;

/// Line-height factor for single-line cells and the side strips, so the row
/// height (not Amiri's tall default line box) bounds the glyph size.
const double _kTightLine = 1.2;

/// Wraps [inner] in braces that print as on the reference poster: `{` at the
/// right end, `}` at the left end. Each brace sits in its own left-to-right
/// isolate (LRI U+2066 … PDI U+2069), so the RTL paragraph does not
/// bidi-mirror it. (Plain `{ … }` — and LRM marks — render mirrored, i.e.
/// `}` on the right; verified by rendering.)
String _braced(String inner) => '\u2066{\u2069 $inner \u2066}\u2069';

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
class LayoutMetrics {
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
  final Size size;

  /// Poster rect minus [PosterTheme.contentPadding].
  final Rect contentRect;

  /// Bottom of the header band (title, emblem, two quote boxes).
  final double headerBottom;

  /// Bottom of the `{ " ... " }` brace-quote line.
  final double braceBottom;

  /// Top of the main area (table and side strips); equals [braceBottom].
  final double tableTop;

  /// Bottom of the table's column-header row.
  final double tableHeaderBottom;

  /// Bottom of the last table row.
  final double tableBottom;

  /// Top of the closing article (bottom of the footer-notes line).
  final double articleTop;

  /// Bottom of the closing article (= `contentRect.bottom`).
  final double articleBottom;

  /// The table itself, without the side strips.
  final Rect tableRect;

  /// Rotated side Q&A strips on the right / left edge of the main area.
  final Rect rightStripRect, leftStripRect;

  /// Number of day rows in the table.
  final int rowCount;

  /// Height of one day row.
  double get rowHeight =>
      rowCount == 0 ? 0 : (tableBottom - tableHeaderBottom) / rowCount;

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

/// The structure shared by every template, modelled on the reference
/// "تقويم أهل البيت" poster. All colours and fonts come from [theme];
/// ornaments come only from the theme's painters. Every piece of variable
/// text goes through [FitText], so nothing can overflow or be clipped.
class PosterLayout extends StatelessWidget {
  const PosterLayout({super.key, required this.poster, required this.theme});

  final MonthPoster poster;
  final PosterTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTextStyle(
        style: TextStyle(
          inherit: false,
          fontFamily: t.bodyFont,
          fontSize: 20,
          color: t.bodyText,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = c.biggest;
            final metrics = LayoutMetrics.compute(size, t, poster.days.length);
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: t.background),
                CustomPaint(painter: t.backgroundPainter()),
                Padding(padding: t.contentPadding, child: _content()),
                IgnorePointer(
                  child: CustomPaint(painter: t.framePainter(metrics)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  TextStyle get _body => TextStyle(fontFamily: theme.bodyFont);
  TextStyle get _heading => TextStyle(fontFamily: theme.headingFont);

  Widget _content() {
    final texts = poster.texts;
    final brace = texts.braceQuote.isEmpty
        ? ''
        : _braced('" ${texts.braceQuote} "');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: theme.headerHeight, child: _header()),
        SizedBox(
          height: _kBraceHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
            child: FitText(
              brace,
              style: _body.copyWith(
                color: theme.bodyText,
                fontWeight: FontWeight.w700,
              ),
              maxSize: 32,
            ),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // RTL: first child is the right edge.
              _sideStrip(texts.sideRight),
              Expanded(child: _table()),
              _sideStrip(texts.sideLeft),
            ],
          ),
        ),
        SizedBox(
          key: const ValueKey('poster-footer'),
          height: _kFooterHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: FitText(
              texts.footerNotes,
              style: _body.copyWith(
                color: theme.bodyText,
                fontWeight: FontWeight.w700,
              ),
              maxSize: 24,
              maxLines: 1,
              align: TextAlign.start,
            ),
          ),
        ),
        _article(),
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
                child: FitText(
                  texts.title,
                  style: _heading.copyWith(
                    color: theme.titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                  maxSize: 64,
                  maxLines: 1,
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.quoteBoxBg,
          border: Border.all(color: theme.quoteBoxBorder, width: 2.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FitText(
                  q.text,
                  style: _body.copyWith(
                    color: theme.quoteText,
                    fontWeight: FontWeight.w700,
                  ),
                  maxSize: 28,
                ),
              ),
              if (q.attribution.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: FitText(
                    q.attribution,
                    style: _body.copyWith(
                      color: theme.accent,
                      fontWeight: FontWeight.w700,
                    ),
                    maxSize: 26,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- side strips

  /// Side Q&A, rotated so it reads top → bottom like the reference (both
  /// margins in the reference run the same way: quarterTurns 3).
  Widget _sideStrip(SideQa qa) {
    Widget line(String label, String value) => Expanded(
      child: FitText(
        value.isEmpty ? '' : '$label : $value',
        style: _body.copyWith(
          color: theme.bodyText,
          fontWeight: FontWeight.w700,
          height: _kTightLine,
        ),
        maxSize: 24,
        maxLines: 1,
        align: TextAlign.start,
      ),
    );
    return SizedBox(
      width: _kSideStripWidth,
      child: RotatedBox(
        quarterTurns: 3,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [line('سؤال', qa.question), line('الجواب', qa.answer)],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- table

  Widget _table() {
    final days = poster.days;
    return Container(
      key: const ValueKey('poster-table'),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: theme.gridLine, width: _kOuterGrid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _kTableHeaderHeight, child: _headerRow()),
          for (var i = 0; i < days.length; i++)
            Expanded(child: _dayRow(days[i], i)),
        ],
      ),
    );
  }

  Widget _cell({
    required double? width,
    required Color bg,
    required Widget child,
    bool last = false,
    bool bottom = true,
  }) {
    final side = BorderSide(color: theme.gridLine, width: _kGrid);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: last ? BorderSide.none : side,
          bottom: bottom ? side : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 1, 3, 1),
        child: child,
      ),
    );
    return width == null
        ? Expanded(child: box)
        : SizedBox(width: width, child: box);
  }

  Widget _headerRow() {
    final bg = theme.tableHeaderBg;
    final fg = theme.tableHeaderFg;
    Widget label(String s, {double max = 30}) => FitText(
      s,
      style: _heading.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
        height: _kTightLine,
      ),
      maxSize: max,
      maxLines: 1,
    );
    Widget cal(String s) => FitText(
      s,
      style: _body.copyWith(color: fg, fontWeight: FontWeight.w700),
      maxSize: 20,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cell(width: _kWeekdayW, bg: bg, child: label('اليوم')),
        _cell(width: _kDateW, bg: bg, child: cal(poster.hijriHeader)),
        _cell(width: _kDateW, bg: bg, child: cal(poster.gregorianHeader)),
        _cell(width: _kDateW, bg: bg, child: cal(poster.solarHeader)),
        for (final s in PrayerSlot.values)
          _cell(width: _kTimeW, bg: bg, child: label(s.labelAr, max: 26)),
        _cell(
          width: null,
          bg: bg,
          last: true,
          child: label('ملاحظات', max: 46),
        ),
      ],
    );
  }

  Widget _dayRow(DayRow d, int index) {
    final isLast = index == poster.days.length - 1;
    final rowBg = d.highlighted
        ? theme.highlightBg
        : (index.isEven ? theme.rowBg : theme.rowAltBg);
    final rowFg = d.highlighted ? theme.highlightFg : theme.rowText;

    Widget text(String s, Color fg, {double max = 24, bool note = false}) =>
        FitText(
          s,
          style: _body.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            height: note ? null : _kTightLine,
          ),
          maxSize: note ? 22 : max,
          minSize: 7,
          maxLines: note ? null : 1,
        );

    Widget dayCell(DayCell c) {
      // Highlighted rows win over label colouring so the row reads as one.
      final label = c.isLabel && !d.highlighted;
      return _cell(
        width: _kDateW,
        bg: label ? theme.labelCellBg : rowBg,
        bottom: !isLast,
        child: text(
          c.isLabel ? c.label! : '${c.number}',
          label ? theme.labelCellFg : rowFg,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cell(
          width: _kWeekdayW,
          bg: rowBg,
          bottom: !isLast,
          child: text(d.weekday.ar, rowFg, max: 22),
        ),
        _cell(
          width: _kDateW,
          bg: rowBg,
          bottom: !isLast,
          child: text('${d.hijriDay}', rowFg),
        ),
        dayCell(d.gregorian),
        dayCell(d.solar),
        for (final s in PrayerSlot.values)
          _cell(
            width: _kTimeW,
            bg: rowBg,
            bottom: !isLast,
            // Null time renders empty, never a placeholder.
            child: text(formatTime(d.times[s]) ?? '', rowFg),
          ),
        _cell(
          width: null,
          bg: rowBg,
          last: true,
          bottom: !isLast,
          child: text(d.note, rowFg, note: true),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- article

  Widget _article() {
    final a = poster.texts.article;
    return Column(
      key: const ValueKey('poster-article'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _kArticleHeadingHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 2),
            child: FitText(
              a.author.isEmpty ? '' : ':: ${a.author} ::',
              style: _body.copyWith(
                color: theme.titleColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: theme.titleColor,
              ),
              maxSize: 32,
              maxLines: 1,
            ),
          ),
        ),
        SizedBox(
          height: _kArticleBodyHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: FitText(
              a.body.isEmpty ? '' : _braced(a.body),
              style: _body.copyWith(
                color: theme.bodyText,
                fontWeight: FontWeight.w700,
              ),
              maxSize: 32,
              align: TextAlign.justify,
            ),
          ),
        ),
        SizedBox(
          height: _kFatihaHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 2),
            child: FitText(
              poster.texts.fatiha,
              style: _body.copyWith(
                color: theme.titleColor,
                fontWeight: FontWeight.w700,
              ),
              maxSize: 30,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
