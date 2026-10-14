// Ivory Medallion (D6): a light, airy ivory poster. A very subtle procedural
// girih (eight-point star lattice) pattern in pale gold-grey covers the
// field, a little stronger in the four corners. At the top centre the raster
// ivory medallion is flanked by code-drawn gold finials; beside it two ivory
// quote panels with thin double gold borders. Below, the brace quote in bold
// navy between two large calligraphic (thick-thin) gold braces. The table is
// the high-contrast centre: navy header row with white text and gold
// separators, white / warm-grey striped rows, a muted-blue hijri day column
// with white numerals, gold month-label pills and dark gold-brown
// highlighted rows with white text. Gold-bordered ivory side Q&A strips, the
// navy footer note and a gold double-bordered article panel (gold author
// heading with dotted flanks, navy body, fatiha) close the poster.
//
// Composition source: templates/Gemini_Generated_Image_rs2fnprs2fnprs2f.jpeg
// (look only; every text comes from the MonthPoster).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/models.dart';
import '../domain/time_format.dart';
import 'kit/kit.dart';
import 'poster_template.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Warm ivory field and the (lighter) ivory of the panels.
const ivBg = Color(0xFFF8F5EC);
const ivPanel = Color(0xFFFFFDF7);

/// Dark navy text and the navy of the table header.
const ivNavy = Color(0xFF1B2A4A);
const ivHeader = Color(0xFF16264A);

/// Ornament gold (borders, braces, finials, pills) and the darker gold used
/// for text on ivory (attributions, labels, author heading).
const ivGold = Color(0xFFC9A24E);
const ivGoldText = Color(0xFF85601E);

/// Muted blue of the hijri day column (white numerals).
const ivBlue = Color(0xFF2F5D7A);

/// Gold-brown of highlighted rows, dark enough for white text (>= 4.5:1).
const ivHighlight = Color(0xFF8A6524);
const ivWhite = Color(0xFFFFFFFF);

/// Striped rows: near-white and a warm light grey; thin grey grid lines.
const ivRow = Color(0xFFFFFEFA);
const ivRowAlt = Color(0xFFECE9E2);
const ivGrid = Color(0xFFC9C4B8);

/// Pale gold-grey of the background lattice and its strongest opacity (in
/// the corners); the base opacity elsewhere.
const ivPattern = Color(0xFFCDBF9F);
const double ivPatternBaseAlpha = 0.30;
const double ivPatternMaxAlpha = 0.6;

/// The darkest colour the lattice ever reaches on the field (text on the
/// field is checked against it).
final Color ivPatternDarkest = Color.alphaBlend(
  ivPattern.withValues(alpha: ivPatternMaxAlpha),
  ivBg,
);

// ---------------------------------------------------------------------------
// Geometry (logical px on the 1000 x 2200 poster)
// ---------------------------------------------------------------------------

const double _margin = 24;
const double _medSize = 330, _medTop = 24;
const double _finialLen = 54, _finialHalf = 30, _finialOverlap = 6;
const double _quoteTop = 70, _quoteBottom = 318, _quoteGap = 4;
const double _braceTop = 378, _braceBottom = 506;
const double _braceW = 46, _braceTextHalf = 350, _braceGap = 8;
const double _tableSide = 88, _tableTop = 524, _tableBottom = 1840;
const double _stripWidth = 52;
const double _noteTop = 1848, _noteHeight = 40, _noteSide = 40;
const double _articleTop = 1898, _articleBottom = 20;
const double _headingHeight = 46, _fatihaHeight = 40;
const double _timeWidth = 64;
const double _patternCell = 150;
const double _cornerGlow = 420;

/// Section rects plus table geometry of the poster for [size].
///
/// Named rects: `medallion`, `finialRight`, `finialLeft`, `quoteRight`,
/// `quoteLeft`, `brace`, `braceRight`, `braceLeft`, `table`, `stripRight`,
/// `stripLeft`, `footerNote`, `article`.
KitMetrics ivoryMedallionMetrics(Size size, int rowCount) {
  final w = size.width, h = size.height;
  final cx = w / 2;
  final med = Rect.fromLTWH(cx - _medSize / 2, _medTop, _medSize, _medSize);
  final cy = med.center.dy;
  final table = Rect.fromLTRB(
    _tableSide,
    _tableTop,
    w - _tableSide,
    _tableBottom,
  );
  final braceMid = (_braceTop + _braceBottom) / 2;
  const braceH = _braceBottom - _braceTop - 8;
  final rects = <String, Rect>{
    'medallion': med,
    'finialRight': Rect.fromLTRB(
      med.right - _finialOverlap,
      cy - _finialHalf,
      med.right - _finialOverlap + _finialLen,
      cy + _finialHalf,
    ),
    'finialLeft': Rect.fromLTRB(
      med.left + _finialOverlap - _finialLen,
      cy - _finialHalf,
      med.left + _finialOverlap,
      cy + _finialHalf,
    ),
    'quoteRight': Rect.fromLTRB(
      med.right - _finialOverlap + _finialLen + _quoteGap,
      _quoteTop,
      w - _margin,
      _quoteBottom,
    ),
    'quoteLeft': Rect.fromLTRB(
      _margin,
      _quoteTop,
      med.left + _finialOverlap - _finialLen - _quoteGap,
      _quoteBottom,
    ),
    'brace': Rect.fromLTRB(
      cx - _braceTextHalf,
      _braceTop,
      cx + _braceTextHalf,
      _braceBottom,
    ),
    'braceRight': Rect.fromCenter(
      center: Offset(cx + _braceTextHalf + _braceGap + _braceW / 2, braceMid),
      width: _braceW,
      height: braceH,
    ),
    'braceLeft': Rect.fromCenter(
      center: Offset(cx - _braceTextHalf - _braceGap - _braceW / 2, braceMid),
      width: _braceW,
      height: braceH,
    ),
    'table': table,
    'stripRight': Rect.fromLTRB(
      w - _margin - _stripWidth,
      table.top,
      w - _margin,
      table.bottom,
    ),
    'stripLeft': Rect.fromLTRB(
      _margin,
      table.top,
      _margin + _stripWidth,
      table.bottom,
    ),
    'footerNote': Rect.fromLTWH(
      _noteSide,
      _noteTop,
      w - 2 * _noteSide,
      _noteHeight,
    ),
    'article': Rect.fromLTRB(
      _margin,
      _articleTop,
      w - _margin,
      h - _articleBottom,
    ),
  };
  return KitMetrics(
    size: size,
    contentRect: Offset.zero & size,
    sections: rects,
    table: TableGeometry.compute(ivoryMedallionTableSpec, table, rowCount),
  );
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = true;

/// A lozenge (diamond) centred on [c].
Path _lozenge(Offset c, double hw, double hh) => Path()
  ..moveTo(c.dx, c.dy - hh)
  ..lineTo(c.dx + hw, c.dy)
  ..lineTo(c.dx, c.dy + hh)
  ..lineTo(c.dx - hw, c.dy)
  ..close();

// ---------------------------------------------------------------------------
// Girih background lattice (built once per size and cached)
// ---------------------------------------------------------------------------

/// Cached lattice paths (<= 4 sizes).
@visibleForTesting
final ivLatticeCache = BoundedCache<Size, Path>();

/// The background lattice for a poster of [size]: eight-point stars (two
/// interlaced squares with an inner octagon) on a [_patternCell] grid
/// centred on the poster's vertical axis, joined by straight bars and small
/// lozenges at the cell corners. Cached per size; no randomness.
Path ivLatticePath(Size size) =>
    ivLatticeCache.get(size, () => _buildLattice(size));

Path _buildLattice(Size size) {
  final p = Path();
  if (size.width < _patternCell || size.height < _patternCell) return p;
  const s = _patternCell;
  const r = 0.40 * s, ri = 0.19 * s, d = 0.7071067811865476;
  final x0 = size.width / 2 - ((size.width / 2) / s).ceil() * s;
  final nx = (size.width / s).ceil() + 2, ny = (size.height / s).ceil() + 2;
  for (var j = -1; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final c = Offset(x0 + i * s, j * s);
      // Two interlaced squares (an eight-point star) and an inner octagon.
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
      // Bars to the right and lower neighbours and along both diagonals.
      p
        ..moveTo(c.dx + r, c.dy)
        ..lineTo(c.dx + s - r, c.dy)
        ..moveTo(c.dx, c.dy + r)
        ..lineTo(c.dx, c.dy + s - r)
        ..moveTo(c.dx + r * d, c.dy + r * d)
        ..lineTo(c.dx + s - r * d, c.dy + s - r * d)
        ..moveTo(c.dx + r * d, c.dy - r * d)
        ..lineTo(c.dx + s - r * d, c.dy - s + r * d);
      // A small lozenge where the diagonals cross.
      p.addPath(
        _lozenge(c + const Offset(s / 2, s / 2), s * 0.09, s * 0.09),
        Offset.zero,
      );
    }
  }
  return p;
}

/// Below the content: the ivory field, the cached lattice (faint everywhere,
/// stronger towards the four corners) and the medallion's soft shadow and
/// outer hairline ring.
class IvoryMedallionBackgroundPainter extends CustomPainter {
  IvoryMedallionBackgroundPainter(this.m);

  final KitMetrics m;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = ivBg);
    final lattice = ivLatticePath(size);
    canvas.drawPath(
      lattice,
      _stroke(ivPattern.withValues(alpha: ivPatternBaseAlpha), 1.2),
    );
    const extra = ivPatternMaxAlpha - ivPatternBaseAlpha;
    for (final c in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final glow = Rect.fromCircle(center: c, radius: _cornerGlow);
      canvas.save();
      canvas.clipRect(glow);
      canvas.drawPath(
        lattice,
        _stroke(ivPattern, 1.2)
          ..shader = RadialGradient(
            colors: [
              ivPattern.withValues(alpha: extra),
              ivPattern.withValues(alpha: extra * 0.45),
              ivPattern.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(glow),
      );
      canvas.restore();
    }

    final med = m.sections['medallion']!;
    if (med.isEmpty) return;
    final r = med.width / 2;
    canvas.drawCircle(
      med.center + const Offset(0, 4),
      r - 6,
      Paint()
        ..color = const Color(0x2E5A4520)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(med.center, r - 4, Paint()..color = ivPanel);
    canvas.drawCircle(med.center, r + 1, _stroke(ivGold, 1.2));
  }

  @override
  bool shouldRepaint(IvoryMedallionBackgroundPainter old) =>
      !old.m.sameLayout(m);
}

// ---------------------------------------------------------------------------
// Finials beside the medallion
// ---------------------------------------------------------------------------

/// A gold finial pointing away from the medallion: a stem, two scrolls, an
/// elongated lozenge with an ivory core and a tip dot. [pointsRight] = the
/// right-hand finial.
class _FinialPainter extends CustomPainter {
  const _FinialPainter({required this.pointsRight});
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 30 || size.height < 30) return;
    final cy = size.height / 2;
    // q(a, b): a = distance from the medallion edge, b = offset from centre.
    Offset q(double a, double b) =>
        Offset(pointsRight ? a : size.width - a, cy + b);
    final gold = Paint()..color = ivGold;
    final line = _stroke(ivGold, 2)..strokeCap = StrokeCap.round;
    canvas.drawLine(q(0, 0), q(size.width - 6, 0), line);
    for (final sy in [-1.0, 1.0]) {
      final scroll = Path()
        ..moveTo(q(4, 0).dx, q(4, 0).dy)
        ..cubicTo(
          q(10, sy * 2).dx,
          q(10, sy * 2).dy,
          q(10, sy * 20).dx,
          q(10, sy * 20).dy,
          q(20, sy * 22).dx,
          q(20, sy * 22).dy,
        )
        ..cubicTo(
          q(27, sy * 23).dx,
          q(27, sy * 23).dy,
          q(29, sy * 15).dx,
          q(29, sy * 15).dy,
          q(23, sy * 14).dx,
          q(23, sy * 14).dy,
        );
      canvas.drawPath(scroll, _stroke(ivGold, 1.8)..strokeCap = StrokeCap.round);
      canvas.drawCircle(q(23, sy * 14), 2.2, gold);
      canvas.drawPath(_lozenge(q(10, sy * 9), 2.6, 2.6), gold);
    }
    final lz = q(size.width - 20, 0);
    canvas.drawPath(_lozenge(lz, 13, 7.5), gold);
    canvas.drawPath(_lozenge(lz, 6, 3), Paint()..color = ivPanel);
    canvas.drawCircle(q(size.width - 3, 0), 3, gold);
  }

  @override
  bool shouldRepaint(_FinialPainter old) => old.pointsRight != pointsRight;
}

// ---------------------------------------------------------------------------
// Calligraphic gold braces (thick-thin filled outline, cached per size)
// ---------------------------------------------------------------------------

/// Cached brace paths (<= 4 (size, side) entries).
@visibleForTesting
final ivBraceCache = BoundedCache<(Size, bool), Path>();

/// The filled outline of an ornamental brace in a box of [size]. The left
/// brace (`{`, [opensRight] true) points outwards to the left; the right one
/// is its mirror image. Strokes swell in the middle of each arm and taper to
/// hairlines at the ends and at the tip. Cached per (size, side).
Path ivBracePath(Size size, {required bool opensRight}) =>
    ivBraceCache.get((size, opensRight), () {
      final p = _buildBrace(size);
      if (opensRight) return p;
      final m = Float64List.fromList([
        -1, 0, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        size.width, 0, 0, 1, //
      ]);
      return p.transform(m);
    });

Path _buildBrace(Size size) {
  const inset = 4.0, thin = 1.1, thick = 6.4;
  final w = size.width - 2 * inset, h = size.height - 2 * inset;
  final out = Path();
  if (w < 10 || h < 30) return out;
  Offset o(double fx, double fy) => Offset(inset + w * fx, inset + h * fy);
  final c = Path()
    ..moveTo(o(1, 0).dx, o(1, 0).dy)
    ..cubicTo(o(.5, 0).dx, o(.5, 0).dy, o(.52, .06).dx, o(.52, .06).dy,
        o(.52, .18).dx, o(.52, .18).dy)
    ..lineTo(o(.52, .36).dx, o(.52, .36).dy)
    ..cubicTo(o(.52, .46).dx, o(.52, .46).dy, o(.26, .5).dx, o(.26, .5).dy,
        o(0.02, .5).dx, o(0.02, .5).dy)
    ..cubicTo(o(.26, .5).dx, o(.26, .5).dy, o(.52, .54).dx, o(.52, .54).dy,
        o(.52, .64).dx, o(.52, .64).dy)
    ..lineTo(o(.52, .82).dx, o(.52, .82).dy)
    ..cubicTo(o(.52, .94).dx, o(.52, .94).dy, o(.5, 1).dx, o(.5, 1).dy,
        o(1, 1).dx, o(1, 1).dy);
  final metric = c.computeMetrics().first;
  final len = metric.length;
  final left = <Offset>[], right = <Offset>[];
  const step = 1.5;
  for (var s = 0.0; s <= len + 0.01; s += step) {
    final t = metric.getTangentForOffset(math.min(s, len))!;
    final u = s / len;
    final hw =
        (thin + (thick - thin) * math.pow(math.sin(2 * math.pi * u).abs(), 0.9)) /
        2;
    final n = Offset(-t.vector.dy, t.vector.dx);
    left.add(t.position + n * hw);
    right.add(t.position - n * hw);
  }
  out.moveTo(left.first.dx, left.first.dy);
  for (final pt in left.skip(1)) {
    out.lineTo(pt.dx, pt.dy);
  }
  for (final pt in right.reversed) {
    out.lineTo(pt.dx, pt.dy);
  }
  out.close();
  // Ball terminals and a lozenge on the tip.
  out
    ..addOval(Rect.fromCircle(center: o(1, 0) + const Offset(-1, 0), radius: 3))
    ..addOval(Rect.fromCircle(center: o(1, 1) + const Offset(-1, 0), radius: 3))
    ..addPath(_lozenge(o(0.02, .5) + const Offset(1, 0), 4, 5), Offset.zero);
  return out;
}

class _BracePainter extends CustomPainter {
  const _BracePainter({required this.opensRight});
  final bool opensRight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPath(
      ivBracePath(size, opensRight: opensRight),
      Paint()..color = ivGold,
    );
  }

  @override
  bool shouldRepaint(_BracePainter old) => old.opensRight != opensRight;
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

const _goldPill = CellBadge(
  color: ivGold,
  border: BorderSide(color: ivGoldText, width: 0.8),
  padding: EdgeInsets.symmetric(horizontal: 3),
);

/// The table: weekday | hijri | gregorian | solar | 4 prayer times | notes
/// (right → left), navy header, white / grey striped rows, blue hijri day
/// column, gold-brown highlighted rows and gold month-label pills.
final TableSpec ivoryMedallionTableSpec = TableSpec(
  headerHeight: 84,
  groups: const [
    [
      TableColumn.weekday(
        width: 86,
        style: CellStyle(maxSize: 21),
        headerStyle: CellStyle(maxSize: 24),
      ),
      TableColumn.hijri(
        width: 58,
        style: CellStyle(
          background: ivBlue,
          foreground: ivWhite,
          fontWeight: FontWeight.w800,
          maxSize: 23,
        ),
      ),
      TableColumn.gregorian(width: 62),
      TableColumn.solar(width: 62),
      TableColumn.time(PrayerSlot.fajr, width: _timeWidth),
      TableColumn.time(PrayerSlot.shurooq, width: _timeWidth),
      TableColumn.time(PrayerSlot.zuhr, width: _timeWidth),
      TableColumn.time(PrayerSlot.maghrib, width: _timeWidth),
      TableColumn.notes(
        style: CellStyle(
          maxSize: 19,
          lineHeight: 1.2,
          wrap: true,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        ),
        headerStyle: CellStyle(maxSize: 32, wrap: false),
      ),
    ],
  ],
  header: const CellStyle(
    background: ivHeader,
    foreground: ivWhite,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w800,
    lineHeight: 1.15,
    maxSize: 20,
    wrap: true,
    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
  ),
  body: const CellStyle(
    foreground: ivNavy,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w700,
    lineHeight: KitDefaults.tightLine,
    maxSize: 22,
  ),
  normalRow: const CellStyle(background: ivRow),
  altRow: const CellStyle(background: ivRowAlt),
  highlightRow: const CellStyle(
    background: ivHighlight,
    foreground: ivWhite,
    fontWeight: FontWeight.w800,
  ),
  labelCell: const CellStyle(
    foreground: ivNavy,
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    badge: _goldPill,
  ),
  grid: const GridLines(
    horizontal: BorderSide(color: ivGrid, width: 1),
    vertical: BorderSide(color: ivGrid, width: 1),
    headerBottom: BorderSide(color: ivGold, width: 2),
  ),
  outerBorder: const BorderSide(color: ivNavy, width: 1.4),
);

/// Gold separators between the header cells (over the kit's grey grid);
/// [geometry] is the table geometry in poster coordinates, [origin] the
/// table's top-left.
class _HeaderSeparatorPainter extends CustomPainter {
  const _HeaderSeparatorPainter(this.geometry, this.origin);
  final TableGeometry geometry;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = geometry.columns;
    if (cols.length < 2) return;
    final top = geometry.rect.top - origin.dy + 10;
    final bottom = geometry.headerBottom - origin.dy - 10;
    if (bottom <= top) return;
    final p = Paint()
      ..color = ivGold
      ..strokeWidth = 1.2;
    for (var i = 0; i < cols.length - 1; i++) {
      final x = cols[i].left - origin.dx + 0.5;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), p);
    }
  }

  @override
  bool shouldRepaint(_HeaderSeparatorPainter old) =>
      old.geometry.rect != geometry.rect || old.origin != origin;
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const _panelShadow = [
  BoxShadow(color: Color(0x1F5A4520), blurRadius: 8, offset: Offset(0, 3)),
];

const _quoteStyle = PanelStyle(
  color: ivPanel,
  border: BorderSide(color: ivGold, width: 1.5),
  innerBorder: BorderSide(color: ivGold, width: 0.9),
  innerBorderGap: 4,
  shadows: _panelShadow,
  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
);

const _articleStyle = PanelStyle(
  color: ivPanel,
  border: BorderSide(color: ivGold, width: 1.8),
  innerBorder: BorderSide(color: ivGold, width: 1),
  innerBorderGap: 5,
  shadows: _panelShadow,
  padding: EdgeInsets.fromLTRB(30, 10, 30, 8),
);

const _tajawal = TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700);
const _tajawalHeavy = TextStyle(
  fontFamily: 'Tajawal',
  fontWeight: FontWeight.w800,
);
const double _blockLine = 1.4;

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

const medallionIvoryAsset = AssetImage('assets/logos/medallion_ivory.png');

class IvoryMedallionTemplate extends PosterTemplate {
  const IvoryMedallionTemplate();

  @override
  String get id => 'ivory_medallion';

  @override
  String get nameAr => 'عاجي بالميدالية';

  @override
  PosterTheme get theme => ivoryMedallionTheme;

  @override
  List<ImageProvider> get images => const [medallionIvoryAsset];

  @override
  Widget build(MonthPoster p) => IvoryMedallionPage(poster: p);
}

class IvoryMedallionPage extends StatelessWidget {
  const IvoryMedallionPage({super.key, required this.poster});

  final MonthPoster poster;

  @override
  Widget build(BuildContext context) {
    final t = poster.texts;
    return PosterPage(
      color: ivBg,
      textStyle: const TextStyle(
        inherit: false,
        fontFamily: 'Tajawal',
        fontSize: 20,
        color: ivNavy,
        decoration: TextDecoration.none,
      ),
      backgroundPainter: (size) => IvoryMedallionBackgroundPainter(
        ivoryMedallionMetrics(size, poster.days.length),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final m = ivoryMedallionMetrics(c.biggest, poster.days.length);
          Widget at(String id, Widget child) =>
              Positioned.fromRect(rect: m.sections[id]!, child: child);
          final table = m.sections['table']!;
          return Stack(
            children: [
              if (!_isEmpty(t.rightQuote))
                at('quoteRight', _quote(t.rightQuote, 'iv-quote-right')),
              if (!_isEmpty(t.leftQuote))
                at('quoteLeft', _quote(t.leftQuote, 'iv-quote-left')),
              at('medallion', _title(t.title)),
              at(
                'finialRight',
                const CustomPaint(painter: _FinialPainter(pointsRight: true)),
              ),
              at(
                'finialLeft',
                const CustomPaint(painter: _FinialPainter(pointsRight: false)),
              ),
              if (t.braceQuote.isNotEmpty) ...[
                at(
                  'braceLeft',
                  const CustomPaint(
                    key: ValueKey('iv-brace-left'),
                    painter: _BracePainter(opensRight: true),
                  ),
                ),
                at(
                  'braceRight',
                  const CustomPaint(
                    key: ValueKey('iv-brace-right'),
                    painter: _BracePainter(opensRight: false),
                  ),
                ),
                at(
                  'brace',
                  FitText(
                    t.braceQuote,
                    key: const ValueKey('iv-brace'),
                    style: _tajawalHeavy.copyWith(
                      color: ivNavy,
                      height: _blockLine,
                    ),
                    maxSize: 36,
                  ),
                ),
              ],
              at(
                'table',
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: ivRow,
                    boxShadow: _panelShadow,
                  ),
                ),
              ),
              at(
                'table',
                PosterTableView(
                  key: const ValueKey('iv-table'),
                  poster: poster,
                  spec: ivoryMedallionTableSpec,
                ),
              ),
              at(
                'table',
                IgnorePointer(
                  child: CustomPaint(
                    painter: _HeaderSeparatorPainter(m.table, table.topLeft),
                  ),
                ),
              ),
              at(
                'stripRight',
                _QaStrip(t.sideRight, key: const ValueKey('iv-strip-right')),
              ),
              at(
                'stripLeft',
                _QaStrip(t.sideLeft, key: const ValueKey('iv-strip-left')),
              ),
              at(
                'footerNote',
                FooterNote(
                  t.footerNotes,
                  style: _tajawal.copyWith(
                    color: ivNavy,
                    height: KitDefaults.tightLine,
                  ),
                  maxSize: 22,
                ),
              ),
              at('article', _ArticlePanel(t.article, t.fatiha)),
            ],
          );
        },
      ),
    );
  }

  static bool _isEmpty(HeaderQuote q) =>
      q.text.isEmpty && q.attribution.isEmpty;

  /// An ivory quote panel; the attribution is set between dashes, as on the
  /// mock-up.
  Widget _quote(HeaderQuote q, String key) => QuoteBlock(
    HeaderQuote(
      text: q.text,
      attribution: q.attribution.isEmpty ? '' : '- ${q.attribution} -',
    ),
    key: ValueKey(key),
    panel: _quoteStyle,
    textStyle: _tajawal.copyWith(color: ivNavy, height: _blockLine),
    attributionStyle: _tajawal.copyWith(color: ivGoldText),
    maxSize: 28,
    attributionMaxSize: 22,
    attributionHeight: 36,
  );

  /// The ivory medallion for the default title; any other (edited) title is
  /// set as navy text on a painted ivory disc, so the poster always shows the
  /// real data.
  Widget _title(String title) {
    final s = title.trim();
    if (s == defaultTitle) {
      return const TitleBlock.image(
        medallionIvoryAsset,
        key: ValueKey('iv-title-image'),
        fallbackText: defaultTitle,
        style: _titleTextStyle,
        maxSize: 76,
        maxLines: 3,
        fallbackPadding: EdgeInsets.all(_medSize * 0.17),
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
                key: const ValueKey('iv-title-text'),
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
    color: ivNavy,
    height: 1.3,
  );
}

/// The disc behind an edited title: ivory disc with a gold double ring.
class _DiscPainter extends CustomPainter {
  const _DiscPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    if (r <= 16) return;
    canvas.drawCircle(c, r - 4, _stroke(ivGold, 3));
    canvas.drawCircle(c, r - 11, _stroke(ivGold, 1.4));
  }

  @override
  bool shouldRepaint(_DiscPainter old) => false;
}

/// Rotated side Q&A strip (reads top → bottom) in an ivory box with a gold
/// double border: dark-gold `سؤال :` / `الجواب :` labels, navy text. Nothing
/// when both values are empty.
class _QaStrip extends StatelessWidget {
  const _QaStrip(this.qa, {super.key});
  final SideQa qa;

  static const double _labelWidth = 84;
  static const double _max = 21;

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
                      color: ivGoldText,
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
                      color: ivNavy,
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
        color: ivPanel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ivGold, width: 1.5),
        boxShadow: _panelShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ivGold, width: 0.8),
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

/// The article panel: gold `:: author ::` heading between dotted gold
/// flanks, braced navy body and the navy fatiha line between two small gold
/// lozenge ornaments.
class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel(this.article, this.fatiha);
  final ClosingArticle article;
  final String fatiha;

  @override
  Widget build(BuildContext context) {
    final body = article.body;
    return PosterPanel(
      key: const ValueKey('iv-article'),
      style: _articleStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (article.author.isNotEmpty)
            SizedBox(
              key: const ValueKey('iv-author'),
              height: _headingHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: CustomPaint(painter: _DotsPainter())),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FitText(
                        ':: ${article.author} ::',
                        style: _tajawalHeavy.copyWith(
                          color: ivGoldText,
                          height: KitDefaults.tightLine,
                        ),
                        maxSize: 30,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const Expanded(child: CustomPaint(painter: _DotsPainter())),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: FitText(
                body.isEmpty ? '' : ivTajawalBraced(body),
                style: _tajawal.copyWith(color: ivNavy, height: _blockLine),
                maxSize: 30,
              ),
            ),
          ),
          if (fatiha.isNotEmpty)
            SizedBox(
              height: _fatihaHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: CustomPaint(painter: _DotsPainter())),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FitText(
                        fatiha,
                        style: _tajawalHeavy.copyWith(
                          color: ivNavy,
                          height: KitDefaults.tightLine,
                        ),
                        maxSize: 26,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const Expanded(child: CustomPaint(painter: _DotsPainter())),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A dotted gold flank: a row of small dots growing towards a centre lozenge.
class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40) return;
    final cy = size.height / 2, cx = size.width / 2;
    final gold = Paint()..color = ivGold;
    canvas.drawPath(_lozenge(Offset(cx, cy), 7, 5), gold);
    for (var i = 1; ; i++) {
      final dx = 8.0 + i * 9;
      if (dx > cx - 4) break;
      final r = math.max(1.0, 2.6 - i * 0.22);
      canvas
        ..drawCircle(Offset(cx - dx, cy), r, gold)
        ..drawCircle(Offset(cx + dx, cy), r, gold);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

/// [inner] between braces that print `{` at the right end and `}` at the
/// left end IN TAJAWAL. Tajawal's brace glyphs are drawn for right-to-left
/// text (pre-mirrored), so the kit's bidi-isolated [braced] (correct for
/// Amiri) comes out reversed in Tajawal; plain braces in the RTL paragraph
/// print correctly (verified by rendering both fonts).
String ivTajawalBraced(String inner) => '{ $inner }';

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

const ivoryMedallionTheme = PosterTheme(
  background: ivBg,
  frameColor: ivGold,
  accent: ivGoldText,
  titleColor: ivNavy,
  bodyText: ivNavy,
  tableHeaderBg: ivHeader,
  tableHeaderFg: ivWhite,
  rowBg: ivRow,
  rowAltBg: ivRowAlt,
  rowText: ivNavy,
  gridLine: ivGrid,
  highlightBg: ivHighlight,
  highlightFg: ivWhite,
  labelCellBg: ivGold,
  labelCellFg: ivNavy,
  quoteBoxBg: ivPanel,
  quoteBoxBorder: ivGold,
  quoteText: ivNavy,
  headingFont: 'ArefRuqaa',
  bodyFont: 'Tajawal',
  tableFont: 'Tajawal',
  backgroundPainter: _blank,
  framePainter: _blankFrame,
);
