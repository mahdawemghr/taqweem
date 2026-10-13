import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'poster_template.dart';

// Minimal Modern palette (binding values from the plan, Task 18).
const _white = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _slate = Color(0xFF1F2937);
const _teal = Color(0xFF0F766E);
const _mist = Color(0xFFF3F4F6);
const _hairline = Color(0xFFE5E7EB);
const _paper = Color(0xFFF9FAFB);
const _rule = Color(0xFFD1D5DB);

/// Template 3 — white, flat and airy: Tajawal throughout, one thin ink rule
/// as the frame, a short teal bar under the title over a line-art teal
/// eight-point star, hairline section rules, and a table with horizontal
/// hairlines only. Highlighted days are solid teal bands with white text;
/// month-change label cells are light grey.
class MinimalModernTemplate extends PosterTemplate {
  const MinimalModernTemplate();

  @override
  String get id => 'minimal_modern';

  @override
  String get nameAr => 'عصري بسيط';

  @override
  PosterTheme get theme => const PosterTheme(
    background: _white,
    frameColor: _ink,
    // Also the quote-attribution TEXT colour: 5.2:1 on quoteBoxBg (R19).
    accent: _teal,
    titleColor: _ink,
    bodyText: _slate,
    tableHeaderBg: _ink,
    tableHeaderFg: _white,
    rowBg: _white,
    rowAltBg: _mist,
    rowText: _ink,
    gridLine: _hairline,
    highlightBg: _teal,
    highlightFg: _white,
    labelCellBg: _hairline,
    labelCellFg: _ink,
    quoteBoxBg: _paper,
    quoteBoxBorder: _rule,
    quoteText: _slate,
    headingFont: 'Tajawal',
    bodyFont: 'Tajawal',
    // Tajawal's wide Arabic letterforms make the table headers/cells break
    // and shrink; Amiri is narrower and keeps them legible (R21).
    tableFont: 'Amiri',
    backgroundPainter: _background,
    framePainter: _frame,
    emblemPainter: _emblem,
    contentPadding: EdgeInsets.all(56),
    verticalGridLines: false,
    tableBorderWidth: 1,
    quoteBoxBorderWidth: 1,
  );
}

CustomPainter _background() => const MinimalModernBackgroundPainter();
CustomPainter _frame(LayoutMetrics? m) => MinimalModernFramePainter(metrics: m);
CustomPainter _emblem() => const MinimalModernEmblemPainter();

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.miter
  ..isAntiAlias = true;

/// Rub el hizb outline (two overlapping squares) with circumradius [r].
Path _rubElHizb(Offset c, double r) {
  final a = Path(), b = Path();
  for (var i = 0; i < 4; i++) {
    final aa = i * math.pi / 2, ab = aa + math.pi / 4;
    final pa = c + Offset(math.cos(aa), math.sin(aa)) * r;
    final pb = c + Offset(math.cos(ab), math.sin(ab)) * r;
    i == 0 ? a.moveTo(pa.dx, pa.dy) : a.lineTo(pa.dx, pa.dy);
    i == 0 ? b.moveTo(pb.dx, pb.dy) : b.lineTo(pb.dx, pb.dy);
  }
  return Path.combine(PathOperation.union, a..close(), b..close());
}

// --------------------------------------------------------------- background

/// Plain white: the layout already paints [PosterTheme.background].
class MinimalModernBackgroundPainter extends CustomPainter {
  const MinimalModernBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(MinimalModernBackgroundPainter old) => false;
}

// -------------------------------------------------------------------- frame

/// One thin ink rule at inset 24, a short teal bar centred under the title,
/// and grey hairlines separating the header and the closing article.
/// The bar is the poster's only teal ornament outside the emblem.
class MinimalModernFramePainter extends CustomPainter {
  const MinimalModernFramePainter({this.metrics});

  final LayoutMetrics? metrics;

  static const double _inset = 24, _strokeW = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outer = (Offset.zero & size).deflate(_inset);
    if (outer.width <= 0 || outer.height <= 0) return;
    canvas.drawRect(outer, _stroke(_ink, _strokeW));

    final m = metrics;
    if (m == null) return;
    final content = m.contentRect;
    final cx = content.center.dx;
    final headerH = m.headerBottom - content.top;

    // Teal accent bar just below the title line (title takes the top 48 %
    // of the header; the emblem painter leaves this band empty).
    final barY = content.top + headerH * 0.48 + 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, barY), width: 72, height: 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = _teal,
    );

    // Hairline section rules: in the gap under the quote boxes (they end
    // 15 px above headerBottom) and between the footer notes and article.
    final hair = _stroke(_rule, 1);
    canvas.drawLine(
      Offset(content.left, m.headerBottom - 6),
      Offset(content.right, m.headerBottom - 6),
      hair,
    );
    canvas.drawLine(
      Offset(content.left, m.articleTop),
      Offset(content.right, m.articleTop),
      hair,
    );
  }

  @override
  bool shouldRepaint(MinimalModernFramePainter old) => old.metrics != metrics;
}

// ------------------------------------------------------------------- emblem

/// Line-art teal rub el hizb with a small inner ring, drawn in the lower
/// part of its box so the title's accent bar has room above it.
class MinimalModernEmblemPainter extends CustomPainter {
  const MinimalModernEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 8) return;
    final c = size.center(Offset(0, s * 0.05));
    final r = s * 0.34;
    final w = math.max(1.0, s * 0.018);
    canvas.drawPath(_rubElHizb(c, r), _stroke(_teal, w));
    canvas.drawCircle(c, r * 0.5, _stroke(_teal, w * 0.8));
    canvas.drawCircle(c, r * 0.14, Paint()..color = _teal);
  }

  @override
  bool shouldRepaint(MinimalModernEmblemPainter old) => false;
}
