import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'poster_template.dart';
import 'shared/painters.dart';

// Cream & Gold palette (binding values from the Task 17 brief + ruling R7).
const _cream = Color(0xFFFBF5E6);
const _gold = Color(0xFFB8892B);
const _deepGold = Color(0xFF8A6414); // R7: table header, attribution text
const _bronze = Color(0xFF7A5710);
const _ink = Color(0xFF2B2416);
const _ivory = Color(0xFFFFFDF6);
const _parchment = Color(0xFFF5EBD0);
const _hairline = Color(0xFFD9C08A);
const _paleGold = Color(0xFFFFF4D6);
const _wheat = Color(0xFFE6CF94);
const _quoteBg = Color(0xFFFFF8E5);

/// Template 2 — warm ivory paper with a faint gold star lattice, a fine
/// triple gold frame with line-art rosettes in the corner notches and
/// pointed cartouches on each edge, leaf-and-rosette gold dividers, and a
/// gold line-art eight-fold rosette (rub el hizb with an inner flower)
/// under the title. Rows are ivory / parchment; highlighted days are deep
/// bronze bands with pale-gold text.
class CreamGoldTemplate extends PosterTemplate {
  const CreamGoldTemplate();

  @override
  String get id => 'cream_gold';

  @override
  String get nameAr => 'كريمي وذهبي';

  @override
  PosterTheme get theme => const PosterTheme(
    background: _cream,
    frameColor: _gold,
    // Accent is only used as TEXT (quote attribution on quoteBoxBg), where
    // the plan's 0xFFB8892B reaches 2.9:1; the R7 deep gold gives 5.1:1.
    accent: _deepGold,
    titleColor: _bronze,
    bodyText: _ink,
    tableHeaderBg: _deepGold,
    tableHeaderFg: Color(0xFFFFFFFF),
    rowBg: _ivory,
    rowAltBg: _parchment,
    rowText: _ink,
    gridLine: _hairline,
    highlightBg: _bronze,
    highlightFg: _paleGold,
    labelCellBg: _wheat,
    labelCellFg: _ink,
    quoteBoxBg: _quoteBg,
    quoteBoxBorder: _gold,
    quoteText: _ink,
    headingFont: 'ArefRuqaa',
    bodyFont: 'Amiri',
    backgroundPainter: _background,
    framePainter: _frame,
    emblemPainter: _emblem,
  );
}

CustomPainter _background() => const CreamGoldBackgroundPainter();
CustomPainter _frame(LayoutMetrics? m) => CreamGoldFramePainter(metrics: m);
CustomPainter _emblem() => const CreamGoldEmblemPainter();

// ------------------------------------------------------------------ helpers

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

Paint _fill(Color c) => Paint()..color = c;

/// Almond-shaped leaf (vesica) from [from] pointing along [angle], [len]
/// long and [width] wide at its middle.
Path _leaf(Offset from, double angle, double len, double width) {
  final d = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-d.dy, d.dx);
  final tip = from + d * len;
  final mid = from + d * (len / 2);
  return Path()
    ..moveTo(from.dx, from.dy)
    ..quadraticBezierTo(
      (mid + n * width).dx,
      (mid + n * width).dy,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      (mid - n * width).dx,
      (mid - n * width).dy,
      from.dx,
      from.dy,
    )
    ..close();
}

/// Eight almond petals radiating from [c], [r] long, first one pointing up
/// (rotated by [turn]).
Path _flower(Offset c, double r, {double turn = 0}) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    p.addPath(
      _leaf(c, -math.pi / 2 + turn + i * math.pi / 4, r, r * 0.22),
      Offset.zero,
    );
  }
  return p;
}

/// Rub el hizb: two overlapping squares with circumradius [r].
Path _rubElHizb(Offset c, double r) {
  final a = Path(), b = Path();
  for (var i = 0; i < 4; i++) {
    final pa =
        c + Offset(math.cos(i * math.pi / 2), math.sin(i * math.pi / 2)) * r;
    final ang = math.pi / 4 + i * math.pi / 2;
    final pb = c + Offset(math.cos(ang), math.sin(ang)) * r;
    i == 0 ? a.moveTo(pa.dx, pa.dy) : a.lineTo(pa.dx, pa.dy);
    i == 0 ? b.moveTo(pb.dx, pb.dy) : b.lineTo(pb.dx, pb.dy);
  }
  return Path.combine(PathOperation.union, a..close(), b..close());
}

/// Pointed (ogee-ended) cartouche centred on [c]; [hw]/[hh] are half the
/// length / thickness; [vertical] turns it 90°.
Path _cartouche(Offset c, double hw, double hh, {bool vertical = false}) {
  Offset p(double x, double y) =>
      vertical ? c + Offset(y, x) : c + Offset(x, y);
  final a = p(-hw, 0), b = p(hw, 0);
  final tl = p(-hw + hh * 1.6, -hh), tr = p(hw - hh * 1.6, -hh);
  final bl = p(-hw + hh * 1.6, hh), br = p(hw - hh * 1.6, hh);
  final ctl = p(-hw + hh * 0.4, -hh), ctr = p(hw - hh * 0.4, -hh);
  final cbl = p(-hw + hh * 0.4, hh), cbr = p(hw - hh * 0.4, hh);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(ctl.dx, ctl.dy, tl.dx, tl.dy)
    ..lineTo(tr.dx, tr.dy)
    ..quadraticBezierTo(ctr.dx, ctr.dy, b.dx, b.dy)
    ..quadraticBezierTo(cbr.dx, cbr.dy, br.dx, br.dy)
    ..lineTo(bl.dx, bl.dy)
    ..quadraticBezierTo(cbl.dx, cbl.dy, a.dx, a.dy)
    ..close();
}

/// Line-art eight-petal rosette: outlined petals, a ring and a gold eye.
void _rosette(Canvas canvas, Offset c, double r, {Color? ground}) {
  if (ground != null) canvas.drawCircle(c, r * 1.08, _fill(ground));
  canvas.drawPath(_flower(c, r), _fill(_gold.withValues(alpha: 0.18)));
  canvas.drawPath(_flower(c, r), _stroke(_gold, math.max(0.9, r * 0.09)));
  canvas.drawCircle(c, r * 0.32, _fill(_cream));
  canvas.drawCircle(c, r * 0.32, _stroke(_bronze, math.max(0.8, r * 0.07)));
  canvas.drawCircle(c, r * 0.14, _fill(_bronze));
}

// --------------------------------------------------------------- background

/// Cream (painted by the layout) warmed towards the edges like aged paper,
/// plus the faint gold star lattice.
class CreamGoldBackgroundPainter extends CustomPainter {
  const CreamGoldBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    // A light, warm vignette: edge tone stays far above every text colour's
    // 4.5:1 limit (titleColor on the darkest edge tone ≈ 5.6:1).
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: const [Color(0x00E8D5A6), Color(0x47E8D5A6)],
              stops: const [0.55, 1],
            ).createShader(
              Rect.fromCenter(
                center: rect.center,
                width: size.width * 1.5,
                height: size.height * 1.1,
              ),
            ),
    );
    const GeometricPatternPainter(
      color: _gold,
      opacity: 0.06,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(CreamGoldBackgroundPainter old) => false;
}

// -------------------------------------------------------------------- frame

/// Fine gold triple frame (the shared double border plus an inner notched
/// hairline) with line-art rosettes in the corner notches, leaf sprays
/// pointing into the corners, pointed cartouches on all four edges, and
/// ornaments placed from the real section positions in [metrics].
///
/// Drawn ABOVE the content, so ornaments only use space the layout leaves
/// empty: the border band, the gap under the quote boxes, the table's own
/// outline / header rule, and the free ends of the article author and
/// fatiha lines (their text is inset 120 / 80 px).
class CreamGoldFramePainter extends CustomPainter {
  const CreamGoldFramePainter({this.metrics});

  final LayoutMetrics? metrics;

  static const double _inset = 16, _gap = 6, _strokeW = 2.5, _corner = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const DoubleBorderPainter(
      color: _gold,
      inset: _inset,
      gap: _gap,
      stroke: _strokeW,
      cornerSize: _corner,
    ).paint(canvas, size);

    final outer = (Offset.zero & size).deflate(_inset);
    final inner = outer.deflate(_gap + _strokeW);
    if (inner.width <= 4 * _corner || inner.height <= 4 * _corner) return;

    // Third, finer notched rule just inside the double border.
    canvas.drawPath(
      _notched(inner.deflate(5), _corner),
      _stroke(_gold.withValues(alpha: 0.75), 1),
    );

    // Corner rosettes in the notches + leaf sprays aiming into the poster.
    const h = _corner / 2;
    final corners = [
      (inner.topLeft, 1.0, 1.0),
      (inner.topRight, -1.0, 1.0),
      (inner.bottomLeft, 1.0, -1.0),
      (inner.bottomRight, -1.0, -1.0),
    ];
    for (final (p, sx, sy) in corners) {
      _rosette(canvas, p + Offset(sx * h, sy * h), h - 2.5, ground: _cream);
      // Trefoil sprouting from the hairline's notch corner (top corners
      // only: at the bottom the fatiha scrolls already fill that space).
      if (sy < 0 && metrics != null) continue;
      final d = Offset(sx, sy) / math.sqrt2;
      final root = p + Offset(sx * (_corner + 7), sy * (_corner + 7));
      final ang = math.atan2(sy, sx);
      canvas.drawCircle(root, 2.2, _fill(_gold));
      final stem = root + d * 3;
      canvas.drawPath(_leaf(stem, ang, 16, 4.5), _fill(_gold));
      for (final t in [-0.9, 0.9]) {
        canvas.drawPath(
          _leaf(stem, ang + t, 11, 3.2),
          _fill(_gold.withValues(alpha: 0.7)),
        );
      }
      canvas.drawCircle(stem + d * 20, 1.4, _fill(_gold));
    }

    // Pointed cartouches straddling the middle of every edge band.
    final band = (outer.top + inner.top) / 2;
    _edgeCartouche(canvas, Offset(size.width / 2, band));
    _edgeCartouche(canvas, Offset(size.width / 2, size.height - band));
    _edgeCartouche(canvas, Offset(band, size.height / 2), vertical: true);
    _edgeCartouche(
      canvas,
      Offset(size.width - band, size.height / 2),
      vertical: true,
    );

    final m = metrics;
    if (m == null) return;
    final content = m.contentRect;

    // Header / brace divider in the gap below the quote boxes.
    _divider(canvas, content, m.headerBottom + 4);

    // Crisp gold outline on the table's pale outer border, and a pale rule
    // inside the bottom of the column-header band.
    if (m.tableBottom > m.tableTop) {
      final r = m.tableRect.deflate(1.25);
      canvas.drawRect(r, _stroke(_gold, 2));
      if (m.tableHeaderBottom < m.tableBottom) {
        canvas.drawLine(
          Offset(r.left + 6, m.tableHeaderBottom - 4),
          Offset(r.right - 6, m.tableHeaderBottom - 4),
          _stroke(_wheat, 1.2),
        );
        canvas.drawLine(
          Offset(r.left, m.tableHeaderBottom),
          Offset(r.right, m.tableHeaderBottom),
          _stroke(_gold, 2),
        );
      }
    }

    // Leafy scrolls either side of the article author line and the fatiha.
    _flanks(canvas, content, m.articleTop + 24, 104);
    _flanks(canvas, content, m.articleBottom - 23, 66);
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

  void _edgeCartouche(Canvas canvas, Offset c, {bool vertical = false}) {
    final outline = _cartouche(c, 46, 9, vertical: vertical);
    canvas.drawPath(outline, _fill(_cream));
    canvas.drawPath(outline, _stroke(_gold, 1.6));
    canvas.drawPath(
      _cartouche(c, 36, 5.5, vertical: vertical),
      _stroke(_gold.withValues(alpha: 0.7), 0.8),
    );
    _rosette(canvas, c, 7.5);
    for (final s in [-1.0, 1.0]) {
      final o = vertical ? Offset(0, s * 21) : Offset(s * 21, 0);
      canvas.drawCircle(c + o, 1.8, _fill(_gold));
    }
  }

  /// Centred divider: a rosette held by two pairs of leaves, fine gold
  /// rules with a dotted under-line, ending in small rings and leaves.
  void _divider(Canvas canvas, Rect content, double y) {
    final cx = content.center.dx;
    final half = content.width / 2 - 70;
    for (final s in [-1.0, 1.0]) {
      final out = s > 0 ? 0.0 : math.pi;
      // Leaves flanking the centre rosette.
      canvas.drawPath(_leaf(Offset(cx + s * 11, y), out, 24, 5), _fill(_gold));
      canvas.drawPath(
        _leaf(Offset(cx + s * 13, y - 2), out - 0.5, 15, 3),
        _stroke(_gold, 0.9),
      );
      canvas.drawPath(
        _leaf(Offset(cx + s * 13, y + 2), out + 0.5, 15, 3),
        _stroke(_gold, 0.9),
      );
      canvas.drawCircle(Offset(cx + s * 41, y), 2.2, _fill(_gold));
      // Main rule and dotted companion.
      final from = cx + s * 48, to = cx + s * half;
      canvas.drawLine(Offset(from, y), Offset(to, y), _stroke(_gold, 1.4));
      for (var x = 64.0; x < half - 90; x += 12) {
        canvas.drawCircle(Offset(cx + s * x, y + 5), 0.9, _fill(_gold));
        canvas.drawCircle(Offset(cx + s * x, y - 5), 0.9, _fill(_gold));
      }
      // Ring and outward leaf at the end.
      canvas.drawCircle(Offset(to + s * 5, y), 4, _stroke(_gold, 1.2));
      canvas.drawPath(
        _leaf(Offset(to + s * 10, y), out, 14, 3.5),
        _fill(_gold),
      );
    }
    _rosette(canvas, Offset(cx, y), 10, ground: _cream);
  }

  /// Mirrored scrolls from each side of [content] inwards, [len] long,
  /// leaving the centred text line free.
  void _flanks(Canvas canvas, Rect content, double y, double len) {
    for (final s in [1.0, -1.0]) {
      final edge = s > 0 ? content.left + 6 : content.right - 6;
      final tip = edge + s * len;
      final inward = s > 0 ? 0.0 : math.pi;
      canvas.drawCircle(Offset(edge, y), 3, _stroke(_gold, 1.2));
      canvas.drawLine(
        Offset(edge + s * 5, y),
        Offset(tip - s * 22, y),
        _stroke(_gold, 1.4),
      );
      // Curl: an open three-quarter ring sitting on the rule.
      final cc = Offset(tip - s * 28, y - 6);
      canvas.drawArc(
        Rect.fromCircle(center: cc, radius: 6),
        s > 0 ? math.pi / 2 : math.pi / 2,
        s * 1.5 * math.pi,
        false,
        _stroke(_gold, 1.2),
      );
      canvas.drawPath(
        _leaf(Offset(tip - s * 22, y), inward, 20, 4.5),
        _fill(_gold),
      );
      canvas.drawPath(
        _leaf(Offset(tip - s * 22, y), inward + s * 0.6, 12, 2.5),
        _stroke(_gold, 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(CreamGoldFramePainter old) => old.metrics != metrics;
}

// ------------------------------------------------------------------- emblem

/// Gold line-art medallion on an ivory disc: double ring with a scalloped
/// band, an outlined rub el hizb on a wheat ground, and an eight-petal
/// flower with a bronze eye.
class CreamGoldEmblemPainter extends CustomPainter {
  const CreamGoldEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 4) return;
    final c = size.center(Offset.zero);
    double w(double f, double min) => math.max(min, r * f);

    canvas.drawCircle(c, r * 0.97, _fill(_quoteBg));
    canvas.drawCircle(c, r * 0.95, _stroke(_gold, w(0.045, 1.4)));
    canvas.drawCircle(c, r * 0.83, _stroke(_gold, w(0.015, 0.7)));
    // Scalloped band: sixteen small arches between the rings.
    final scallops = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * 2 * math.pi / 16;
      final pc = c + Offset(math.cos(a), math.sin(a)) * r * 0.83;
      scallops.addArc(
        Rect.fromCircle(center: pc, radius: r * 0.1),
        a - math.pi / 2,
        math.pi,
      );
    }
    canvas.drawPath(scallops, _stroke(_gold, w(0.018, 0.7)));
    for (var i = 0; i < 16; i++) {
      final a = i * 2 * math.pi / 16 + math.pi / 16;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.885,
        w(0.022, 0.8),
        _fill(_gold),
      );
    }
    // Rub el hizb on a wheat ground, outlined twice.
    final star = _rubElHizb(c, r * 0.7);
    canvas.drawPath(star, _fill(_wheat.withValues(alpha: 0.55)));
    canvas.drawPath(star, _stroke(_gold, w(0.035, 1)));
    canvas.drawPath(
      _rubElHizb(c, r * 0.6),
      _stroke(_gold.withValues(alpha: 0.8), w(0.012, 0.6)),
    );
    canvas.drawCircle(c, r * 0.44, _fill(_quoteBg));
    canvas.drawCircle(c, r * 0.44, _stroke(_bronze, w(0.022, 0.8)));
    // Flower: gold petals with bronze outlines, rotated half a step behind.
    canvas.drawPath(
      _flower(c, r * 0.4, turn: math.pi / 8),
      _stroke(_gold.withValues(alpha: 0.6), w(0.012, 0.6)),
    );
    canvas.drawPath(_flower(c, r * 0.4), _fill(_gold));
    canvas.drawPath(_flower(c, r * 0.4), _stroke(_bronze, w(0.014, 0.6)));
    canvas.drawCircle(c, r * 0.11, _fill(_quoteBg));
    canvas.drawCircle(c, r * 0.11, _stroke(_bronze, w(0.02, 0.7)));
    canvas.drawCircle(c, r * 0.05, _fill(_bronze));
  }

  @override
  bool shouldRepaint(CreamGoldEmblemPainter old) => false;
}
