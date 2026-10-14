import 'dart:collection';

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
/// [maxLines] limits it) and the available height wins; the widest single word
/// must also fit the width, so a word is never broken across lines. If nothing down to
/// [minSize] fits, shrinking continues to [kFitTextFloor]; if [maxLines] is
/// what prevents fitting, the line limit is dropped and the search repeats
/// (words are never lost); if even that fails the floor-size paragraph is
/// scaled down as a whole (FittedBox) so it still never leaves its box.
///
/// Text scaling is always [TextScaler.noScaling] for both measuring and
/// painting, so what is measured is exactly what is drawn.
///
/// Performance: the search result is a pure function of the text, the merged
/// style, [maxSize], [minSize], [align], [maxLines] and the box size, so it is
/// memoised in a bounded LRU ([kFitTextCacheSize] entries) keyed by exactly
/// those inputs. A warm rebuild of a poster (same data, same size) performs no
/// text layouts at all; the result is bit-for-bit what the search returns.
/// The cache is dropped whenever the set of available fonts changes.
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
    if (!debugCacheEnabled) {
      return fitFontSizeUncached(base, maxWidth, maxHeight);
    }
    _listenForFontChanges();
    final key = _FitKey(
      text,
      base,
      maxSize,
      minSize,
      align,
      maxLines,
      maxWidth,
      maxHeight,
    );
    final hit = _cache.remove(key);
    if (hit != null) {
      debugCacheHits++;
      _cache[key] = hit; // most recently used last
      return hit;
    }
    final r = fitFontSizeUncached(base, maxWidth, maxHeight);
    if (_cache.length >= kFitTextCacheSize) _cache.remove(_cache.keys.first);
    _cache[key] = r;
    return r;
  }

  /// Memoised results of [fitFontSize], least recently used first.
  static final LinkedHashMap<_FitKey, (double, int?, bool)> _cache =
      LinkedHashMap<_FitKey, (double, int?, bool)>();
  static bool _listening = false;

  static void _listenForFontChanges() {
    if (_listening) return;
    _listening = true;
    // A newly loaded font can change every measurement.
    PaintingBinding.instance.systemFonts.addListener(_cache.clear);
  }

  /// Whether [fitFontSize] uses the memo cache (test/benchmark switch).
  @visibleForTesting
  static bool debugCacheEnabled = true;

  /// Number of [fitFontSize] calls answered from the cache.
  @visibleForTesting
  static int debugCacheHits = 0;

  /// Number of entries currently memoised.
  @visibleForTesting
  static int get debugCacheLength => _cache.length;

  /// Drops every memoised result.
  @visibleForTesting
  static void debugClearCache() => _cache.clear();

  /// The binary search behind [fitFontSize], without the cache.
  @visibleForTesting
  (double, int?, bool) fitFontSizeUncached(
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
    var fits =
        !tp.didExceedMaxLines && tp.height <= maxHeight && tp.width <= maxWidth;
    tp.dispose();
    if (fits) {
      // Word-break guard (R22): the widest unbreakable word must fit the
      // box, otherwise the line breaker splits it mid-glyph-run. It is
      // measured on an unconstrained layout: after a constrained layout the
      // engine reports the width of the already-split fragment instead.
      // Monotone in the font size, so the binary search stays valid.
      final free = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
      )..layout();
      fits = free.minIntrinsicWidth <= maxWidth;
      free.dispose();
    }
    return fits;
  }
}

/// Upper bound of memoised [FitText] results (a poster has ~290 texts; this
/// keeps a dozen posters at a few sizes warm while staying a few hundred KB).
const int kFitTextCacheSize = 4096;

/// Every input of [FitText.fitFontSize]; equal keys always give equal
/// results.
@immutable
class _FitKey {
  const _FitKey(
    this.text,
    this.style,
    this.maxSize,
    this.minSize,
    this.align,
    this.maxLines,
    this.maxWidth,
    this.maxHeight,
  );

  final String text;
  final TextStyle style;
  final double maxSize;
  final double minSize;
  final TextAlign align;
  final int? maxLines;
  final double maxWidth;
  final double maxHeight;

  @override
  bool operator ==(Object other) =>
      other is _FitKey &&
      other.text == text &&
      other.maxWidth == maxWidth &&
      other.maxHeight == maxHeight &&
      other.maxSize == maxSize &&
      other.minSize == minSize &&
      other.align == align &&
      other.maxLines == maxLines &&
      other.style == style;

  @override
  int get hashCode => Object.hash(
    text,
    style,
    maxSize,
    minSize,
    align,
    maxLines,
    maxWidth,
    maxHeight,
  );
}
