// Golden images in test/templates/goldens/ are rendered on Linux with the
// bundled fonts (loadAppFonts). Pixel output differs between platforms /
// Flutter engine versions: when the platform or engine changes, regenerate
// them with
//   flutter test test/templates/golden_test.dart --update-goldens
// and re-inspect every PNG before accepting it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final t in allTemplates) {
    testWidgets('golden ${t.id}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);
      final poster = seedReferenceMonth().copyWith(templateId: t.id);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: PosterPreview(poster: poster, width: 1000))));
      // Logos load asynchronously: decode them before comparing.
      await precacheTemplate(tester, t);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byType(PosterPreview), matchesGoldenFile('goldens/${t.id}.png'));
    });
  }

  test('navy_gold is registered first (default for unknown ids)', () {
    expect(allTemplates, isNotEmpty);
    expect(allTemplates.first.id, 'navy_gold');
    expect(templateById('nope').id, 'navy_gold');
  });
}
