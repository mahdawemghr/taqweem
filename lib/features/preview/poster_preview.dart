import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../../templates/poster_template.dart';
import '../../templates/registry.dart';

/// The poster at its fixed logical size [kPosterSize], scaled to fit.
///
/// [boundaryKey] (if given) sits on the [RepaintBoundary] wrapping exactly
/// the 1000x2200 poster, for PNG export. [width] fixes the displayed width
/// (height follows the poster ratio); without it the poster scales to the
/// parent's constraints. [template] overrides `templateById(poster.templateId)`.
///
/// System text scaling is disabled inside the poster so accessibility font
/// sizes can never break its layout.
class PosterPreview extends StatelessWidget {
  const PosterPreview({
    super.key,
    required this.poster,
    this.boundaryKey,
    this.width,
    this.template,
  });

  final MonthPoster poster;
  final GlobalKey? boundaryKey;
  final double? width;
  final PosterTemplate? template;

  @override
  Widget build(BuildContext context) {
    final t = template ?? templateById(poster.templateId);
    final mq = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    Widget child = FittedBox(
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox.fromSize(size: kPosterSize, child: t.build(poster)),
      ),
    );
    final w = width;
    if (w != null) {
      child = SizedBox(
        width: w,
        height: w * kPosterSize.height / kPosterSize.width,
        child: child,
      );
    }
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }
}
