import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'poster_template.dart';
import 'shared/painters.dart';

// Navy & Gold palette (binding values from the Task 10 brief).
const _navy = Color(0xFF0B1B3F);
const _navyBand = Color(0xFF14295C);
const _navyPanel = Color(0xFF102552);
const _gold = Color(0xFFC9A24B);
const _paleGold = Color(0xFFF1D78A);
const _ivory = Color(0xFFF4EBD0);
const _cream = Color(0xFFF7F0DC);
const _creamAlt = Color(0xFFEDE3C7);

/// Template 1 — deep navy poster with a faint gold star lattice, a gold
/// double frame with corner rosettes, ornamental gold dividers between the
/// header, the table and the closing article, and a gold-ringed star
/// medallion under the title. The table sits on cream rows with gold
/// hairlines; highlighted days are navy bands with pale-gold text.
class NavyGoldTemplate extends PosterTemplate {
  const NavyGoldTemplate();

  @override
  String get id => 'navy_gold';

  @override
  String get nameAr => 'كحلي وذهبي';

  @override
  PosterTheme get theme => const PosterTheme(
    background: _navy,
    frameColor: _gold,
    accent: _gold,
    titleColor: _paleGold,
    bodyText: _ivory,
    tableHeaderBg: _navyBand,
    tableHeaderFg: _paleGold,
    rowBg: _cream,
    rowAltBg: _creamAlt,
    rowText: _navy,
    gridLine: _gold,
    highlightBg: _navy,
    highlightFg: _paleGold,
    labelCellBg: _gold,
    labelCellFg: _navy,
    quoteBoxBg: _navyPanel,
    quoteBoxBorder: _gold,
    quoteText: _ivory,
    headingFont: 'ArefRuqaa',
    bodyFont: 'Amiri',
    backgroundPainter: _background,
    framePainter: _frame,
    emblemPainter: _emblem,
  );
}

CustomPainter _background() => const NavyGoldBackgroundPainter();
CustomPainter _frame(LayoutMetrics? m) => NavyGoldFramePainter(metrics: m);
CustomPainter _emblem() => const NavyGoldEmblemPainter();

// ------------------------------------------------------------------ helpers

/// 8-point star outline (16 vertices), first tip pointing up.
Path _star(Offset c, double outer, double inner, {double turn = 0}) {
  final p = Path();
  for (var i = 0; i < 16; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + turn + i * math.pi / 8;
    final pt = c + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Diamond (lozenge) centred on [c], half-width [w], half-height [h].
Path _diamond(Offset c, double w, double h) => Path()
  ..moveTo(c.dx, c.dy - h)
  ..lineTo(c.dx + w, c.dy)
  ..lineTo(c.dx, c.dy + h)
  ..lineTo(c.dx - w, c.dy)
  ..close();

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = true;

Paint _fill(Color c) => Paint()..color = c;

/// Small rosette: navy disc, gold 8-point star, navy eye, gold dot.
void _rosette(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(c, r * 1.05, _fill(_navy));
  canvas.drawPath(_star(c, r, r * 0.62), _fill(_gold));
  canvas.drawCircle(c, r * 0.38, _fill(_navy));
  canvas.drawCircle(c, r * 0.18, _fill(_paleGold));
}

// --------------------------------------------------------------- background

/// Flat navy (painted by the layout) + a soft darkening towards the edges
/// and the faint gold star lattice.
class NavyGoldBackgroundPainter extends CustomPainter {
  const NavyGoldBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    // Vignette only darkens, so text contrast on the navy only increases.
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: const [Color(0x00050D22), Color(0x55050D22)],
            ).createShader(
              Rect.fromCenter(
                center: rect.center,
                width: size.width * 1.6,
                height: size.height,
              ),
            ),
    );
    const GeometricPatternPainter(
      color: _gold,
      opacity: 0.07,
      cell: 84,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(NavyGoldBackgroundPainter old) => false;
}

// -------------------------------------------------------------------- frame

/// Gold double border with corner rosettes and crests, plus ornamental
/// dividers placed from the real section positions in [metrics].
///
/// Everything here is drawn ABOVE the content, so every ornament lives in a
/// margin or gap the layout leaves empty: the border band (outside
/// `contentRect`), the strip between the quote boxes and the brace line,
/// the inside of the table header's bottom rule, and the free space either
/// side of the article author / fatiha lines (their text is inset 120 / 80
/// px by the layout).
class NavyGoldFramePainter extends CustomPainter {
  const NavyGoldFramePainter({this.metrics});

  final LayoutMetrics? metrics;

  static const double _inset = 18, _gap = 8, _strokeW = 3, _corner = 24;

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
    if (inner.width <= 2 * _corner || inner.height <= 2 * _corner) return;

    // Hairline just outside the heavy outer rule.
    canvas.drawRect(
      outer.inflate(5),
      _stroke(_gold.withValues(alpha: 0.55), 1),
    );

    // Corner rosettes in the notches of the inner rule.
    const h = _corner / 2;
    for (final c in [
      inner.topLeft + const Offset(h, h),
      inner.topRight + const Offset(-h, h),
      inner.bottomLeft + const Offset(h, -h),
      inner.bottomRight + const Offset(-h, -h),
    ]) {
      _rosette(canvas, c, 10);
    }

    // Crests on the middle of the top and bottom rules.
    final midBand = (outer.top + inner.top) / 2;
    _crest(canvas, Offset(size.width / 2, midBand), up: true);
    _crest(canvas, Offset(size.width / 2, size.height - midBand), up: false);

    final m = metrics;
    if (m == null) return;
    final content = m.contentRect;

    // Header / brace divider in the gap below the quote boxes.
    _divider(canvas, content, m.headerBottom + 4);

    // Gold rule under the table's column-header band (drawn inside the
    // band so it never touches day-row text).
    if (m.tableHeaderBottom < m.tableBottom) {
      final r = m.tableRect;
      canvas.drawLine(
        Offset(r.left, m.tableHeaderBottom - 2),
        Offset(r.right, m.tableHeaderBottom - 2),
        _stroke(_gold, 3),
      );
    }

    // Flourishes either side of the article author line and the fatiha.
    _flanks(canvas, content, m.articleTop + 24, 104);
    _flanks(canvas, content, m.articleBottom - 23, 66);
  }

  /// Lozenge with a star, straddling a horizontal border at [c].
  void _crest(Canvas canvas, Offset c, {required bool up}) {
    canvas.drawPath(_diamond(c, 30, 13), _fill(_navy));
    canvas.drawPath(_diamond(c, 30, 13), _stroke(_gold, 2));
    canvas.drawPath(_diamond(c, 22, 8), _stroke(_gold, 1));
    _rosette(canvas, c, 7);
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(c + Offset(s * 40, 0), 3, _fill(_gold));
    }
  }

  /// Centred divider: tapered double rule with diamond beads and a small
  /// central star, spanning most of [content]'s width at height [y].
  void _divider(Canvas canvas, Rect content, double y) {
    final cx = content.center.dx;
    final half = content.width / 2 - 70;
    for (final s in [-1.0, 1.0]) {
      final from = cx + s * 20;
      final to = cx + s * half;
      canvas.drawLine(Offset(from, y), Offset(to, y), _stroke(_gold, 1.8));
      final thin = cx + s * (half - 60);
      canvas.drawLine(
        Offset(from + s * 18, y + 4),
        Offset(thin, y + 4),
        _stroke(_gold, 0.8),
      );
      canvas.drawLine(
        Offset(from + s * 18, y - 4),
        Offset(thin, y - 4),
        _stroke(_gold, 0.8),
      );
      for (final f in [0.35, 0.7]) {
        canvas.drawPath(
          _diamond(Offset(cx + s * half * f, y), 5, 3.5),
          _fill(_gold),
        );
      }
      canvas.drawPath(_diamond(Offset(to, y), 7, 4), _fill(_gold));
    }
    canvas.drawPath(_star(Offset(cx, y), 9, 5), _fill(_gold));
    canvas.drawCircle(Offset(cx, y), 2.4, _fill(_navy));
  }

  /// Mirrored flourishes from each side of [content] inwards, [len] long,
  /// leaving the centred text line free.
  void _flanks(Canvas canvas, Rect content, double y, double len) {
    for (final s in [1.0, -1.0]) {
      final edge = s > 0 ? content.left + 6 : content.right - 6;
      final tip = edge + s * len;
      canvas.drawCircle(Offset(edge, y), 2.5, _fill(_gold));
      canvas.drawLine(
        Offset(edge + s * 6, y),
        Offset(tip - s * 12, y),
        _stroke(_gold, 1.6),
      );
      canvas.drawLine(
        Offset(edge + s * 18, y + 4),
        Offset(tip - s * 26, y + 4),
        _stroke(_gold, 0.8),
      );
      canvas.drawPath(_diamond(Offset(tip - s * 6, y), 6, 4), _fill(_gold));
    }
  }

  @override
  bool shouldRepaint(NavyGoldFramePainter old) => old.metrics != metrics;
}

// ------------------------------------------------------------------- emblem

/// Gold-ringed medallion: beaded double ring, a twelve-ray sunburst, a
/// filled 8-point star with a navy eye and a pale-gold inner star.
class NavyGoldEmblemPainter extends CustomPainter {
  const NavyGoldEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 4) return;
    final c = size.center(Offset.zero);

    canvas.drawCircle(c, r * 0.97, _fill(_navyPanel));
    canvas.drawCircle(c, r * 0.95, _stroke(_gold, math.max(1.5, r * 0.05)));
    canvas.drawCircle(c, r * 0.82, _stroke(_gold, math.max(0.8, r * 0.015)));
    // Bead ring between the two rules.
    for (var i = 0; i < 32; i++) {
      final a = i * 2 * math.pi / 32;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.885,
        math.max(0.8, r * 0.025),
        _fill(_gold),
      );
    }
    // Faint rays behind the star.
    final ray = _stroke(
      _gold.withValues(alpha: 0.45),
      math.max(0.6, r * 0.012),
    );
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * math.pi / 24 + math.pi / 24;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.5, c + d * r * 0.76, ray);
    }
    // Outlined rotated star under the filled one => 16-point interlace.
    canvas.drawPath(
      _star(c, r * 0.74, r * 0.52, turn: math.pi / 8),
      _stroke(_gold, math.max(0.8, r * 0.02)),
    );
    canvas.drawPath(_star(c, r * 0.72, r * 0.5), _fill(_gold));
    canvas.drawCircle(c, r * 0.4, _fill(_navy));
    canvas.drawCircle(c, r * 0.4, _stroke(_paleGold, math.max(0.6, r * 0.012)));
    canvas.drawPath(_star(c, r * 0.3, r * 0.17), _fill(_paleGold));
    canvas.drawCircle(c, r * 0.08, _fill(_navy));
  }

  @override
  bool shouldRepaint(NavyGoldEmblemPainter old) => false;
}
