import 'package:flutter/widgets.dart';

import '../domain/models.dart';
import 'shared/poster_layout.dart';

export 'shared/poster_layout.dart'
    show
        LayoutMetrics,
        PosterLayout,
        kDefaultContentPadding,
        referenceTableSpec;

/// Every poster is drawn at this fixed logical size and scaled for display
/// or export.
const kPosterSize = Size(1000, 2200);

/// Palette, fonts and ornament painters of one visual template. The shared
/// [PosterLayout] reads every colour and font from here; nothing in the
/// layout is hard-coded.
class PosterTheme {
  const PosterTheme({
    required this.background,
    required this.frameColor,
    required this.accent,
    required this.titleColor,
    required this.bodyText,
    required this.tableHeaderBg,
    required this.tableHeaderFg,
    required this.rowBg,
    required this.rowAltBg,
    required this.rowText,
    required this.gridLine,
    required this.highlightBg,
    required this.highlightFg,
    required this.labelCellBg,
    required this.labelCellFg,
    required this.quoteBoxBg,
    required this.quoteBoxBorder,
    required this.quoteText,
    required this.headingFont,
    required this.bodyFont,
    required this.backgroundPainter,
    required this.framePainter,
    this.emblemPainter,
    this.contentPadding = kDefaultContentPadding,
    this.headerHeight = 250,
    this.verticalGridLines = true,
    this.tableBorderWidth = 2.5,
    this.quoteBoxBorderWidth = 2.5,
    this.tableFont,
  });

  final Color background,
      frameColor,
      accent,
      titleColor,
      bodyText,
      tableHeaderBg,
      tableHeaderFg,
      rowBg,
      rowAltBg,
      rowText,
      gridLine,
      highlightBg,
      highlightFg,
      labelCellBg,
      labelCellFg,
      quoteBoxBg,
      quoteBoxBorder,
      quoteText;

  /// Font families bundled in pubspec: 'ArefRuqaa' | 'Amiri' | 'Tajawal'.
  final String headingFont, bodyFont;

  /// Optional family for everything inside the table (header labels and
  /// every day-row cell). Null keeps [headingFont] for header labels and
  /// [bodyFont] for cells.
  final String? tableFont;

  /// Full-poster pattern / silhouette, painted below the content.
  final CustomPainter Function() backgroundPainter;

  /// Borders / ornaments painted above the content. Receives the real
  /// section positions of the laid-out poster (null only if a caller paints
  /// the frame outside a [PosterLayout]).
  final CustomPainter Function(LayoutMetrics? metrics) framePainter;

  /// Optional centre emblem under the title. When null the layout draws a
  /// `StarMedallionPainter` in [accent].
  final CustomPainter Function()? emblemPainter;

  final EdgeInsets contentPadding;
  final double headerHeight;

  /// Whether table cells draw vertical separators between columns. When
  /// false only the horizontal row hairlines are drawn.
  final bool verticalGridLines;

  /// Stroke width of the table's outer border (in [gridLine]).
  final double tableBorderWidth;

  /// Stroke width of the header quote boxes' border (in [quoteBoxBorder]).
  final double quoteBoxBorderWidth;
}

/// One selectable visual template.
abstract class PosterTemplate {
  const PosterTemplate();
  String get id;
  String get nameAr;
  PosterTheme get theme;
  Widget build(MonthPoster p) => PosterLayout(poster: p, theme: theme);

  /// Raster assets (logos) this template draws. Images load asynchronously,
  /// so anything that captures the poster (export, goldens) or shows it
  /// without a pop-in must [precache] them first. Empty = vector-only.
  List<ImageProvider> get images => const [];

  /// Loads every image of [images] into the image cache (completes when all
  /// are decoded or have failed; a missing asset never throws here). Once
  /// cached, an `Image` shows its picture in the very first frame, so a
  /// capture taken after `await precache(context)` + one frame contains the
  /// logos. The default (no [images]) completes immediately.
  Future<void> precache(BuildContext context) async {
    final list = images;
    if (list.isEmpty) return;
    await Future.wait([
      for (final i in list) precacheImage(i, context, onError: (_, _) {}),
    ]);
  }
}
