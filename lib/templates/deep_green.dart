import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'poster_template.dart';
import 'shared/painters.dart';

// Deep Green palette (binding values from the plan, Task 19).
const _green = Color(0xFF0A3B2C);
const _gold = Color(0xFFD4AF37);
const _paleGold = Color(0xFFF3E3A1);
const _ivory = Color(0xFFF6F1DC);
const _emerald = Color(0xFF0F5A43);
const _row = Color(0xFFF4F1E1);
const _rowAlt = Color(0xFFE6E3CE);
const _hairline = Color(0xFFB9A24A);
const _panel = Color(0xFF0F4A38);

// Ornament-only tones (never behind text except [_panel]).
const _forest = Color(0xFF1B6B50); // lattice strokes
const _shade = Color(0xFF04211A); // vignette edge / frame band
const _band = Color(0xFF07301F); // frame band fill

/// Template 4 — traditional deep-green poster. The green field carries the
/// design: a forest-green star lattice with faint gold highlights, a
/// darkened edge vignette, lighter green panels (a pointed mihrab arch
/// behind the title, side Q&A panels and an article panel), a heavy gold
/// frame whose dark band carries a chain of gold lozenges and eight-pointed
/// khatam stars in large corner notches, thin gold section dividers with a
/// centred diamond, and a khatam medallion with an arabesque ring and a
/// crescent under the title.
class DeepGreenTemplate extends PosterTemplate {
  const DeepGreenTemplate();

  @override
  String get id => 'deep_green';

  @override
  String get nameAr => 'أخضر إسلامي';

  @override
  PosterTheme get theme => _theme;
}

const _theme = PosterTheme(
  background: _green,
  frameColor: _gold,
  // Also the quote-attribution TEXT colour: 4.86:1 on quoteBoxBg (R19).
  accent: _gold,
  titleColor: _paleGold,
  bodyText: _ivory,
  tableHeaderBg: _emerald,
  tableHeaderFg: _paleGold,
  rowBg: _row,
  rowAltBg: _rowAlt,
  rowText: _green,
  gridLine: _hairline,
  highlightBg: _green,
  highlightFg: _paleGold,
  labelCellBg: _gold,
  labelCellFg: _green,
  quoteBoxBg: _panel,
  quoteBoxBorder: _gold,
  quoteText: _ivory,
  headingFont: 'ArefRuqaa',
  bodyFont: 'Amiri',
  backgroundPainter: _background,
  framePainter: _frame,
  emblemPainter: _emblem,
);

CustomPainter _background() => const DeepGreenBackgroundPainter();
CustomPainter _frame(LayoutMetrics? m) => DeepGreenFramePainter(metrics: m);
CustomPainter _emblem() => const DeepGreenEmblemPainter();

// ------------------------------------------------------------------ helpers

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.miter
  ..isAntiAlias = true;

Paint _fill(Color c) => Paint()..color = c;

/// Diamond (lozenge) centred on [c], half-width [w], half-height [h].
Path _diamond(Offset c, double w, double h) => Path()
  ..moveTo(c.dx, c.dy - h)
  ..lineTo(c.dx + w, c.dy)
  ..lineTo(c.dx, c.dy + h)
  ..lineTo(c.dx - w, c.dy)
  ..close();

/// Khatam / rub el hizb: two overlapping squares with circumradius [r],
/// as one outline.
Path _khatam(Offset c, double r, {double turn = 0}) {
  final a = Path(), b = Path();
  for (var i = 0; i < 4; i++) {
    final aa = turn + i * math.pi / 2, ab = aa + math.pi / 4;
    final pa = c + Offset(math.cos(aa), math.sin(aa)) * r;
    final pb = c + Offset(math.cos(ab), math.sin(ab)) * r;
    i == 0 ? a.moveTo(pa.dx, pa.dy) : a.lineTo(pa.dx, pa.dy);
    i == 0 ? b.moveTo(pb.dx, pb.dy) : b.lineTo(pb.dx, pb.dy);
  }
  return Path.combine(PathOperation.union, a..close(), b..close());
}

/// Regular octagon with circumradius [r] (flat sides facing the axes).
Path _octagon(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = math.pi / 8 + i * math.pi / 4;
    final pt = c + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Small gold khatam on a dark ground with a green eye.
void _khatamBadge(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(c, r * 1.02, _fill(_shade));
  final star = _khatam(c, r, turn: math.pi / 4);
  canvas.drawPath(star, _fill(_gold));
  canvas.drawPath(
    _octagon(c, r * 0.62),
    _stroke(_green, math.max(0.8, r * 0.07)),
  );
  canvas.drawCircle(c, r * 0.36, _fill(_green));
  canvas.drawCircle(c, r * 0.16, _fill(_paleGold));
}

/// Pointed (two-centred) arch: vertical sides from [bottom] up to the
/// springing line [spring], then two curves meeting at the apex [peak].
Path _arch(double cx, double hw, double peak, double spring, double bottom) {
  final rise = spring - peak;
  return Path()
    ..moveTo(cx - hw, bottom)
    ..lineTo(cx - hw, spring)
    ..cubicTo(
      cx - hw,
      spring - rise * 0.62,
      cx - hw * 0.38,
      peak + rise * 0.16,
      cx,
      peak,
    )
    ..cubicTo(
      cx + hw * 0.38,
      peak + rise * 0.16,
      cx + hw,
      spring - rise * 0.62,
      cx + hw,
      spring,
    )
    ..lineTo(cx + hw, bottom)
    ..close();
}

/// [r] with square notches of [n] cut into each corner.
Path _notched(Rect r, double n) {
  final l = r.left, t = r.top, rt = r.right, b = r.bottom;
  return Path()
    ..moveTo(l + n, t)
    ..lineTo(rt - n, t)
    ..lineTo(rt - n, t + n)
    ..lineTo(rt, t + n)
    ..lineTo(rt, b - n)
    ..lineTo(rt - n, b - n)
    ..lineTo(rt - n, b)
    ..lineTo(l + n, b)
    ..lineTo(l + n, b - n)
    ..lineTo(l, b - n)
    ..lineTo(l, t + n)
    ..lineTo(l + n, t + n)
    ..close();
}

// Header arch geometry relative to the content rect (shared by the
// background panel and the frame's apex ornament).
const double _archHalfWidth = 170;
const double _archPeakAbove = 10; // apex this far above contentRect.top
const double _archSpringBelow = 40; // springing line below contentRect.top

double _articlePanelTop(LayoutMetrics m) => m.articleTop + 6;

/// Green panel behind the closing article. Only the BOTTOM corners are
/// notched (wide enough to hold the frame's bottom khatam badges); the top
/// corners are square because nothing sits in them.
Path _articlePanel(LayoutMetrics m, Size size) {
  final r = Rect.fromLTRB(
    m.contentRect.left,
    _articlePanelTop(m),
    m.contentRect.right,
    math.min(m.articleBottom + 8, size.height - 34),
  );
  const n = 34.0;
  return Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right, r.bottom - n)
    ..lineTo(r.right - n, r.bottom - n)
    ..lineTo(r.right - n, r.bottom)
    ..lineTo(r.left + n, r.bottom)
    ..lineTo(r.left + n, r.bottom - n)
    ..lineTo(r.left, r.bottom - n)
    ..close();
}

// --------------------------------------------------------------- background

/// Deep green (painted by the layout), an edge-only vignette, a forest
/// lattice offset half a cell under the plan's faint gold lattice, and the
/// lighter green panels behind the title, side strips and article. Panels
/// sit BELOW the content, so they can never cover text; every text colour
/// keeps >= 8.9:1 on [_panel].
class DeepGreenBackgroundPainter extends CustomPainter {
  const DeepGreenBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    // Vignette: transparent over the middle, darkening only the edges.
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _shade.withValues(alpha: 0),
                _shade.withValues(alpha: 0.6),
              ],
              stops: const [0.6, 1],
            ).createShader(
              Rect.fromCenter(
                center: rect.center,
                width: size.width * 1.45,
                height: size.height * 1.12,
              ),
            ),
    );
    canvas.save();
    canvas.translate(45, 45);
    const GeometricPatternPainter(
      color: _forest,
      opacity: 0.55,
      cell: 90,
    ).paint(canvas, size);
    canvas.restore();
    const GeometricPatternPainter(
      color: _gold,
      opacity: 0.08,
      cell: 90,
    ).paint(canvas, size);

    if (size.width < 600 || size.height < 1200) return;
    final m = LayoutMetrics.compute(size, _theme, 0);
    final content = m.contentRect;

    // Mihrab arch behind the title and the emblem.
    final cx = content.center.dx;
    final arch = _arch(
      cx,
      _archHalfWidth,
      content.top - _archPeakAbove,
      content.top + _archSpringBelow,
      m.headerBottom - 8,
    );
    canvas.drawPath(arch, _fill(_panel));
    canvas.save();
    canvas.clipPath(arch);
    const GeometricPatternPainter(
      color: _gold,
      opacity: 0.07,
      cell: 45,
    ).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(arch, _stroke(_gold, 2));
    canvas.drawPath(
      _arch(
        cx,
        _archHalfWidth - 7,
        content.top - _archPeakAbove + 9,
        content.top + _archSpringBelow + 2,
        m.headerBottom - 15,
      ),
      _stroke(_gold.withValues(alpha: 0.55), 1),
    );

    // Side Q&A panels.
    for (final s in [m.rightStripRect, m.leftStripRect]) {
      canvas.drawRect(s, _fill(_panel));
    }

    // Article panel; its notches leave room for the corner khatams.
    canvas.drawPath(_articlePanel(m, size), _fill(_panel));
  }

  @override
  bool shouldRepaint(DeepGreenBackgroundPainter old) => false;
}

// -------------------------------------------------------------------- frame

/// Heavy gold double border (shared painter, large corner notches) whose
/// dark band carries a chain of gold lozenges and dots, gold khatam stars
/// in the corner notches, a hairline inside the band, and — placed from
/// the real section positions in [metrics] — thin gold section dividers
/// with a centred diamond, outlines on the green panels and the arch apex
/// finial.
///
/// Drawn ABOVE the content: every ornament stays in the frame band, in the
/// gap under the quote boxes, on panel edges, or in the 16 px ends of the
/// side strips (their text is inset 16 px).
class DeepGreenFramePainter extends CustomPainter {
  const DeepGreenFramePainter({this.metrics});

  final LayoutMetrics? metrics;

  static const double _inset = 10, _gap = 13, _strokeW = 3, _corner = 46;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outer = (Offset.zero & size).deflate(_inset);
    final inner = outer.deflate(_gap + _strokeW);
    final big = inner.width > 4 * _corner && inner.height > 4 * _corner;

    // Dark band between the two rules (incl. the corner notch tiles).
    if (big) {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(outer),
          _notched(inner, _corner),
        ),
        _fill(_band),
      );
    }
    const DoubleBorderPainter(
      color: _gold,
      inset: _inset,
      gap: _gap,
      stroke: _strokeW,
      cornerSize: _corner,
    ).paint(canvas, size);
    if (!big) return;

    // Fine hairline just outside the outer rule.
    canvas.drawRect(
      outer.deflate(-4.5),
      _stroke(_gold.withValues(alpha: 0.6), 1),
    );

    _bandChain(canvas, outer, inner);

    // Khatam stars over the shared painter's small notch diamonds.
    const h = _corner / 2;
    for (final c in [
      inner.topLeft + const Offset(h, h),
      inner.topRight + const Offset(-h, h),
      inner.bottomLeft + const Offset(h, -h),
      inner.bottomRight + const Offset(-h, -h),
    ]) {
      canvas.drawCircle(c, h - 4, _stroke(_gold.withValues(alpha: 0.7), 1));
      _khatamBadge(canvas, c, h - 8);
    }

    final m = metrics;
    if (m == null) return;
    final content = m.contentRect;

    // Header / brace divider in the gap under the quote boxes.
    _divider(canvas, content, m.headerBottom + 4);

    // Gold outlines on the side Q&A panels.
    for (final s in [m.rightStripRect, m.leftStripRect]) {
      if (s.height > 0) canvas.drawRect(s.deflate(0.75), _stroke(_gold, 1.5));
    }

    // Table: pale-gold rule inside the bottom of the column-header band.
    if (m.tableHeaderBottom < m.tableBottom) {
      final r = m.tableRect;
      canvas.drawLine(
        Offset(r.left, m.tableHeaderBottom - 1.5),
        Offset(r.right, m.tableHeaderBottom - 1.5),
        _stroke(_gold, 3),
      );
      canvas.drawLine(
        Offset(r.left + 8, m.tableHeaderBottom - 6),
        Offset(r.right - 8, m.tableHeaderBottom - 6),
        _stroke(_gold.withValues(alpha: 0.6), 1),
      );
    }

    // Table / article divider = the article panel's top edge.
    canvas.drawPath(
      _articlePanel(m, size),
      _stroke(_gold.withValues(alpha: 0.75), 1.2),
    );
    _divider(canvas, content, _articlePanelTop(m));
  }

  /// Gold lozenges alternating with dots along the middle of the band,
  /// on all four sides between the corner tiles.
  void _bandChain(Canvas canvas, Rect outer, Rect inner) {
    final mid = Rect.fromLTRB(
      (outer.left + inner.left) / 2,
      (outer.top + inner.top) / 2,
      (outer.right + inner.right) / 2,
      (outer.bottom + inner.bottom) / 2,
    );
    const step = 26.0;
    final lozenge = _fill(_gold.withValues(alpha: 0.85));
    final dot = _fill(_gold.withValues(alpha: 0.6));
    void run(Offset a, Offset b, bool horizontal) {
      final len = (b - a).distance;
      final n = (len / step).floor();
      if (n < 2) return;
      final d = (b - a) / n.toDouble();
      for (var i = 0; i <= n; i++) {
        final p = a + d * i.toDouble();
        canvas.drawPath(
          horizontal ? _diamond(p, 5.5, 3.2) : _diamond(p, 3.2, 5.5),
          lozenge,
        );
        if (i < n) canvas.drawCircle(p + d / 2, 1.4, dot);
      }
    }

    const skip = _corner + 22;
    run(
      Offset(inner.left + skip, mid.top),
      Offset(inner.right - skip, mid.top),
      true,
    );
    run(
      Offset(inner.left + skip, mid.bottom),
      Offset(inner.right - skip, mid.bottom),
      true,
    );
    run(
      Offset(mid.left, inner.top + skip),
      Offset(mid.left, inner.bottom - skip),
      false,
    );
    run(
      Offset(mid.right, inner.top + skip),
      Offset(mid.right, inner.bottom - skip),
      false,
    );
  }

  /// Thin gold rule across [content] with a centred diamond (gold, green
  /// core) and small lozenge terminals.
  void _divider(Canvas canvas, Rect content, double y) {
    final cx = content.center.dx;
    final half = content.width / 2 - 50;
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(cx + s * 22, y),
        Offset(cx + s * (half - 8), y),
        _stroke(_gold, 1.2),
      );
      canvas.drawCircle(Offset(cx + s * 26, y), 2, _fill(_gold));
      canvas.drawPath(_diamond(Offset(cx + s * half, y), 7, 3.5), _fill(_gold));
    }
    canvas.drawPath(_diamond(Offset(cx, y), 13, 7), _fill(_green));
    canvas.drawPath(_diamond(Offset(cx, y), 13, 7), _stroke(_gold, 1.6));
    canvas.drawPath(_diamond(Offset(cx, y), 6, 3.2), _fill(_gold));
  }

  @override
  bool shouldRepaint(DeepGreenFramePainter old) => old.metrics != metrics;
}

// ------------------------------------------------------------------- emblem

/// Khatam medallion: a dark disc in a double gold ring, an arabesque ring
/// of sixteen pointed lobes, a gold eight-pointed khatam with an inner
/// interlace octagon, and a pale-gold crescent with a small star at its
/// heart.
class DeepGreenEmblemPainter extends CustomPainter {
  const DeepGreenEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 4) return;
    final c = size.center(Offset.zero);
    double w(double f, double min) => math.max(min, r * f);

    canvas.drawCircle(c, r * 0.97, _fill(_shade));
    canvas.drawCircle(c, r * 0.95, _stroke(_gold, w(0.04, 1.4)));
    canvas.drawCircle(c, r * 0.87, _stroke(_gold, w(0.014, 0.7)));

    // Arabesque ring: sixteen pointed lobes between r 0.66 and 0.85.
    final lobes = Path();
    for (var i = 0; i < 16; i++) {
      final a0 = i * 2 * math.pi / 16, a1 = (i + 1) * 2 * math.pi / 16;
      final am = (a0 + a1) / 2;
      Offset at(double a, double rr) =>
          c + Offset(math.cos(a), math.sin(a)) * r * rr;
      final p0 = at(a0, 0.68), p1 = at(a1, 0.68), tip = at(am, 0.84);
      final k0 = at(a0 + 0.05, 0.82), k1 = at(a1 - 0.05, 0.82);
      if (i == 0) lobes.moveTo(p0.dx, p0.dy);
      lobes
        ..quadraticBezierTo(k0.dx, k0.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(k1.dx, k1.dy, p1.dx, p1.dy);
    }
    lobes.close();
    canvas.drawPath(lobes, _fill(_panel));
    canvas.drawPath(lobes, _stroke(_gold, w(0.02, 0.8)));
    for (var i = 0; i < 16; i++) {
      final a = (i + 0.5) * 2 * math.pi / 16;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.76,
        w(0.022, 0.8),
        _fill(_gold),
      );
    }

    // Gold khatam with an interlace octagon and a green core.
    final star = _khatam(c, r * 0.66, turn: math.pi / 8);
    canvas.drawPath(star, _fill(_gold));
    canvas.drawPath(_octagon(c, r * 0.42), _stroke(_green, w(0.03, 0.8)));
    canvas.drawCircle(c, r * 0.36, _fill(_green));
    canvas.drawCircle(c, r * 0.36, _stroke(_paleGold, w(0.014, 0.6)));

    // Crescent opening to the upper left, with a small star in its arms.
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.27)),
      Path()..addOval(
        Rect.fromCircle(
          center: c + Offset(-r * 0.1, -r * 0.07),
          radius: r * 0.23,
        ),
      ),
    );
    canvas.drawPath(moon, _fill(_paleGold));
    canvas.drawPath(
      _khatam(c + Offset(-r * 0.09, -r * 0.06), r * 0.08),
      _fill(_paleGold),
    );
  }

  @override
  bool shouldRepaint(DeepGreenEmblemPainter old) => false;
}
