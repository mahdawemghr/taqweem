import 'package:flutter/material.dart';

import '../../brand/brand_logo.dart';
import '../../core/motion.dart';

/// The app's one orchestrated moment: the native splash (flat emerald +
/// medallion) continues into a ≤1.1 s reveal — the medallion fades in, its
/// calligraphy is wiped on from right to left like a pen stroke, one gold
/// shimmer sweeps across it, then the emerald overlay fades away onto Home.
///
/// Never blocks startup (Home is built underneath, interactive once the
/// overlay is gone: the overlay ignores pointers). Plays once per process
/// ([played]); skipped with reduce-motion or when motion is off.
class LaunchReveal extends StatefulWidget {
  const LaunchReveal({super.key, required this.child});
  final Widget child;

  /// Set after the first reveal so a rebuilt app (hot restart aside) does not
  /// replay it.
  static bool played = false;

  @override
  State<LaunchReveal> createState() => _LaunchRevealState();
}

class _LaunchRevealState extends State<LaunchReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;
  bool _done = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || LaunchReveal.played) return;
    LaunchReveal.played = true;
    if (!Motion.enabled(context)) return;
    _done = false;
    _c =
        AnimationController(
            vsync: this,
            duration: Motion.of(context, Motion.reveal),
          )
          ..forward().whenComplete(() {
            if (mounted) setState(() => _done = true);
          });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_done || c == null) return widget.child;
    // Phases: 0–.5 fade-in + wipe, .4–.8 shimmer, .78–1 overlay fade-out.
    final overlayOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: c,
        curve: const Interval(0.78, 1, curve: Curves.easeInCubic),
      ),
    );
    final logoOpacity = CurvedAnimation(
      parent: c,
      curve: const Interval(0, 0.25, curve: Curves.easeOut),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: overlayOpacity,
                child: ColoredBox(
                  color: BrandColors.emerald,
                  child: Center(
                    child: FadeTransition(
                      opacity: logoOpacity,
                      child: LayoutBuilder(
                        builder: (context, box) => _Medallion(
                          progress: c,
                          size: (box.biggest.shortestSide * 0.5).clamp(
                            140.0,
                            280.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The medallion with a right-to-left wipe (clip only) and one soft gold
/// shimmer band (a shader over the small logo, never over a large surface).
class _Medallion extends StatelessWidget {
  const _Medallion({required this.progress, required this.size});
  final Animation<double> progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = RepaintBoundary(
      child: BrandMedallion(size: size, semanticLabel: null),
    );
    return AnimatedBuilder(
      animation: progress,
      child: logo,
      builder: (context, child) {
        final t = progress.value;
        final wipe = Motion.emph.transform((t / 0.5).clamp(0.0, 1.0));
        final shimmer = ((t - 0.4) / 0.4).clamp(0.0, 1.0);
        Widget w = child!;
        if (shimmer > 0 && shimmer < 1) {
          w = ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment(-1.6 + 3.2 * shimmer, -0.6),
              end: Alignment(-0.6 + 3.2 * shimmer, 0.6),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x66F3DFA2),
                Color(0x00FFFFFF),
              ],
            ).createShader(r),
            child: w,
          );
        }
        return ClipRect(clipper: _WipeClipper(wipe), child: w);
      },
    );
  }
}

/// Reveals the child from its right edge towards the left (reading order).
class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * (1 - fraction), 0, size.width, size.height);

  @override
  bool shouldReclip(_WipeClipper old) => old.fraction != fraction;
}
