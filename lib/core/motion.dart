import 'package:flutter/widgets.dart';

/// Motion tokens. Everything animated in the app uses these so the feel is
/// consistent and can be switched off in one place.
///
/// Rules: transform + opacity only, 90–360 ms (the launch reveal is the one
/// longer moment), nothing loops, nothing inside a poster template, and
/// nothing animates a whole poster widget (use cached rasters).
abstract final class Motion {
  /// Global multiplier (tests set it to 0 in `flutter_test_config.dart`;
  /// motion tests set it back to 1).
  static double scale = 1;

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration emphasised = Duration(milliseconds: 360);
  static const Duration reveal = Duration(milliseconds: 1100);

  /// Enter / exit / emphasised curves.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emph = Cubic(0.05, 0.7, 0.1, 1);

  /// Whether animations are on for [context] (the platform's reduce-motion /
  /// `disableAnimations` setting and the global [scale] both count).
  static bool enabled(BuildContext context) =>
      scale > 0 && !MediaQuery.disableAnimationsOf(context);

  /// [d] scaled for [context]: zero when motion is off.
  static Duration of(BuildContext context, Duration d) =>
      enabled(context) ? d * scale : Duration.zero;
}
