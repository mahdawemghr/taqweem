// Kit self-test template (tests only, never registered): composes a whole
// page from the template kit — cartouche title, rounded + cartouche quote
// panels (one slightly rotated), a notched ribbon brace quote, a pointed
// mihrab (arch) panel around a table split into three glass panels
// (dates | times | notes, right → left) with a filled hijri column, pill
// badges on highlighted weekdays and month-label cells, a gradient article
// panel, and a frame painter aligned through KitMetrics.
import 'package:flutter/widgets.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/domain/time_format.dart';
import 'package:taqweem/templates/kit/kit.dart';
import 'package:taqweem/templates/poster_template.dart';

const _emerald = Color(0xFF0B3B2E);
const _deep = Color(0xFF062A20);
const _panel = Color(0xFF12523F);
const _gold = Color(0xFFD4AF37);
const _paleGold = Color(0xFFF3E3A1);
const _ivory = Color(0xFFF6F1DC);
const _navy = Color(0xFF0F2347);
const _cream = Color(0xFFF4E9C8);
const _brown = Color(0xFF5A3A12);
const _brownDeep = Color(0xFF3B2408);

// Geometry — the demo's only sizes, shared by widgets and the painter.
const _pagePadding = EdgeInsets.all(36);
const _gap = 12.0;
const _archPadding = EdgeInsets.fromLTRB(20, 14, 20, 20);
const _archRise = 140.0;
const _stripWidth = 48.0;

List<Section> get _sections => const [
  Section('title', 140),
  Section('quotes', 210),
  Section('brace', 100),
  Section.flex('main'),
  Section('footer', 46),
  Section('article', 300),
];

const _archStyle = PanelStyle(
  shape: PanelShape.arch(rise: _archRise, pointed: true, radius: 18),
  color: _panel,
  border: BorderSide(color: _gold, width: 3),
  innerBorder: BorderSide(color: Color(0x99D4AF37), width: 1.2),
  innerBorderGap: 5,
  shadows: [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
  padding: _archPadding,
);

const _glass = PanelStyle(
  shape: PanelShape.rounded(14),
  color: Color(0x1FFFFFFF),
  border: BorderSide(color: Color(0x66F3E3A1), width: 1.2),
  padding: EdgeInsets.all(6),
);

TableSpec _tableSpec() {
  const hairline = BorderSide(color: Color(0x40F6F1DC), width: 1);
  return TableSpec(
    split: true,
    gap: 12,
    headerHeight: 76,
    panel: _glass,
    groups: const [
      [
        TableColumn.weekday(),
        // Filled date column.
        TableColumn.hijri(
          style: CellStyle(background: _gold, foreground: _deep),
        ),
        TableColumn.gregorian(),
        TableColumn.solar(),
      ],
      [
        TableColumn.time(PrayerSlot.fajr),
        TableColumn.time(PrayerSlot.shurooq),
        TableColumn.time(PrayerSlot.zuhr),
        TableColumn.time(PrayerSlot.maghrib),
      ],
      [
        TableColumn.notes(
          style: CellStyle(
            lineHeight: kFontLineHeight,
            maxSize: 20,
            wrap: true,
          ),
        ),
      ],
    ],
    header: const CellStyle(
      background: Color(0xFF0E4636),
      foreground: _paleGold,
      fontFamily: 'ArefRuqaa',
      fontWeight: FontWeight.w700,
      lineHeight: KitDefaults.tightLine,
      maxSize: 26,
    ),
    body: const CellStyle(
      foreground: _ivory,
      fontFamily: 'Amiri',
      fontWeight: FontWeight.w700,
      lineHeight: KitDefaults.tightLine,
      maxSize: 22,
    ),
    altRow: const CellStyle(background: Color(0x14FFFFFF)),
    highlightRow: const CellStyle(
      background: Color(0x40D4AF37),
      foreground: _paleGold,
    ),
    labelCell: const CellStyle(
      foreground: _deep,
      badge: CellBadge(color: _paleGold),
    ),
    cellHook: (ref) =>
        ref.state == RowState.highlighted &&
            ref.column.kind == ColumnKind.weekday
        ? const CellStyle(
            foreground: _deep,
            badge: CellBadge(
              color: _gold,
              border: BorderSide(color: _paleGold, width: 1),
            ),
          )
        : null,
    grid: const GridLines(horizontal: hairline, vertical: hairline),
  );
}

/// Section and table geometry of the demo for a page of [size].
KitMetrics demoMetrics(Size size, int rowCount) {
  final content = _pagePadding.deflateRect(Offset.zero & size);
  final layout = SectionLayout.vertical(content, _sections, gap: _gap);
  final main = layout['main'];
  final inner = (_archPadding + _archStyle.shape.safeInsets(main.size))
      .resolve(TextDirection.rtl)
      .deflateRect(main);
  final tableRect = Rect.fromLTRB(
    inner.left + _stripWidth,
    inner.top,
    inner.right - _stripWidth,
    inner.bottom,
  );
  return KitMetrics(
    size: size,
    contentRect: content,
    sections: layout.rects,
    table: TableGeometry.compute(_tableSpec(), tableRect, rowCount),
  );
}

class KitDemoTemplate extends PosterTemplate {
  const KitDemoTemplate();

  @override
  String get id => 'kit_demo';

  @override
  String get nameAr => 'تجربة الأدوات';

  @override
  PosterTheme get theme => _theme;

  @override
  Widget build(MonthPoster p) => KitDemoPage(poster: p);
}

class KitDemoPage extends StatelessWidget {
  const KitDemoPage({super.key, required this.poster});

  final MonthPoster poster;

  static const _body = TextStyle(
    fontFamily: 'Amiri',
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final texts = poster.texts;
    return PosterPage(
      textStyle: const TextStyle(
        inherit: false,
        fontFamily: 'Amiri',
        fontSize: 20,
        color: _ivory,
        decoration: TextDecoration.none,
      ),
      background: const [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_emerald, _deep],
            ),
          ),
        ),
      ],
      foregroundPainter: (size) =>
          _DemoFramePainter(demoMetrics(size, poster.days.length)),
      child: LayoutBuilder(
        builder: (context, c) {
          final m = demoMetrics(c.biggest, poster.days.length);
          Widget at(String id, Widget child) =>
              Positioned.fromRect(rect: m.sections[id]!, child: child);
          return Stack(
            children: [
              at(
                'title',
                PosterPanel(
                  style: const PanelStyle(
                    shape: PanelShape.cartouche(cut: 34, concave: true),
                    color: _navy,
                    border: BorderSide(color: _gold, width: 3),
                    innerBorder: BorderSide(color: _gold, width: 1),
                    padding: EdgeInsets.fromLTRB(150, 10, 150, 14),
                  ),
                  child: TitleBlock.text(
                    texts.title,
                    style: const TextStyle(
                      fontFamily: 'ArefRuqaa',
                      fontWeight: FontWeight.w700,
                      color: _paleGold,
                      shadows: [
                        Shadow(color: Color(0xAA000000), blurRadius: 4),
                      ],
                    ),
                    maxSize: 80,
                  ),
                ),
              ),
              at(
                'quotes',
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: QuoteBlock(
                        texts.rightQuote,
                        textStyle: _body.copyWith(color: _ivory),
                        attributionStyle: _body.copyWith(color: _gold),
                        panel: const PanelStyle(
                          shape: PanelShape.rounded(22),
                          color: _navy,
                          border: BorderSide(color: _gold, width: 2.5),
                          innerBorder: BorderSide(color: _gold, width: 1),
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: QuoteBlock(
                        texts.leftQuote,
                        rotation: -0.02,
                        textStyle: _body.copyWith(color: _ivory),
                        attributionStyle: _body.copyWith(color: _gold),
                        panel: const PanelStyle(
                          shape: PanelShape.cartouche(cut: 22),
                          color: _navy,
                          border: BorderSide(color: _gold, width: 2.5),
                          padding: EdgeInsets.fromLTRB(10, 12, 10, 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              at(
                'brace',
                PosterPanel(
                  style: const PanelStyle(
                    shape: PanelShape.ribbon(depth: 46, notched: true),
                    color: _cream,
                    border: BorderSide(color: _gold, width: 2.5),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: BraceQuote(
                    texts.braceQuote,
                    style: _body.copyWith(color: _navy),
                    maxLines: 1,
                  ),
                ),
              ),
              at(
                'main',
                PosterPanel(
                  style: _archStyle,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SideQaStrip.of(
                        poster,
                        PosterSide.right,
                        width: _stripWidth,
                        style: _body.copyWith(
                          color: _paleGold,
                          height: KitDefaults.tightLine,
                        ),
                      ),
                      Expanded(
                        child: PosterTableView(
                          key: const ValueKey('kit-table'),
                          poster: poster,
                          spec: _tableSpec(),
                        ),
                      ),
                      SideQaStrip.of(
                        poster,
                        PosterSide.left,
                        width: _stripWidth,
                        style: _body.copyWith(
                          color: _paleGold,
                          height: KitDefaults.tightLine,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              at(
                'footer',
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FooterNote(
                    texts.footerNotes,
                    style: _body.copyWith(color: _ivory),
                  ),
                ),
              ),
              at(
                'article',
                PosterPanel(
                  style: const PanelStyle(
                    shape: PanelShape.rounded(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_brown, _brownDeep],
                    ),
                    border: BorderSide(color: _gold, width: 2.5),
                    innerBorder: BorderSide(color: Color(0x99D4AF37), width: 1),
                    padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
                  ),
                  child: ClosingArticleBlock.of(
                    poster,
                    headingStyle: _body.copyWith(color: _paleGold),
                    bodyStyle: _body.copyWith(color: _ivory),
                    fatihaStyle: _body.copyWith(color: _paleGold),
                    bodyHeight: null,
                    headingPadding: const EdgeInsets.symmetric(
                      horizontal: 100,
                      vertical: 2,
                    ),
                    fatihaPadding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 2,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Thin gold page frame plus small diamonds at the table panels' corners and
/// a gold rule under the table header — positioned through [KitMetrics].
class _DemoFramePainter extends CustomPainter {
  _DemoFramePainter(this.m);
  final KitMetrics m;

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect((Offset.zero & size).deflate(14), gold);
    canvas.drawRect((Offset.zero & size).deflate(20), gold..strokeWidth = 0.8);
    final fill = Paint()..color = _gold;
    for (final r in m.table.panels) {
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 6)
            ..lineTo(c.dx + 6, c.dy)
            ..lineTo(c.dx, c.dy + 6)
            ..lineTo(c.dx - 6, c.dy)
            ..close(),
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DemoFramePainter old) => false;
}

class _Blank extends CustomPainter {
  const _Blank();
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

CustomPainter _blank() => const _Blank();
CustomPainter _blankFrame(LayoutMetrics? _) => const _Blank();

const _theme = PosterTheme(
  background: _emerald,
  frameColor: _gold,
  accent: _gold,
  titleColor: _paleGold,
  bodyText: _ivory,
  tableHeaderBg: Color(0xFF0E4636),
  tableHeaderFg: _paleGold,
  rowBg: _panel,
  rowAltBg: _panel,
  rowText: _ivory,
  gridLine: _gold,
  highlightBg: _gold,
  highlightFg: _deep,
  labelCellBg: _paleGold,
  labelCellFg: _deep,
  quoteBoxBg: _navy,
  quoteBoxBorder: _gold,
  quoteText: _ivory,
  headingFont: 'ArefRuqaa',
  bodyFont: 'Amiri',
  backgroundPainter: _blank,
  framePainter: _blankFrame,
);
