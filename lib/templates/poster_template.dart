import 'package:flutter/widgets.dart';

import '../domain/models.dart';
import 'shared/poster_layout.dart';

export 'shared/poster_layout.dart'
    show LayoutMetrics, PosterLayout, kDefaultContentPadding;

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
}

/// One selectable visual template.
abstract class PosterTemplate {
  const PosterTemplate();
  String get id;
  String get nameAr;
  PosterTheme get theme;
  Widget build(MonthPoster p) => PosterLayout(poster: p, theme: theme);
}
