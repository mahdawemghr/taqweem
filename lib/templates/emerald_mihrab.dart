// Emerald Mihrab (D4): a deep emerald poster whose top is covered by a gold
// girih-style arabesque lattice fading into the plain green; the circular
// calligraphic medallion at the top centre with a soft gold glow, flanked by
// two navy quote cartouches tucked behind it; the brace quote in light gold
// inside the apex of a large pointed mihrab arch that holds the gold-bordered
// table (gold header, navy / green rows, gold highlighted rows, light-gold
// hijri column, gold month-label pills); gold-framed side Q&A strips, the
// cream footer note, and a navy article panel with a gold author pill.
//
// Composition source: templates/Gemini_Generated_Image_gt9onygt9onygt9o.jpeg
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

/// Emerald field (top / lightest; every text on the field is checked
/// against it).
const emEmerald = Color(0xFF0B3D2E);

/// Emerald field, middle and bottom.
const emEmeraldMid = Color(0xFF093426);
const emEmeraldDeep = Color(0xFF06261C);

/// Mihrab arch panel fill (a slightly lighter green), top → bottom.
const emArchTop = Color(0xFF135440);
const emArchBottom = Color(0xFF0E4434);

/// Ornament gold (borders, lattice, table header, highlights, label pills).
const emGold = Color(0xFFD4AF5E);

/// Light gold (hijri column, brace quote, author pill highlight).
const emGoldLight = Color(0xFFEBD08F);

/// Navy of the quote panels and the article panel (bottom of their
/// gradient) and its lighter top.
const emNavy = Color(0xFF0E1A30);
const emNavyTop = Color(0xFF16264A);

/// Table rows: very dark navy and dark green.
const emNavyRow = Color(0xFF0C1727);
const emGreenRow = Color(0xFF0B3125);

/// Cream text on dark fills.
const emCream = Color(0xFFF7EDD3);

/// Dark navy text on gold.
const emInk = Color(0xFF0E1A2E);

/// Opaque mid gold of the vertical table rules: visible on the gold header
/// row as well as on the dark rows.
const emGoldRule = Color(0xFF9C7B3C);

/// Side-strip fill.
const emStripFill = Color(0xFF072A1F);

/// Disc of the text medallion (edited titles).
const emDisc = Color(0xFF0C3B2C);

// ---------------------------------------------------------------------------
// Geometry (logical px on the 1000 x 2200 poster); widgets and painters read
// the same rects through [emeraldMihrabMetrics].
// ---------------------------------------------------------------------------

/// Height of the band the lattice covers (it fades out towards its bottom).
const double emLatticeHeight = 660;
const double _latticeCell = 56;

const double _medSize = 330, _medTop = 28, _discInset = 6;
const double _quoteTop = 96, _quoteHeight = 208, _quoteMargin = 20;
const double _quoteTuck = 60, _quoteTextGap = 10;
const double _quoteLobe = 30, _quoteRadius = 18;
const double _quotePadTop = 16, _quotePadBottom = 12, _quotePadOuter = 12;
const double _archTop = 300, _archSide = 78, _archBottom = 1784;
const double _archRise = 262, _archRadius = 18, _archEcho = 9;
const double _braceLeft = 214, _braceTop = 410, _braceBottom = 552;
const double _tablePad = 14, _tableTopGap = 6;
const double _stripMargin = 8, _stripWidth = 54;
const double _noteTop = 1800, _noteHeight = 42;
const double _articleSide = 44, _articleTop = 1880, _articleBottom = 32;
const double _pillWidth = 440, _pillHeight = 52;
const double _fatihaHeight = 50;
const double _blockLine = 1.45;
const double _timeWidth = 62;

/// The mihrab arch outline (pointed, rounded bottom corners).
const emArchShape = PanelShape.arch(
  rise: _archRise,
  pointed: true,
  radius: _archRadius,
);

/// Section rects plus table geometry of the poster for [size].
///
/// Named rects: `medallion`, `quoteRight`, `quoteLeft` (panel outlines),
/// `quoteRightText`, `quoteLeftText` (text boxes, clear of the medallion),
/// `arch`, `brace`, `table`, `stripRight`, `stripLeft`, `footerNote`,
/// `article`, `pill`, `lattice`.
KitMetrics emeraldMihrabMetrics(Size size, int rowCount) {
  final w = size.width, h = size.height;
  final cx = w / 2;
  final med = Rect.fromLTWH(cx - _medSize / 2, _medTop, _medSize, _medSize);
  final quoteRight = Rect.fromLTRB(
    med.right - _quoteTuck,
    _quoteTop,
    w - _quoteMargin,
    _quoteTop + _quoteHeight,
  );
  final quoteLeft = Rect.fromLTRB(
    _quoteMargin,
    _quoteTop,
    med.left + _quoteTuck,
    _quoteTop + _quoteHeight,
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
    h - _articleBottom,
  );
  final rects = <String, Rect>{
    'lattice': Rect.fromLTWH(0, 0, w, math.min(emLatticeHeight, h)),
    'medallion': med,
    'quoteRight': quoteRight,
    'quoteLeft': quoteLeft,
    'quoteRightText': Rect.fromLTRB(
      med.right + _quoteTextGap,
      quoteRight.top + _quotePadTop,
      quoteRight.right - _quoteLobe - _quotePadOuter,
      quoteRight.bottom - _quotePadBottom,
    ),
    'quoteLeftText': Rect.fromLTRB(
      quoteLeft.left + _quoteLobe + _quotePadOuter,
      quoteLeft.top + _quotePadTop,
      med.left - _quoteTextGap,
      quoteLeft.bottom - _quotePadBottom,
    ),
    'arch': arch,
    'brace': Rect.fromLTRB(_braceLeft, _braceTop, w - _braceLeft, _braceBottom),
    'table': table,
    'stripRight': Rect.fromLTRB(
      w - _stripMargin - _stripWidth,
      table.top,
      w - _stripMargin,
      table.bottom,
    ),
    'stripLeft': Rect.fromLTRB(
      _stripMargin,
      table.top,
      _stripMargin + _stripWidth,
      table.bottom,
    ),
    'footerNote': Rect.fromLTWH(
      table.left,
      _noteTop,
      table.width,
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
    table: TableGeometry.compute(emeraldMihrabTableSpec, table, rowCount),
  );
}

// ---------------------------------------------------------------------------
// Quote cartouche outline: straight inner end (hidden behind the medallion),
// rounded corners and a pointed ogee lobe at the outer end.
// ---------------------------------------------------------------------------

/// The quote-panel outline for [rect]; the lobe points right when
/// [outerRight], else left. [inset] shrinks it (borders).
Path emQuotePanelPath(
  Rect rect, {
  required bool outerRight,
  double lobe = _quoteLobe,
  double radius = _quoteRadius,
  double inset = 0,
}) {
  final r = rect.deflate(inset);
  if (r.width <= 0 || r.height <= 0) return Path();
  final d = math.max(0.0, math.min(lobe - inset * 0.4, r.width / 4));
  final c = math.max(0.0, math.min(radius - inset * 0.5, r.height / 4));
  final l = r.left, t = r.top, rt = r.right, b = r.bottom;
  final cy = r.center.dy, h = r.height;
  // Built with the lobe on the right; mirrored for the left panel.
  double x(double v) => outerRight ? v : l + rt - v;
  final br = rt - d;
  return Path()
    ..moveTo(x(l), t)
    ..lineTo(x(br - c), t)
    ..quadraticBezierTo(x(br), t, x(br), t + c)
    ..cubicTo(x(br), t + h * 0.36, x(rt - d * 0.12), cy - h * 0.07, x(rt), cy)
    ..cubicTo(x(rt - d * 0.12), cy + h * 0.07, x(br), b - h * 0.36, x(br), b - c)
    ..quadraticBezierTo(x(br), b, x(br - c), b)
    ..lineTo(x(l), b)
    ..close();
}

/// Paints a quote cartouche: soft shadow, navy gradient, gold double border.
class _QuotePanelPainter extends CustomPainter {
  const _QuotePanelPainter({required this.outerRight});
  final bool outerRight;

  static const _outer = 2.6, _inner = 1.0, _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    Path path([double inset = 0]) =>
        emQuotePanelPath(rect, outerRight: outerRight, inset: inset);
    canvas.drawPath(
      path().shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x88000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      path(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [emNavyTop, emNavy],
        ).createShader(rect),
    );
    canvas.drawPath(path(_outer / 2), _stroke(emGold, _outer));
    canvas.drawPath(
      path(_outer + _gap + _inner / 2),
      _stroke(const Color(0xAAD4AF5E), _inner),
    );
  }

  @override
  bool shouldRepaint(_QuotePanelPainter old) => old.outerRight != outerRight;
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = true;

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const _archStyle = PanelStyle(
  shape: emArchShape,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [emArchTop, emArchBottom],
  ),
  border: BorderSide(color: emGold, width: 3),
  innerBorder: BorderSide(color: Color(0xAAD4AF5E), width: 1.2),
  innerBorderGap: 5,
  shadows: [
    BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 4)),
  ],
);

const _articleStyle = PanelStyle(
  shape: PanelShape.rounded(26),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [emNavyTop, emNavy],
  ),
  border: BorderSide(color: emGold, width: 2.2),
  innerBorder: BorderSide(color: Color(0x88D4AF5E), width: 1),
  innerBorderGap: 5,
  shadows: [
    BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, 4)),
  ],
  padding: EdgeInsets.fromLTRB(26, _pillHeight / 2 + 4, 26, 2),
);

const _amiri = TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700);
const _amiriBlock = TextStyle(
  fontFamily: 'Amiri',
  fontWeight: FontWeight.w700,
  height: _blockLine,
);
const _tajawal = TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700);

const _goldCell = CellStyle(background: emGold, foreground: emInk);

/// The table: weekday | hijri | gregorian | solar | 4 prayer times | notes
/// (right → left), gold header row, navy / green rows, gold highlighted
/// rows, a light-gold hijri column and gold month-label pills.
final TableSpec emeraldMihrabTableSpec = TableSpec(
  headerHeight: 82,
  groups: const [
    [
      TableColumn.weekday(
        width: 78,
        style: CellStyle(maxSize: 20),
        headerStyle: CellStyle(maxSize: 24),
      ),
      TableColumn.hijri(
        width: 52,
        style: CellStyle(background: emGoldLight, foreground: emInk),
      ),
      TableColumn.gregorian(width: 58),
      TableColumn.solar(width: 58),
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
        headerStyle: CellStyle(maxSize: 40, wrap: false),
      ),
    ],
  ],
  header: const CellStyle(
    background: emGold,
    foreground: emInk,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w800,
    lineHeight: 1.15,
    maxSize: 20,
    wrap: true,
    padding: EdgeInsets.symmetric(horizontal: 1, vertical: 4),
  ),
  body: const CellStyle(
    foreground: emCream,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w700,
    lineHeight: KitDefaults.tightLine,
    maxSize: 22,
  ),
  normalRow: const CellStyle(background: emNavyRow),
  altRow: const CellStyle(background: emGreenRow),
  highlightRow: _goldCell,
  labelCell: const CellStyle(
    foreground: emInk,
    badge: CellBadge(
      color: emGold,
      padding: EdgeInsets.symmetric(horizontal: 3),
    ),
  ),
  grid: const GridLines(
    horizontal: BorderSide(color: Color(0x73D4AF5E), width: 1),
    vertical: BorderSide(color: emGoldRule, width: 1),
    headerBottom: BorderSide(color: emGold, width: 2),
  ),
  outerBorder: const BorderSide(color: emGold, width: 2),
);

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

class EmeraldMihrabTemplate extends PosterTemplate {
  const EmeraldMihrabTemplate();

  @override
  String get id => 'emerald_mihrab';

  @override
  String get nameAr => 'زمردي بالمحراب';

  @override
  PosterTheme get theme => emeraldMihrabTheme;

  @override
  List<ImageProvider> get images => const [];

  @override
  Widget build(MonthPoster p) => EmeraldMihrabPage(poster: p);
}

class EmeraldMihrabPage extends StatelessWidget {
  const EmeraldMihrabPage({super.key, required this.poster});

  final MonthPoster poster;

  @override
  Widget build(BuildContext context) {
    final t = poster.texts;
    return PosterPage(
      color: emEmeraldMid,
      textStyle: const TextStyle(
        inherit: false,
        fontFamily: 'Tajawal',
        fontSize: 20,
        color: emCream,
        decoration: TextDecoration.none,
      ),
      backgroundPainter: (size) => EmeraldMihrabBackgroundPainter(
        emeraldMihrabMetrics(size, poster.days.length),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final m = emeraldMihrabMetrics(c.biggest, poster.days.length);
          Widget at(String id, Widget child) =>
              Positioned.fromRect(rect: m.sections[id]!, child: child);
          return Stack(
            children: [
              at(
                'arch',
                const PosterPanel(key: ValueKey('em-arch'), style: _archStyle),
              ),
              if (t.braceQuote.isNotEmpty)
                at(
                  'brace',
                  BraceQuote(
                    t.braceQuote,
                    key: const ValueKey('em-brace'),
                    style: _amiriBlock.copyWith(
                      color: emGoldLight,
                      shadows: const [
                        Shadow(color: Color(0x99000000), blurRadius: 4),
                      ],
                    ),
                    maxSize: 34,
                  ),
                ),
              at(
                'table',
                PosterTableView(
                  key: const ValueKey('em-table'),
                  poster: poster,
                  spec: emeraldMihrabTableSpec,
                ),
              ),
              at(
                'stripRight',
                _QaStrip(t.sideRight, key: const ValueKey('em-strip-right')),
              ),
              at(
                'stripLeft',
                _QaStrip(t.sideLeft, key: const ValueKey('em-strip-left')),
              ),
              at(
                'footerNote',
                FooterNote(
                  t.footerNotes,
                  style: _tajawal.copyWith(
                    color: emCream,
                    height: KitDefaults.tightLine,
                  ),
                  maxSize: 22,
                ),
              ),
              ..._quote(m, t.rightQuote, right: true),
              ..._quote(m, t.leftQuote, right: false),
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

  /// The quote cartouche and its text box; nothing for an empty quote.
  List<Widget> _quote(KitMetrics m, HeaderQuote q, {required bool right}) {
    if (q.text.isEmpty && q.attribution.isEmpty) return const [];
    final side = right ? 'Right' : 'Left';
    return [
      Positioned.fromRect(
        rect: m.sections['quote$side']!,
        child: CustomPaint(
          key: ValueKey('em-quote-${side.toLowerCase()}'),
          painter: _QuotePanelPainter(outerRight: right),
        ),
      ),
      Positioned.fromRect(
        rect: m.sections['quote${side}Text']!,
        child: QuoteBlock(
          q,
          textStyle: _amiriBlock.copyWith(color: emCream),
          attributionStyle: _amiri.copyWith(color: emGold),
          maxSize: 32,
          attributionMaxSize: 24,
          attributionHeight: 38,
        ),
      ),
    ];
  }

  /// The calligraphic medallion for the default title; any other (edited)
  /// title is set as gold text on a painted medallion disc, so the poster
  /// always shows the real data.
  Widget _title(String title) {
    final s = title.trim();
    if (s == defaultTitle) {
      return const BrandMedallion(
        key: ValueKey('em-title-image'),
        style: BrandMedallionStyle.emerald,
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
                key: const ValueKey('em-title-text'),
                style: _titleTextStyle,
                maxSize: 80,
                maxLines: 3,
              ),
      ),
    );
  }

  static const _titleTextStyle = TextStyle(
    fontFamily: 'ArefRuqaa',
    fontWeight: FontWeight.w700,
    color: emGoldLight,
    height: 1.3,
  );
}

/// The medallion disc behind an edited title: green disc, gold rings.
class _DiscPainter extends CustomPainter {
  const _DiscPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    if (r <= 8) return;
    canvas.drawCircle(c, r - 2, Paint()..color = emDisc);
    canvas.drawCircle(c, r - 5, _stroke(emGold, 6));
    canvas.drawCircle(c, r - 13, _stroke(const Color(0xAAD4AF5E), 1.2));
  }

  @override
  bool shouldRepaint(_DiscPainter old) => false;
}

/// Gold stadium pill with the `:: author ::` heading on the article's top
/// edge.
class _AuthorPill extends StatelessWidget {
  const _AuthorPill(this.author);
  final String author;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('em-pill'),
    decoration: const ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: emGoldLight, width: 1.5)),
      gradient: LinearGradient(colors: [emGold, emGoldLight, emGold]),
      shadows: [
        BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
      child: FitText(
        ':: $author ::',
        style: _amiri.copyWith(color: emInk, height: KitDefaults.tightLine),
        maxSize: 30,
        maxLines: 1,
      ),
    ),
  );
}

/// Rotated side Q&A strip (reads top → bottom) in a gold-framed dark-green
/// frame: gold `سؤال :` / `الجواب :` labels, cream text. Nothing at all when
/// both values are empty.
class _QaStrip extends StatelessWidget {
  const _QaStrip(this.qa, {super.key});
  final SideQa qa;

  static const double _labelWidth = 104;
  static const double _max = 22;

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
                      color: emGold,
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
                      color: emCream,
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
        color: emStripFill,
        borderRadius: BorderRadius.circular(_stripWidth / 2),
        border: Border.all(color: emGold, width: 1.4),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line('سؤال', qa.question),
              line('الجواب', qa.answer),
            ],
          ),
        ),
      ),
    );
  }
}

/// The navy article panel: braced cream body and the gold fatiha line
/// between two small ornaments. The author pill sits on its top edge.
class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel(this.article, this.fatiha);
  final ClosingArticle article;
  final String fatiha;

  @override
  Widget build(BuildContext context) {
    final body = article.body;
    return PosterPanel(
      key: const ValueKey('em-article'),
      style: _articleStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FitText(
              body.isEmpty ? '' : braced(body),
              style: _amiriBlock.copyWith(color: emCream),
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
                    child: CustomPaint(painter: _OrnamentPainter(true)),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FitText(
                        fatiha,
                        style: _amiri.copyWith(color: emGold),
                        maxSize: 30,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: CustomPaint(painter: _OrnamentPainter(false)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A short gold rule ending in a small eight-point star next to the text
/// ([starRight]: the star is at the right end) and a dot at the other end.
class _OrnamentPainter extends CustomPainter {
  const _OrnamentPainter(this.starRight);
  final bool starRight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 24) return;
    final y = size.height / 2;
    final star = Offset(starRight ? size.width - 12 : 12, y);
    final dot = Offset(starRight ? 6 : size.width - 6, y);
    canvas.drawLine(dot, star, _stroke(emGold, 1.4));
    final fill = Paint()..color = emGold;
    canvas.drawPath(_star8(star, 9, 4.2), fill);
    canvas.drawCircle(dot, 2.6, fill);
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) => old.starRight != starRight;
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

// ---------------------------------------------------------------------------
// Background: emerald field, gold arabesque lattice, arch echo, glow
// ---------------------------------------------------------------------------

/// Cached lattice paths (<= 4 sizes).
@visibleForTesting
final emLatticeCache = BoundedCache<Size, Path>();

/// The arabesque lattice for a poster of [size] (built once per size and
/// cached): a khatam grid — eight-point stars (two interlaced squares with an
/// inner star and ring) on every node, joined through square links on the
/// cell centres, covering the top [emLatticeHeight] px.
Path emLatticePath(Size size) =>
    emLatticeCache.get(size, () => _buildLattice(size));

Path _buildLattice(Size size) {
  final p = Path();
  final w = size.width;
  final h = math.min(emLatticeHeight, size.height);
  if (w <= 0 || h <= 0) return p;
  const s = _latticeCell;
  const big = s / 2; // star point distance: neighbours' points meet
  const diag = big / math.sqrt2;
  final cx = w / 2;
  final nx = (w / 2 / s).ceil();
  final ny = (h / s).floor();
  void square(Offset c, double half, bool diamond) {
    if (diamond) {
      p
        ..moveTo(c.dx, c.dy - half)
        ..lineTo(c.dx + half, c.dy)
        ..lineTo(c.dx, c.dy + half)
        ..lineTo(c.dx - half, c.dy)
        ..close();
    } else {
      p.addRect(Rect.fromCenter(center: c, width: half * 2, height: half * 2));
    }
  }

  for (var j = 0; j <= ny; j++) {
    for (var i = -nx; i <= nx; i++) {
      final n = Offset(cx + i * s, j * s);
      // Eight-point star: a diamond reaching the axis neighbours and a
      // square whose corners meet the cell links.
      square(n, big, true);
      square(n, diag, false);
      // Inner star and ring.
      square(n, big * 0.46, true);
      square(n, diag * 0.46, false);
      p.addOval(Rect.fromCircle(center: n, radius: big * 0.22));
      // Link on the cell centre: a square whose corners touch the four
      // surrounding stars' square corners, with a small rosette.
      if (j < ny) {
        final m = n + const Offset(s / 2, s / 2);
        square(m, s / 2 - diag, true);
        p.addOval(Rect.fromCircle(center: m, radius: s * 0.08));
      }
    }
  }
  return p;
}

/// Below the content: the emerald field with a soft vignette, the fading gold
/// lattice, a gold echo line around the mihrab arch and the medallion glow.
class EmeraldMihrabBackgroundPainter extends CustomPainter {
  EmeraldMihrabBackgroundPainter(this.m);

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
          colors: [emEmerald, emEmeraldMid, emEmeraldDeep],
          stops: [0, 0.45, 1],
        ).createShader(page),
    );

    // Lattice: a gold band with a dark core (reads as interlaced ribbons),
    // both fading out towards the bottom of the band.
    final band = m.sections['lattice']!;
    final lattice = emLatticePath(size);
    canvas.save();
    canvas.clipRect(band);
    canvas.drawPath(
      lattice,
      _stroke(emGold, 2.4)
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE0D4AF5E), Color(0xB0D4AF5E), Color(0x00D4AF5E)],
          stops: [0, 0.55, 1],
        ).createShader(band),
    );
    canvas.drawPath(
      lattice,
      _stroke(emEmerald, 0.8)
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B3D2E), Color(0xFF0B3D2E), Color(0x000B3D2E)],
          stops: [0, 0.55, 1],
        ).createShader(band),
    );
    canvas.restore();

    // Vignette: darker edges and corners.
    canvas.drawRect(
      page,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.0,
          colors: const [Color(0x00000000), Color(0x66000000)],
          stops: const [0.55, 1],
        ).createShader(
          Rect.fromCenter(
            center: page.center,
            width: size.width * 1.6,
            height: size.height,
          ),
        ),
    );

    // Gold echo line around the mihrab arch.
    final arch = m.sections['arch']!;
    canvas.drawPath(
      emArchShape.pathFor(arch.inflate(_archEcho)),
      _stroke(const Color(0xCCD4AF5E), 1.4),
    );

    // Medallion glow (a halo outside the disc) and a dark backing disc so
    // the lattice never peeks through the medallion's anti-aliased rim.
    final med = m.sections['medallion']!;
    final glow = Rect.fromCircle(center: med.center, radius: med.width * 0.74);
    canvas.drawCircle(
      med.center,
      glow.width / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xAAD4AF5E), Color(0x55D4AF5E), Color(0x00D4AF5E)],
          stops: [0.6, 0.75, 1],
        ).createShader(glow),
    );
    canvas.drawCircle(
      med.center,
      math.max(0.0, med.width / 2 - _discInset),
      Paint()..color = emDisc,
    );
  }

  @override
  bool shouldRepaint(EmeraldMihrabBackgroundPainter old) =>
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

const emeraldMihrabTheme = PosterTheme(
  background: emEmerald,
  frameColor: emGold,
  accent: emGold,
  titleColor: emGold,
  bodyText: emCream,
  tableHeaderBg: emGold,
  tableHeaderFg: emInk,
  rowBg: emNavyRow,
  rowAltBg: emGreenRow,
  rowText: emCream,
  gridLine: emGold,
  highlightBg: emGold,
  highlightFg: emInk,
  labelCellBg: emGold,
  labelCellFg: emInk,
  quoteBoxBg: emNavy,
  quoteBoxBorder: emGold,
  quoteText: emCream,
  headingFont: 'Amiri',
  bodyFont: 'Tajawal',
  tableFont: 'Tajawal',
  backgroundPainter: _blank,
  framePainter: _blankFrame,
);
