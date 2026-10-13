import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/shared/fit_text.dart';

/// Every FitText's paragraph lies entirely inside the FitText's box and never
/// truncates lines (no clipping, no ellipsis). Measured in the FitText's own
/// coordinate space, so it also holds inside rotated panels/strips. Returns
/// the number of non-empty FitTexts checked.
int expectFitTextsContained(WidgetTester tester) {
  final fits = find.byType(FitText);
  expect(fits, findsWidgets);
  var checked = 0;
  for (final e in fits.evaluate()) {
    final fitBox = e.renderObject! as RenderBox;
    final box = Offset.zero & fitBox.size;
    final rich = find.descendant(
      of: find.byWidget(e.widget),
      matching: find.byType(RichText),
    );
    if (rich.evaluate().isEmpty) continue; // empty string
    final para = tester.renderObject<RenderParagraph>(rich);
    expect(para.didExceedMaxLines, isFalse);
    expect(para.textSize.height, lessThanOrEqualTo(para.size.height + 0.01));
    final r = MatrixUtils.transformRect(
      para.getTransformTo(fitBox),
      Offset.zero & para.size,
    );
    expect(r.top, greaterThanOrEqualTo(box.top - 0.01));
    expect(r.bottom, lessThanOrEqualTo(box.bottom + 0.01));
    expect(r.left, greaterThanOrEqualTo(box.left - 0.01));
    expect(r.right, lessThanOrEqualTo(box.right + 0.01));
    checked++;
  }
  return checked;
}

/// Paragraphs whose widest unbreakable word is wider than their box (the
/// line breaker would split the word mid-glyph-run). Same check as
/// header_wordbreak_test.
List<String> midWordBreakOffenders(WidgetTester tester) {
  final offenders = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) {
      final maxW = o.constraints.maxWidth;
      final minW = o.getMinIntrinsicWidth(double.infinity);
      if (minW > maxW + 0.5) {
        offenders.add(
          '"${o.text.toPlainText()}" minIntrinsic=$minW maxWidth=$maxW',
        );
      }
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return offenders;
}
