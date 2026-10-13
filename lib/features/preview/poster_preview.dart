import 'dart:async';

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
///
/// Logos: on its first build (and whenever the template changes) the preview
/// starts [PosterTemplate.precache], so the template's images are decoded
/// into the shared image cache once; every later preview of that template
/// (home thumbnails, editor mini preview, export pages) then shows its logo
/// in the very first frame instead of popping it in. Vector-only templates
/// make this a no-op.
class PosterPreview extends StatefulWidget {
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
  State<PosterPreview> createState() => _PosterPreviewState();
}

class _PosterPreviewState extends State<PosterPreview> {
  /// Id of the template whose images were last precached by this preview.
  String? _warmed;

  PosterTemplate get _template =>
      widget.template ?? templateById(widget.poster.templateId);

  void _warm() {
    final t = _template;
    if (_warmed == t.id) return;
    _warmed = t.id;
    unawaited(t.precache(context));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warm();
  }

  @override
  void didUpdateWidget(PosterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _warm();
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;
    final mq = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    Widget child = FittedBox(
      child: RepaintBoundary(
        key: widget.boundaryKey,
        child: SizedBox.fromSize(
          size: kPosterSize,
          child: t.build(widget.poster),
        ),
      ),
    );
    final w = widget.width;
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
