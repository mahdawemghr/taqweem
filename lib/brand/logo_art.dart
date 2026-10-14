import 'dart:ui' show Color, Offset;

/// A vector logo: colour layers of SVG path data in a `width` x `height`
/// view box (the generated instances live in `logo_paths.dart`).
class LogoArt {
  const LogoArt({
    required this.id,
    required this.width,
    required this.height,
    required this.layers,
  });

  /// Unique id (also the path / shader cache key).
  final String id;
  final double width, height;

  /// Painted in order (first = bottom).
  final List<LogoLayer> layers;

  double get aspectRatio => width / height;

  LogoLayer layer(String id) => layers.firstWhere((l) => l.id == id);
}

/// One filled layer: even-odd [pathData] in [color] or [gradient].
class LogoLayer {
  const LogoLayer({
    required this.id,
    required this.color,
    required this.pathData,
    this.gradient,
  });

  final String id;

  /// Flat colour; with a [gradient] it is the gradient's mid colour (used
  /// for single-colour previews and as the documented brand swatch).
  final Color color;
  final LogoGradient? gradient;
  final String pathData;
}

/// A gradient in view-box coordinates.
class LogoGradient {
  const LogoGradient.linear({
    required Offset this.from,
    required Offset this.to,
    required this.colors,
    required this.stops,
  }) : center = null,
       radius = null;

  const LogoGradient.radial({
    required Offset this.center,
    required double this.radius,
    required this.colors,
    required this.stops,
  }) : from = null,
       to = null;

  final Offset? from, to;
  final Offset? center;
  final double? radius;
  final List<Color> colors;
  final List<double> stops;

  bool get isRadial => center != null;
}
