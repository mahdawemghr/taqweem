// Emerald Garden (D5): the richer "garden" emerald poster. An ornate gold
// arabesque border runs round all four sides (two interlaced vine strands
// with flowers in their eyes, double rules, a lace edge and rosette corner
// blocks with small flourishes); inside, a lighter emerald field whose top
// band and arch spandrels carry a dense gold arabesque (an ogee lattice of
// interlaced vines with palmettes, rosettes and scrolling tendrils, fading
// downwards, never behind text). At the top
// centre the double-ring medallion sits on a wide navy banner with pointed
// ends whose outer ends carry the two header quotes; below, inside the apex
// of a basket-arched panel with a cusped (polylobed) inner lace line, a thin
// gold double rule with a lozenge and the brace quote in bold gold; the
// table in the arch has glass rows, gold pills for the weekday and the hijri
// day, gold highlighted rows and gold month-label pills. Gold-framed side
// Q&A strips, the cream footer note and a navy article panel with ornate
// gold corner brackets and a gold author pill close the poster.
//
// Composition source: templates/Gemini_Generated_Image_hfx58yhfx58yhfx5.jpeg
// (look only; every text comes from the MonthPoster).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../brand/brand_logo.dart';
import '../domain/models.dart';
import '../domain/time_format.dart';
import 'kit/kit.dart';
import 'poster_template.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Deep emerald of the ornate border band.
const gdBand = Color(0xFF062A1F);

/// Field: emerald at the edges, lighter emerald in the centre (every text on
/// the field is checked against the lighter one).
const gdEmerald = Color(0xFF0B3D2E);
const gdFieldLight = Color(0xFF125440);

/// Arch panel fill (slightly lighter green), top → bottom.
const gdArchTop = Color(0xFF1A6149);
const gdArchBottom = Color(0xFF145541);

/// Ornament gold, light gold and the bright gold of the brace quote.
const gdGold = Color(0xFFD4AF5E);
const gdGoldLight = Color(0xFFF0D894);
const gdBraceGold = Color(0xFFF2D27A);

/// Navy of the banner and the article panel (bottom / top of the gradient).
const gdNavy = Color(0xFF0F1B33);
const gdNavyTop = Color(0xFF1B2B52);

/// Cream text and dark ink (text on gold).
const gdCream = Color(0xFFF8EED6);
const gdInk = Color(0xFF0F1E18);

/// Glass rows: translucent dark green and a lighter translucent green over
/// the arch panel.
const gdRowDark = Color(0xC0061E16);
const gdRowLight = Color(0x80082A1F);

/// Pill on highlighted (gold) rows: dark ink pill with light-gold text.
const gdPillDark = Color(0xFF14261E);

/// Opaque mid gold of the vertical table rules (visible on the gold header
/// and on the glass rows).
const gdGoldRule = Color(0xFF9C7B3C);

/// Side-strip fill and the edited-title disc.
const gdStripFill = Color(0xFF082C21);
const gdDisc = Color(0xFF0C3B2C);

// ---------------------------------------------------------------------------
// Geometry (logical px on the 1000 x 2200 poster)
// ---------------------------------------------------------------------------

/// Width of the ornate border band; no content enters it.
const double gdBorderWidth = 42;
const double _corner = gdBorderWidth;
const double _bandOuter = 7, _bandInner = 34; // strand band between
const double _vineAmp = 8.5, _vinePeriod = 44, _laceBulge = 2.5;

/// Corner-block scale relative to the original 60-px band design.
const double _ck = 0.7;

const double _medSize = 290, _medTop = 60, _discInset = 6;

/// Transparent margin of medallion_emerald_b.png (17 of 437 px) at
/// [_medSize]: the visible disc ends this far inside the medallion box.
const double gdMedInk = _medSize * 17 / 437;
const double _bannerSide = 48, _bannerTop = 104, _bannerBottom = 334;
const double _bannerDepth = 22, _bannerSag = 16;
const double _quoteTextGap = 8, _quotePadV = 12, _quotePadOuter = 6;
const double _archSide = 102, _archTop = 368, _archBottom = 1800;
const double _archRise = 200, _archRadius = 16;
const double _laceInset = 12, _laceLobes = 22;
const double _ruleTop = _archTop + 50, _ruleHalf = 150, _ruleHeight = 22;
const double _braceHalf = 240;
const double _braceTop = _archTop + 78, _braceBottom = _archTop + 190;
const double _tablePad = 12, _tableTopGap = 8;
const double _stripMargin = 6, _stripWidth = 46;
const double _noteTop = 1810, _noteHeight = 40, _noteSide = 66;
const double _articleSide = 72, _articleTop = 1888, _articleBottom = 12;

/// The arabesque fills the top band and the spandrels down to this line
/// (a little below the arch's springing line; the side strips and the
/// table start lower).
const double gdArabesqueBottom = _archTop + _archRise + 12;
const double _arabW = 64, _arabP = 96; // ogee lattice cell
const double _pillWidth = 400, _pillHeight = 48;
const double _fatihaHeight = 46;
const double _bracketLen = 52;
const double _blockLine = 1.45;
const double _quoteLine = 1.32;
const double _timeWidth = 58;

/// The arch outline: a wide basket (elliptical) arch, distinct from the
/// pointed mihrab of emerald_mihrab.
const gdArchShape = PanelShape.arch(
  rise: _archRise,
  pointed: false,
  radius: _archRadius,
);

/// Section rects plus table geometry of the poster for [size].
///
/// Named rects: `field` (inside the border), `medallion`, `banner`,
/// `quoteRightText`, `quoteLeftText`, `arch`, `rule`, `brace`, `table`,
/// `stripRight`, `stripLeft`, `footerNote`, `article`, `pill`.
KitMetrics emeraldGardenMetrics(Size size, int rowCount) {
  final w = size.width, h = size.height;
  final cx = w / 2;
  final med = Rect.fromLTWH(cx - _medSize / 2, _medTop, _medSize, _medSize);
  final banner = Rect.fromLTRB(
    _bannerSide,
    _bannerTop,
    w - _bannerSide,
    _bannerBottom,
  );
  final arch = Rect.fromLTRB(_archSide, _archTop, w - _archSide, _archBottom);
  final table = Rect.fromLTRB(
    arch.left + _tablePad,
    arch.top + _archRise + _tableTopGap,
    arch.right - _tablePad,
    arch.bottom - _tablePad,
  );
  final article = Rect.fromLTRB(
    _articleSide,
    _articleTop,
    w - _articleSide,
    h - gdBorderWidth - _articleBottom,
  );
  final textTop = banner.top + _bannerSag + _quotePadV;
  // The bottom edge rises towards the centre (sag): stay above it.
  final textBottom = banner.bottom - _bannerSag / 2 - _quotePadV;
  final rects = <String, Rect>{
    'field': Rect.fromLTRB(
      gdBorderWidth,
      gdBorderWidth,
      w - gdBorderWidth,
      h - gdBorderWidth,
    ),
    'medallion': med,
    'banner': banner,
    'quoteRightText': Rect.fromLTRB(
      med.right - gdMedInk + _quoteTextGap,
      textTop,
      banner.right - _bannerDepth - _quotePadOuter,
      textBottom,
    ),
    'quoteLeftText': Rect.fromLTRB(
      banner.left + _bannerDepth + _quotePadOuter,
      textTop,
      med.left + gdMedInk - _quoteTextGap,
      textBottom,
    ),
    'arch': arch,
    'rule': Rect.fromLTRB(
      cx - _ruleHalf,
      _ruleTop,
      cx + _ruleHalf,
      _ruleTop + _ruleHeight,
    ),
    'brace': Rect.fromLTRB(
      cx - _braceHalf,
      _braceTop,
      cx + _braceHalf,
      _braceBottom,
    ),
    'table': table,
    'stripRight': Rect.fromLTRB(
      w - gdBorderWidth - _stripMargin - _stripWidth,
      table.top,
      w - gdBorderWidth - _stripMargin,
      table.bottom,
    ),
    'stripLeft': Rect.fromLTRB(
      gdBorderWidth + _stripMargin,
      table.top,
      gdBorderWidth + _stripMargin + _stripWidth,
      table.bottom,
    ),
    'footerNote': Rect.fromLTWH(
      _noteSide,
      _noteTop,
      w - 2 * _noteSide,
      _noteHeight,
    ),
    'article': article,
    'pill': Rect.fromCenter(
      center: Offset(cx, article.top),
      width: _pillWidth,
      height: _pillHeight,
    ),
  };
  return KitMetrics(
    size: size,
    contentRect: Offset.zero & size,
    sections: rects,
    table: TableGeometry.compute(emeraldGardenTableSpec, table, rowCount),
  );
}

// ---------------------------------------------------------------------------
// Banner: wide navy ribbon with pointed ends whose edges sag towards the
// ends (the centre is hidden behind the medallion).
// ---------------------------------------------------------------------------

/// The banner outline for [rect], shrunk by [inset] (borders).
Path gdBannerPath(Rect rect, {double inset = 0}) {
  final r = rect.deflate(inset);
  if (r.width <= 0 || r.height <= 0) return Path();
  final d = math.max(0.0, math.min(_bannerDepth - inset * 0.5, r.width / 4));
  final s = math.min(_bannerSag, r.height / 4);
  final l = r.left, t = r.top, rt = r.right, b = r.bottom - s;
  final cx = r.center.dx, cy = (t + b) / 2 + s;
  return Path()
    ..moveTo(l + d, t + s)
    ..quadraticBezierTo(cx, t - s, rt - d, t + s)
    ..lineTo(rt, cy)
    ..lineTo(rt - d, b + s)
    ..quadraticBezierTo(cx, b - s, l + d, b + s)
    ..lineTo(l, cy)
    ..close();
}

class _BannerPainter extends CustomPainter {
  const _BannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;
    canvas.drawPath(
      gdBannerPath(rect).shift(const Offset(0, 5)),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      gdBannerPath(rect),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gdNavyTop, gdNavy],
        ).createShader(rect),
    );
    canvas.drawPath(gdBannerPath(rect, inset: 1.5), _stroke(gdGold, 3));
    canvas.drawPath(
      gdBannerPath(rect, inset: 8),
      _stroke(const Color(0xB3D4AF5E), 1.1),
    );
  }

  @override
  bool shouldRepaint(_BannerPainter old) => false;
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = true;

// ---------------------------------------------------------------------------
// Ornate border (built once per size and cached)
// ---------------------------------------------------------------------------

/// The paths of the ornate border: [rules] (double frame rules and the lace
/// edge, stroked), [strands] (the two interlaced vine strands, stroked as a
/// gold band with a dark core), [fills] (flowers, corner rosettes and
/// flourishes, filled gold) and [cores] (dark details over the fills).
class GdBorderPaths {
  GdBorderPaths._(this.rules, this.strands, this.fills, this.cores);
  final Path rules, strands, fills, cores;
}

/// Cached border paths (<= 4 sizes).
@visibleForTesting
final gdBorderCache = BoundedCache<Size, GdBorderPaths>();

/// The ornate border for a poster of [size] (cached per size).
GdBorderPaths gdBorderPaths(Size size) =>
    gdBorderCache.get(size, () => _buildBorder(size));

GdBorderPaths _buildBorder(Size size) {
  final rules = Path(), strands = Path(), fills = Path(), cores = Path();
  final w = size.width, h = size.height;
  if (w < 4 * _corner || h < 4 * _corner) {
    return GdBorderPaths._(rules, strands, fills, cores);
  }
  // Double rules outside and inside the strand band.
  for (final i in [3.0, 6.0, _bandInner + 1, _bandInner + 4]) {
    rules.addRect(Rect.fromLTRB(i, i, w - i, h - i));
  }
  const mid = (_bandOuter + _bandInner) / 2;
  // Across offset (from the band centre towards the field) of the inner
  // rule, where the lace scallops start.
  const lace = _bandInner + 4 - mid;

  // One straight run of the vine between two corner blocks. [at] maps
  // (distance along the run, offset across the band towards the field) to a
  // poster point.
  void run(double length, Offset Function(double s, double n) at) {
    final n = math.max(1, (length / _vinePeriod).round());
    final p = length / n;
    const step = 3.0;
    final count = (length / step).ceil();
    for (final sign in [1.0, -1.0]) {
      for (var k = 0; k <= count; k++) {
        final s = math.min(length, k * step);
        final o = at(s, sign * _vineAmp * math.sin(2 * math.pi * s / p));
        k == 0 ? strands.moveTo(o.dx, o.dy) : strands.lineTo(o.dx, o.dy);
      }
    }
    // Flowers in the eyes (alternating four-petal flowers and buds) and the
    // lace edge: a shallow scallop per half period on the field side.
    for (var e = 0; e < 2 * n; e++) {
      final c = at((e + 0.5) * p / 2, 0);
      if (e.isEven) {
        fills
          ..addOval(Rect.fromCenter(center: c, width: 8, height: 3.2))
          ..addOval(Rect.fromCenter(center: c, width: 3.2, height: 8));
        cores.addOval(Rect.fromCircle(center: c, radius: 1.2));
      } else {
        fills.addOval(Rect.fromCircle(center: c, radius: 2));
      }
      // A small lozenge knot where the strands cross.
      if (e > 0) {
        final k = at(e * p / 2, 0);
        fills.addPath(_lozenge(k, 2.8, 2.8), Offset.zero);
      }
    }
    for (var e = 0; e < 2 * n; e++) {
      final a = at(e * p / 2, lace);
      final b = at((e + 1) * p / 2, lace);
      final c = at((e + 0.5) * p / 2, lace + 2 * _laceBulge);
      rules
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    }
  }

  final hl = w - 2 * _corner, vl = h - 2 * _corner;
  // Top (left → right), bottom, right (top → bottom), left.
  run(hl, (s, n) => Offset(_corner + s, mid + n));
  run(hl, (s, n) => Offset(_corner + s, h - mid - n));
  run(vl, (s, n) => Offset(w - mid - n, _corner + s));
  run(vl, (s, n) => Offset(mid + n, _corner + s));

  // Corner blocks: ring, eight-point star, centre boss; and a small leaf
  // flourish with two curls pointing diagonally into the field.
  for (final c in [
    const Offset(mid, mid),
    Offset(w - mid, mid),
    Offset(mid, h - mid),
    Offset(w - mid, h - mid),
  ]) {
    rules
      ..addOval(Rect.fromCircle(center: c, radius: 21 * _ck))
      ..addOval(Rect.fromCircle(center: c, radius: 25 * _ck));
    fills.addPath(_star8(c, 18 * _ck, 8.5 * _ck), Offset.zero);
    cores.addPath(_star8(c, 10 * _ck, 5 * _ck), Offset.zero);
    fills.addOval(Rect.fromCircle(center: c, radius: 3.4 * _ck));
    final dx = c.dx < w / 2 ? 1.0 : -1.0, dy = c.dy < h / 2 ? 1.0 : -1.0;
    Offset q(double a, double b) => Offset(
      c.dx + dx * (_corner - mid + a * _ck),
      c.dy + dy * (_corner - mid + b * _ck),
    );
    // Leaf along the diagonal.
    fills
      ..moveTo(q(2, 2).dx, q(2, 2).dy)
      ..quadraticBezierTo(q(16, 4).dx, q(16, 4).dy, q(22, 22).dx, q(22, 22).dy)
      ..quadraticBezierTo(q(4, 16).dx, q(4, 16).dy, q(2, 2).dx, q(2, 2).dy)
      ..close();
    // Curls along both edges.
    for (final flip in [false, true]) {
      Offset f(double a, double b) => flip ? q(b, a) : q(a, b);
      rules
        ..moveTo(f(6, 1).dx, f(6, 1).dy)
        ..cubicTo(
          f(14, 1).dx,
          f(14, 1).dy,
          f(24, 3).dx,
          f(24, 3).dy,
          f(26, 9).dx,
          f(26, 9).dy,
        )
        ..cubicTo(
          f(27, 13).dx,
          f(27, 13).dy,
          f(22, 14).dx,
          f(22, 14).dy,
          f(21, 10).dx,
          f(21, 10).dy,
        );
      fills.addOval(Rect.fromCircle(center: f(21, 10), radius: 1.6));
    }
  }
  return GdBorderPaths._(rules, strands, fills, cores);
}

/// An eight-point star centred on [c] (outer radius [ro], inner [ri]).
Path _star8(Offset c, double ro, double ri) {
  final p = Path();
  for (var i = 0; i < 16; i++) {
    final a = -math.pi / 2 + i * math.pi / 8;
    final r = i.isEven ? ro : ri;
    final o = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// A lozenge (diamond) centred on [c].
Path _lozenge(Offset c, double hw, double hh) => Path()
  ..moveTo(c.dx, c.dy - hh)
  ..lineTo(c.dx + hw, c.dy)
  ..lineTo(c.dx, c.dy + hh)
  ..lineTo(c.dx - hw, c.dy)
  ..close();

// ---------------------------------------------------------------------------
// Arabesque: an ogee lattice of interlaced scrolling vines (double ribbons
// with fine echo lines), palmettes in the lens cells, four-petal rosettes in
// the diamond cells, rings at the crossings and lozenges where the vines
// touch. Built once per size (bounded cache) over the band from the page top
// to [gdArabesqueBottom]; the painter clips it to the field outside the arch
// and fades it with distance from the top.
// ---------------------------------------------------------------------------

/// The arabesque paths: [ribbons] (vines, stroked as a gold band with a dark
/// core), [fine] (thin echo lines and rings), [leaves] (palmettes, rosettes,
/// lozenges, filled gold) and [cores] (dark details over the leaves).
class GdArabesquePaths {
  GdArabesquePaths._(this.ribbons, this.fine, this.leaves, this.cores);
  final Path ribbons, fine, leaves, cores;
}

/// Cached arabesque paths (<= 4 sizes).
@visibleForTesting
final gdArabesqueCache = BoundedCache<Size, GdArabesquePaths>();

/// The arabesque for a poster of [size] (cached per size, deterministic).
GdArabesquePaths gdArabesquePaths(Size size) =>
    gdArabesqueCache.get(size, () => _buildArabesque(size));

GdArabesquePaths _buildArabesque(Size size) {
  final ribbons = Path(), fine = Path(), leaves = Path(), cores = Path();
  final w = size.width;
  final bottom = math.min(size.height, gdArabesqueBottom);
  if (w < 4 * _corner || bottom < 4 * _corner) {
    return GdArabesquePaths._(ribbons, fine, leaves, cores);
  }
  const hw = _arabW / 2, p = _arabP;
  final cx = w / 2;
  final kMax = (w / 2 / _arabW).ceil() + 1;
  final jMax = (bottom / (p / 2)).ceil() + 1;
  const step = 3.0;
  final count = (bottom / step).ceil() + 1;
  // Vine families: x = x_k ± a·sin(2πy/P). The ±hw families cross at
  // y = jP/2 and touch their neighbours, forming the ogee lattice; the
  // ±0.55·hw families are the fine echo lines inside each lens.
  for (var k = -kMax; k <= kMax; k++) {
    final xk = cx + k * _arabW;
    for (final (amp, path) in [
      (hw, ribbons),
      (-hw, ribbons),
      (hw * 0.55, fine),
      (-hw * 0.55, fine),
    ]) {
      for (var i = 0; i <= count; i++) {
        final y = math.min(bottom, i * step);
        final x = xk + amp * math.sin(2 * math.pi * y / p);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
    }
    for (var j = 0; j <= jMax; j++) {
      // Crossing ring and the palmette of the lens below it.
      final cross = Offset(xk, j * p / 2);
      fine.addOval(Rect.fromCircle(center: cross, radius: 4.2));
      leaves.addOval(Rect.fromCircle(center: cross, radius: 1.6));
      final lens = Offset(xk, j * p / 2 + p / 4);
      _palmette(leaves, cores, lens, up: j.isEven);
      _tendrils(fine, leaves, lens, up: j.isEven);
      // Diamond cell beside the crossing: a four-petal rosette with curls.
      final dia = Offset(xk + hw, j * p / 2);
      leaves
        ..addOval(Rect.fromCenter(center: dia, width: 15, height: 5))
        ..addOval(Rect.fromCenter(center: dia, width: 5, height: 15));
      cores.addOval(Rect.fromCircle(center: dia, radius: 1.5));
      for (final sx in [-1.0, 1.0]) {
        fine
          ..moveTo(dia.dx + sx * 3, dia.dy - 9)
          ..quadraticBezierTo(
            dia.dx + sx * 13,
            dia.dy - 12,
            dia.dx + sx * 13,
            dia.dy - 4,
          )
          ..moveTo(dia.dx + sx * 3, dia.dy + 9)
          ..quadraticBezierTo(
            dia.dx + sx * 13,
            dia.dy + 12,
            dia.dx + sx * 13,
            dia.dy + 4,
          );
      }
      // Lozenge where neighbouring vines touch.
      leaves.addPath(
        _lozenge(Offset(xk + hw, j * p / 2 + p / 4), 3, 4.5),
        Offset.zero,
      );
    }
  }
  return GdArabesquePaths._(ribbons, fine, leaves, cores);
}

/// A palmette centred on [c]: a pointed central leaf with two curled side
/// lobes and a dark vein, pointing up ([up]) or down.
void _palmette(Path leaves, Path cores, Offset c, {required bool up}) {
  final d = up ? -1.0 : 1.0;
  Offset o(double x, double y) => Offset(c.dx + x, c.dy + d * y);
  final tip = o(0, 15), base = o(0, -11);
  leaves
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(o(9, -2).dx, o(9, -2).dy, tip.dx, tip.dy)
    ..quadraticBezierTo(o(-9, -2).dx, o(-9, -2).dy, base.dx, base.dy)
    ..close();
  for (final sx in [-1.0, 1.0]) {
    final a = o(sx * 2, -8), t = o(sx * 13, 1);
    leaves
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(o(sx * 12, -11).dx, o(sx * 12, -11).dy, t.dx, t.dy)
      ..quadraticBezierTo(o(sx * 6, -3).dx, o(sx * 6, -3).dy, a.dx, a.dy)
      ..close();
  }
  cores
    ..moveTo(o(-0.9, -6).dx, o(-0.9, -6).dy)
    ..lineTo(o(0, 9).dx, o(0, 9).dy)
    ..lineTo(o(0.9, -6).dx, o(0.9, -6).dy)
    ..close();
}

/// Two scrolling tendrils flanking a palmette at [c]: each leaves the side
/// lobe, sweeps outwards along the lens and ends in a small spiral curl
/// with a bud.
void _tendrils(Path fine, Path leaves, Offset c, {required bool up}) {
  final d = up ? -1.0 : 1.0;
  for (final sx in [-1.0, 1.0]) {
    Offset o(double x, double y) => Offset(c.dx + sx * x, c.dy + d * y);
    final a = o(12, -2), b = o(19, 16), k1 = o(20, 0), k2 = o(13, 13);
    final e = o(14, 19);
    fine
      ..moveTo(a.dx, a.dy)
      ..cubicTo(k1.dx, k1.dy, o(24, 10).dx, o(24, 10).dy, b.dx, b.dy)
      ..quadraticBezierTo(k2.dx, k2.dy, e.dx, e.dy);
    fine
      ..moveTo(o(10, -6).dx, o(10, -6).dy)
      ..quadraticBezierTo(
        o(18, -16).dx,
        o(18, -16).dy,
        o(24, -12).dx,
        o(24, -12).dy,
      )
      ..quadraticBezierTo(
        o(26, -7).dx,
        o(26, -7).dy,
        o(21, -8).dx,
        o(21, -8).dy,
      );
    leaves
      ..addOval(Rect.fromCircle(center: e, radius: 1.8))
      ..addOval(Rect.fromCircle(center: o(21, -8), radius: 1.5));
  }
}

/// The region the arabesque may cover: the field from its top down to
/// [gdArabesqueBottom], minus the arch (inflated so its gold outline and
/// shadow stay clear).
Path gdArabesqueRegion(KitMetrics m) {
  final field = m.sections['field']!;
  final band = Rect.fromLTRB(
    field.left,
    field.top,
    field.right,
    math.min(field.bottom, gdArabesqueBottom),
  );
  if (band.isEmpty) return Path();
  final arch = m.sections['arch']!;
  return Path.combine(
    PathOperation.difference,
    Path()..addRect(band),
    gdArchShape.pathFor(arch.inflate(6)),
  );
}

// ---------------------------------------------------------------------------
// Arch lace: a cusped (polylobed) inner line following the basket arch, and
// a straight inner line down the sides (cached per arch rect).
// ---------------------------------------------------------------------------

/// Cached arch lace paths (<= 4 arch rects).
@visibleForTesting
final gdLaceCache = BoundedCache<Rect, Path>();

/// The arch's inner lace line in coordinates local to [arch] (0,0 = arch
/// top-left).
Path gdArchLacePath(Rect arch) =>
    gdLaceCache.get(arch, () => _buildLace(arch.size));

Path _buildLace(Size s) {
  final p = Path();
  final rise = gdArchShape.archRise(s.width, s.height);
  final a = s.width / 2 - _laceInset, b = rise - _laceInset;
  if (a <= 0 || b <= 0 || s.height <= rise + _laceInset) return p;
  final c = Offset(s.width / 2, rise);
  Offset on(double th) => c + Offset(a * math.cos(th), b * math.sin(th));
  const n = _laceLobes;
  final bottom = s.height - _laceInset;
  p
    ..moveTo(_laceInset, bottom)
    ..lineTo(_laceInset, rise);
  for (var i = 0; i < n; i++) {
    final p0 = on(math.pi + i * math.pi / n);
    final p1 = on(math.pi + (i + 1) * math.pi / n);
    final chord = (p1 - p0).distance;
    // Shallow cusps bulging into the panel.
    p.arcToPoint(p1, radius: Radius.circular(chord * 0.75), clockwise: false);
  }
  p.lineTo(s.width - _laceInset, bottom);
  return p;
}

class _ArchLacePainter extends CustomPainter {
  const _ArchLacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final lace = gdArchLacePath(Offset.zero & size);
    canvas.drawPath(lace, _stroke(const Color(0xCCD4AF5E), 1.4));
  }

  @override
  bool shouldRepaint(_ArchLacePainter old) => false;
}

/// The thin gold double rule with a lozenge in the middle above the brace.
class _RulePainter extends CustomPainter {
  const _RulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40) return;
    final cy = size.height / 2, cx = size.width / 2;
    final line = _stroke(gdGold, 1.2);
    for (final dy in [-2.5, 2.5]) {
      canvas
        ..drawLine(Offset(0, cy + dy), Offset(cx - 18, cy + dy), line)
        ..drawLine(Offset(cx + 18, cy + dy), Offset(size.width, cy + dy), line);
    }
    final fill = Paint()..color = gdGold;
    canvas.drawPath(_lozenge(Offset(cx, cy), 13, 9), fill);
    canvas.drawPath(
      _lozenge(Offset(cx, cy), 5, 3.5),
      Paint()..color = gdArchTop,
    );
    for (final x in [3.0, size.width - 3]) {
      canvas.drawCircle(Offset(x, cy), 2.6, fill);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => false;
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const _archStyle = PanelStyle(
  shape: gdArchShape,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gdArchTop, gdArchBottom],
  ),
  border: BorderSide(color: gdGold, width: 2),
  shadows: [
    BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, 4)),
  ],
);

const _articleStyle = PanelStyle(
  shape: PanelShape.rounded(10),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gdNavyTop, gdNavy],
  ),
  border: BorderSide(color: gdGold, width: 1.6),
  innerBorder: BorderSide(color: Color(0x66D4AF5E), width: 1),
  innerBorderGap: 5,
  shadows: [
    BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, 4)),
  ],
  padding: EdgeInsets.fromLTRB(30, _pillHeight / 2 + 4, 30, 4),
);

const _amiri = TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700);
const _amiriBlock = TextStyle(
  fontFamily: 'Amiri',
  fontWeight: FontWeight.w700,
  height: _blockLine,
);
const _tajawal = TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700);

const _goldPill = CellBadge(
  color: gdGold,
  border: BorderSide(color: gdGoldLight, width: 1),
  padding: EdgeInsets.symmetric(horizontal: 3),
);
const _darkPill = CellBadge(
  color: gdPillDark,
  border: BorderSide(color: gdInk, width: 1),
  padding: EdgeInsets.symmetric(horizontal: 3),
);
const _pillCellPad = EdgeInsets.symmetric(horizontal: 4, vertical: 4);

/// Highlighted (gold) rows: the weekday / hijri pills turn dark with light
/// gold text so they still read as pills.
CellStyle? _gardenHook(CellRef ref) {
  final k = ref.column.kind;
  if (ref.state == RowState.highlighted &&
      (k == ColumnKind.weekday || k == ColumnKind.hijri)) {
    return const CellStyle(foreground: gdGoldLight, badge: _darkPill);
  }
  return null;
}

/// The table: weekday | hijri | gregorian | solar | 4 prayer times | notes
/// (right → left), gold header row, glass rows, gold pills for weekday and
/// hijri day, gold highlighted rows and gold month-label pills.
final TableSpec emeraldGardenTableSpec = TableSpec(
  headerHeight: 74,
  groups: const [
    [
      TableColumn.weekday(
        width: 80,
        style: CellStyle(
          foreground: gdInk,
          maxSize: 19,
          padding: _pillCellPad,
          badge: _goldPill,
        ),
        headerStyle: CellStyle(maxSize: 24),
      ),
      TableColumn.hijri(
        width: 52,
        style: CellStyle(
          foreground: gdInk,
          padding: _pillCellPad,
          badge: _goldPill,
        ),
      ),
      TableColumn.gregorian(width: 56),
      TableColumn.solar(width: 56),
      TableColumn.time(PrayerSlot.fajr, width: _timeWidth),
      TableColumn.time(PrayerSlot.shurooq, width: _timeWidth),
      TableColumn.time(PrayerSlot.zuhr, width: _timeWidth),
      TableColumn.time(PrayerSlot.maghrib, width: _timeWidth),
      TableColumn.notes(
        style: CellStyle(
          maxSize: 18,
          lineHeight: 1.12,
          wrap: true,
          padding: EdgeInsets.symmetric(horizontal: 5),
        ),
        headerStyle: CellStyle(maxSize: 30, wrap: false),
      ),
    ],
  ],
  header: const CellStyle(
    background: gdGold,
    foreground: gdInk,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w800,
    lineHeight: 1.15,
    maxSize: 19,
    wrap: true,
    padding: EdgeInsets.symmetric(horizontal: 1, vertical: 4),
  ),
  body: const CellStyle(
    foreground: gdCream,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w700,
    lineHeight: KitDefaults.tightLine,
    maxSize: 21,
  ),
  normalRow: const CellStyle(background: gdRowDark),
  altRow: const CellStyle(background: gdRowLight),
  highlightRow: const CellStyle(background: gdGold, foreground: gdInk),
  labelCell: const CellStyle(
    foreground: gdInk,
    padding: _pillCellPad,
    badge: _goldPill,
  ),
  cellHook: _gardenHook,
  grid: const GridLines(
    horizontal: BorderSide(color: Color(0x8CD4AF5E), width: 1),
    vertical: BorderSide(color: gdGoldRule, width: 1),
    headerBottom: BorderSide(color: gdGoldLight, width: 2),
  ),
  outerBorder: const BorderSide(color: gdGold, width: 1.6),
);

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

class EmeraldGardenTemplate extends PosterTemplate {
  const EmeraldGardenTemplate();

  @override
  String get id => 'emerald_garden';

  @override
  String get nameAr => 'زمردي بالأرابيسك';

  @override
  PosterTheme get theme => emeraldGardenTheme;

  @override
  List<ImageProvider> get images => const [];

  @override
  Widget build(MonthPoster p) => EmeraldGardenPage(poster: p);
}

class EmeraldGardenPage extends StatelessWidget {
  const EmeraldGardenPage({super.key, required this.poster});

  final MonthPoster poster;

  @override
  Widget build(BuildContext context) {
    final t = poster.texts;
    return PosterPage(
      color: gdEmerald,
      textStyle: const TextStyle(
        inherit: false,
        fontFamily: 'Tajawal',
        fontSize: 20,
        color: gdCream,
        decoration: TextDecoration.none,
      ),
      backgroundPainter: (size) => EmeraldGardenBackgroundPainter(
        emeraldGardenMetrics(size, poster.days.length),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final m = emeraldGardenMetrics(c.biggest, poster.days.length);
          Widget at(String id, Widget child) =>
              Positioned.fromRect(rect: m.sections[id]!, child: child);
          final hasQuotes = !_isEmpty(t.rightQuote) || !_isEmpty(t.leftQuote);
          return Stack(
            children: [
              at(
                'arch',
                const PosterPanel(key: ValueKey('gd-arch'), style: _archStyle),
              ),
              at(
                'arch',
                const CustomPaint(
                  key: ValueKey('gd-lace'),
                  painter: _ArchLacePainter(),
                ),
              ),
              if (t.braceQuote.isNotEmpty) ...[
                at('rule', const CustomPaint(painter: _RulePainter())),
                at(
                  'brace',
                  BraceQuote(
                    t.braceQuote,
                    key: const ValueKey('gd-brace'),
                    style: _amiriBlock.copyWith(
                      color: gdBraceGold,
                      shadows: const [
                        Shadow(color: Color(0x99000000), blurRadius: 4),
                      ],
                    ),
                    maxSize: 34,
                  ),
                ),
              ],
              at(
                'table',
                PosterTableView(
                  key: const ValueKey('gd-table'),
                  poster: poster,
                  spec: emeraldGardenTableSpec,
                ),
              ),
              at(
                'stripRight',
                _QaStrip(t.sideRight, key: const ValueKey('gd-strip-right')),
              ),
              at(
                'stripLeft',
                _QaStrip(t.sideLeft, key: const ValueKey('gd-strip-left')),
              ),
              at(
                'footerNote',
                FooterNote(
                  t.footerNotes,
                  style: _tajawal.copyWith(
                    color: gdCream,
                    height: KitDefaults.tightLine,
                  ),
                  maxSize: 22,
                ),
              ),
              if (hasQuotes)
                at(
                  'banner',
                  const CustomPaint(
                    key: ValueKey('gd-banner'),
                    painter: _BannerPainter(),
                  ),
                ),
              if (!_isEmpty(t.rightQuote))
                at('quoteRightText', _quote(t.rightQuote)),
              if (!_isEmpty(t.leftQuote))
                at('quoteLeftText', _quote(t.leftQuote)),
              at('medallion', _title(t.title)),
              at('article', _ArticlePanel(t.article, t.fatiha)),
              if (t.article.author.isNotEmpty)
                at('pill', _AuthorPill(t.article.author)),
            ],
          );
        },
      ),
    );
  }

  static bool _isEmpty(HeaderQuote q) =>
      q.text.isEmpty && q.attribution.isEmpty;

  Widget _quote(HeaderQuote q) => QuoteBlock(
    q,
    textStyle: _amiri.copyWith(color: gdCream, height: _quoteLine),
    attributionStyle: _amiri.copyWith(color: gdGold),
    maxSize: 30,
    attributionMaxSize: 24,
    attributionHeight: 36,
  );

  /// The double-ring medallion for the default title; any other (edited)
  /// title is set as gold text on a painted disc, so the poster always shows
  /// the real data.
  Widget _title(String title) {
    final s = title.trim();
    if (s == defaultTitle) {
      return const BrandMedallion(
        key: ValueKey('gd-title-image'),
        style: BrandMedallionStyle.emeraldDouble,
      );
    }
    return CustomPaint(
      painter: const _DiscPainter(),
      child: Padding(
        padding: const EdgeInsets.all(_medSize * 0.17),
        child: s.isEmpty
            ? const SizedBox.shrink()
            : TitleBlock.text(
                s,
                key: const ValueKey('gd-title-text'),
                style: _titleTextStyle,
                maxSize: 76,
                maxLines: 3,
              ),
      ),
    );
  }

  static const _titleTextStyle = TextStyle(
    fontFamily: 'ArefRuqaa',
    fontWeight: FontWeight.w700,
    color: gdGoldLight,
    height: 1.3,
  );
}

/// The disc behind an edited title: green disc with a gold double ring.
class _DiscPainter extends CustomPainter {
  const _DiscPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    if (r <= 16) return;
    canvas.drawCircle(c, r - 2, Paint()..color = gdDisc);
    canvas.drawCircle(c, r - 4, _stroke(gdGold, 3));
    canvas.drawCircle(c, r - 11, _stroke(gdGold, 2));
  }

  @override
  bool shouldRepaint(_DiscPainter old) => false;
}

/// Small gold pill with `:: author ::` on the article's top edge.
class _AuthorPill extends StatelessWidget {
  const _AuthorPill(this.author);
  final String author;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('gd-pill'),
    decoration: const ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: gdGoldLight, width: 1.5)),
      gradient: LinearGradient(colors: [gdGold, gdGoldLight, gdGold]),
      shadows: [
        BoxShadow(
          color: Color(0x88000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      child: FitText(
        ':: $author ::',
        style: _amiri.copyWith(color: gdInk, height: KitDefaults.tightLine),
        maxSize: 28,
        maxLines: 1,
      ),
    ),
  );
}

/// Rotated side Q&A strip (reads top → bottom) in a gold double frame:
/// gold `سؤال :` / `الجواب :` labels, cream text. Nothing when both values
/// are empty.
class _QaStrip extends StatelessWidget {
  const _QaStrip(this.qa, {super.key});
  final SideQa qa;

  static const double _labelWidth = 80;
  static const double _max = 20;

  @override
  Widget build(BuildContext context) {
    if (qa.question.isEmpty && qa.answer.isEmpty) {
      return const SizedBox.shrink();
    }
    Widget line(String label, String value) => Expanded(
      child: value.isEmpty
          ? const SizedBox.shrink()
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: FitText(
                    '$label :',
                    style: _tajawal.copyWith(
                      color: gdGold,
                      height: KitDefaults.tightLine,
                    ),
                    maxSize: _max,
                    maxLines: 1,
                    align: TextAlign.start,
                  ),
                ),
                Expanded(
                  child: FitText(
                    value,
                    style: _tajawal.copyWith(
                      color: gdCream,
                      height: KitDefaults.tightLine,
                    ),
                    maxSize: _max,
                    maxLines: 1,
                    align: TextAlign.start,
                  ),
                ),
              ],
            ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gdStripFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gdGold, width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0x99D4AF5E), width: 1),
          ),
          child: RotatedBox(
            quarterTurns: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line('سؤال', qa.question),
                  line('الجواب', qa.answer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The navy article panel with ornate gold corner brackets: braced cream
/// body and the gold fatiha line between two small ornaments.
class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel(this.article, this.fatiha);
  final ClosingArticle article;
  final String fatiha;

  @override
  Widget build(BuildContext context) {
    final body = article.body;
    return CustomPaint(
      foregroundPainter: const _BracketPainter(),
      child: PosterPanel(
        key: const ValueKey('gd-article'),
        style: _articleStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FitText(
                body.isEmpty ? '' : braced(body),
                style: _amiriBlock.copyWith(color: gdCream),
                maxSize: 30,
              ),
            ),
            if (fatiha.isNotEmpty)
              SizedBox(
                height: _fatihaHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(
                      child: CustomPaint(painter: _OrnamentPainter()),
                    ),
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FitText(
                          fatiha,
                          style: _amiri.copyWith(color: gdGold),
                          maxSize: 30,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: CustomPaint(painter: _OrnamentPainter()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ornate gold corner brackets over the article panel's corners: an L with
/// a curl at each end and a lozenge on the corner. They stay within
/// [_bracketLen] of the corners and inside the panel padding.
class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 3 * _bracketLen || size.height < 2 * _bracketLen) return;
    final line = _stroke(gdGold, 2.4)..strokeCap = StrokeCap.round;
    final fill = Paint()..color = gdGold;
    for (final (cx, sx) in [(0.0, 1.0), (size.width, -1.0)]) {
      for (final (cy, sy) in [(0.0, 1.0), (size.height, -1.0)]) {
        Offset q(double a, double b) => Offset(cx + sx * a, cy + sy * b);
        final p = Path()
          ..moveTo(q(_bracketLen, 4).dx, q(_bracketLen, 4).dy)
          ..lineTo(q(10, 4).dx, q(10, 4).dy)
          ..quadraticBezierTo(q(4, 4).dx, q(4, 4).dy, q(4, 10).dx, q(4, 10).dy)
          ..lineTo(q(4, _bracketLen).dx, q(4, _bracketLen).dy);
        // End curls.
        p
          ..moveTo(q(_bracketLen, 4).dx, q(_bracketLen, 4).dy)
          ..quadraticBezierTo(
            q(_bracketLen + 8, 4).dx,
            q(_bracketLen + 8, 4).dy,
            q(_bracketLen + 6, 11).dx,
            q(_bracketLen + 6, 11).dy,
          )
          ..moveTo(q(4, _bracketLen).dx, q(4, _bracketLen).dy)
          ..quadraticBezierTo(
            q(4, _bracketLen + 8).dx,
            q(4, _bracketLen + 8).dy,
            q(11, _bracketLen + 6).dx,
            q(11, _bracketLen + 6).dy,
          );
        // Inner parallel line.
        p
          ..moveTo(q(_bracketLen - 14, 11).dx, q(_bracketLen - 14, 11).dy)
          ..lineTo(q(11, 11).dx, q(11, 11).dy)
          ..lineTo(q(11, _bracketLen - 14).dx, q(11, _bracketLen - 14).dy);
        canvas.drawPath(p, line);
        canvas.drawPath(_lozenge(q(4, 4), 6, 6), fill);
        canvas.drawCircle(q(_bracketLen + 6, 11), 2.4, fill);
        canvas.drawCircle(q(11, _bracketLen + 6), 2.4, fill);
      }
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

/// A small gold rosette (eight-point star with a dot) between short rules.
class _OrnamentPainter extends CustomPainter {
  const _OrnamentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 30) return;
    final c = size.center(Offset.zero);
    final fill = Paint()..color = gdGold;
    final line = _stroke(gdGold, 1.3);
    canvas
      ..drawLine(Offset(4, c.dy), Offset(c.dx - 13, c.dy), line)
      ..drawLine(Offset(c.dx + 13, c.dy), Offset(size.width - 4, c.dy), line)
      ..drawPath(_star8(c, 10, 4.6), fill)
      ..drawCircle(c, 2.2, Paint()..color = gdNavy)
      ..drawCircle(Offset(4, c.dy), 2.2, fill)
      ..drawCircle(Offset(size.width - 4, c.dy), 2.2, fill);
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) => false;
}

// ---------------------------------------------------------------------------
// Background: border band, lighter emerald field, ornate border, medallion
// glow and backing disc
// ---------------------------------------------------------------------------

/// Below the content: the deep band, the lighter emerald field (radial
/// gradient), the arabesque over the top band and the spandrels, the cached
/// ornate border and the medallion glow.
class EmeraldGardenBackgroundPainter extends CustomPainter {
  EmeraldGardenBackgroundPainter(this.m);

  final KitMetrics m;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final page = Offset.zero & size;
    canvas.drawRect(page, Paint()..color = gdBand);
    final field = m.sections['field']!;
    if (!field.isEmpty) {
      canvas.drawRect(
        field,
        Paint()
          ..shader =
              RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.9,
                colors: const [gdFieldLight, gdEmerald],
              ).createShader(
                Rect.fromCenter(
                  center: field.center,
                  width: field.width * 1.4,
                  height: field.height,
                ),
              ),
      );
    }

    _paintArabesque(canvas, size);

    final b = gdBorderPaths(size);
    canvas.drawPath(b.rules, _stroke(gdGold, 1.3));
    canvas.drawPath(b.strands, _stroke(gdGold, 3));
    canvas.drawPath(b.strands, _stroke(gdBand, 1));
    canvas.drawPath(b.fills, Paint()..color = gdGold);
    canvas.drawPath(b.cores, Paint()..color = gdBand);

    // Medallion glow (a halo outside the disc) and a dark backing disc.
    final med = m.sections['medallion']!;
    final glow = Rect.fromCircle(center: med.center, radius: med.width * 0.72);
    canvas.drawCircle(
      med.center,
      glow.width / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x99D4AF5E), Color(0x44D4AF5E), Color(0x00D4AF5E)],
          stops: [0.62, 0.76, 1],
        ).createShader(glow),
    );
    canvas.drawCircle(
      med.center,
      math.max(0.0, med.width / 2 - _discInset),
      Paint()..color = gdDisc,
    );
  }

  /// The arabesque, clipped to [gdArabesqueRegion] and faded from the top
  /// (strong) towards [gdArabesqueBottom] (faint) through a dstIn mask.
  void _paintArabesque(Canvas canvas, Size size) {
    final region = gdArabesqueRegion(m);
    final bounds = region.getBounds();
    if (bounds.isEmpty) return;
    final a = gdArabesquePaths(size);
    canvas
      ..save()
      ..clipPath(region)
      ..saveLayer(bounds, Paint());
    canvas
      ..drawPath(a.fine, _stroke(gdGold, 1.15))
      ..drawPath(a.ribbons, _stroke(gdGold, 2.8))
      ..drawPath(a.ribbons, _stroke(gdBand, 0.9))
      ..drawPath(a.leaves, Paint()..color = gdGold)
      ..drawPath(a.cores, Paint()..color = gdBand)
      ..drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xCCFFFFFF),
              Color(0x73FFFFFF),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(bounds),
      )
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(EmeraldGardenBackgroundPainter old) =>
      !old.m.sameLayout(m);
}

// ---------------------------------------------------------------------------
// Theme (palette for the editor, contrast tests and fallbacks)
// ---------------------------------------------------------------------------

class _Blank extends CustomPainter {
  const _Blank();
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

CustomPainter _blank() => const _Blank();
CustomPainter _blankFrame(LayoutMetrics? _) => const _Blank();

/// Opaque equivalents of the glass rows over the arch panel (used by the
/// theme so the generic contrast loop sees the real row colours).
final Color gdRowDarkOnArch = Color.alphaBlend(gdRowDark, gdArchTop);
final Color gdRowLightOnArch = Color.alphaBlend(gdRowLight, gdArchTop);

const emeraldGardenTheme = PosterTheme(
  background: gdFieldLight,
  frameColor: gdGold,
  accent: gdGold,
  titleColor: gdGoldLight,
  bodyText: gdCream,
  tableHeaderBg: gdGold,
  tableHeaderFg: gdInk,
  rowBg: Color(0xFF0B2F23),
  rowAltBg: Color(0xFF104534),
  rowText: gdCream,
  gridLine: gdGold,
  highlightBg: gdGold,
  highlightFg: gdInk,
  labelCellBg: gdGold,
  labelCellFg: gdInk,
  quoteBoxBg: gdNavy,
  quoteBoxBorder: gdGold,
  quoteText: gdCream,
  headingFont: 'Amiri',
  bodyFont: 'Tajawal',
  tableFont: 'Tajawal',
  backgroundPainter: _blank,
  framePainter: _blankFrame,
);
