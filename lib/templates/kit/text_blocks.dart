import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../shared/fit_text.dart';
import 'constants.dart';
import 'panel.dart';

/// Wraps [inner] in braces that print as on the reference poster: `{` at the
/// right end, `}` at the left end. Each brace sits in its own left-to-right
/// isolate (LRI U+2066 … PDI U+2069), so the RTL paragraph does not
/// bidi-mirror it. (Plain `{ … }` — and LRM marks — render mirrored, i.e.
/// `}` on the right; verified by rendering.)
String braced(String inner) => '\u2066{\u2069 $inner \u2066}\u2069';

/// Which side of the poster a side block belongs to.
enum PosterSide { right, left }

/// The poster title: text in a heading font, or an image logo.
///
/// Text titles go through [FitText] (one line by default, shrinks, never
/// clips). Image titles are scaled with [fit] inside the given box and may be
/// recoloured with [tint] (`BlendMode.srcIn`, so a one-colour logo takes the
/// template's gold). Image logos are sampled with [FilterQuality.high] and
/// anti-aliasing so up/down-scaled rasters stay as smooth as possible. When
/// the asset fails to load, [fallbackText] (if any) is set via [FitText] in
/// [style] (inside [fallbackPadding]) instead, so the title never vanishes.
class TitleBlock extends StatelessWidget {
  const TitleBlock.text(
    String this.text, {
    super.key,
    this.style = const TextStyle(fontWeight: FontWeight.w700),
    this.maxSize = KitDefaults.titleMax,
    this.maxLines = 1,
  }) : image = null,
       fit = BoxFit.contain,
       tint = null,
       semanticLabel = null,
       fallbackText = null,
       fallbackPadding = EdgeInsets.zero;

  const TitleBlock.image(
    ImageProvider this.image, {
    super.key,
    this.fit = BoxFit.contain,
    this.tint,
    this.semanticLabel,
    this.fallbackText,
    this.style = const TextStyle(fontWeight: FontWeight.w700),
    this.maxSize = KitDefaults.titleMax,
    this.maxLines = 1,
    this.fallbackPadding = EdgeInsets.zero,
  }) : text = null;

  final String? text;
  final TextStyle style;
  final double maxSize;
  final int? maxLines;
  final ImageProvider? image;
  final BoxFit fit;
  final Color? tint;
  final String? semanticLabel;

  /// Image titles only: text shown (in [style], [maxSize], [maxLines]) when
  /// the image cannot be loaded. Null or empty: nothing is shown.
  final String? fallbackText;

  /// Padding around [fallbackText] (e.g. to keep it inside a painted disc).
  final EdgeInsetsGeometry fallbackPadding;

  /// The quality every kit / template logo is drawn with.
  static const imageQuality = FilterQuality.high;

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img != null) {
      return Image(
        image: img,
        fit: fit,
        color: tint,
        colorBlendMode: tint == null ? null : BlendMode.srcIn,
        semanticLabel: semanticLabel,
        filterQuality: imageQuality,
        isAntiAlias: true,
        // A missing logo must never break a poster: show the title as text.
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return FitText(text!, style: style, maxSize: maxSize, maxLines: maxLines);
  }

  Widget _fallback() {
    final f = fallbackText;
    if (f == null || f.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('title-fallback'),
      padding: fallbackPadding,
      child: FitText(f, style: style, maxSize: maxSize, maxLines: maxLines),
    );
  }
}

/// A header quote: the text (wrapping, shrinking) above a one-line
/// attribution of fixed height. Renders nothing when both are empty.
///
/// With a [panel] the block is drawn inside a [PosterPanel] of that style
/// (the panel disappears too when the quote is empty).
class QuoteBlock extends StatelessWidget {
  const QuoteBlock(
    this.quote, {
    super.key,
    this.textStyle = const TextStyle(fontWeight: FontWeight.w700),
    this.attributionStyle = const TextStyle(fontWeight: FontWeight.w700),
    this.maxSize = KitDefaults.quoteMax,
    this.attributionMaxSize = KitDefaults.attributionMax,
    this.attributionHeight = KitDefaults.attributionHeight,
    this.align = TextAlign.center,
    this.panel,
    this.rotation = 0,
  });

  final HeaderQuote quote;
  final TextStyle textStyle, attributionStyle;
  final double maxSize, attributionMaxSize, attributionHeight;
  final TextAlign align;
  final PanelStyle? panel;
  final double rotation;

  bool get isEmpty => quote.text.isEmpty && quote.attribution.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FitText(
            quote.text,
            style: textStyle,
            maxSize: maxSize,
            align: align,
          ),
        ),
        if (quote.attribution.isNotEmpty)
          SizedBox(
            height: attributionHeight,
            child: FitText(
              quote.attribution,
              style: attributionStyle,
              maxSize: attributionMaxSize,
              maxLines: 1,
            ),
          ),
      ],
    );
    final p = panel;
    if (p == null) return body;
    return PosterPanel(style: p, rotation: rotation, child: body);
  }
}

/// The `{ " … " }` quote line, using the bidi-isolated braces of [braced].
/// Empty text renders nothing (no stray braces).
class BraceQuote extends StatelessWidget {
  const BraceQuote(
    this.text, {
    super.key,
    this.style = const TextStyle(fontWeight: FontWeight.w700),
    this.maxSize = KitDefaults.braceMax,
    this.maxLines,
    this.quoteMarks = true,
    this.align = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final double maxSize;
  final int? maxLines;

  /// Also wrap the text in `" … "` inside the braces (as on the reference).
  final bool quoteMarks;
  final TextAlign align;

  /// The exact string drawn.
  String get display =>
      text.isEmpty ? '' : braced(quoteMarks ? '" $text "' : text);

  @override
  Widget build(BuildContext context) => FitText(
    display,
    style: style,
    maxSize: maxSize,
    maxLines: maxLines,
    align: align,
  );
}

/// The one-line footer notes (`ملاحظات: …`), start-aligned.
class FooterNote extends StatelessWidget {
  const FooterNote(
    this.text, {
    super.key,
    this.style = const TextStyle(fontWeight: FontWeight.w700),
    this.maxSize = KitDefaults.footerMax,
    this.maxLines = 1,
    this.align = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final double maxSize;
  final int? maxLines;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => FitText(
    text,
    style: style,
    maxSize: maxSize,
    maxLines: maxLines,
    align: align,
  );
}

/// A side question/answer strip. By default rotated a quarter turn so it
/// reads top → bottom along the poster edge ([quarterTurns] 3 on both sides,
/// like the reference). Each line is `label : value`, one line, shrinking.
class SideQaStrip extends StatelessWidget {
  const SideQaStrip(
    this.qa, {
    super.key,
    this.width = KitDefaults.sideStripWidth,
    this.quarterTurns = 3,
    this.padding = const EdgeInsets.fromLTRB(16, 2, 16, 2),
    this.style = const TextStyle(
      fontWeight: FontWeight.w700,
      height: KitDefaults.tightLine,
    ),
    this.answerStyle,
    this.maxSize = KitDefaults.sideMax,
    this.questionLabel = 'سؤال',
    this.answerLabel = 'الجواب',
    this.align = TextAlign.start,
  });

  /// The strip for [side] of [poster].
  factory SideQaStrip.of(
    MonthPoster poster,
    PosterSide side, {
    Key? key,
    double width = KitDefaults.sideStripWidth,
    TextStyle style = const TextStyle(
      fontWeight: FontWeight.w700,
      height: KitDefaults.tightLine,
    ),
    TextStyle? answerStyle,
  }) => SideQaStrip(
    side == PosterSide.right ? poster.texts.sideRight : poster.texts.sideLeft,
    key: key,
    width: width,
    style: style,
    answerStyle: answerStyle,
  );

  final SideQa qa;

  /// Strip width (null = fill the parent's width, e.g. inside a panel).
  final double? width;
  final int quarterTurns;
  final EdgeInsets padding;
  final TextStyle style;
  final TextStyle? answerStyle;
  final double maxSize;
  final String questionLabel, answerLabel;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, TextStyle s) => Expanded(
      child: FitText(
        value.isEmpty ? '' : '$label : $value',
        style: s,
        maxSize: maxSize,
        maxLines: 1,
        align: align,
      ),
    );
    return SizedBox(
      width: width,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line(questionLabel, qa.question, style),
              line(answerLabel, qa.answer, answerStyle ?? style),
            ],
          ),
        ),
      ),
    );
  }
}

/// The closing article: `:: author ::` heading, the braced body (justified,
/// wrapping, shrinking) and the fatiha line.
///
/// Section heights are fixed by default; pass `bodyHeight: null` to let the
/// body take the remaining height (the block then needs a bounded parent).
class ClosingArticleBlock extends StatelessWidget {
  const ClosingArticleBlock({
    super.key,
    required this.article,
    required this.fatiha,
    this.headingStyle = const TextStyle(fontWeight: FontWeight.w700),
    this.bodyStyle = const TextStyle(fontWeight: FontWeight.w700),
    this.fatihaStyle = const TextStyle(fontWeight: FontWeight.w700),
    this.headingHeight = KitDefaults.articleHeadingHeight,
    this.bodyHeight = KitDefaults.articleBodyHeight,
    this.fatihaHeight = KitDefaults.fatihaHeight,
    this.headingPadding = const EdgeInsets.symmetric(
      horizontal: 120,
      vertical: 2,
    ),
    this.bodyPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    this.fatihaPadding = const EdgeInsets.symmetric(
      horizontal: 80,
      vertical: 2,
    ),
    this.headingMax = KitDefaults.articleHeadingMax,
    this.bodyMax = KitDefaults.articleBodyMax,
    this.fatihaMax = KitDefaults.fatihaMax,
    this.bodyAlign = TextAlign.justify,
    this.braceBody = true,
    this.showFatiha = true,
  });

  /// The article for [poster] (its author/body and fatiha line).
  factory ClosingArticleBlock.of(
    MonthPoster poster, {
    Key? key,
    TextStyle headingStyle = const TextStyle(fontWeight: FontWeight.w700),
    TextStyle bodyStyle = const TextStyle(fontWeight: FontWeight.w700),
    TextStyle fatihaStyle = const TextStyle(fontWeight: FontWeight.w700),
    double headingHeight = KitDefaults.articleHeadingHeight,
    double? bodyHeight = KitDefaults.articleBodyHeight,
    double fatihaHeight = KitDefaults.fatihaHeight,
    EdgeInsets headingPadding = const EdgeInsets.symmetric(
      horizontal: 120,
      vertical: 2,
    ),
    EdgeInsets bodyPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 2,
    ),
    EdgeInsets fatihaPadding = const EdgeInsets.symmetric(
      horizontal: 80,
      vertical: 2,
    ),
    bool showFatiha = true,
  }) => ClosingArticleBlock(
    key: key,
    article: poster.texts.article,
    fatiha: poster.texts.fatiha,
    headingStyle: headingStyle,
    bodyStyle: bodyStyle,
    fatihaStyle: fatihaStyle,
    headingHeight: headingHeight,
    bodyHeight: bodyHeight,
    fatihaHeight: fatihaHeight,
    headingPadding: headingPadding,
    bodyPadding: bodyPadding,
    fatihaPadding: fatihaPadding,
    showFatiha: showFatiha,
  );

  final ClosingArticle article;
  final String fatiha;
  final TextStyle headingStyle, bodyStyle, fatihaStyle;
  final double headingHeight, fatihaHeight;
  final double? bodyHeight;
  final EdgeInsets headingPadding, bodyPadding, fatihaPadding;
  final double headingMax, bodyMax, fatihaMax;
  final TextAlign bodyAlign;
  final bool braceBody, showFatiha;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final body = Padding(
      padding: bodyPadding,
      child: FitText(
        a.body.isEmpty ? '' : (braceBody ? braced(a.body) : a.body),
        style: bodyStyle,
        maxSize: bodyMax,
        align: bodyAlign,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: headingHeight,
          child: Padding(
            padding: headingPadding,
            child: FitText(
              a.author.isEmpty ? '' : ':: ${a.author} ::',
              style: headingStyle,
              maxSize: headingMax,
              maxLines: 1,
            ),
          ),
        ),
        if (bodyHeight == null)
          Expanded(child: body)
        else
          SizedBox(height: bodyHeight, child: body),
        if (showFatiha)
          SizedBox(
            height: fatihaHeight,
            child: Padding(
              padding: fatihaPadding,
              child: FitText(
                fatiha,
                style: fatihaStyle,
                maxSize: fatihaMax,
                maxLines: 1,
              ),
            ),
          ),
      ],
    );
  }
}
