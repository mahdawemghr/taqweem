import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../../domain/time_format.dart';
import '../shared/fit_text.dart';
import 'constants.dart';
import 'panel.dart';

/// [CellStyle.lineHeight] value meaning "the font's own line height" (used to
/// clear an inherited tight line height, e.g. for wrapping notes).
const double kFontLineHeight = 0;

/// The data a table column shows.
enum ColumnKind { weekday, hijri, gregorian, solar, time, notes }

/// Row states a cell can be styled for.
enum RowState {
  /// Even rows (0, 2, …).
  normal,

  /// Odd rows (the stripe).
  alt,

  /// Rows the user marked as highlighted.
  highlighted,
}

/// A pill / rounded badge drawn behind a cell's text (e.g. the day-number
/// pills of the mock-ups). Not drawn for empty cells.
@immutable
class CellBadge {
  const CellBadge({
    this.color,
    this.border,
    this.radius,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  final Color? color;
  final BorderSide? border;

  /// Corner radius; null = stadium (fully round ends).
  final double? radius;

  /// Padding between the badge edge and the text.
  final EdgeInsets padding;

  ShapeBorder get shape {
    final side = border ?? BorderSide.none;
    final r = radius;
    return r == null
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(
            side: side,
            borderRadius: BorderRadius.circular(r),
          );
  }
}

/// How one table cell looks. Every field is optional; styles are layered
/// with [merge] (a non-null field of the later style wins):
///
/// `TableSpec.body` → row state (`normalRow` / `altRow` / `highlightRow`) →
/// `TableColumn.style` → `TableSpec.labelCell` (gregorian/solar month-name
/// cells, not on highlighted rows) → `TableSpec.cellHook`.
///
/// Header cells: `TableSpec.header` → `TableColumn.headerStyle`.
@immutable
class CellStyle {
  const CellStyle({
    this.background,
    this.foreground,
    this.fontFamily,
    this.fontWeight,
    this.lineHeight,
    this.maxSize,
    this.minSize,
    this.wrap,
    this.padding,
    this.align,
    this.badge,
    this.shadows,
  });

  final Color? background, foreground;
  final String? fontFamily;
  final FontWeight? fontWeight;

  /// Line-height factor; [kFontLineHeight] = the font's own.
  final double? lineHeight;

  /// FitText caps.
  final double? maxSize, minSize;

  /// Whether the text may wrap (false = one line, dropped only if the text
  /// cannot fit otherwise — FitText never loses words).
  final bool? wrap;
  final EdgeInsets? padding;
  final TextAlign? align;
  final CellBadge? badge;
  final List<Shadow>? shadows;

  CellStyle merge(CellStyle? o) => o == null
      ? this
      : CellStyle(
          background: o.background ?? background,
          foreground: o.foreground ?? foreground,
          fontFamily: o.fontFamily ?? fontFamily,
          fontWeight: o.fontWeight ?? fontWeight,
          lineHeight: o.lineHeight ?? lineHeight,
          maxSize: o.maxSize ?? maxSize,
          minSize: o.minSize ?? minSize,
          wrap: o.wrap ?? wrap,
          padding: o.padding ?? padding,
          align: o.align ?? align,
          badge: o.badge ?? badge,
          shadows: o.shadows ?? shadows,
        );

  /// The text style FitText merges onto the page's default style.
  TextStyle get textStyle {
    final h = lineHeight;
    return TextStyle(
      fontFamily: fontFamily,
      color: foreground,
      fontWeight: fontWeight,
      height: h == null || h == kFontLineHeight ? null : h,
      shadows: shadows,
    );
  }
}

/// One table column: what it shows, how wide it is and how it looks.
@immutable
class TableColumn {
  const TableColumn._(
    this.kind, {
    this.slot,
    this.width,
    this.flex = 1,
    this.style,
    this.headerStyle,
    this.header,
  });

  const TableColumn.weekday({
    double? width = KitDefaults.weekdayWidth,
    int flex = 1,
    CellStyle? style,
    CellStyle? headerStyle,
    String? header,
  }) : this._(
         ColumnKind.weekday,
         width: width,
         flex: flex,
         style: style,
         headerStyle: headerStyle,
         header: header,
       );

  const TableColumn.hijri({
    double? width = KitDefaults.dateWidth,
    int flex = 1,
    CellStyle? style,
    CellStyle? headerStyle,
    String? header,
  }) : this._(
         ColumnKind.hijri,
         width: width,
         flex: flex,
         style: style,
         headerStyle: headerStyle,
         header: header,
       );

  const TableColumn.gregorian({
    double? width = KitDefaults.dateWidth,
    int flex = 1,
    CellStyle? style,
    CellStyle? headerStyle,
    String? header,
  }) : this._(
         ColumnKind.gregorian,
         width: width,
         flex: flex,
         style: style,
         headerStyle: headerStyle,
         header: header,
       );

  const TableColumn.solar({
    double? width = KitDefaults.dateWidth,
    int flex = 1,
    CellStyle? style,
    CellStyle? headerStyle,
    String? header,
  }) : this._(
         ColumnKind.solar,
         width: width,
         flex: flex,
         style: style,
         headerStyle: headerStyle,
         header: header,
       );

  const TableColumn.time(
    PrayerSlot slot, {
    double? width = KitDefaults.timeWidth,
    int flex = 1,
    CellStyle? style,
    CellStyle? headerStyle,
    String? header,
  }) : this._(
         ColumnKind.time,
         slot: slot,
         width: width,
         flex: flex,
         style: style,
         headerStyle: headerStyle,
         header: header,
       );

  /// Notes; by default takes the remaining width ([width] null, [flex]).
  const TableColumn.notes({
    double? width,
    int flex = 1,
    CellStyle? style,
    CellStyle? headerStyle,
    String? header,
  }) : this._(
         ColumnKind.notes,
         width: width,
         flex: flex,
         style: style,
         headerStyle: headerStyle,
         header: header,
       );

  final ColumnKind kind;

  /// The prayer for [ColumnKind.time].
  final PrayerSlot? slot;

  /// Fixed width; null = share the remaining width by [flex].
  final double? width;
  final int flex;
  final CellStyle? style, headerStyle;

  /// Header text override (default: the poster's column header).
  final String? header;

  /// The header label for [poster].
  String headerText(MonthPoster poster) =>
      header ??
      switch (kind) {
        ColumnKind.weekday => 'اليوم',
        ColumnKind.hijri => poster.hijriHeader,
        ColumnKind.gregorian => poster.gregorianHeader,
        ColumnKind.solar => poster.solarHeader,
        ColumnKind.time => slot!.labelAr,
        ColumnKind.notes => 'ملاحظات',
      };

  /// The cell text for day [d]. Null times render empty, never a
  /// placeholder.
  String cellText(DayRow d) => switch (kind) {
    ColumnKind.weekday => d.weekday.ar,
    ColumnKind.hijri => '${d.hijriDay}',
    ColumnKind.gregorian => _day(d.gregorian),
    ColumnKind.solar => _day(d.solar),
    ColumnKind.time => formatTime(d.times[slot!]) ?? '',
    ColumnKind.notes => d.note,
  };

  static String _day(DayCell c) => c.isLabel ? c.label! : '${c.number}';

  /// Whether this column's cell for [d] is a month-name label cell.
  bool isLabelCell(DayRow d) => switch (kind) {
    ColumnKind.gregorian => d.gregorian.isLabel,
    ColumnKind.solar => d.solar.isLabel,
    _ => false,
  };
}

/// Everything a [TableSpec.cellHook] may look at.
@immutable
class CellRef {
  const CellRef({
    required this.column,
    required this.columnIndex,
    required this.rowIndex,
    required this.day,
    required this.state,
    required this.isLabel,
  });

  final TableColumn column;

  /// Index in the flattened column order (right → left).
  final int columnIndex;
  final int rowIndex;
  final DayRow day;
  final RowState state;
  final bool isLabel;
}

/// Grid lines inside a table panel. Null = no line.
@immutable
class GridLines {
  const GridLines({this.horizontal, this.vertical, this.headerBottom});

  /// Line below each row (not below the last row).
  final BorderSide? horizontal;

  /// Line between columns (not after a panel's last column).
  final BorderSide? vertical;

  /// Line below the header row; null = [horizontal].
  final BorderSide? headerBottom;
}

/// Configuration of a [PosterTableView].
@immutable
class TableSpec {
  const TableSpec({
    required this.groups,
    this.split = false,
    this.gap = KitDefaults.splitGap,
    this.headerHeight = KitDefaults.tableHeaderHeight,
    this.rowHeight,
    this.header = const CellStyle(),
    this.body = const CellStyle(),
    this.normalRow,
    this.altRow,
    this.highlightRow,
    this.labelCell,
    this.cellHook,
    this.grid = const GridLines(),
    this.outerBorder,
    this.panel,
  });

  /// The reference column order (right → left): weekday, hijri, gregorian,
  /// solar, the four prayer times, notes — as ONE group.
  static const List<List<TableColumn>> referenceGroups = [
    [
      TableColumn.weekday(),
      TableColumn.hijri(),
      TableColumn.gregorian(),
      TableColumn.solar(),
      TableColumn.time(PrayerSlot.fajr),
      TableColumn.time(PrayerSlot.shurooq),
      TableColumn.time(PrayerSlot.zuhr),
      TableColumn.time(PrayerSlot.maghrib),
      TableColumn.notes(),
    ],
  ];

  /// Column groups, right → left (RTL). With [split] each group is its own
  /// panel (e.g. `[[dates…], [times…], [notes]]`), separated by [gap];
  /// otherwise the groups are concatenated into one table.
  final List<List<TableColumn>> groups;
  final bool split;
  final double gap;

  /// Header row height; 0 = no header row.
  final double headerHeight;

  /// Fixed day-row height; null = all rows share the height equally.
  final double? rowHeight;

  final CellStyle header, body;
  final CellStyle? normalRow, altRow, highlightRow, labelCell;

  /// Last-word styling hook (merged on top of everything else).
  final CellStyle? Function(CellRef ref)? cellHook;

  final GridLines grid;

  /// Rectangular border drawn ABOVE each panel's content.
  final BorderSide? outerBorder;

  /// Panel style of the table (each split panel gets it).
  final PanelStyle? panel;

  /// All columns, right → left.
  List<TableColumn> get columns => [for (final g in groups) ...g];

  /// The panels as column lists ([groups] when split, else one panel).
  List<List<TableColumn>> get panels => split ? groups : [columns];

  RowState stateOf(DayRow d, int index) => d.highlighted
      ? RowState.highlighted
      : (index.isEven ? RowState.normal : RowState.alt);

  /// The resolved style of a body cell.
  CellStyle resolve(TableColumn col, int colIndex, DayRow d, int rowIndex) {
    final state = stateOf(d, rowIndex);
    var s = body
        .merge(switch (state) {
          RowState.normal => normalRow,
          RowState.alt => altRow,
          RowState.highlighted => highlightRow,
        })
        .merge(col.style);
    final label = col.isLabelCell(d);
    // Highlighted rows win over label colouring so the row reads as one.
    if (label && state != RowState.highlighted) s = s.merge(labelCell);
    final hook = cellHook;
    if (hook != null) {
      s = s.merge(
        hook(
          CellRef(
            column: col,
            columnIndex: colIndex,
            rowIndex: rowIndex,
            day: d,
            state: state,
            isLabel: label,
          ),
        ),
      );
    }
    return s;
  }

  /// Horizontal space a panel adds around its columns.
  double get panelExtraWidth {
    final p = panel;
    if (p == null) return 0;
    final safe = p.isPlainRect
        ? EdgeInsets.zero
        : p.shape.safeInsets(Size.zero);
    return p.padding.horizontal + safe.horizontal;
  }
}

/// The calendar table built from a [MonthPoster] and a [TableSpec].
///
/// Every cell's text goes through [FitText] — it shrinks, wraps only at word
/// boundaries (the widest word always fits) and is never clipped or
/// ellipsised. Rows fill the available height equally unless
/// [TableSpec.rowHeight] is set. Use [geometry] for painters that must align
/// with the table.
class PosterTableView extends StatelessWidget {
  const PosterTableView({super.key, required this.poster, required this.spec});

  final MonthPoster poster;
  final TableSpec spec;

  /// Where the panels, header and rows of a table laid out in [rect] are.
  TableGeometry geometry(Rect rect) =>
      TableGeometry.compute(spec, rect, poster.days.length);

  @override
  Widget build(BuildContext context) {
    final panels = spec.panels;
    if (!spec.split) return _panel(panels.single, 0);
    final children = <Widget>[];
    var offset = 0;
    for (var i = 0; i < panels.length; i++) {
      final cols = panels[i];
      if (i > 0) children.add(SizedBox(width: spec.gap));
      final panel = _panel(cols, offset);
      final fixed = cols.every((c) => c.width != null);
      children.add(
        fixed
            ? SizedBox(
                width:
                    cols.fold<double>(0, (a, c) => a + c.width!) +
                    spec.panelExtraWidth,
                child: panel,
              )
            : Expanded(
                flex: cols
                    .where((c) => c.width == null)
                    .fold(0, (a, c) => a + c.flex),
                child: panel,
              ),
      );
      offset += cols.length;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// One panel holding [cols]; [offset] is the index of its first column in
  /// [TableSpec.columns].
  Widget _panel(List<TableColumn> cols, int offset) {
    final days = poster.days;
    final rh = spec.rowHeight;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec.headerHeight > 0)
          SizedBox(height: spec.headerHeight, child: _headerRow(cols)),
        for (var i = 0; i < days.length; i++)
          rh == null
              ? Expanded(child: _dayRow(cols, offset, days[i], i))
              : SizedBox(height: rh, child: _dayRow(cols, offset, days[i], i)),
      ],
    );
    final p = spec.panel;
    if (p != null) content = PosterPanel(style: p, child: content);
    final ob = spec.outerBorder;
    if (ob != null) {
      content = Container(
        foregroundDecoration: BoxDecoration(border: Border.fromBorderSide(ob)),
        child: content,
      );
    }
    return content;
  }

  Widget _cell({
    required TableColumn col,
    required CellStyle s,
    required String text,
    bool last = false,
    BorderSide? bottom,
  }) {
    final v = spec.grid.vertical;
    final fit = FitText(
      text,
      style: s.textStyle,
      maxSize: s.maxSize ?? KitDefaults.cellMax,
      minSize: s.minSize ?? KitDefaults.cellMin,
      maxLines: (s.wrap ?? false) ? null : 1,
      align: s.align ?? TextAlign.center,
    );
    final badge = s.badge;
    final content = badge == null || text.isEmpty
        ? fit
        : DecoratedBox(
            decoration: ShapeDecoration(color: badge.color, shape: badge.shape),
            child: Padding(padding: badge.padding, child: fit),
          );
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: s.background,
        border: Border(
          left: last || v == null ? BorderSide.none : v,
          bottom: bottom ?? BorderSide.none,
        ),
      ),
      child: Padding(
        padding:
            s.padding ??
            const EdgeInsets.fromLTRB(
              KitDefaults.cellPadH,
              KitDefaults.cellPadV,
              KitDefaults.cellPadH,
              KitDefaults.cellPadV,
            ),
        child: content,
      ),
    );
    final w = col.width;
    return w == null
        ? Expanded(flex: col.flex, child: box)
        : SizedBox(width: w, child: box);
  }

  Widget _headerRow(List<TableColumn> cols) {
    final bottom = spec.grid.headerBottom ?? spec.grid.horizontal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cols.length; i++)
          _cell(
            col: cols[i],
            s: spec.header.merge(cols[i].headerStyle),
            text: cols[i].headerText(poster),
            last: i == cols.length - 1,
            bottom: bottom,
          ),
      ],
    );
  }

  Widget _dayRow(List<TableColumn> cols, int offset, DayRow d, int index) {
    final isLast = index == poster.days.length - 1;
    final bottom = isLast ? null : spec.grid.horizontal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cols.length; i++)
          _cell(
            col: cols[i],
            s: spec.resolve(cols[i], offset + i, d, index),
            text: cols[i].cellText(d),
            last: i == cols.length - 1,
            bottom: bottom,
          ),
      ],
    );
  }
}

/// Positions (in the coordinates of the rect passed to [compute]) of a
/// [PosterTableView]'s panels, header and rows — computed with the same
/// arithmetic the widget's Row/Column layout uses, so ornament painters can
/// align with the real table.
@immutable
class TableGeometry {
  const TableGeometry._({
    required this.rect,
    required this.panels,
    required this.innerPanels,
    required this.columns,
    required this.headerBottom,
    required this.rowTop,
    required this.rowHeight,
    required this.rowCount,
  });

  factory TableGeometry.compute(TableSpec spec, Rect rect, int rowCount) {
    final groups = spec.panels;
    // Panel rects, right → left.
    final panelRects = <Rect>[];
    if (!spec.split) {
      panelRects.add(rect);
    } else {
      final widths = <double?>[];
      var fixedTotal = spec.gap * (groups.length - 1);
      var flexTotal = 0;
      for (final g in groups) {
        if (g.every((c) => c.width != null)) {
          final w =
              g.fold<double>(0, (a, c) => a + c.width!) + spec.panelExtraWidth;
          widths.add(w);
          fixedTotal += w;
        } else {
          widths.add(null);
          flexTotal += g
              .where((c) => c.width == null)
              .fold(0, (a, c) => a + c.flex);
        }
      }
      final free = math.max(0.0, rect.width - fixedTotal);
      var x = rect.right;
      for (var i = 0; i < groups.length; i++) {
        final g = groups[i];
        final w =
            widths[i] ??
            free /
                flexTotal *
                g.where((c) => c.width == null).fold(0, (a, c) => a + c.flex);
        panelRects.add(Rect.fromLTRB(x - w, rect.top, x, rect.bottom));
        x -= w + spec.gap;
      }
    }
    final p = spec.panel;
    final inner = [
      for (final r in panelRects)
        p == null
            ? r
            : (p.isPlainRect
                      ? p.padding
                      : p.padding + p.shape.safeInsets(r.size))
                  .resolve(TextDirection.rtl)
                  .deflateRect(r),
    ];
    final columns = <Rect>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i], r = inner[i];
      final fixed = g.fold<double>(0, (a, c) => a + (c.width ?? 0));
      final flex = g
          .where((c) => c.width == null)
          .fold(0, (a, c) => a + c.flex);
      final free = math.max(0.0, r.width - fixed);
      var x = r.right;
      for (final c in g) {
        final w = c.width ?? (flex == 0 ? 0.0 : free / flex * c.flex);
        columns.add(Rect.fromLTRB(x - w, r.top, x, r.bottom));
        x -= w;
      }
    }
    final top = inner.first.top;
    final headerBottom = top + spec.headerHeight;
    final bodyH = inner.first.bottom - headerBottom;
    final rh = spec.rowHeight ?? (rowCount == 0 ? 0.0 : bodyH / rowCount);
    return TableGeometry._(
      rect: rect,
      panels: panelRects,
      innerPanels: inner,
      columns: columns,
      headerBottom: headerBottom,
      rowTop: headerBottom,
      rowHeight: rh,
      rowCount: rowCount,
    );
  }

  /// The whole table area.
  final Rect rect;

  /// Each panel's outer rect, right → left (one entry when not split).
  final List<Rect> panels;

  /// Each panel's content rect (inside its padding / shape insets).
  final List<Rect> innerPanels;

  /// Every column's full-height rect, in [TableSpec.columns] order.
  final List<Rect> columns;

  /// Bottom of the header row (= top of the first day row).
  final double headerBottom;
  final double rowTop, rowHeight;
  final int rowCount;

  /// Bottom of the last day row.
  double get rowsBottom => rowTop + rowHeight * rowCount;

  /// Day row [i], spanning all panels (gaps included).
  Rect rowRect(int i) {
    final l = innerPanels.map((r) => r.left).reduce(math.min);
    final r = innerPanels.map((r) => r.right).reduce(math.max);
    final t = rowTop + rowHeight * i;
    return Rect.fromLTRB(l, t, r, t + rowHeight);
  }
}
