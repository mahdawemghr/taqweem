import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Sequential fade-through: when [token] changes the old child fades out
/// (90 ms), is REMOVED, and only then the new one is built and fades in
/// (160 ms, rising 8 px). Never two heavy subtrees at once. With motion off
/// the swap is immediate.
class FadeThrough extends StatefulWidget {
  const FadeThrough({super.key, required this.token, required this.child});

  /// Identifies which content is shown; a change starts the transition.
  final Object token;
  final Widget child;

  @override
  State<FadeThrough> createState() => _FadeThroughState();
}

class _FadeThroughState extends State<FadeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
  );
  late Widget _shown = widget.child;
  late Object _token = widget.token;
  bool _swapping = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FadeThrough old) {
    super.didUpdateWidget(old);
    if (_swapping) return; // the swap picks up the latest widget.child
    if (widget.token == _token) {
      _shown = widget.child;
    } else if (!Motion.enabled(context)) {
      _shown = widget.child;
      _token = widget.token;
    } else {
      _swapping = true;
      _c
          .animateBack(
            0,
            duration: Motion.of(context, Motion.instant),
            curve: Motion.exit,
          )
          .whenComplete(_swap);
    }
  }

  void _swap() {
    if (!mounted) return;
    setState(() {
      _shown = widget.child;
      _token = widget.token;
      _swapping = false;
    });
    _c.animateTo(
      1,
      duration: Motion.of(context, Motion.quick),
      curve: Motion.enter,
    );
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - _c.value)),
        child: child,
      ),
      child: _shown,
    ),
  );
}

/// Plays [child]'s entrance once: fade + scale from [from] (default 0.92).
/// Does not loop; renders at rest when motion is off.
class OneShotEntrance extends StatefulWidget {
  const OneShotEntrance({super.key, required this.child, this.from = 0.92});
  final Widget child;
  final double from;

  @override
  State<OneShotEntrance> createState() => _OneShotEntranceState();
}

class _OneShotEntranceState extends State<OneShotEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.enabled(context)) {
      _c.animateTo(
        1,
        duration: Motion.of(context, Motion.emphasised),
        curve: Motion.emph,
      );
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: ScaleTransition(
      scale: Tween<double>(begin: widget.from, end: 1).animate(_c),
      child: widget.child,
    ),
  );
}

/// Briefly shows a round check "stamp" over the app (export succeeded):
/// scales in over 300 ms, holds, fades out. Does nothing with motion off.
void showSuccessStamp(BuildContext context, {Color? color}) {
  if (!Motion.enabled(context)) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SuccessStamp(
      color: color ?? const Color(0xFF1E7B57),
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _SuccessStamp extends StatefulWidget {
  const _SuccessStamp({required this.color, required this.onDone});
  final Color color;
  final VoidCallback onDone;

  @override
  State<_SuccessStamp> createState() => _SuccessStampState();
}

class _SuccessStampState extends State<_SuccessStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.25, curve: Cubic(0.2, 1.4, 0.4, 1)),
    );
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 20),
    ]).animate(_c);
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.4, end: 1).animate(scale),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 16),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Icon(
                  IconData(0xe156, fontFamily: 'MaterialIcons'),
                  color: Color(0xFFFFFFFF),
                  size: 44,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shakes [child] horizontally once (300 ms) when built — for a failure
/// message. Static with motion off.
class ShakeOnce extends StatelessWidget {
  const ShakeOnce({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 300)),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 4) * 6 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// Fades and shrinks [child] (0.92×) over 160 ms when [out] turns true —
/// e.g. a card being deleted. Static with motion off.
class FadeScaleOut extends StatelessWidget {
  const FadeScaleOut({super.key, required this.out, required this.child});
  final bool out;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.quick);
    return AnimatedScale(
      scale: out ? 0.92 : 1,
      duration: d,
      curve: Motion.exit,
      child: AnimatedOpacity(
        opacity: out ? 0 : 1,
        duration: d,
        curve: Motion.exit,
        child: child,
      ),
    );
  }
}
