import 'package:flutter/widgets.dart';

/// Builds a painter for the poster once its real size is known.
typedef SizedPainterBuilder = CustomPainter? Function(Size size);

/// The poster canvas: a fixed-size (normally `kPosterSize`, given by
/// `PosterPreview`) right-to-left page with system text scaling disabled,
/// made of layers painted bottom to top:
///
/// 1. [color] fill, then [backgroundPainter], then [background] widgets;
/// 2. [child] — the flowing content, inside [padding];
/// 3. [positioned] — `Positioned` widgets in poster coordinates (origin
///    top-left), for templates that place sections at computed rects
///    (see `SectionLayout`);
/// 4. [foregroundPainter], then [foreground] widgets (ornaments, frames;
///    they never receive pointer events).
///
/// [textStyle] becomes the page's `DefaultTextStyle` (every `FitText` merges
/// onto it), so templates set their body font and colour once.
class PosterPage extends StatelessWidget {
  const PosterPage({
    super.key,
    this.color,
    this.backgroundPainter,
    this.background = const [],
    this.padding = EdgeInsets.zero,
    this.child,
    this.positioned = const [],
    this.foregroundPainter,
    this.foreground = const [],
    this.textStyle,
  });

  final Color? color;
  final SizedPainterBuilder? backgroundPainter;
  final List<Widget> background;
  final EdgeInsets padding;
  final Widget? child;
  final List<Widget> positioned;
  final SizedPainterBuilder? foregroundPainter;
  final List<Widget> foreground;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    Widget page = LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final bg = backgroundPainter?.call(size);
        final fg = foregroundPainter?.call(size);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (color != null) ColoredBox(color: color!),
            if (bg != null) CustomPaint(painter: bg),
            ...background,
            Padding(padding: padding, child: child),
            ...positioned,
            if (fg != null) IgnorePointer(child: CustomPaint(painter: fg)),
            if (foreground.isNotEmpty)
              IgnorePointer(
                child: Stack(fit: StackFit.expand, children: foreground),
              ),
          ],
        );
      },
    );
    final style = textStyle;
    if (style != null) page = DefaultTextStyle(style: style, child: page);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: Directionality(textDirection: TextDirection.rtl, child: page),
    );
  }
}
