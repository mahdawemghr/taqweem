/// Default sizes of the template kit (logical px on the 1000 x 2200 poster).
///
/// Templates built with the kit take every size from here (or from their own
/// named constants derived from these), never from literals scattered through
/// widget code. The defaults equal the proportions of the reference scan used
/// by the shared [PosterLayout], so a kit table with default column widths
/// lines up with the five original templates.
abstract final class KitDefaults {
  /// Weekday column width.
  static const double weekdayWidth = 60;

  /// Hijri / gregorian / solar day column width.
  static const double dateWidth = 46;

  /// Prayer-time column width.
  static const double timeWidth = 54;

  /// Height of the table's column-header row.
  static const double tableHeaderHeight = 84;

  /// Width of a rotated side Q&A strip.
  static const double sideStripWidth = 52;

  /// Hairline grid width inside the table.
  static const double gridWidth = 1;

  /// Line-height factor for single-line cells and strips: the row height (not
  /// the font's tall default line box) bounds the glyph size.
  static const double tightLine = 1.2;

  /// Padding inside every table cell.
  static const double cellPadH = 3, cellPadV = 1;

  /// Gap between the panels of a split table (notes | times | dates).
  static const double splitGap = 14;

  /// FitText caps used by the kit blocks.
  static const double titleMax = 64;
  static const double quoteMax = 28;
  static const double attributionMax = 26;
  static const double attributionHeight = 40;
  static const double braceMax = 32;
  static const double footerMax = 24;
  static const double sideMax = 24;
  static const double articleHeadingMax = 32;
  static const double articleBodyMax = 32;
  static const double fatihaMax = 30;
  static const double cellMax = 24;
  static const double weekdayMax = 22;
  static const double noteMax = 22;
  static const double cellMin = 7;
  static const double headerLabelMax = 30;
  static const double headerTimeMax = 26;
  static const double headerNotesMax = 46;
  static const double headerCalendarMax = 20;

  /// Closing-article section heights.
  static const double articleHeadingHeight = 48;
  static const double articleBodyHeight = 200;
  static const double fatihaHeight = 46;
}
