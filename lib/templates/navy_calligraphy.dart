// Navy Calligraphy (D3): a deep-navy header block carrying the white
// calligraphic title logo and the gold mosque finial, two lobed navy quote
// panels straddling the gold header rule, a pale lobed ribbon for the brace
// quote with interlace knots on a gold hairline, a white table with a gold
// header row, navy highlighted rows / occasion day cells, side Q&A strips,
// and a navy footer block with a lobed gold-framed article panel.
//
// Composition source: templates/Gemini_Generated_Image_711gqy711gqy711g.jpeg
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

/// Header / footer navy.
const ncNavy = Color(0xFF0B1F38);

/// Lighter navy at the centre of the header/footer radial glow.
const ncNavyGlow = Color(0xFF12294A);

/// Darker navy at the edges of the header/footer glow.
const ncNavyEdge = Color(0xFF081629);

/// Ornament gold (rules, borders, attribution / author / fatiha text).
const ncGold = Color(0xFFCBA862);

/// Light gold (highlights of the top/bottom tabs).
const ncGoldLight = Color(0xFFE6CD92);

/// Deep gold of the table header row (white text reaches 4.5:1 on it).
const ncGoldDeep = Color(0xFF8A6A2B);

/// Gold for text on the white band (side-strip labels).
const ncGoldText = Color(0xFF7A5B1F);

/// The white band behind the ribbon, table, strips and footer note.
const ncPaper = Color(0xFFFDFCF9);

/// Table rows: white and the light grey stripe.
const ncRow = Color(0xFFFFFFFF);
const ncRowAlt = Color(0xFFECEBE7);

/// Ribbon fill (top → bottom).
const ncRibbonTop = Color(0xFFFBFBF8);
const ncRibbonBottom = Color(0xFFE6E4DE);

/// Dark text on the white band, rows and ribbon.
const ncInk = Color(0xFF111A2B);

/// White text on navy.
const ncWhite = Color(0xFFFFFFFF);

/// Horizontal row hairline.
const ncRowLine = Color(0xFFD9D5CB);

/// Article panel fill (a slightly lifted navy over the footer block).
const ncArticleFill = Color(0xFF10264A);

// ---------------------------------------------------------------------------
// Geometry (logical px on the 1000 x 2200 poster); widgets and painters read
// the same constants through [navyCalligraphyMetrics].
// ---------------------------------------------------------------------------

List<Section> get _sections => const [
  Section('header', 308),
  Section('quotes', 180),
  Section('gap1', 22),
  Section('brace', 96),
  Section('gap2', 22),
  Section.flex('main'),
  Section('footerNote', 46),
  Section('gap3', 10),
  Section('footer', 384),
];

const double _tabInset = 140, _tabHeight = 13, _tabRadius = 10;
const double _topHairline = 3;
const double _titleLeft = 196, _titleTop = 76;
const double _titleWidth = 560, _titleHeight = 202;
const double _finialLeft = 792, _finialTop = 72;
const double _finialWidth = 150, _finialHeight = 210;
const double _quoteMargin = 34, _quoteWidth = 438;
const double _quoteLobe = 26, _quoteRadius = 16;
const double _headerRule = 3;
const double _ribbonInset = 104, _ribbonLobe = 32, _ribbonRadius = 14;
const double _knotSize = 46, _knotOffset = 32;
const double _stripMargin = 14, _stripWidth = 54, _tableGap = 10;
const double _footerRule = 3;
const double _pillWidth = 400, _pillHeight = 56;
const double _pillLobe = 18, _pillRadius = 10;
const double _articleInset = 54, _articleTopOffset = 64, _articleBottom = 30;
const double _articleLobe = 30, _articleRadius = 18;
const double _articleBorder = 2.2, _articleInner = 0.9, _articleGap = 5;
const double _fatihaHeight = 54;
const double _blockLine = 1.5;
const double _timeWidth = 62;

/// Section rects plus table geometry of the poster for [size].
///
/// Extra named rects: `headerBlock`, `footerBlock`, `title`, `finial`,
/// `quoteRight`, `quoteLeft`, `ribbon`, `knotRight`, `knotLeft`, `table`,
/// `stripRight`, `stripLeft`, `pill`, `article`, `articleKnotRight`,
/// `articleKnotLeft`.
KitMetrics navyCalligraphyMetrics(Size size, int rowCount) {
  final page = Offset.zero & size;
  final s = SectionLayout.vertical(page, _sections).rects;
  final w = size.width;
  final header = s['header']!, quotes = s['quotes']!, brace = s['brace']!;
  final main = s['main']!, footer = s['footer']!;
  final headerBottom = quotes.center.dy;
  final table = Rect.fromLTRB(
    _stripMargin + _stripWidth + _tableGap,
    main.top,
    w - _stripMargin - _stripWidth - _tableGap,
    main.bottom,
  );
  final article = Rect.fromLTRB(
    _articleInset,
    footer.top + _articleTopOffset,
    w - _articleInset,
    footer.bottom - _articleBottom,
  );
  Rect knot(double cx, double cy) =>
      Rect.fromCenter(center: Offset(cx, cy), width: _knotSize, height: _knotSize);
  final rects = <String, Rect>{
    ...s,
    'headerBlock': Rect.fromLTRB(0, 0, w, headerBottom),
    'footerBlock': Rect.fromLTRB(0, footer.top, w, size.height),
    'title': Rect.fromLTWH(
      _titleLeft,
      header.top + _titleTop,
      _titleWidth,
      _titleHeight,
    ),
    'finial': Rect.fromLTWH(
      _finialLeft,
      header.top + _finialTop,
      _finialWidth,
      _finialHeight,
    ),
    'quoteRight': Rect.fromLTRB(
      w - _quoteMargin - _quoteWidth,
      quotes.top,
      w - _quoteMargin,
      quotes.bottom,
    ),
    'quoteLeft': Rect.fromLTRB(
      _quoteMargin,
      quotes.top,
      _quoteMargin + _quoteWidth,
      quotes.bottom,
    ),
    'ribbon': Rect.fromLTRB(
      _ribbonInset,
      brace.top,
      w - _ribbonInset,
      brace.bottom,
    ),
    'knotRight': knot(w - _ribbonInset + _knotOffset, brace.center.dy),
    'knotLeft': knot(_ribbonInset - _knotOffset, brace.center.dy),
    'table': table,
    'stripRight': Rect.fromLTRB(
      w - _stripMargin - _stripWidth,
      main.top,
      w - _stripMargin,
      main.bottom,
    ),
    'stripLeft': Rect.fromLTRB(
      _stripMargin,
      main.top,
      _stripMargin + _stripWidth,
      main.bottom,
    ),
    'footerNote': Rect.fromLTRB(
      table.left,
      s['footerNote']!.top,
      table.right,
      s['footerNote']!.bottom,
    ),
    'pill': Rect.fromCenter(
      center: Offset(w / 2, article.top),
      width: _pillWidth,
      height: _pillHeight,
    ),
    'article': article,
    'articleKnotRight': knot(article.right, article.center.dy),
    'articleKnotLeft': knot(article.left, article.center.dy),
  };
  return KitMetrics(
    size: size,
    contentRect: page,
    sections: rects,
    table: TableGeometry.compute(navyCalligraphyTableSpec, table, rowCount),
  );
}

// ---------------------------------------------------------------------------
// Lobed outline (rounded rect whose left/right ends swell into a pointed
// ogee lobe) — the quote panels, ribbon, author pill and article panel.
// ---------------------------------------------------------------------------

/// The lobed outline for [rect]: straight top/bottom edges with corner
/// [radius], and left/right sides that curve out to a point [lobe] px beyond
/// the body, at mid-height. [inset] shrinks the outline (borders).
Path lobedPath(Rect rect, double lobe, double radius, {double inset = 0}) {
  final r = rect.deflate(inset);
  if (r.width <= 0 || r.height <= 0) return Path();
  final d = math.max(0.0, math.min(lobe - inset * 0.4, r.width / 4));
  final c = math.max(0.0, math.min(radius - inset * 0.5, r.height / 4));
  final l = r.left, t = r.top, rt = r.right, b = r.bottom;
  final cy = r.center.dy, h = r.height;
  final bl = l + d, br = rt - d; // body edges
  return Path()
    ..moveTo(bl + c, t)
    ..lineTo(br - c, t)
    ..quadraticBezierTo(br, t, br, t + c)
    ..cubicTo(br, t + h * 0.36, rt - d * 0.12, cy - h * 0.07, rt, cy)
    ..cubicTo(rt - d * 0.12, cy + h * 0.07, br, b - h * 0.36, br, b - c)
    ..quadraticBezierTo(br, b, br - c, b)
    ..lineTo(bl + c, b)
    ..quadraticBezierTo(bl, b, bl, b - c)
    ..cubicTo(bl, b - h * 0.36, l + d * 0.12, cy + h * 0.07, l, cy)
    ..cubicTo(l + d * 0.12, cy - h * 0.07, bl, t + h * 0.36, bl, t + c)
    ..quadraticBezierTo(bl, t, bl + c, t)
    ..close();
}

/// Look of a lobed panel.
@immutable
class LobedStyle {
  const LobedStyle({
    required this.lobe,
    required this.radius,
    this.color,
    this.gradient,
    this.border,
    this.innerBorder,
    this.innerGap = 4,
  });

  final double lobe, radius;
  final Color? color;
  final Gradient? gradient;
  final BorderSide? border, innerBorder;
  final double innerGap;
}

/// Paints a [LobedStyle] outline: fill, then outer and inner border.
class LobedPainter extends CustomPainter {
  const LobedPainter(this.style);
  final LobedStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final s = style;
    final fill = Paint()..isAntiAlias = true;
    if (s.gradient != null) {
      fill.shader = s.gradient!.createShader(rect);
    } else if (s.color != null) {
      fill.color = s.color!;
    } else {
      fill.color = const Color(0x00000000);
    }
    canvas.drawPath(lobedPath(rect, s.lobe, s.radius), fill);
    var inset = 0.0;
    final o = s.border;
    if (o != null) {
      canvas.drawPath(
        lobedPath(rect, s.lobe, s.radius, inset: o.width / 2),
        _stroke(o),
      );
      inset = o.width;
    }
    final i = s.innerBorder;
    if (i != null) {
      canvas.drawPath(
        lobedPath(rect, s.lobe, s.radius, inset: inset + s.innerGap + i.width / 2),
        _stroke(i),
      );
    }
  }

  static Paint _stroke(BorderSide b) => Paint()
    ..color = b.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = b.width
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(LobedPainter old) => !identical(old.style, style);
}

/// A lobed panel with [child] inside [padding] (keep the padding at least
/// [LobedStyle.lobe] horizontally so content stays in the straight body).
class LobedPanel extends StatelessWidget {
  const LobedPanel({
    super.key,
    required this.style,
    required this.padding,
    this.child,
  });

  final LobedStyle style;
  final EdgeInsets padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: LobedPainter(style),
    child: Padding(padding: padding, child: child),
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const _quoteStyle = LobedStyle(
  lobe: _quoteLobe,
  radius: _quoteRadius,
  color: ncNavy,
  border: BorderSide(color: ncGold, width: 2.4),
  innerBorder: BorderSide(color: Color(0xCCFFFFFF), width: 0.9),
  innerGap: 4,
);

const _ribbonStyle = LobedStyle(
  lobe: _ribbonLobe,
  radius: _ribbonRadius,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ncRibbonTop, ncRibbonBottom],
  ),
  border: BorderSide(color: ncGold, width: 2),
);

const _pillStyle = LobedStyle(
  lobe: _pillLobe,
  radius: _pillRadius,
  color: ncNavy,
  border: BorderSide(color: ncGold, width: 2),
);

const _articleStyle = LobedStyle(
  lobe: _articleLobe,
  radius: _articleRadius,
  color: ncArticleFill,
  border: BorderSide(color: ncGold, width: _articleBorder),
  innerBorder: BorderSide(color: Color(0x99CBA862), width: _articleInner),
  innerGap: _articleGap,
);

const _amiri = TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700);

/// Amiri with a tighter line box for the multi-line quotes (its default
/// line is very tall, which would shrink the text needlessly).
const _amiriBlock = TextStyle(
  fontFamily: 'Amiri',
  fontWeight: FontWeight.w700,
  height: _blockLine,
);
const _tajawal = TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700);

const _headerCell = CellStyle(
  background: ncGoldDeep,
  foreground: ncWhite,
  fontFamily: 'Tajawal',
  fontWeight: FontWeight.w700,
  lineHeight: 1.15,
  maxSize: 20,
  wrap: true,
  padding: EdgeInsets.symmetric(horizontal: 1, vertical: 4),
);

const _navyCell = CellStyle(background: ncNavy, foreground: ncWhite);

/// The table: weekday | hijri | gregorian | solar | 4 prayer times | notes
/// (right → left), gold header row, white / grey rows, navy highlighted rows,
/// navy month-label cells and navy hijri cells on days with an occasion.
final TableSpec navyCalligraphyTableSpec = TableSpec(
  headerHeight: 86,
  groups: const [
    [
      TableColumn.weekday(
        width: 74,
        style: CellStyle(maxSize: 20),
        headerStyle: CellStyle(maxSize: 24),
      ),
      TableColumn.hijri(width: 52),
      TableColumn.gregorian(width: 56),
      TableColumn.solar(width: 56),
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
  header: _headerCell,
  body: const CellStyle(
    foreground: ncInk,
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w700,
    lineHeight: KitDefaults.tightLine,
    maxSize: 22,
  ),
  normalRow: const CellStyle(background: ncRow),
  altRow: const CellStyle(background: ncRowAlt),
  highlightRow: _navyCell,
  labelCell: _navyCell,
  cellHook: _occasionDayCell,
  grid: const GridLines(
    horizontal: BorderSide(color: ncRowLine, width: 1),
    vertical: BorderSide(color: ncGold, width: 1),
    headerBottom: BorderSide(color: ncGold, width: 1.5),
  ),
  outerBorder: const BorderSide(color: ncGold, width: 1.6),
);

/// Days that carry an occasion (non-empty note) get a navy hijri cell.
CellStyle? _occasionDayCell(CellRef ref) =>
    ref.column.kind == ColumnKind.hijri &&
        ref.state != RowState.highlighted &&
        ref.day.note.trim().isNotEmpty
    ? _navyCell
    : null;

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

const finialGoldAsset = AssetImage('assets/logos/finial_gold.png');

class NavyCalligraphyTemplate extends PosterTemplate {
  const NavyCalligraphyTemplate();

  @override
  String get id => 'navy_calligraphy';

  @override
  String get nameAr => 'كحلي بالخط العربي';

  @override
  PosterTheme get theme => navyCalligraphyTheme;

  @override
  List<ImageProvider> get images => const [finialGoldAsset];

  @override
  Widget build(MonthPoster p) => NavyCalligraphyPage(poster: p);
}

class NavyCalligraphyPage extends StatelessWidget {
  const NavyCalligraphyPage({super.key, required this.poster});

  final MonthPoster poster;

  @override
  Widget build(BuildContext context) {
    final t = poster.texts;
    final hasBrace = t.braceQuote.isNotEmpty;
    return PosterPage(
      color: ncPaper,
      textStyle: const TextStyle(
        inherit: false,
        fontFamily: 'Tajawal',
        fontSize: 20,
        color: ncInk,
        decoration: TextDecoration.none,
      ),
      backgroundPainter: (size) => NavyCalligraphyBackgroundPainter(
        navyCalligraphyMetrics(size, poster.days.length),
        hasBrace: hasBrace,
      ),
      foregroundPainter: (size) => NavyCalligraphyKnotPainter(
        navyCalligraphyMetrics(size, poster.days.length),
        hasBrace: hasBrace,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final m = navyCalligraphyMetrics(c.biggest, poster.days.length);
          Widget at(String id, Widget child) =>
              Positioned.fromRect(rect: m.sections[id]!, child: child);
          return Stack(
            children: [
              at('title', _title(t.title)),
              at(
                'finial',
                const TitleBlock.image(
                  finialGoldAsset,
                  key: ValueKey('nc-finial'),
                ),
              ),
              at('quoteRight', _QuotePanel(t.rightQuote)),
              at('quoteLeft', _QuotePanel(t.leftQuote)),
              if (hasBrace)
                at(
                  'ribbon',
                  LobedPanel(
                    key: const ValueKey('nc-ribbon'),
                    style: _ribbonStyle,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _ribbonLobe + 22,
                      vertical: 6,
                    ),
                    child: BraceQuote(
                      t.braceQuote,
                      style: _amiriBlock.copyWith(color: ncInk),
                      maxSize: 32,
                      maxLines: 2,
                    ),
                  ),
                ),
              at(
                'stripRight',
                _QaStrip(t.sideRight, key: const ValueKey('nc-strip-right')),
              ),
              at(
                'stripLeft',
                _QaStrip(t.sideLeft, key: const ValueKey('nc-strip-left')),
              ),
              at(
                'table',
                PosterTableView(
                  key: const ValueKey('nc-table'),
                  poster: poster,
                  spec: navyCalligraphyTableSpec,
                ),
              ),
              at(
                'footerNote',
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FooterNote(
                    t.footerNotes,
                    style: _tajawal.copyWith(color: ncInk),
                    maxSize: 22,
                  ),
                ),
              ),
              at('article', _ArticlePanel(t.article, t.fatiha)),
              if (t.article.author.isNotEmpty)
                at(
                  'pill',
                  LobedPanel(
                    key: const ValueKey('nc-pill'),
                    style: _pillStyle,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _pillLobe + 14,
                      vertical: 4,
                    ),
                    child: FitText(
                      t.article.author,
                      style: _amiri.copyWith(color: ncGold),
                      maxSize: 30,
                      maxLines: 1,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The vector calligraphy (white letters, gold accents) for the default
  /// title; any other (edited) title is set as text in the same box so the
  /// poster always shows the real data.
  Widget _title(String title) {
    final s = title.trim();
    if (s.isEmpty) return const SizedBox.shrink();
    if (s == defaultTitle) {
      return const BrandTitle(key: ValueKey('nc-title-image'));
    }
    return TitleBlock.text(
      s,
      key: const ValueKey('nc-title-text'),
      style: _titleTextStyle,
      maxSize: 110,
      maxLines: 2,
    );
  }

  static const _titleTextStyle = TextStyle(
    fontFamily: 'ArefRuqaa',
    fontWeight: FontWeight.w700,
    color: ncWhite,
    shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)],
  );
}

/// A lobed navy header-quote panel; nothing at all for an empty quote.
class _QuotePanel extends StatelessWidget {
  const _QuotePanel(this.quote);
  final HeaderQuote quote;

  @override
  Widget build(BuildContext context) {
    if (quote.text.isEmpty && quote.attribution.isEmpty) {
      return const SizedBox.shrink();
    }
    final a = quote.attribution;
    return LobedPanel(
      style: _quoteStyle,
      padding: const EdgeInsets.fromLTRB(
        _quoteLobe + 18,
        14,
        _quoteLobe + 18,
        10,
      ),
      child: QuoteBlock(
        HeaderQuote(text: quote.text, attribution: a.isEmpty ? '' : '($a)'),
        textStyle: _amiriBlock.copyWith(color: ncWhite),
        attributionStyle: _amiri.copyWith(color: ncGold),
        maxSize: 32,
        attributionMaxSize: 22,
        attributionHeight: 36,
      ),
    );
  }
}

/// Rotated side Q&A strip (reads top → bottom): gold `سؤال :` / `الجواب :`
/// labels, navy question and answer text. Empty values print nothing.
class _QaStrip extends StatelessWidget {
  const _QaStrip(this.qa, {super.key});
  final SideQa qa;

  static const double _labelWidth = 84;
  static const double _max = 22;

  @override
  Widget build(BuildContext context) {
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
                      color: ncGoldText,
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
                      color: ncNavy,
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
    return RotatedBox(
      quarterTurns: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line('سؤال', qa.question),
            line('الجواب', qa.answer),
          ],
        ),
      ),
    );
  }
}

/// The lobed article panel: braced body (white) and the fatiha line (gold)
/// between two short gold rules. The author pill is placed on its top edge
/// by the page.
class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel(this.article, this.fatiha);
  final ClosingArticle article;
  final String fatiha;

  @override
  Widget build(BuildContext context) {
    final body = article.body;
    return LobedPanel(
      key: const ValueKey('nc-article'),
      style: _articleStyle,
      padding: const EdgeInsets.fromLTRB(
        _articleLobe + 24,
        _pillHeight / 2 + 8,
        _articleLobe + 24,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FitText(
              body.isEmpty ? '' : braced(body),
              style: _amiriBlock.copyWith(color: ncWhite),
              maxSize: 30,
            ),
          ),
          if (fatiha.isNotEmpty)
            SizedBox(
              height: _fatihaHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: CustomPaint(painter: _RulePainter())),
                  Expanded(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FitText(
                        fatiha,
                        style: _amiri.copyWith(color: ncGold),
                        maxSize: 30,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const Expanded(child: CustomPaint(painter: _RulePainter())),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A short gold rule at mid-height with a small diamond at each end.
class _RulePainter extends CustomPainter {
  const _RulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p = Paint()
      ..color = ncGold
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), p);
    final fill = Paint()..color = ncGold;
    for (final x in [4.0, size.width - 4]) {
      canvas.drawPath(_diamond(Offset(x, y), 4), fill);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => false;
}

Path _diamond(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r)
  ..lineTo(c.dx + r, c.dy)
  ..lineTo(c.dx, c.dy + r)
  ..lineTo(c.dx - r, c.dy)
  ..close();

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Below the content: the navy header and footer blocks (radial glow and a
/// faint gold lattice), the gold top/bottom tabs and hairlines, the header
/// and footer gold rules with their diamond ornaments, and the gold hairline
/// behind the brace ribbon.
class NavyCalligraphyBackgroundPainter extends CustomPainter {
  NavyCalligraphyBackgroundPainter(this.m, {required this.hasBrace});

  final KitMetrics m;
  final bool hasBrace;

  static const _lattice = Color(0x10CBA862);
  static const double _latticeStep = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final header = m.sections['headerBlock']!;
    final footer = m.sections['footerBlock']!;
    for (final block in [header, footer]) {
      _navyBlock(canvas, block);
    }
    final gold = Paint()..color = ncGold;
    final w = size.width;

    // Top: full-width hairline and the centred tab.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, _topHairline), gold);
    _tab(canvas, Rect.fromLTRB(_tabInset, 0, w - _tabInset, _tabHeight), true);

    // Header rule with diamond ornaments (centre and both page edges).
    final hb = header.bottom;
    canvas.drawRect(Rect.fromLTRB(0, hb - _headerRule / 2, w, hb + _headerRule / 2), gold);
    canvas.drawRect(
      Rect.fromLTRB(0, hb + _headerRule / 2 + 3, w, hb + _headerRule / 2 + 4),
      Paint()..color = const Color(0x99CBA862),
    );
    for (final x in [w / 2, 12.0, w - 12]) {
      canvas.drawPath(_diamond(Offset(x, hb), 8), gold);
    }
    canvas.drawPath(_diamond(Offset(w / 2 - 18, hb), 4), gold);
    canvas.drawPath(_diamond(Offset(w / 2 + 18, hb), 4), gold);

    // Brace hairline (the ribbon and knots sit on it).
    if (hasBrace) {
      final cy = m.sections['brace']!.center.dy;
      canvas.drawRect(Rect.fromLTRB(0, cy - 0.8, w, cy + 0.8), gold);
    }

    // Footer rule and bottom tab + hairline.
    final ft = footer.top;
    canvas.drawRect(Rect.fromLTRB(0, ft, w, ft + _footerRule), gold);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - _topHairline, w, _topHairline),
      gold,
    );
    _tab(
      canvas,
      Rect.fromLTRB(_tabInset, size.height - _tabHeight, w - _tabInset, size.height),
      false,
    );
  }

  void _navyBlock(Canvas canvas, Rect r) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: const [ncNavyGlow, ncNavy, ncNavyEdge],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCenter(
          center: r.center,
          width: r.width,
          height: math.max(r.height, r.width * 0.6),
        )),
    );
    canvas.save();
    canvas.clipRect(r);
    final p = Paint()
      ..color = _lattice
      ..strokeWidth = 1;
    final span = r.width + r.height;
    for (var d = -r.height; d < span; d += _latticeStep) {
      canvas.drawLine(
        Offset(r.left + d, r.top),
        Offset(r.left + d + r.height, r.bottom),
        p,
      );
      canvas.drawLine(
        Offset(r.left + d, r.bottom),
        Offset(r.left + d + r.height, r.top),
        p,
      );
    }
    canvas.restore();
  }

  void _tab(Canvas canvas, Rect r, bool top) {
    final rr = top
        ? RRect.fromRectAndCorners(
            r,
            bottomLeft: const Radius.circular(_tabRadius),
            bottomRight: const Radius.circular(_tabRadius),
          )
        : RRect.fromRectAndCorners(
            r,
            topLeft: const Radius.circular(_tabRadius),
            topRight: const Radius.circular(_tabRadius),
          );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          colors: const [ncGold, ncGoldLight, ncGold],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(NavyCalligraphyBackgroundPainter old) =>
      old.hasBrace != hasBrace || !old.m.sameLayout(m);
}

/// Above the content: gold interlace knots at the ribbon ends and on the
/// article panel's lobe tips (all outside the text boxes).
class NavyCalligraphyKnotPainter extends CustomPainter {
  NavyCalligraphyKnotPainter(this.m, {required this.hasBrace});

  final KitMetrics m;
  final bool hasBrace;

  @override
  void paint(Canvas canvas, Size size) {
    final ids = [
      if (hasBrace) ...['knotRight', 'knotLeft'],
      'articleKnotRight',
      'articleKnotLeft',
    ];
    for (final id in ids) {
      paintKnot(canvas, m.sections[id]!);
    }
  }

  /// A square interlace knot (rotated 45°) in [r]: gold diamond frame with a
  /// woven lattice and corner loops, backed with navy.
  static void paintKnot(Canvas canvas, Rect r) {
    final c = r.center;
    final h = r.width / 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4);
    final s = h * 0.62; // half side of the square
    final stroke = Paint()
      ..color = ncGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true;
    final back = Paint()..color = ncNavy;
    final sq = Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 2);
    // Corner loops.
    for (final o in [sq.topLeft, sq.topRight, sq.bottomLeft, sq.bottomRight]) {
      canvas.drawCircle(o, s * 0.32, back);
      canvas.drawCircle(o, s * 0.32, stroke);
    }
    canvas.drawRect(sq, back);
    canvas.drawRect(sq, stroke);
    canvas.drawRect(sq.deflate(s * 0.18), stroke..strokeWidth = 1);
    // Woven lattice.
    final inner = sq.deflate(s * 0.18);
    for (var i = 1; i < 4; i++) {
      final x = inner.left + inner.width * i / 4;
      final y = inner.top + inner.height * i / 4;
      canvas.drawLine(Offset(x, inner.top), Offset(x, inner.bottom), stroke);
      canvas.drawLine(Offset(inner.left, y), Offset(inner.right, y), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NavyCalligraphyKnotPainter old) =>
      old.hasBrace != hasBrace || !old.m.sameLayout(m);
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

const navyCalligraphyTheme = PosterTheme(
  background: ncNavy,
  frameColor: ncGold,
  accent: ncGold,
  titleColor: ncWhite,
  bodyText: ncWhite,
  tableHeaderBg: ncGoldDeep,
  tableHeaderFg: ncWhite,
  rowBg: ncRow,
  rowAltBg: ncRowAlt,
  rowText: ncInk,
  gridLine: ncGold,
  highlightBg: ncNavy,
  highlightFg: ncWhite,
  labelCellBg: ncNavy,
  labelCellFg: ncWhite,
  quoteBoxBg: ncNavy,
  quoteBoxBorder: ncGold,
  quoteText: ncWhite,
  headingFont: 'Amiri',
  bodyFont: 'Tajawal',
  tableFont: 'Tajawal',
  backgroundPainter: _blank,
  framePainter: _blankFrame,
);
