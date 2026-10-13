import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The outline families a [PosterPanel] can take.
enum ShapeKind {
  /// Plain rectangle.
  rect,

  /// Rectangle with circular corners ([PanelShape.radius]).
  rounded,

  /// Mihrab: a round or pointed arch on top of straight sides.
  arch,

  /// Banner with pointed (or swallow-tail notched) left and right ends.
  ribbon,

  /// Rectangle with clipped (chamfered or concave) corners.
  cartouche,
}

/// A panel outline. Pure geometry: [pathFor] maps a rect to the outline path,
/// used for the fill, the border(s), the content clip and by template
/// painters that want to echo the shape.
@immutable
class PanelShape {
  const PanelShape.rect()
    : kind = ShapeKind.rect,
      radius = 0,
      rise = null,
      pointed = false,
      depth = 0,
      notched = false,
      cut = 0,
      concave = false;

  /// Rounded rectangle with corner [radius].
  const PanelShape.rounded(this.radius)
    : kind = ShapeKind.rounded,
      rise = null,
      pointed = false,
      depth = 0,
      notched = false,
      cut = 0,
      concave = false;

  /// Mihrab arch. [rise] is the height of the arched top (null = half the
  /// width, i.e. a semicircle for a round arch). [pointed] gives the
  /// two-centred pointed arch of a mihrab; [radius] rounds the bottom corners.
  const PanelShape.arch({this.rise, this.pointed = false, this.radius = 0})
    : kind = ShapeKind.arch,
      depth = 0,
      notched = false,
      cut = 0,
      concave = false;

  /// Ribbon whose left/right ends are pointed outwards by [depth] px, or cut
  /// inwards as a swallow-tail when [notched].
  const PanelShape.ribbon({this.depth = 24, this.notched = false})
    : kind = ShapeKind.ribbon,
      radius = 0,
      rise = null,
      pointed = false,
      cut = 0,
      concave = false;

  /// Cartouche: each corner is cut by [cut] px — a straight chamfer, or a
  /// quarter-circle bite when [concave].
  const PanelShape.cartouche({this.cut = 18, this.concave = false})
    : kind = ShapeKind.cartouche,
      radius = 0,
      rise = null,
      pointed = false,
      depth = 0,
      notched = false;

  final ShapeKind kind;
  final double radius;
  final double? rise;
  final bool pointed;
  final double depth;
  final bool notched;
  final double cut;
  final bool concave;

  /// Effective arch rise for a panel of [width] x [height].
  double archRise(double width, double height) =>
      (rise ?? width / 2).clamp(0.0, height).toDouble();

  /// The outline for [rect], shrunk by [inset] (used to stroke borders
  /// inside the shape and for double borders).
  Path pathFor(Rect rect, {double inset = 0}) {
    final r = rect.deflate(inset);
    if (r.width <= 0 || r.height <= 0) return Path();
    final l = r.left, t = r.top, rt = r.right, b = r.bottom;
    final cx = r.center.dx, cy = r.center.dy;
    switch (kind) {
      case ShapeKind.rect:
        return Path()..addRect(r);
      case ShapeKind.rounded:
        final rad = math.max(0.0, radius - inset);
        return Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(rad)));
      case ShapeKind.arch:
        final h = math.max(0.0, archRise(rect.width, rect.height) - inset);
        final br = math.min(math.max(0.0, radius - inset), r.width / 2);
        final p = Path()..moveTo(l, t + h);
        if (pointed) {
          final w = r.width;
          p
            ..cubicTo(l, t + h * 0.45, cx - w * 0.22, t + h * 0.12, cx, t)
            ..cubicTo(cx + w * 0.22, t + h * 0.12, rt, t + h * 0.45, rt, t + h);
        } else {
          p.arcTo(Rect.fromLTRB(l, t, rt, t + 2 * h), math.pi, math.pi, false);
        }
        p.lineTo(rt, b - br);
        if (br > 0) {
          p.arcToPoint(Offset(rt - br, b), radius: Radius.circular(br));
        }
        p.lineTo(l + br, b);
        if (br > 0) {
          p.arcToPoint(Offset(l, b - br), radius: Radius.circular(br));
        }
        return p..close();
      case ShapeKind.ribbon:
        final d = math.min(math.max(0.0, depth - inset * 0.5), r.width / 2);
        final p = Path();
        if (notched) {
          p
            ..moveTo(l, t)
            ..lineTo(rt, t)
            ..lineTo(rt - d, cy)
            ..lineTo(rt, b)
            ..lineTo(l, b)
            ..lineTo(l + d, cy);
        } else {
          p
            ..moveTo(l + d, t)
            ..lineTo(rt - d, t)
            ..lineTo(rt, cy)
            ..lineTo(rt - d, b)
            ..lineTo(l + d, b)
            ..lineTo(l, cy);
        }
        return p..close();
      case ShapeKind.cartouche:
        final c = math.min(
          math.max(0.0, cut - inset * 0.4),
          math.min(r.width, r.height) / 2,
        );
        final p = Path()..moveTo(l + c, t);
        p.lineTo(rt - c, t);
        _corner(p, Offset(rt, t + c), Offset(rt, t), c);
        p.lineTo(rt, b - c);
        _corner(p, Offset(rt - c, b), Offset(rt, b), c);
        p.lineTo(l + c, b);
        _corner(p, Offset(l, b - c), Offset(l, b), c);
        p.lineTo(l, t + c);
        _corner(p, Offset(l + c, t), Offset(l, t), c);
        return p..close();
    }
  }

  void _corner(Path p, Offset to, Offset corner, double c) {
    if (c <= 0) return;
    if (concave) {
      // Quarter-circle bite centred on the (removed) corner point.
      p.arcToPoint(to, radius: Radius.circular(c), clockwise: false);
    } else {
      p.lineTo(to.dx, to.dy);
    }
  }

  /// Extra padding that keeps content out of the shape's non-rectangular
  /// parts (arch top, ribbon points, cut corners) for a panel of [size].
  EdgeInsets safeInsets(Size size) => switch (kind) {
    ShapeKind.rect => EdgeInsets.zero,
    ShapeKind.rounded => EdgeInsets.all(radius * 0.3),
    ShapeKind.arch => EdgeInsets.only(
      top: archRise(size.width, size.height),
      left: radius * 0.3,
      right: radius * 0.3,
      bottom: radius * 0.3,
    ),
    ShapeKind.ribbon => EdgeInsets.symmetric(horizontal: depth),
    ShapeKind.cartouche => EdgeInsets.symmetric(horizontal: cut * 0.6),
  };

  @override
  bool operator ==(Object other) =>
      other is PanelShape &&
      other.kind == kind &&
      other.radius == radius &&
      other.rise == rise &&
      other.pointed == pointed &&
      other.depth == depth &&
      other.notched == notched &&
      other.cut == cut &&
      other.concave == concave;

  @override
  int get hashCode =>
      Object.hash(kind, radius, rise, pointed, depth, notched, cut, concave);
}

/// Look of a [PosterPanel].
@immutable
class PanelStyle {
  const PanelStyle({
    this.shape = const PanelShape.rect(),
    this.color,
    this.gradient,
    this.border,
    this.innerBorder,
    this.innerBorderGap = 4,
    this.shadows = const [],
    this.padding = EdgeInsets.zero,
    this.clip = true,
  });

  final PanelShape shape;

  /// Solid fill (ignored when [gradient] is set). Null = transparent.
  final Color? color;
  final Gradient? gradient;

  /// Outer border, stroked inside the outline.
  final BorderSide? border;

  /// Optional second border (double frame) [innerBorderGap] px inside
  /// [border].
  final BorderSide? innerBorder;
  final double innerBorderGap;

  /// Drop shadows (offset, blur sigma, colour; spread inflates the outline).
  final List<BoxShadow> shadows;

  /// Content padding, added to the shape's [PanelShape.safeInsets].
  final EdgeInsets padding;

  /// Clip the content to the outline (not needed for plain rects).
  final bool clip;

  /// A plain rect panel paints exactly like a `BoxDecoration` (the shared
  /// layout's quote boxes rely on this for pixel-identical output).
  bool get isPlainRect =>
      shape.kind == ShapeKind.rect &&
      gradient == null &&
      innerBorder == null &&
      shadows.isEmpty;

  PanelStyle copyWith({
    PanelShape? shape,
    Color? color,
    Gradient? gradient,
    BorderSide? border,
    BorderSide? innerBorder,
    double? innerBorderGap,
    List<BoxShadow>? shadows,
    EdgeInsets? padding,
    bool? clip,
  }) => PanelStyle(
    shape: shape ?? this.shape,
    color: color ?? this.color,
    gradient: gradient ?? this.gradient,
    border: border ?? this.border,
    innerBorder: innerBorder ?? this.innerBorder,
    innerBorderGap: innerBorderGap ?? this.innerBorderGap,
    shadows: shadows ?? this.shadows,
    padding: padding ?? this.padding,
    clip: clip ?? this.clip,
  );
}

/// A decorated container in any [PanelShape]: fill or gradient, single or
/// double border, shadow, inner padding, content clipped to the outline.
/// Used for quote panels, article panels, table panels and glass panels.
///
/// [rotation] (radians) tilts the whole panel, e.g. the slightly rotated
/// quote cards of the midnight design; text inside still uses FitText.
class PosterPanel extends StatelessWidget {
  const PosterPanel({
    super.key,
    this.style = const PanelStyle(),
    this.rotation = 0,
    this.child,
  });

  final PanelStyle style;
  final double rotation;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = style;
    Widget panel;
    if (s.isPlainRect) {
      final b = s.border;
      panel = DecoratedBox(
        decoration: BoxDecoration(
          color: s.color,
          border: b == null ? null : Border.fromBorderSide(b),
        ),
        child: Padding(padding: s.padding, child: child),
      );
    } else {
      panel = LayoutBuilder(
        builder: (context, c) {
          final size = c.biggest;
          final inner = Padding(
            padding: s.shape.safeInsets(size) + s.padding,
            child: child,
          );
          return CustomPaint(
            painter: PanelFillPainter(s),
            foregroundPainter: PanelBorderPainter(s),
            child: s.clip
                ? ClipPath(
                    clipper: PanelClipper(s.shape),
                    clipBehavior: Clip.antiAlias,
                    child: inner,
                  )
                : inner,
          );
        },
      );
    }
    if (rotation != 0) {
      panel = Transform.rotate(angle: rotation, child: panel);
    }
    return panel;
  }
}

/// Clips to a [PanelShape] outline.
class PanelClipper extends CustomClipper<Path> {
  const PanelClipper(this.shape);
  final PanelShape shape;

  @override
  Path getClip(Size size) => shape.pathFor(Offset.zero & size);

  @override
  bool shouldReclip(PanelClipper oldClipper) => oldClipper.shape != shape;
}

/// Paints a panel's shadows and fill.
class PanelFillPainter extends CustomPainter {
  const PanelFillPainter(this.style);
  final PanelStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final sh in style.shadows) {
      final path = style.shape
          .pathFor(rect.inflate(sh.spreadRadius))
          .shift(sh.offset);
      canvas.drawPath(
        path,
        Paint()
          ..color = sh.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sh.blurSigma),
      );
    }
    final g = style.gradient;
    final c = style.color;
    if (g == null && c == null) return;
    final paint = Paint()..isAntiAlias = true;
    if (g != null) {
      paint.shader = g.createShader(rect);
    } else {
      paint.color = c!;
    }
    canvas.drawPath(style.shape.pathFor(rect), paint);
  }

  @override
  bool shouldRepaint(PanelFillPainter old) => old.style != style;
}

/// Paints a panel's border(s) above its content.
class PanelBorderPainter extends CustomPainter {
  const PanelBorderPainter(this.style);
  final PanelStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = style.border;
    var inset = 0.0;
    if (outer != null && outer.width > 0) {
      canvas.drawPath(
        style.shape.pathFor(rect, inset: outer.width / 2),
        _stroke(outer),
      );
      inset = outer.width;
    }
    final inner = style.innerBorder;
    if (inner != null && inner.width > 0) {
      canvas.drawPath(
        style.shape.pathFor(
          rect,
          inset: inset + style.innerBorderGap + inner.width / 2,
        ),
        _stroke(inner),
      );
    }
  }

  Paint _stroke(BorderSide s) => Paint()
    ..color = s.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = s.width
    ..strokeJoin = StrokeJoin.miter
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(PanelBorderPainter old) => old.style != style;
}
