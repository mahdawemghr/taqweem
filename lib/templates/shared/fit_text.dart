import 'package:flutter/widgets.dart';

/// Absolute floor for [FitText]: below [FitText.minSize] the text keeps
/// shrinking down to this size, because clipping is never acceptable.
const double kFitTextFloor = 6;

/// Right-to-left text that shrinks (never ellipsises, never clips) until it
/// fits the space its parent gives it.
///
/// The font size is chosen from [maxSize] downwards in 0.5 steps (binary
/// search, a handful of layouts per text); the largest size
/// whose laid-out text fits both the available width (wrapping allowed unless
/// [maxLines] limits it) and the available height wins. If nothing down to
/// [minSize] fits, shrinking continues to [kFitTextFloor]; if [maxLines] is
/// what prevents fitting, the line limit is dropped and the search repeats
/// (words are never lost); if even that fails the floor-size paragraph is
/// scaled down as a whole (FittedBox) so it still never leaves its box.
///
/// Text scaling is always [TextScaler.noScaling] for both measuring and
/// painting, so what is measured is exactly what is drawn.
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    this.style = const TextStyle(),
    this.maxSize = 24,
    this.minSize = 7,
    this.align = TextAlign.center,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final double maxSize;
  final double minSize;
  final TextAlign align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final base = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, c) {
        final (size, lines, fits) = fitFontSize(base, c.maxWidth, c.maxHeight);
        final text = Text(
          this.text,
          style: base.copyWith(fontSize: size),
          textAlign: align,
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          softWrap: true,
          maxLines: lines,
          overflow: TextOverflow.visible,
        );
        final sized = c.hasBoundedWidth
            ? SizedBox(width: c.maxWidth, child: text)
            : text;
        // Last resort for absurd lengths: scale the floor-size paragraph
        // down as a whole so it still lies entirely inside the box.
        return Align(
          alignment: Alignment.center,
          child: fits ? sized : FittedBox(fit: BoxFit.scaleDown, child: sized),
        );
      },
    );
  }

  /// The font size and line limit [build] uses for a box of
  /// [maxWidth] x [maxHeight], and whether the text fits at all.
  ///
  /// If the text cannot fit within [maxLines] lines even at the floor size,
  /// the line limit is dropped (wrapping is better than losing words).
  @visibleForTesting
  (double, int?, bool) fitFontSize(
    TextStyle base,
    double maxWidth,
    double maxHeight,
  ) {
    final floor = minSize < kFitTextFloor ? minSize : kFitTextFloor;
    // Candidate sizes are maxSize - 0.5 * i for i in 0..n (all >= floor).
    final n = ((maxSize - floor) / 0.5).floor();
    final attempts = maxLines == null ? const [null] : [maxLines, null];
    for (final lines in attempts) {
      if (n < 0) break;
      bool fitsAt(int i) => _fits(
        base.copyWith(fontSize: maxSize - 0.5 * i),
        lines,
        maxWidth,
        maxHeight,
      );
      // Common case: the largest size already fits (one layout).
      if (fitsAt(0)) return (maxSize, lines, true);
      if (!fitsAt(n)) continue;
      // Binary search for the smallest i (largest size) that fits; fitting
      // is monotonic in the font size. Invariant: lo fails, hi fits.
      var lo = 0, hi = n;
      while (hi - lo > 1) {
        final mid = (lo + hi) >> 1;
        if (fitsAt(mid)) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      return (maxSize - 0.5 * hi, lines, true);
    }
    return (floor, null, false);
  }

  /// Number of text layouts [FitText] has performed (test instrumentation).
  @visibleForTesting
  static int debugLayoutCount = 0;

  bool _fits(TextStyle style, int? lines, double maxWidth, double maxHeight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: lines,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);
    debugLayoutCount++;
    final fits =
        !tp.didExceedMaxLines && tp.height <= maxHeight && tp.width <= maxWidth;
    tp.dispose();
    return fits;
  }
}
