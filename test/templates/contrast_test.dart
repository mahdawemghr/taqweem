import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every text colour / background pair the shared layout paints.
Map<String, (Color, Color)> textPairs(PosterTheme t) => {
      'rowText/rowBg': (t.rowText, t.rowBg),
      'rowText/rowAltBg': (t.rowText, t.rowAltBg),
      'highlightFg/highlightBg': (t.highlightFg, t.highlightBg),
      'labelCellFg/labelCellBg': (t.labelCellFg, t.labelCellBg),
      'tableHeaderFg/tableHeaderBg': (t.tableHeaderFg, t.tableHeaderBg),
      'bodyText/background': (t.bodyText, t.background),
      'quoteText/quoteBoxBg': (t.quoteText, t.quoteBoxBg),
      'titleColor/background': (t.titleColor, t.background),
      // Quote attribution is drawn in accent on the quote box.
      'accent/quoteBoxBg': (t.accent, t.quoteBoxBg),
    };

void main() {
  test('contrastRatio sanity: black/white = 21, same = 1', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF0B1B3F), const Color(0xFF0B1B3F)),
        closeTo(1, 0.0001));
  });

  for (final tpl in allTemplates) {
    group(tpl.id, () {
      textPairs(tpl.theme).forEach((name, pair) {
        test('$name >= 4.5:1', () {
          final r = contrastRatio(pair.$1, pair.$2);
          expect(r, greaterThanOrEqualTo(4.5),
              reason: '${tpl.id} $name = ${r.toStringAsFixed(2)}');
        });
      });
    });
  }
}
