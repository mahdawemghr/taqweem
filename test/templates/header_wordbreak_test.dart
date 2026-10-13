// Regression: no text anywhere in a poster may be wider (minimum intrinsic
// width = its widest unbreakable word) than the box it is laid out in,
// otherwise the line breaker splits a word mid-glyph-run (e.g. `جماد/ى`,
// `القع/دة` in table headers). Checked for every template x all 12 Hijri
// months. The poster is scaled by one outer FittedBox, but scaling does not
// change the ratio between a paragraph's intrinsic width and its constraint,
// so the check is meaningful for all paragraphs and none are skipped.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final t in allTemplates) {
    for (var m = 0; m < 12; m++) {
      testWidgets('no mid-word breaks: ${t.id} month $m', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 2200));
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetDevicePixelRatio);
        final poster = seedReferenceMonth().copyWith(
          templateId: t.id,
          hijriMonthIndex: m,
          hijriYear: 1448,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PosterPreview(poster: poster, width: 1000)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final offenders = <String>[];
        void visit(RenderObject o) {
          if (o is RenderParagraph) {
            final maxW = o.constraints.maxWidth;
            final minW = o.getMinIntrinsicWidth(double.infinity);
            if (minW > maxW + 0.5) {
              offenders.add(
                '"${o.text.toPlainText()}" minIntrinsic=$minW '
                'maxWidth=$maxW',
              );
            }
          }
          o.visitChildren(visit);
        }

        visit(tester.binding.renderViews.first);
        expect(offenders, isEmpty, reason: offenders.join('\n'));
      });
    }
  }
}
