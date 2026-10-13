import 'package:flutter/widgets.dart';

import 'table.dart';

/// What a frame / ornament painter may know about a laid-out poster:
/// the content area, named section rects and the table rows. Implemented by
/// the shared layout's `LayoutMetrics` and by [KitMetrics] for kit-composed
/// templates, so painters can be written against either.
abstract interface class LayoutMetricsLike {
  /// Whole poster size.
  Size get size;

  /// Poster rect minus the page padding.
  Rect get contentRect;

  /// The table area (all panels).
  Rect get tableRect;

  /// Bottom of the table's header row.
  double get tableHeaderBottom;

  /// Number of day rows.
  int get rowCount;

  /// Height of one day row.
  double get rowHeight;

  /// Day row [i] (poster coordinates).
  Rect rowRect(int i);

  /// A named section (e.g. 'header', 'brace', 'table', 'footer',
  /// 'article'), or null if the template has no such section.
  Rect? section(String id);
}

/// One entry of a [SectionLayout]: a fixed [height] (or width, for
/// horizontal layouts) or a [flex] share of the remaining space.
@immutable
class Section {
  const Section(this.id, this.height) : flex = 0;
  const Section.flex(this.id, [this.flex = 1]) : height = null;

  final String id;
  final double? height;
  final int flex;
}

/// Deterministic slicing of a rect into named sections — the template's
/// single source of geometry: widgets are placed with
/// `Positioned.fromRect(layout[id])` and painters read the same rects.
@immutable
class SectionLayout {
  const SectionLayout._(this.rects);

  /// Stacks [sections] top → bottom inside [area], [gap] px apart.
  factory SectionLayout.vertical(
    Rect area,
    List<Section> sections, {
    double gap = 0,
  }) => SectionLayout._(_slice(area, sections, gap, vertical: true));

  /// Places [sections] right → left (RTL) inside [area], [gap] px apart.
  factory SectionLayout.horizontal(
    Rect area,
    List<Section> sections, {
    double gap = 0,
  }) => SectionLayout._(_slice(area, sections, gap, vertical: false));

  final Map<String, Rect> rects;

  Rect operator [](String id) =>
      rects[id] ?? (throw ArgumentError.value(id, 'id', 'unknown section'));

  static Map<String, Rect> _slice(
    Rect area,
    List<Section> sections,
    double gap, {
    required bool vertical,
  }) {
    final total = vertical ? area.height : area.width;
    var fixed = gap * (sections.isEmpty ? 0 : sections.length - 1);
    var flex = 0;
    for (final s in sections) {
      fixed += s.height ?? 0;
      flex += s.height == null ? s.flex : 0;
    }
    final free = (total - fixed).clamp(0.0, double.infinity);
    final out = <String, Rect>{};
    var pos = vertical ? area.top : area.right;
    for (final s in sections) {
      final len = s.height ?? (flex == 0 ? 0.0 : free / flex * s.flex);
      out[s.id] = vertical
          ? Rect.fromLTRB(area.left, pos, area.right, pos + len)
          : Rect.fromLTRB(pos - len, area.top, pos, area.bottom);
      pos += vertical ? len + gap : -(len + gap);
    }
    return out;
  }
}

/// [LayoutMetricsLike] for a kit-composed poster: named [sections] plus the
/// [table] geometry (computed with `TableGeometry.compute` /
/// `PosterTableView.geometry` for the rect the table is placed in).
@immutable
class KitMetrics implements LayoutMetricsLike {
  const KitMetrics({
    required this.size,
    required this.contentRect,
    required this.sections,
    required this.table,
  });

  @override
  final Size size;
  @override
  final Rect contentRect;
  final Map<String, Rect> sections;
  final TableGeometry table;

  @override
  Rect get tableRect => table.rect;
  @override
  double get tableHeaderBottom => table.headerBottom;
  @override
  int get rowCount => table.rowCount;
  @override
  double get rowHeight => table.rowHeight;
  @override
  Rect rowRect(int i) => table.rowRect(i);
  @override
  Rect? section(String id) => sections[id];
}
