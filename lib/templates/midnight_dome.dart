// Midnight Dome (D7): a dark midnight-navy poster. A deep blue-black
// gradient field carries a very faint girih (eight-point star) lattice that
// only shows in the corners and along the top, and a soft green glow towards
// the bottom-right. At the top centre the gold calligraphic title logo glows
// softly above the small green dome of the Prophet's mosque. Two navy quote
// panels with double gold borders flank the title, tilted a few degrees
// (the left one counter-clockwise, the right one clockwise, as on the
// mock-up) over an untilted gold hairline frame, so their corners read as
// eight-point stars. Below the dome a navy-teal ribbon with a double gold
// border and gold-line tips holds the brace quote. The table is three
// frosted-glass panels (dates | prayer times | notes) with aligned rows,
// dark headers with gold text (the notes header deep green), green day pills
// (gold-ringed on highlighted days), green month-label pills and bronze
// highlighted rows. Gold-framed side Q&A strips, the cream footer note, a
// bronze article panel with a gold-on-dark author pill and the fatiha line
// between two small gold stars close the poster.
//
// Composition source: templates/Gemini_Generated_Image_sg3d2ysg3d2ysg3d.jpeg
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

/// The midnight field: top, middle and bottom of its vertical gradient.
const mdBgTop = Color(0xFF0F1D36);
const mdBgMid = Color(0xFF0A1529);
const mdBgBottom = Color(0xFF07101F);

/// Ornament gold (borders, title glow, lines) and the brighter gold used for
/// text on dark fills.
const mdGold = Color(0xFFC9A04E);
const mdGoldText = Color(0xFFE6C274);

/// Cream body text and the white of the prayer times / day numbers.
const mdCream = Color(0xFFF4EBD8);
const mdWhite = Color(0xFFFFFFFF);

/// Navy fill of the quote panels and of the side strips.
const mdPanel = Color(0xFF0F1C34);

/// The navy-teal ribbon of the brace quote (gradient ends).
const mdTealA = Color(0xFF14394A);
const mdTealB = Color(0xFF0D2737);

/// Frosted glass of the table panels (translucent, slightly lighter than the
/// field) and their light hairline border.
const mdGlassTop = Color(0xE01D2D4A);
const mdGlassBottom = Color(0xE0132038);
const mdGlassBorder = Color(0x8CB7C7DD);

/// Dark header strip of the date / time panels and the deep green header of
/// the notes panel.
const mdHeader = Color(0xFF0B1628);
const mdGreenHeader = Color(0xFF0F4732);

/// Faint white stripe of the odd rows.
const mdStripe = Color(0x0FFFFFFF);

/// Green of the day pills and month-label pills, its lighter rim, and the
/// deeper green of the gold-ringed pills on highlighted days.
const mdGreen = Color(0xFF1C6847);
const mdGreenRim = Color(0xFF2F8C63);
const mdGreenDeep = Color(0xFF134B33);

/// Brown-gold of highlighted rows (cream text).
const mdHighlight = Color(0xFF7A5424);

/// Warm dark bronze of the article panel (gradient stops) and the dark fill
/// of its author pill.
const mdBronzeA = Color(0xFF5E3D1D);
const mdBronzeB = Color(0xFF452B12);
const mdBronzeC = Color(0xFF573819);
const mdPill = Color(0xFF1E1409);

/// Lattice stroke colour and its strongest opacity (corners / top).
const mdPattern = Color(0xFF9FB6D8);
const double mdPatternMaxAlpha = 0.16;

/// Green glow colour (bottom-right) and its strongest opacity.
const mdGlowGreen = Color(0xFF1F7552);
const double mdGlowGreenAlpha = 0.30;

// ---------------------------------------------------------------------------
// Geometry (logical px on the 1000 x 2200 poster)
// ---------------------------------------------------------------------------

const double _titleW = 480, _titleTop = 22;

/// title_gold.png is 601 x 236.
const double _titleAspect = 236 / 601;

/// dome_green.png is 138 x 137: drawn at 138 px it is sharp only at x1;
/// x2/x3 exports upscale it (FilterQuality.high smooths but cannot add
/// detail), so higher-resolution masters are recommended.
const double _domeSize = 138, _domeTop = 204;
const double _quoteW = 226, _quoteH = 262, _quoteTop = 54, _quoteMargin = 22;

/// Tilt of the quote panels (radians, ~6 degrees). Flutter's positive angle
/// is clockwise: the right panel turns clockwise, the left counter-clockwise.
const double mdQuoteTilt = 6 * math.pi / 180;
const double _ribbonTop = 360, _ribbonBottom = 478, _ribbonSide = 110;
const double _ribbonTipLen = 74;
const double _stripMargin = 16, _stripW = 46;
const double _tableSide = 70, _tableTop = 498, _tableBottom = 1840;
const double _noteTop = 1848, _noteH = 42, _noteSide = 40;
const double _articleTop = 1898, _articleBottom = 2124, _articleSide = 30;
const double _fatihaTop = 2132, _fatihaBottom = 2186, _fatihaSide = 90;
const double _headerH = 86, _panelGap = 10, _panelRadius = 14;
const double _patternCell = 240;

/// Half the size of the axis-aligned box around a quote panel tilted by
/// [mdQuoteTilt].
Size get _quoteHalfBox {
  final c = math.cos(mdQuoteTilt), s = math.sin(mdQuoteTilt);
  return Size((_quoteW * c + _quoteH * s) / 2, (_quoteH * c + _quoteW * s) / 2);
}

/// Section rects plus table geometry of the poster for [size].
///
/// Named rects: `title`, `dome`, `quoteRight`, `quoteLeft` (unrotated),
/// `ribbon`, `ribbonDeco`, `table`, `stripRight`, `stripLeft`, `footerNote`,
/// `article`, `fatiha`.
KitMetrics midnightDomeMetrics(Size size, int rowCount) {
  final w = size.width;
  final cx = w / 2;
  final half = _quoteHalfBox;
  final qcy = _quoteTop + _quoteH / 2;
  final rqcx = w - _quoteMargin - half.width;
  final lqcx = _quoteMargin + half.width;
  final table = Rect.fromLTRB(
    _tableSide,
    _tableTop,
    w - _tableSide,
    _tableBottom,
  );
  final rects = <String, Rect>{
    'title': Rect.fromLTWH(
      cx - _titleW / 2,
      _titleTop,
      _titleW,
      _titleW * _titleAspect,
    ),
    'dome': Rect.fromLTWH(cx - _domeSize / 2, _domeTop, _domeSize, _domeSize),
    'quoteRight': Rect.fromCenter(
      center: Offset(rqcx, qcy),
      width: _quoteW,
      height: _quoteH,
    ),
    'quoteLeft': Rect.fromCenter(
      center: Offset(lqcx, qcy),
      width: _quoteW,
      height: _quoteH,
    ),
    'ribbon': Rect.fromLTRB(
      _ribbonSide,
      _ribbonTop,
      w - _ribbonSide,
      _ribbonBottom,
    ),
    'ribbonDeco': Rect.fromLTRB(
      _ribbonSide - _ribbonTipLen,
      _ribbonTop,
      w - _ribbonSide + _ribbonTipLen,
      _ribbonBottom,
    ),
    'table': table,
    'stripRight': Rect.fromLTRB(
      w - _stripMargin - _stripW,
      table.top,
      w - _stripMargin,
      table.bottom,
    ),
    'stripLeft': Rect.fromLTRB(
      _stripMargin,
      table.top,
      _stripMargin + _stripW,
      table.bottom,
    ),
    'footerNote': Rect.fromLTRB(
      _noteSide,
      _noteTop,
      w - _noteSide,
      _noteTop + _noteH,
    ),
    'article': Rect.fromLTRB(
      _articleSide,
      _articleTop,
      w - _articleSide,
      _articleBottom,
    ),
    'fatiha': Rect.fromLTRB(
      _fatihaSide,
      _fatihaTop,
      w - _fatihaSide,
      _fatihaBottom,
    ),
  };
  return KitMetrics(
    size: size,
    contentRect: Offset.zero & size,
    sections: rects,
    table: TableGeometry.compute(midnightDomeTableSpec, table, rowCount),
  );
}

/// The four corners of [r] rotated by [angle] about its centre (where a
/// tilted quote panel really paints).
List<Offset> mdRotatedCorners(Rect r, double angle) {
  final c = r.center, cs = math.cos(angle), sn = math.sin(angle);
  return [
    for (final p in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft])
      Offset(
        c.dx + (p.dx - c.dx) * cs - (p.dy - c.dy) * sn,
        c.dy + (p.dx - c.dx) * sn + (p.dy - c.dy) * cs,
      ),
  ];
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = true;

Path _lozenge(Offset c, double hw, double hh) => Path()
  ..moveTo(c.dx, c.dy - hh)
  ..lineTo(c.dx + hw, c.dy)
  ..lineTo(c.dx, c.dy + hh)
  ..lineTo(c.dx - hw, c.dy)
  ..close();

/// A small filled eight-point star (two squares) of outer radius [r].
Path _star(Offset c, double r) {
  final p = Path();
  for (final rot in [0.0, math.pi / 4]) {
    for (var k = 0; k < 4; k++) {
      final a = rot + k * math.pi / 2;
      final o = c + Offset(math.cos(a) * r, math.sin(a) * r);
      k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    p.close();
  }
  return p;
}

// ---------------------------------------------------------------------------
// Background: gradient field, girih lattice, glows (lattice path cached)
// ---------------------------------------------------------------------------

/// Cached lattice paths (<= 4 sizes).
@visibleForTesting
final mdLatticeCache = BoundedCache<Size, Path>();

/// The girih lattice for a poster of [size]: interlaced eight-point stars
/// with inner octagons on a [_patternCell] grid centred on the vertical
/// axis, joined by bars along the grid and the diagonals. Cached per size;
/// no randomness.
Path mdLatticePath(Size size) =>
    mdLatticeCache.get(size, () => _buildLattice(size));

Path _buildLattice(Size size) {
  final p = Path();
  if (size.width < _patternCell || size.height < _patternCell) return p;
  const s = _patternCell;
  const r = 0.42 * s, ri = 0.22 * s, d = 0.7071067811865476;
  final x0 = size.width / 2 - ((size.width / 2) / s).ceil() * s;
  final nx = (size.width / s).ceil() + 2, ny = (size.height / s).ceil() + 2;
  for (var j = -1; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final c = Offset(x0 + i * s, j * s);
      for (final rot in [0.0, math.pi / 4]) {
        for (var k = 0; k < 4; k++) {
          final a = rot + k * math.pi / 2;
          final o = c + Offset(math.cos(a) * r, math.sin(a) * r);
          k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        p.close();
      }
      for (var k = 0; k < 8; k++) {
        final a = math.pi / 8 + k * math.pi / 4;
        final o = c + Offset(math.cos(a) * ri, math.sin(a) * ri);
        k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      p
        ..moveTo(c.dx + r, c.dy)
        ..lineTo(c.dx + s - r, c.dy)
        ..moveTo(c.dx, c.dy + r)
        ..lineTo(c.dx, c.dy + s - r)
        ..moveTo(c.dx + r * d, c.dy + r * d)
        ..lineTo(c.dx + s - r * d, c.dy + s - r * d)
        ..moveTo(c.dx + r * d, c.dy - r * d)
        ..lineTo(c.dx + s - r * d, c.dy - s + r * d);
      p.addPath(
        _lozenge(c + const Offset(s / 2, s / 2), s * 0.08, s * 0.08),
        Offset.zero,
      );
    }
  }
  return p;
}

/// Below the content: the vertical midnight gradient, the faint lattice
/// (visible only in the four corners and along the top), the green glow at
/// the bottom-right, the gold glow behind the title and a faint halo behind
/// the dome.
class MidnightDomeBackgroundPainter extends CustomPainter {
  MidnightDomeBackgroundPainter(this.m);

  final KitMetrics m;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final page = Offset.zero & size;
    canvas.drawRect(
      page,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mdBgTop, mdBgMid, mdBgBottom],
          stops: [0, 0.45, 1],
        ).createShader(page),
    );
    // Green glow towards the bottom-right.
    final glowC = Offset(size.width * 0.95, size.height * 0.86);
    final glow = Rect.fromCircle(center: glowC, radius: size.width * 0.75);
    canvas.drawRect(
      page,
      Paint()
        ..shader = RadialGradient(
          colors: [
            mdGlowGreen.withValues(alpha: mdGlowGreenAlpha),
            mdGlowGreen.withValues(alpha: mdGlowGreenAlpha * 0.4),
            mdGlowGreen.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(glow),
    );

    // The lattice, faded in from the corners and the top edge.
    final lattice = mdLatticePath(size);
    final corner = size.width * 0.62;
    for (final (c, a) in [
      (Offset.zero, 1.0),
      (Offset(size.width, 0), 1.0),
      (Offset(0, size.height), 0.7),
      (Offset(size.width, size.height), 0.7),
    ]) {
      final g = Rect.fromCircle(center: c, radius: corner);
      canvas.save();
      canvas.clipRect(g);
      canvas.drawPath(
        lattice,
        _stroke(mdPattern, 1.3)
          ..shader = RadialGradient(
            colors: [
              mdPattern.withValues(alpha: mdPatternMaxAlpha * a),
              mdPattern.withValues(alpha: mdPatternMaxAlpha * a * 0.45),
              mdPattern.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(g),
      );
      canvas.restore();
    }
    final top = Rect.fromLTWH(0, 0, size.width, math.min(size.height, 420));
    canvas.save();
    canvas.clipRect(top);
    canvas.drawPath(
      lattice,
      _stroke(mdPattern, 1.3)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mdPattern.withValues(alpha: mdPatternMaxAlpha * 0.5),
            mdPattern.withValues(alpha: 0),
          ],
        ).createShader(top),
    );
    canvas.restore();

    // Gold glow behind the title, a faint pale halo behind the dome.
    final title = m.sections['title']!;
    if (!title.isEmpty) {
      final r = Rect.fromCenter(
        center: title.center,
        width: title.width * 1.1,
        height: title.height * 1.5,
      );
      canvas.drawOval(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              mdGold.withValues(alpha: 0.20),
              mdGold.withValues(alpha: 0.07),
              mdGold.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(r),
      );
    }
    final dome = m.sections['dome']!;
    if (!dome.isEmpty) {
      final r = Rect.fromCircle(center: dome.center, radius: dome.width * 0.85);
      canvas.drawOval(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF8FE0B8).withValues(alpha: 0.16),
              const Color(0xFF8FE0B8).withValues(alpha: 0),
            ],
          ).createShader(r),
      );
    }
  }

  @override
  bool shouldRepaint(MidnightDomeBackgroundPainter old) =>
      !old.m.sameLayout(m);
}

// ---------------------------------------------------------------------------
// Ornaments
// ---------------------------------------------------------------------------

/// An untilted gold hairline frame behind a tilted quote panel (the two
/// frames cross at the corners like an eight-point star, as on the mock-up).
class _StarFramePainter extends CustomPainter {
  const _StarFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 20 || size.height < 20) return;
    final r = (Offset.zero & size).deflate(6);
    canvas.drawRect(r, _stroke(mdGold.withValues(alpha: 0.75), 1.1));
    canvas.drawRect(r.deflate(4), _stroke(mdGold.withValues(alpha: 0.45), 0.7));
  }

  @override
  bool shouldRepaint(_StarFramePainter old) => false;
}

/// The ribbon's pointed gold-line ends: from each ribbon tip a gold line runs
/// outwards, with a small lozenge and a dot at its end, plus two shorter
/// hairlines above and below.
class _RibbonTipsPainter extends CustomPainter {
  const _RibbonTipsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = _ribbonTipLen;
    if (size.width < 2 * len + 40) return;
    final cy = size.height / 2;
    final gold = Paint()..color = mdGold;
    final line = _stroke(mdGold, 1.6)..strokeCap = StrokeCap.round;
    final thin = _stroke(mdGold.withValues(alpha: 0.7), 0.9)
      ..strokeCap = StrokeCap.round;
    for (final (tip, dir) in [(len, -1.0), (size.width - len, 1.0)]) {
      canvas.drawLine(
        Offset(tip, cy),
        Offset(tip + dir * (len - 18), cy),
        line,
      );
      canvas.drawPath(
        _lozenge(Offset(tip + dir * (len - 14), cy), 7, 4.5),
        gold,
      );
      canvas.drawCircle(Offset(tip + dir * (len - 3), cy), 2.4, gold);
      for (final dy in [-9.0, 9.0]) {
        canvas.drawLine(
          Offset(tip + dir * 8, cy + dy),
          Offset(tip + dir * (len - 30), cy + dy * 0.4),
          thin,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RibbonTipsPainter old) => false;
}

/// Frosted-glass highlights over the table panels: a bright hairline along
/// each panel's top edge fading towards the corners, and a faint sheen in
/// the upper part of the header strip. [geometry] is in poster coordinates,
/// [origin] is the table's top-left.
class _GlassSheenPainter extends CustomPainter {
  const _GlassSheenPainter(this.geometry, this.origin);
  final TableGeometry geometry;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in geometry.panels) {
      final r = p.shift(-origin);
      if (r.width < 3 * _panelRadius) continue;
      final y = r.top + 1.6;
      final line = Rect.fromLTRB(
        r.left + _panelRadius,
        y - 1,
        r.right - _panelRadius,
        y + 1,
      );
      canvas.drawLine(
        Offset(line.left, y),
        Offset(line.right, y),
        Paint()
          ..strokeWidth = 1.3
          ..shader = LinearGradient(
            colors: [
              mdWhite.withValues(alpha: 0),
              mdWhite.withValues(alpha: 0.55),
              mdWhite.withValues(alpha: 0),
            ],
          ).createShader(line),
      );
    }
  }

  @override
  bool shouldRepaint(_GlassSheenPainter old) =>
      old.geometry.rect != geometry.rect || old.origin != origin;
}

/// A fatiha flank: a gold line growing towards the text, ending in a small
/// eight-point star. [towardsLeft] = the line runs from the star on the right
/// to the text on the left (the right-hand flank).
class _FatihaFlankPainter extends CustomPainter {
  const _FatihaFlankPainter({required this.towardsLeft});
  final bool towardsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40) return;
    final cy = size.height / 2;
    final gold = Paint()..color = mdGold;
    final far = towardsLeft ? size.width - 14.0 : 14.0;
    final near = towardsLeft ? 6.0 : size.width - 6;
    canvas.drawPath(_star(Offset(far, cy), 9), gold);
    canvas.drawCircle(Offset(far, cy), 3, Paint()..color = mdBgBottom);
    final dir = towardsLeft ? -1.0 : 1.0;
    canvas.drawLine(
      Offset(far + dir * 14, cy),
      Offset(near, cy),
      _stroke(mdGold, 1.2)..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(_lozenge(Offset(far + dir * 26, cy), 4.5, 3), gold);
  }

  @override
  bool shouldRepaint(_FatihaFlankPainter old) => old.towardsLeft != towardsLeft;
}

// ---------------------------------------------------------------------------
// Table: three glass panels (dates | times | notes)
// ---------------------------------------------------------------------------

const _dayPill = CellBadge(
  color: mdGreen,
  border: BorderSide(color: mdGreenRim, width: 0.8),
  padding: EdgeInsets.symmetric(horizontal: 3),
);

/// The gold-ringed pill of a highlighted (important) day.
const mdImportantPill = CellBadge(
  color: mdGreenDeep,
  border: BorderSide(color: mdGoldText, width: 1.6),
  padding: EdgeInsets.symmetric(horizontal: 3),
);

const _labelPill = CellBadge(
  color: mdGreen,
  border: BorderSide(color: mdGreenRim, width: 0.8),
  padding: EdgeInsets.symmetric(horizontal: 3),
);

const _glassPanel = PanelStyle(
  shape: PanelShape.rounded(_panelRadius),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [mdGlassTop, mdGlassBottom],
  ),
  border: BorderSide(color: mdGlassBorder, width: 1.1),
  shadows: [
    // Outside the outline only: under the translucent glass a shadow would
    // darken the panel interior.
    BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 14,
      offset: Offset(0, 6),
      blurStyle: BlurStyle.outer,
    ),
  ],
);

const double _timeW = 60;
const _timeStyle = CellStyle(foreground: mdWhite, maxSize: 22);
const _timeHeader = CellStyle(maxSize: 18, wrap: false);

CellStyle? _hook(CellRef ref) =>
    ref.column.kind == ColumnKind.hijri && ref.state == RowState.highlighted
    ? const CellStyle(badge: mdImportantPill)
    : null;

/// The three glass panels, right → left: weekday | hijri | gregorian | solar,
/// the four prayer times, the notes. Rows share the height equally, so they
/// line up across the panels.
final TableSpec midnightDomeTableSpec = TableSpec(
  split: true,
  gap: _panelGap,
  headerHeight: _headerH,
  panel: _glassPanel,
  groups: const [
    [
      TableColumn.weekday(
        width: 80,
        style: CellStyle(maxSize: 20),
        headerStyle: CellStyle(maxSize: 22, wrap: false),
      ),
      TableColumn.hijri(
        width: 52,
        style: CellStyle(
          foreground: mdWhite,
          fontWeight: FontWeight.w800,
          maxSize: 20,
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          badge: _dayPill,
        ),
      ),
      TableColumn.gregorian(width: 58),
      TableColumn.solar(width: 58),
    ],
    [
      TableColumn.time(
        PrayerSlot.fajr,
        width: _timeW,
        style: _timeStyle,
        headerStyle: _timeHeader,
      ),
      TableColumn.time(
        PrayerSlot.shurooq,
        width: _timeW,
        style: _timeStyle,
        headerStyle: _timeHeader,
      ),
      TableColumn.time(
        PrayerSlot.zuhr,
        width: _timeW,
        style: _timeStyle,
        headerStyle: _timeHeader,
      ),
      TableColumn.time(
        PrayerSlot.maghrib,
        width: _timeW,
        style: _timeStyle,
        headerStyle: _timeHeader,
      ),
    ],
    [
      TableColumn.notes(
        style: CellStyle(
          maxSize: 19,
          lineHeight: 1.2,
          wrap: true,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        ),
        headerStyle: CellStyle(
          background: mdGreenHeader,
          maxSize: 32,
          wrap: false,
        ),
      ),
    ],
  ],
  header: const CellStyle(
    background: mdHeader,
    foreground: mdGoldText,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w800,
    lineHeight: 1.15,
    maxSize: 19,
    wrap: true,
    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
  ),
  body: const CellStyle(
    foreground: mdCream,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w700,
    lineHeight: KitDefaults.tightLine,
    maxSize: 21,
  ),
  altRow: const CellStyle(background: mdStripe),
  highlightRow: const CellStyle(
    background: mdHighlight,
    foreground: mdCream,
    fontWeight: FontWeight.w800,
  ),
  labelCell: const CellStyle(
    foreground: mdCream,
    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 6),
    badge: _labelPill,
  ),
  cellHook: _hook,
  grid: const GridLines(
    horizontal: BorderSide(color: Color(0x2EFFFFFF), width: 1),
    vertical: BorderSide(color: Color(0x1FFFFFFF), width: 1),
    headerBottom: BorderSide(color: Color(0xB3C9A04E), width: 1.4),
  ),
);

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const _quotePanel = PanelStyle(
  color: mdPanel,
  border: BorderSide(color: mdGold, width: 1.6),
  innerBorder: BorderSide(color: mdGold, width: 0.9),
  innerBorderGap: 4,
  shadows: [
    BoxShadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 5)),
  ],
  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
);

const _ribbonPanel = PanelStyle(
  shape: PanelShape.ribbon(depth: 34),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [mdTealA, mdTealB],
  ),
  border: BorderSide(color: mdGold, width: 1.6),
  innerBorder: BorderSide(color: mdGold, width: 0.8),
  innerBorderGap: 5,
  shadows: [
    BoxShadow(color: Color(0x4D2FA874), blurRadius: 18, offset: Offset(0, 6)),
  ],
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
);

const _articlePanel = PanelStyle(
  shape: PanelShape.rounded(24),
  gradient: LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [mdBronzeA, mdBronzeB, mdBronzeC],
    stops: [0, 0.55, 1],
  ),
  border: BorderSide(color: mdGold, width: 1.6),
  innerBorder: BorderSide(color: Color(0x8CC9A04E), width: 0.8),
  innerBorderGap: 5,
  shadows: [
    BoxShadow(color: Color(0x47D4A24C), blurRadius: 22),
    BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 4)),
  ],
  padding: EdgeInsets.fromLTRB(26, 10, 26, 12),
);

const _tajawal = TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700);
const _tajawalHeavy = TextStyle(
  fontFamily: 'Tajawal',
  fontWeight: FontWeight.w800,
);
const double _blockLine = 1.4;
const double _authorPillW = 470, _authorPillH = 48;

/// [inner] between braces that print `{` at the right end and `}` at the
/// left end IN TAJAWAL (its brace glyphs are pre-mirrored, so the kit's
/// bidi-isolated `braced()` — correct for Amiri — prints them reversed;
/// plain braces in the RTL paragraph print correctly; see the D6 report).
String mdTajawalBraced(String inner) => '{ $inner }';

/// The attribution as printed under a quote: in square brackets (plain
/// brackets, which the RTL paragraph mirrors correctly in Tajawal).
String mdAttribution(String a) => a.isEmpty ? '' : '[ $a ]';

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

const domeGreenAsset = AssetImage('assets/logos/dome_green.png');

class MidnightDomeTemplate extends PosterTemplate {
  const MidnightDomeTemplate();

  @override
  String get id => 'midnight_dome';

  @override
  String get nameAr => 'ليلي بالقبة الخضراء';

  @override
  PosterTheme get theme => midnightDomeTheme;

  @override
  List<ImageProvider> get images => const [domeGreenAsset];

  @override
  Widget build(MonthPoster p) => MidnightDomePage(poster: p);
}

class MidnightDomePage extends StatelessWidget {
  const MidnightDomePage({super.key, required this.poster});

  final MonthPoster poster;

  @override
  Widget build(BuildContext context) {
    final t = poster.texts;
    return PosterPage(
      color: mdBgMid,
      textStyle: const TextStyle(
        inherit: false,
        fontFamily: 'Tajawal',
        fontSize: 20,
        color: mdCream,
        decoration: TextDecoration.none,
      ),
      backgroundPainter: (size) => MidnightDomeBackgroundPainter(
        midnightDomeMetrics(size, poster.days.length),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final m = midnightDomeMetrics(c.biggest, poster.days.length);
          Widget at(String id, Widget child) =>
              Positioned.fromRect(rect: m.sections[id]!, child: child);
          final table = m.sections['table']!;
          return Stack(
            children: [
              if (!_isEmpty(t.rightQuote)) ...[
                at(
                  'quoteRight',
                  const CustomPaint(painter: _StarFramePainter()),
                ),
                at(
                  'quoteRight',
                  _quote(t.rightQuote, 'md-quote-right', mdQuoteTilt),
                ),
              ],
              if (!_isEmpty(t.leftQuote)) ...[
                at(
                  'quoteLeft',
                  const CustomPaint(painter: _StarFramePainter()),
                ),
                at(
                  'quoteLeft',
                  _quote(t.leftQuote, 'md-quote-left', -mdQuoteTilt),
                ),
              ],
              at('title', _title(t.title)),
              at(
                'dome',
                const Image(
                  key: ValueKey('md-dome'),
                  image: domeGreenAsset,
                  fit: BoxFit.contain,
                  filterQuality: TitleBlock.imageQuality,
                  isAntiAlias: true,
                  // The dome is decorative and may vanish (the title is
                  // vector art and always draws).
                  errorBuilder: _noImage,
                ),
              ),
              if (t.braceQuote.isNotEmpty) ...[
                at(
                  'ribbonDeco',
                  const CustomPaint(painter: _RibbonTipsPainter()),
                ),
                at(
                  'ribbon',
                  PosterPanel(
                    key: const ValueKey('md-ribbon'),
                    style: _ribbonPanel,
                    child: FitText(
                      '" ${t.braceQuote} "',
                      key: const ValueKey('md-brace'),
                      style: _tajawalHeavy.copyWith(
                        color: mdCream,
                        height: _blockLine,
                      ),
                      maxSize: 32,
                    ),
                  ),
                ),
              ],
              at(
                'table',
                PosterTableView(
                  key: const ValueKey('md-table'),
                  poster: poster,
                  spec: midnightDomeTableSpec,
                ),
              ),
              at(
                'table',
                IgnorePointer(
                  child: CustomPaint(
                    painter: _GlassSheenPainter(m.table, table.topLeft),
                  ),
                ),
              ),
              at(
                'stripRight',
                _QaStrip(t.sideRight, key: const ValueKey('md-strip-right')),
              ),
              at(
                'stripLeft',
                _QaStrip(t.sideLeft, key: const ValueKey('md-strip-left')),
              ),
              at(
                'footerNote',
                FooterNote(
                  t.footerNotes,
                  style: _tajawal.copyWith(
                    color: mdCream,
                    height: KitDefaults.tightLine,
                  ),
                  maxSize: 22,
                ),
              ),
              at('article', _ArticlePanel(t.article)),
              if (t.fatiha.isNotEmpty) at('fatiha', _Fatiha(t.fatiha)),
            ],
          );
        },
      ),
    );
  }

  static Widget _noImage(BuildContext _, Object _, StackTrace? _) =>
      const SizedBox.shrink();

  static bool _isEmpty(HeaderQuote q) =>
      q.text.isEmpty && q.attribution.isEmpty;

  /// A tilted navy quote panel: cream text, gold bracketed attribution.
  Widget _quote(HeaderQuote q, String key, double angle) => QuoteBlock(
    HeaderQuote(text: q.text, attribution: mdAttribution(q.attribution)),
    key: ValueKey(key),
    panel: _quotePanel,
    rotation: angle,
    textStyle: _tajawal.copyWith(color: mdCream, height: _blockLine),
    attributionStyle: _tajawalHeavy.copyWith(color: mdGoldText),
    maxSize: 26,
    attributionMaxSize: 21,
    attributionHeight: 34,
  );

  /// The gold calligraphic logo for the default title; any other (edited)
  /// title is set as glowing gold text, so the poster shows the real data.
  Widget _title(String title) {
    final s = title.trim();
    if (s == defaultTitle) {
      return const BrandTitle(
        key: ValueKey('md-title-image'),
        style: BrandTitleStyle.gold,
      );
    }
    if (s.isEmpty) return const SizedBox.shrink();
    return TitleBlock.text(
      s,
      key: const ValueKey('md-title-text'),
      style: _titleTextStyle,
      maxSize: 84,
      maxLines: 2,
    );
  }

  static final _titleTextStyle = TextStyle(
    fontFamily: 'ArefRuqaa',
    fontWeight: FontWeight.w700,
    color: mdGoldText,
    height: 1.3,
    shadows: [Shadow(color: mdGold.withValues(alpha: 0.6), blurRadius: 14)],
  );
}

/// Rotated side Q&A strip (reads top → bottom) in a thin navy box with a
/// double gold frame: gold `سؤال :` / `الجواب :` labels and light-gold text.
/// Nothing when both values are empty.
class _QaStrip extends StatelessWidget {
  const _QaStrip(this.qa, {super.key});
  final SideQa qa;

  static const double _labelWidth = 80;
  static const double _max = 19;

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
                    style: _tajawalHeavy.copyWith(
                      color: mdGoldText,
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
                      color: mdCream,
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
        color: mdPanel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mdGold, width: 1.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: mdGold.withValues(alpha: 0.6),
              width: 0.7,
            ),
          ),
          child: RotatedBox(
            quarterTurns: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 1),
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

/// The bronze article panel: the author in a gold-on-dark pill, then the
/// braced cream body. Nothing when the article is empty.
class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel(this.article);
  final ClosingArticle article;

  @override
  Widget build(BuildContext context) {
    final body = article.body;
    if (body.isEmpty && article.author.isEmpty) return const SizedBox.shrink();
    return PosterPanel(
      key: const ValueKey('md-article'),
      style: _articlePanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (article.author.isNotEmpty)
            Center(
              child: SizedBox(
                key: const ValueKey('md-author'),
                width: _authorPillW,
                height: _authorPillH,
                child: DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: mdPill,
                    shape: StadiumBorder(
                      side: BorderSide(color: mdGold, width: 1.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 4,
                    ),
                    child: FitText(
                      ':: ${article.author} ::',
                      style: _tajawalHeavy.copyWith(
                        color: mdGoldText,
                        height: KitDefaults.tightLine,
                      ),
                      maxSize: 28,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FitText(
                body.isEmpty ? '' : mdTajawalBraced(body),
                style: _tajawal.copyWith(color: mdCream, height: _blockLine),
                maxSize: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fatiha line in cream between two small gold star ornaments.
class _Fatiha extends StatelessWidget {
  const _Fatiha(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('md-fatiha'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Expanded(
        child: CustomPaint(painter: _FatihaFlankPainter(towardsLeft: true)),
      ),
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: FitText(
            text,
            style: _tajawal.copyWith(
              color: mdCream,
              height: KitDefaults.tightLine,
            ),
            maxSize: 26,
            maxLines: 1,
          ),
        ),
      ),
      const Expanded(
        child: CustomPaint(painter: _FatihaFlankPainter(towardsLeft: false)),
      ),
    ],
  );
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

/// The glass row colour as it renders on the field (used by the theme: the
/// rows themselves are translucent).
const mdGlassRow = Color(0xFF16233C);

const midnightDomeTheme = PosterTheme(
  background: mdBgMid,
  frameColor: mdGold,
  accent: mdGoldText,
  titleColor: mdGoldText,
  bodyText: mdCream,
  tableHeaderBg: mdHeader,
  tableHeaderFg: mdGoldText,
  rowBg: mdGlassRow,
  rowAltBg: mdGlassRow,
  rowText: mdCream,
  gridLine: mdGlassBorder,
  highlightBg: mdHighlight,
  highlightFg: mdCream,
  labelCellBg: mdGreen,
  labelCellFg: mdCream,
  quoteBoxBg: mdPanel,
  quoteBoxBorder: mdGold,
  quoteText: mdCream,
  headingFont: 'ArefRuqaa',
  bodyFont: 'Tajawal',
  tableFont: 'Tajawal',
  backgroundPainter: _blank,
  framePainter: _blankFrame,
);
