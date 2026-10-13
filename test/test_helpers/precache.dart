import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/poster_template.dart';

/// Loads [template]'s raster assets (real async: image decoding does not run
/// under the fake clock), then pumps so the poster repaints with them.
/// Call after pumping a [PosterPreview] and before capturing / comparing.
/// A no-op (one pump) for vector-only templates.
Future<void> precacheTemplate(
  WidgetTester tester,
  PosterTemplate template,
) async {
  if (template.images.isNotEmpty) {
    final context = tester.element(find.byType(PosterPreview).first);
    await tester.runAsync(() => template.precache(context));
  }
  await tester.pump();
}
