import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show mapEquals, setEquals;
import 'package:flutter/widgets.dart';

import 'logo_art.dart';
import 'logo_paths.dart';
import 'svg_path.dart';

export 'logo_art.dart';
export 'logo_paths.dart';

/// The brand name the logos spell (semantic label of every logo widget).
const brandName = 'تقويم أهل البيت';

/// Brand palette (sampled from the traced artwork; see brand/README.md).
abstract final class BrandColors {
  /// Emerald disc of the medallion (mid-radius tone).
  static const emerald = Color(0xFF08342C);

  /// Deep emerald (disc rim / app-icon background).
  static const emeraldDeep = Color(0xFF082623);

  /// Medallion gold (ring mid tone).
  static const gold = Color(0xFFC9A45E);

  /// Light calligraphy gold.
  static const goldLight = Color(0xFFD8B977);

  /// Gold of the accent marks of the two-tone title.
  static const goldAccent = Color(0xFFAD9767);

  /// Off-white of the two-tone title.
  static const white = Color(0xFFFBFDFD);

  /// Ivory medallion paper / navy calligraphy.
  static const ivory = Color(0xFFF9F9F4);
  static const navy = Color(0xFF142139);
}

/// The two traced title calligraphies.
enum BrandTitleStyle {
  /// Wide one-line title: off-white letters, gold accent marks
  /// (from the navy calligraphy mock-up; `brand/svg/title_two_tone.svg`).
  twoTone,

  /// Gilded one-line title with its light-to-deep gold gradient
  /// (from the midnight mock-up; `brand/svg/title_gold.svg`).
  gold,
}

/// The three traced medallions.
enum BrandMedallionStyle {
  /// Emerald disc, single gold ring, gold calligraphy.
  emerald,

  /// Emerald disc, gold double ring, gold calligraphy and seal.
  emeraldDouble,

  /// Ivory disc with pale arabesque, navy and gold rings, gold / navy
  /// calligraphy.
  ivory,
}

/// Paints a [LogoArt] scaled with [BoxFit.contain] and centred in the
/// paint area.
///
/// Parsed paths and gradient shaders are cached per art + layer for the
/// lifetime of the app (they live in view-box coordinates, so they do not
/// depend on the paint size); a paint is only a few `drawPath` calls.
/// [shouldRepaint] is false unless the configuration changed, so a logo is
/// painted once and then reused (put it under a `RepaintBoundary` to cache
/// its raster too; `CustomPaint.isComplex` is set by [BrandLogo]).
class BrandLogoPainter extends CustomPainter {
  const BrandLogoPainter(
    this.art, {
    this.colors = const {},
    this.hidden = const {},
    this.tint,
  });

  final LogoArt art;

  /// Flat colours per layer id, replacing the layer's own colour/gradient.
  final Map<String, Color> colors;

  /// Layer ids not painted.
  final Set<String> hidden;

  /// Paints every (visible) layer in this one colour.
  final Color? tint;

  static final _paths = <String, ui.Path>{};
  static final _shaders = <String, ui.Shader>{};

  /// The (cached) path of [layer] of [art], in view-box coordinates.
  static ui.Path pathOf(LogoArt art, LogoLayer layer) => _paths.putIfAbsent(
    '${art.id}/${layer.id}',
    () => parseSvgPath(layer.pathData),
  );

  static ui.Shader _shaderOf(LogoArt art, LogoLayer layer) {
    final g = layer.gradient!;
    return _shaders.putIfAbsent('${art.id}/${layer.id}', () {
      if (g.isRadial) {
        return ui.Gradient.radial(g.center!, g.radius!, g.colors, g.stops);
      }
      return ui.Gradient.linear(g.from!, g.to!, g.colors, g.stops);
    });
  }

  /// The view-box -> paint-area mapping for [size] (contain, centred):
  /// `(scale, offset)`.
  static (double, Offset) fit(LogoArt art, Size size) {
    final sx = size.width / art.width, sy = size.height / art.height;
    final s = sx < sy ? sx : sy;
    return (
      s,
      Offset(
        (size.width - art.width * s) / 2,
        (size.height - art.height * s) / 2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    final (scale, offset) = fit(art, size);
    canvas
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
    final paint = Paint()..isAntiAlias = true;
    for (final layer in art.layers) {
      if (hidden.contains(layer.id)) continue;
      final flat = tint ?? colors[layer.id];
      if (flat != null) {
        paint
          ..shader = null
          ..color = flat;
      } else if (layer.gradient != null) {
        paint
          ..color = const Color(0xFF000000)
          ..shader = _shaderOf(art, layer);
      } else {
        paint
          ..shader = null
          ..color = layer.color;
      }
      canvas.drawPath(pathOf(art, layer), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandLogoPainter oldDelegate) =>
      oldDelegate.art.id != art.id ||
      oldDelegate.tint != tint ||
      !mapEquals(oldDelegate.colors, colors) ||
      !setEquals(oldDelegate.hidden, hidden);
}

/// A vector logo widget: [art] painted with [BrandLogoPainter].
///
/// Sizing: [width] / [height] when given (one of them derives the other
/// from the art's aspect ratio), otherwise the art's own view-box size,
/// constrained by the parent (tight constraints, e.g. `Positioned.fill`,
/// fill the box and the art is contain-fitted and centred inside it).
class BrandLogo extends StatelessWidget {
  const BrandLogo(
    this.art, {
    super.key,
    this.width,
    this.height,
    this.colors = const {},
    this.hidden = const {},
    this.tint,
    this.semanticLabel = brandName,
  });

  final LogoArt art;
  final double? width, height;
  final Map<String, Color> colors;
  final Set<String> hidden;
  final Color? tint;

  /// Null excludes the logo from semantics (decorative use).
  final String? semanticLabel;

  Size get _size {
    final w = width, h = height;
    if (w != null && h != null) return Size(w, h);
    if (w != null) return Size(w, w / art.aspectRatio);
    if (h != null) return Size(h * art.aspectRatio, h);
    return Size(art.width, art.height);
  }

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: _size,
      isComplex: true,
      painter: BrandLogoPainter(
        art,
        colors: colors,
        hidden: hidden,
        tint: tint,
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(label: label, image: true, child: paint);
  }
}

/// The calligraphic title «تقويم أهل البيت» as vector art.
///
/// [color] recolours the letters (twoTone: the off-white body; gold: the
/// whole title, replacing the gradient); [accentColor] recolours the
/// twoTone accent marks (defaults to the brand gold; pass the same colour
/// as [color] for a one-colour title).
class BrandTitle extends StatelessWidget {
  const BrandTitle({
    super.key,
    this.style = BrandTitleStyle.twoTone,
    this.color,
    this.accentColor,
    this.width,
    this.height,
    this.semanticLabel = brandName,
  });

  final BrandTitleStyle style;
  final Color? color, accentColor;
  final double? width, height;
  final String? semanticLabel;

  LogoArt get art => switch (style) {
    BrandTitleStyle.twoTone => logoTitleTwoTone,
    BrandTitleStyle.gold => logoTitleGold,
  };

  Map<String, Color> get _colors {
    final c = color, a = accentColor;
    return switch (style) {
      BrandTitleStyle.twoTone => {'body': ?c, 'accent': ?a},
      BrandTitleStyle.gold => {'gold': ?c},
    };
  }

  @override
  Widget build(BuildContext context) => BrandLogo(
    art,
    width: width,
    height: height,
    colors: _colors,
    semanticLabel: semanticLabel,
  );
}

/// A full-colour medallion (disc, ring(s), calligraphy) as vector art.
class BrandMedallion extends StatelessWidget {
  const BrandMedallion({
    super.key,
    this.style = BrandMedallionStyle.emerald,
    this.size,
    this.semanticLabel = brandName,
  });

  final BrandMedallionStyle style;

  /// Diameter (the art's padded square box); null = parent / natural size.
  final double? size;
  final String? semanticLabel;

  LogoArt get art => switch (style) {
    BrandMedallionStyle.emerald => logoMedallionEmerald,
    BrandMedallionStyle.emeraldDouble => logoMedallionEmeraldDouble,
    BrandMedallionStyle.ivory => logoMedallionIvory,
  };

  @override
  Widget build(BuildContext context) =>
      BrandLogo(art, width: size, height: size, semanticLabel: semanticLabel);
}

/// The one-colour brand mark: the emerald medallion's ring and calligraphy
/// in [color] on a transparent ground (no disc) — for watermarks,
/// monochrome / themed app icons, stamps and small sizes on any background.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.color = BrandColors.gold,
    this.size,
    this.semanticLabel = brandName,
  });

  final Color color;
  final double? size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => BrandLogo(
    logoMedallionEmerald,
    width: size,
    height: size,
    hidden: const {'disc'},
    tint: color,
    semanticLabel: semanticLabel,
  );
}
