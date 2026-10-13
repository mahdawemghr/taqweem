import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'poster_template.dart';

// Mosque Blue palette (binding values from the plan, Task 20).
const _night = Color(0xFF08122B); // background top, row text, highlight
const _dusk = Color(0xFF123A6F); // gradient bottom
const _gold = Color(0xFFE8C766);
const _paleGold = Color(0xFFFFE9A8);
const _moonWhite = Color(0xFFEAF0FF);
const _band = Color(0xFF0E2A57); // table header, quote boxes, side panels
const _row = Color(0xFFEEF3FF);
const _rowAlt = Color(0xFFDCE6FB);
const _hairline = Color(0xFF7F9ACB);

/// Silhouette colour and opacity of the mosque illustration (plan).
const kMosqueSilhouetteColor = Color(0xFF0B2350);
const double kMosqueSilhouetteOpacity = 0.9;

// Illustration-only tones (never behind text).
const _glow = Color(0xFF2A5E9F); // moonlit sky behind the dome
const _lamp = Color(0xFFD9AE52); // lit windows (muted lamp gold)
const _rim = Color(0xFF6F9BD8); // moonlight catching the silhouette edges

/// Template 5 — an illustrative night scene. A vertical night-sky
/// gradient, a faint crescent and a scatter of stars, and a mosque
/// silhouette (onion dome on a drum, prayer hall with lit arched windows,
/// two slender minarets) rising behind the title against a moonlit glow;
/// a low skyline of domes, houses and minarets closes the poster behind
/// the article. Gold is used sparingly: a fine double frame with small
/// khatam corners, ground-line dividers with a star, the outlines of the
/// lighter-blue side panels, and a lit gold portal as the header emblem.
/// The table and quote boxes are opaque, so the illustration never
/// touches readability.
class MosqueBlueTemplate extends PosterTemplate {
  const MosqueBlueTemplate();

  @override
  String get id => 'mosque_blue';

  @override
  String get nameAr => 'أزرق ليلي ومسجد';

  @override
  PosterTheme get theme => _theme;
}

const _theme = PosterTheme(
  background: _night,
  frameColor: _gold,
  // Also the quote-attribution TEXT colour: 8.6:1 on quoteBoxBg (R19).
  accent: _gold,
  titleColor: _paleGold,
  bodyText: _moonWhite,
  tableHeaderBg: _band,
  tableHeaderFg: _paleGold,
  rowBg: _row,
  rowAltBg: _rowAlt,
  rowText: _night,
  gridLine: _hairline,
  highlightBg: _night,
  highlightFg: _paleGold,
  labelCellBg: _gold,
  labelCellFg: _night,
  quoteBoxBg: _band,
  quoteBoxBorder: _gold,
  quoteText: _moonWhite,
  headingFont: 'ArefRuqaa',
  bodyFont: 'Amiri',
  backgroundPainter: _background,
  framePainter: _frame,
  emblemPainter: _emblem,
);

CustomPainter _background() => const MosqueBlueBackgroundPainter();
CustomPainter _frame(LayoutMetrics? m) => MosqueBlueFramePainter(metrics: m);
CustomPainter _emblem() => const MosqueBlueEmblemPainter();

// ------------------------------------------------------------------ helpers

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = true;

Paint _fill(Color c) => Paint()..color = c;

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

/// Khatam / rub el hizb: two overlapping squares with circumradius [r].
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

/// Crescent of radius [r] opening towards [open] (unit-ish offset).
Path _crescent(Offset c, double r, Offset open) => Path.combine(
  PathOperation.difference,
  Path()..addOval(Rect.fromCircle(center: c, radius: r)),
  Path()
    ..addOval(Rect.fromCircle(center: c + open * (r * 0.42), radius: r * 0.84)),
);

/// Four-point sparkle star.
Path _sparkle(Offset c, double r) {
  final k = r * 0.22;
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
    ..close();
}

Path _union(Iterable<Path> parts) {
  Path? out;
  for (final p in parts) {
    out = out == null ? p : Path.combine(PathOperation.union, out, p);
  }
  return out ?? Path();
}

/// One mosque drawn on a ground line: [solid] is the silhouette (union of
/// every part), [windows] the arched openings lit from inside.
class _Mosque {
  _Mosque(this.solid, this.windows);
  final Path solid;
  final Path windows;
}

/// The mosque of the header, centred on [cx] with its ground at [ground],
/// scaled by [s] (1 = 272 px tall). Design units: dx from the axis, dy
/// above the ground. With [portal] false the centre of the hall gets an
/// arched door of its own (the header uses the emblem portal instead).
_Mosque _mosque(double cx, double ground, double s, {bool portal = false}) {
  Offset p(double dx, double dy) => Offset(cx + dx * s, ground - dy * s);
  Rect box(double dx0, double dy0, double dx1, double dy1) =>
      Rect.fromPoints(p(dx0, dy0), p(dx1, dy1));
  Path rect(double dx0, double dy0, double dx1, double dy1) =>
      Path()..addRect(box(dx0, dy0, dx1, dy1));

  final parts = <Path>[
    // Prayer hall with a cornice and a row of small merlons.
    rect(-176, 0, 176, 64),
    rect(-182, 62, 182, 68),
    for (var dx = -168.0; dx <= 168; dx += 16) rect(dx - 4, 66, dx + 4, 74),
    // Drum under the dome, with its own cornice.
    rect(-104, 66, 104, 100),
    rect(-112, 98, 112, 106),
  ];

  // Onion dome: swelling flanks, a slight neck and a pointed tip.
  Offset d(double dx, double dy) => p(dx, dy);
  final b0 = d(-106, 104), b1 = d(106, 104);
  final dome = Path()
    ..moveTo(b0.dx, b0.dy)
    ..cubicTo(
      d(-140, 132).dx,
      d(-140, 132).dy,
      d(-128, 184).dx,
      d(-128, 184).dy,
      d(-48, 210).dx,
      d(-48, 210).dy,
    )
    ..cubicTo(
      d(-22, 220).dx,
      d(-22, 220).dy,
      d(-6, 228).dx,
      d(-6, 228).dy,
      d(0, 246).dx,
      d(0, 246).dy,
    )
    ..cubicTo(
      d(6, 228).dx,
      d(6, 228).dy,
      d(22, 220).dx,
      d(22, 220).dy,
      d(48, 210).dx,
      d(48, 210).dy,
    )
    ..cubicTo(
      d(128, 184).dx,
      d(128, 184).dy,
      d(140, 132).dx,
      d(140, 132).dy,
      b1.dx,
      b1.dy,
    )
    ..close();
  parts.add(dome);
  // Finial: stem, ball and a crescent opening upwards.
  parts
    ..add(rect(-1.6, 240, 1.6, 266))
    ..add(Path()..addOval(Rect.fromCircle(center: p(0, 254), radius: 4.2 * s)))
    ..add(_crescent(p(0, 272), 7.5 * s, const Offset(0, -1)));

  // Side domes over the hall ends.
  for (final sx in [-1.0, 1.0]) {
    final c = sx * 136;
    final base0 = p(c - 26, 66), base1 = p(c + 26, 66);
    parts
      ..add(
        Path()
          ..moveTo(base0.dx, base0.dy)
          ..cubicTo(
            p(c - 30, 86).dx,
            p(c - 30, 86).dy,
            p(c - 12, 98).dx,
            p(c - 12, 98).dy,
            p(c, 106).dx,
            p(c, 106).dy,
          )
          ..cubicTo(
            p(c + 12, 98).dx,
            p(c + 12, 98).dy,
            p(c + 30, 86).dx,
            p(c + 30, 86).dy,
            base1.dx,
            base1.dy,
          )
          ..close(),
      )
      ..add(rect(c - 1.2, 104, c + 1.2, 116))
      ..add(
        Path()..addOval(Rect.fromCircle(center: p(c, 118), radius: 2.6 * s)),
      );
  }

  // Two minarets: tall shaft, two balconies on corbels, a lantern and a
  // pointed cap with a finial.
  for (final sx in [-1.0, 1.0]) {
    final c = sx * 167;
    Path corbel(double dy, double hwFrom, double hwTo, double h) {
      final a = p(c - hwFrom, dy), b = p(c + hwFrom, dy);
      final e = p(c + hwTo, dy + h), f = p(c - hwTo, dy + h);
      return Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(e.dx, e.dy)
        ..lineTo(f.dx, f.dy)
        ..close();
    }

    final tip = p(c, 264), capL = p(c - 10, 222), capR = p(c + 10, 222);
    parts
      ..add(rect(c - 10, 0, c + 10, 146))
      ..add(corbel(140, 10, 15, 8))
      ..add(rect(c - 15, 148, c + 15, 155))
      ..add(rect(c - 8, 155, c + 8, 196))
      ..add(corbel(192, 8, 12.5, 6))
      ..add(rect(c - 12.5, 198, c + 12.5, 203))
      ..add(rect(c - 7, 203, c + 7, 220))
      ..add(rect(c - 10, 219, c + 10, 223))
      ..add(
        Path()
          ..moveTo(capL.dx, capL.dy)
          ..quadraticBezierTo(
            p(c - 8, 246).dx,
            p(c - 8, 246).dy,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            p(c + 8, 246).dx,
            p(c + 8, 246).dy,
            capR.dx,
            capR.dy,
          )
          ..close(),
      )
      ..add(rect(c - 1, 262, c + 1, 274))
      ..add(
        Path()..addOval(Rect.fromCircle(center: p(c, 270), radius: 2.4 * s)),
      );
  }

  // Lit arched windows: hall arcade, drum, minaret slits.
  final windows = <Path>[];
  Path win(double dx, double hw, double top, double bottom) {
    final a = p(dx, top), sp = p(dx, top - hw * 1.3), bt = p(dx, bottom);
    return _arch(a.dx, hw * s, a.dy, sp.dy, bt.dy);
  }

  for (final sx in [-1.0, 1.0]) {
    for (final dx in [80.0, 106.0, 136.0]) {
      windows.add(win(sx * dx, 5.5, 48, 12));
    }
    for (final dx in [72.0, 90.0]) {
      windows.add(win(sx * dx, 4.5, 94, 74));
    }
    windows
      ..add(win(sx * 167, 3.2, 120, 100))
      ..add(win(sx * 167, 2.6, 184, 168))
      ..add(win(sx * 167, 2.4, 216, 206));
  }
  if (!portal) windows.add(win(0, 18, 58, 0));
  return _Mosque(_union(parts), _union(windows));
}

/// The header mosque for a poster laid out with [m].
_Mosque _headerMosque(LayoutMetrics m) =>
    _mosque(m.contentRect.center.dx, m.headerBottom, 1, portal: true);

/// Quote-box rects of the header (opaque content painted over the sky).
List<Rect> _quoteBoxes(LayoutMetrics m) {
  final c = m.contentRect;
  final w = c.width * 0.3;
  final top = c.top + _theme.headerHeight * 0.17;
  final bottom = m.headerBottom - _theme.headerHeight * 0.06;
  return [
    Rect.fromLTRB(c.right - w, top, c.right, bottom),
    Rect.fromLTRB(c.left, top, c.left + w, bottom),
  ];
}

/// Centre of the faint crescent moon in the header sky.
Offset _moonCentre(LayoutMetrics m) =>
    Offset(m.contentRect.right - 78, m.contentRect.top + 14);
const double _moonRadius = 19;

/// Deterministic star field of the header sky: at most 40 stars from a
/// fixed seed, kept off the quote boxes, the mosque and the moon.
List<({Offset center, double radius, double alpha})> mosqueBlueStars(
  Size size,
) {
  if (size.width < 600 || size.height < 1200) return const [];
  final m = LayoutMetrics.compute(size, _theme, 0);
  final mosque = _headerMosque(m).solid;
  final boxes = [for (final b in _quoteBoxes(m)) b.inflate(6)];
  final moon = _moonCentre(m);
  final rnd = math.Random(1448);
  final out = <({Offset center, double radius, double alpha})>[];
  for (var tries = 0; tries < 600 && out.length < 36; tries++) {
    final c = Offset(
      30 + rnd.nextDouble() * (size.width - 60),
      30 + rnd.nextDouble() * (m.headerBottom - 44),
    );
    final big = rnd.nextDouble() < 0.18;
    final alpha = 0.35 + rnd.nextDouble() * 0.5;
    if (boxes.any((b) => b.contains(c))) continue;
    if ((c - moon).distance < _moonRadius + 16) continue;
    var hit = false;
    for (final o in const [
      Offset.zero,
      Offset(6, 0),
      Offset(-6, 0),
      Offset(0, 6),
      Offset(0, -6),
    ]) {
      if (mosque.contains(c + o)) hit = true;
    }
    if (hit) continue;
    if (out.any((s) => (s.center - c).distance < 26)) continue;
    out.add((center: c, radius: big ? 5.5 : 1.3 + alpha * 1.4, alpha: alpha));
  }
  return out;
}

/// Low skyline along the bottom edge: a small mosque in the middle, two
/// minarets near the corners and rows of domed houses in between. Every
/// part stays within the bottom 220 px.
_Mosque _skyline(Size size) {
  final ground = size.height;
  final cx = size.width / 2;
  final mid = _mosque(cx, ground, 0.5);
  final parts = <Path>[mid.solid];
  final windows = <Path>[mid.windows];

  // Corner minarets.
  // x = 36: outside the article text (inset 12 from content.left 40).
  for (final x in [36.0, size.width - 36]) {
    final s = 0.62;
    Offset p(double dx, double dy) => Offset(x + dx * s, ground - dy * s);
    Path rect(double dx0, double dy0, double dx1, double dy1) =>
        Path()..addRect(Rect.fromPoints(p(dx0, dy0), p(dx1, dy1)));
    final tip = p(0, 300), l = p(-11, 258), r = p(11, 258);
    parts
      ..add(rect(-12, 0, 12, 190))
      ..add(rect(-18, 186, 18, 194))
      ..add(rect(-9, 194, 9, 256))
      ..add(rect(-12, 254, 12, 259))
      ..add(
        Path()
          ..moveTo(l.dx, l.dy)
          ..quadraticBezierTo(p(-9, 284).dx, p(-9, 284).dy, tip.dx, tip.dy)
          ..quadraticBezierTo(p(9, 284).dx, p(9, 284).dy, r.dx, r.dy)
          ..close(),
      )
      ..add(_crescent(p(0, 310), 6 * s, const Offset(0, -1)));
    windows.add(
      _arch(x, 3, ground - 150 * s, ground - 142 * s, ground - 126 * s),
    );
  }

  // Domed houses: (centre x fraction, half width, height, dome?).
  const houses = <(double, double, double, bool)>[
    (0.035, 26, 46, false),
    (0.15, 30, 58, true),
    (0.215, 22, 38, false),
    (0.27, 34, 66, true),
    (0.335, 20, 44, false),
    (0.665, 20, 44, false),
    (0.73, 34, 66, true),
    (0.785, 22, 38, false),
    (0.85, 30, 58, true),
    (0.965, 26, 46, false),
  ];
  for (final (fx, hw, h, dome) in houses) {
    final x = size.width * fx;
    parts.add(
      Path()..addRect(Rect.fromLTRB(x - hw, ground - h, x + hw, ground)),
    );
    if (dome) {
      final r = hw * 0.7;
      parts.add(
        Path()..addArc(
          Rect.fromCircle(center: Offset(x, ground - h), radius: r),
          math.pi,
          math.pi,
        ),
      );
      parts.add(
        Path()..addRect(
          Rect.fromLTRB(x - 1, ground - h - r - 9, x + 1, ground - h - r + 1),
        ),
      );
    }
    windows.add(_arch(x, 4, ground - h + 12, ground - h + 18, ground - h + 30));
  }
  // Continuous low wall joining everything.
  parts.add(Path()..addRect(Rect.fromLTRB(0, ground - 26, size.width, ground)));
  return _Mosque(_union(parts), _union(windows));
}

// --------------------------------------------------------------- background

/// Night-sky gradient, moonlit glow behind the header mosque, a faint
/// crescent and stars, the mosque silhouette in the top 300 px, the low
/// skyline in the bottom 220 px and lighter-blue panels behind the side
/// Q&A. Everything is below the content: rows and quote boxes are opaque.
class MosqueBlueBackgroundPainter extends CustomPainter {
  const MosqueBlueBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_night, _night, _dusk],
          stops: [0, 0.12, 1],
        ).createShader(rect),
    );
    if (size.width < 600 || size.height < 1200) return;
    final m = LayoutMetrics.compute(size, _theme, 0);
    final cx = m.contentRect.center.dx;

    // Moonlit glow behind the dome.
    final glowC = Offset(cx, m.headerBottom - 150);
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, m.headerBottom + 60),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _glow.withValues(alpha: 0.75),
            _glow.withValues(alpha: 0.3),
            _glow.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: glowC, radius: 300)),
    );

    // Faint crescent with a soft halo.
    final moon = _moonCentre(m);
    canvas.drawCircle(
      moon,
      _moonRadius * 2.4,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _paleGold.withValues(alpha: 0.16),
                _paleGold.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: moon, radius: _moonRadius * 2.4),
            ),
    );
    canvas.drawPath(
      _crescent(moon, _moonRadius, const Offset(-0.75, -0.55)),
      _fill(_paleGold.withValues(alpha: 0.72)),
    );

    // Stars.
    for (final s in mosqueBlueStars(size)) {
      final paint = _fill(_moonWhite.withValues(alpha: s.alpha));
      if (s.radius > 4) {
        canvas.drawPath(_sparkle(s.center, s.radius), paint);
      } else {
        canvas.drawCircle(s.center, s.radius, paint);
      }
    }

    // Header mosque and the bottom skyline.
    _drawMosque(canvas, _headerMosque(m));
    // Rim stroke and lit windows are dropped where they would pass behind
    // the article / fatiha text: only the side margins and the bottom strip
    // keep them.
    final textBand = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(
        Rect.fromLTRB(52, size.height - 260, size.width - 52, size.height - 52),
      ),
    );
    _drawMosque(canvas, _skyline(size), detailClip: textBand);

    // Lighter-blue panels behind the side Q&A strips.
    for (final s in [m.rightStripRect, m.leftStripRect]) {
      canvas.drawRect(s, _fill(_band));
    }
  }

  void _drawMosque(Canvas canvas, _Mosque mosque, {Path? detailClip}) {
    canvas.drawPath(
      mosque.solid,
      _fill(kMosqueSilhouetteColor.withValues(alpha: kMosqueSilhouetteOpacity)),
    );
    if (detailClip != null) {
      canvas.save();
      canvas.clipPath(detailClip);
    }
    canvas.drawPath(mosque.solid, _stroke(_rim.withValues(alpha: 0.5), 1.4));
    canvas.drawPath(mosque.windows, _fill(_lamp.withValues(alpha: 0.78)));
    if (detailClip != null) canvas.restore();
  }

  @override
  bool shouldRepaint(MosqueBlueBackgroundPainter old) => false;
}

// -------------------------------------------------------------------- frame

/// Fine gold double frame with small khatam corners, gold ground-line
/// dividers with a centred star under the header and above the article,
/// gold outlines on the side panels and a gold rule under the table's
/// column headers. Drawn above the content, but only on the frame band,
/// panel edges and section gaps.
class MosqueBlueFramePainter extends CustomPainter {
  const MosqueBlueFramePainter({this.metrics});

  final LayoutMetrics? metrics;

  static const double _outer = 14, _inner = 21;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final o = (Offset.zero & size).deflate(_outer);
    if (o.width <= 2 * _inner || o.height <= 2 * _inner) return;
    final i = (Offset.zero & size).deflate(_inner);
    canvas.drawRect(o, _stroke(_gold, 2.4));
    canvas.drawRect(i, _stroke(_gold.withValues(alpha: 0.7), 1));

    // Khatam corner badges straddling both rules.
    final mid = (_outer + _inner) / 2;
    for (final c in [
      Offset(mid, mid),
      Offset(size.width - mid, mid),
      Offset(mid, size.height - mid),
      Offset(size.width - mid, size.height - mid),
    ]) {
      canvas.drawCircle(c, 12, _fill(_night));
      canvas.drawPath(_khatam(c, 11, turn: math.pi / 8), _fill(_gold));
      canvas.drawCircle(c, 4.2, _fill(_night));
      canvas.drawCircle(c, 1.8, _fill(_paleGold));
    }

    final m = metrics;
    if (m == null) return;
    final content = m.contentRect;

    // Ground line of the header mosque.
    _divider(canvas, content, m.headerBottom + 1);

    // Side panels.
    for (final s in [m.rightStripRect, m.leftStripRect]) {
      if (s.height > 0) {
        canvas.drawRect(
          s.deflate(0.75),
          _stroke(_gold.withValues(alpha: 0.85), 1.3),
        );
      }
    }

    // Gold rule under the column-header band.
    if (m.tableHeaderBottom < m.tableBottom) {
      final r = m.tableRect;
      canvas.drawLine(
        Offset(r.left, m.tableHeaderBottom - 1.5),
        Offset(r.right, m.tableHeaderBottom - 1.5),
        _stroke(_gold, 3),
      );
    }

    // Table / article divider.
    _divider(canvas, content, m.articleTop + 4);
  }

  /// Gold rule across [content] fading at both ends, with a centred
  /// eight-pointed star and two dots.
  void _divider(Canvas canvas, Rect content, double y) {
    final cx = content.center.dx;
    for (final sx in [-1.0, 1.0]) {
      final a = Offset(cx + sx * 20, y),
          b = Offset(cx + sx * (content.width / 2), y);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 1.4
          ..shader = LinearGradient(
            colors: [
              _gold,
              _gold.withValues(alpha: 0.9),
              _gold.withValues(alpha: 0),
            ],
            stops: const [0, 0.7, 1],
          ).createShader(Rect.fromPoints(a, b)),
      );
      canvas.drawCircle(Offset(cx + sx * 27, y), 2.2, _fill(_gold));
    }
    canvas.drawPath(
      _khatam(Offset(cx, y), 10, turn: math.pi / 8),
      _fill(_night),
    );
    canvas.drawPath(_khatam(Offset(cx, y), 9, turn: math.pi / 8), _fill(_gold));
    canvas.drawCircle(Offset(cx, y), 3, _fill(_night));
  }

  @override
  bool shouldRepaint(MosqueBlueFramePainter old) => old.metrics != metrics;
}

// ------------------------------------------------------------------- emblem

/// The mosque's main portal, lit from inside: a gold-outlined pointed
/// arch in the silhouette colour, a warm lamp-light doorway, a hanging
/// lantern and a small khatam in the tympanum.
class MosqueBlueEmblemPainter extends CustomPainter {
  const MosqueBlueEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 8) return;
    final c = size.center(Offset.zero);
    final top = c.dy - s / 2, bottom = c.dy + s / 2;
    double w(double f, double min) => math.max(min, s * f);

    // Outer frame of the portal (iwan) and its gold outline.
    final outer = _arch(c.dx, s * 0.4, top + s * 0.02, top + s * 0.42, bottom);
    canvas.drawPath(outer, _fill(kMosqueSilhouetteColor));
    canvas.drawPath(outer, _stroke(_gold, w(0.02, 1)));

    // Lit doorway.
    final door = _arch(c.dx, s * 0.3, top + s * 0.12, top + s * 0.5, bottom);
    canvas.drawPath(
      door,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _paleGold.withValues(alpha: 0.95),
            _gold.withValues(alpha: 0.75),
            _gold.withValues(alpha: 0.35),
          ],
        ).createShader(door.getBounds()),
    );
    canvas.drawPath(door, _stroke(_paleGold, w(0.012, 0.8)));

    // Khatam in the tympanum.
    canvas.drawPath(
      _khatam(Offset(c.dx, top + s * 0.3), s * 0.075, turn: math.pi / 8),
      _fill(kMosqueSilhouetteColor),
    );

    // Hanging lantern.
    final lx = c.dx, ly = top + s * 0.56;
    canvas.drawLine(
      Offset(lx, top + s * 0.39),
      Offset(lx, ly - s * 0.05),
      _stroke(kMosqueSilhouetteColor, w(0.01, 0.8)),
    );
    final lantern = Path()
      ..moveTo(lx, ly - s * 0.06)
      ..lineTo(lx + s * 0.045, ly)
      ..lineTo(lx + s * 0.03, ly + s * 0.08)
      ..lineTo(lx - s * 0.03, ly + s * 0.08)
      ..lineTo(lx - s * 0.045, ly)
      ..close();
    canvas.drawPath(lantern, _fill(kMosqueSilhouetteColor));
    canvas.drawCircle(Offset(lx, ly + s * 0.025), s * 0.016, _fill(_paleGold));

    // Threshold step.
    canvas.drawRect(
      Rect.fromLTRB(
        c.dx - s * 0.36,
        bottom - s * 0.04,
        c.dx + s * 0.36,
        bottom,
      ),
      _fill(_gold.withValues(alpha: 0.8)),
    );
  }

  @override
  bool shouldRepaint(MosqueBlueEmblemPainter old) => false;
}
