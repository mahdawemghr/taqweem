// Asset precache mechanism: PosterTemplate.precache (default no-op),
// PosterPreview warming its template once, and a precached logo showing in
// the very first frame of a new preview (no pop-in).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/navy_calligraphy.dart';
import 'package:taqweem/templates/navy_gold.dart';
import 'package:taqweem/templates/poster_template.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';

class _CountingTemplate extends PosterTemplate {
  _CountingTemplate(this.id);
  @override
  final String id;
  int calls = 0;
  @override
  String get nameAr => 'عدّاد';
  @override
  PosterTheme get theme => const NavyGoldTemplate().theme;
  @override
  Future<void> precache(BuildContext context) async => calls++;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(loadAppFonts);

  test('vector templates declare no images (precache is a no-op)', () {
    for (final t in allTemplates) {
      if (t.id == 'navy_calligraphy') continue;
      expect(t.images, isEmpty, reason: t.id);
    }
    expect(const NavyCalligraphyTemplate().images, hasLength(2));
  });

  testWidgets('default precache completes immediately without images', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SizedBox()));
    final ctx = tester.element(find.byType(SizedBox));
    var done = false;
    const NavyGoldTemplate().precache(ctx).then((_) => done = true);
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('PosterPreview precaches its template once, again on change', (
    tester,
  ) async {
    final a = _CountingTemplate('a'), b = _CountingTemplate('b');
    final p = seedReferenceMonth();
    await tester.pumpWidget(_host(PosterPreview(poster: p, template: a)));
    expect(a.calls, 1);
    // Unrelated rebuilds (new poster data) do not precache again.
    await tester.pumpWidget(
      _host(PosterPreview(poster: p.copyWith(hijriYear: 1449), template: a)),
    );
    expect(a.calls, 1);
    await tester.pumpWidget(_host(PosterPreview(poster: p, template: b)));
    expect(b.calls, 1);
    expect(a.calls, 1);
  });

  testWidgets('a precached logo is painted in the first frame (no flicker)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const t = NavyCalligraphyTemplate();
    final p = seedReferenceMonth().copyWith(templateId: t.id);
    // Warm the cache once (e.g. a home thumbnail did it).
    await tester.pumpWidget(_host(PosterPreview(poster: p, width: 100)));
    // Control: a cold cache cannot paint the logo in the first frame.
    expect(
      tester
          .widgetList<RawImage>(find.byType(RawImage))
          .every((r) => r.image == null),
      isTrue,
    );
    final ctx = tester.element(find.byType(PosterPreview));
    await tester.runAsync(() => t.precache(ctx));
    // A brand-new preview elsewhere: ONE frame, no extra pumps.
    await tester.pumpWidget(
      _host(PosterPreview(key: UniqueKey(), poster: p, width: 1000)),
    );
    final images = tester.widgetList<RawImage>(find.byType(RawImage));
    expect(images, hasLength(2));
    expect(images.every((r) => r.image != null), isTrue);
  });
}
