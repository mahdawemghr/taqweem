/// Template kit: reusable, configurable building blocks for posters that
/// own their whole layout. See docs/design/template-kit.md.
///
/// A template composes a [PosterPage] from [PosterPanel]s, text blocks
/// ([TitleBlock], [QuoteBlock], [BraceQuote], [FooterNote], [SideQaStrip],
/// [ClosingArticleBlock]) and the calendar [PosterTableView]; geometry comes
/// from [SectionLayout] / [TableGeometry] so ornament painters line up with
/// the content ([LayoutMetricsLike], [KitMetrics]). All text goes through
/// [FitText]: it shrinks, never clips, never breaks a word.
library;

export '../shared/fit_text.dart' show FitText, kFitTextFloor;
export 'bounded_cache.dart';
export 'constants.dart';
export 'metrics.dart';
export 'page.dart';
export 'panel.dart';
export 'table.dart';
export 'text_blocks.dart';
