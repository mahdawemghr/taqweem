import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/motion.dart';
import 'package:taqweem/core/motion_widgets.dart';
import 'package:taqweem/features/splash/launch_reveal.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: child,
  ),
);

class _Probe extends StatefulWidget {
  const _Probe(this.name, this.alive, {super.key});
  final String name;
  final Set<String> alive;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.alive.add(widget.name);
  }

  @override
  void dispose() {
    widget.alive.remove(widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.name);
}

void main() {
  setUp(() => Motion.scale = 1);
  tearDown(() => Motion.scale = 0);

  test('durations scale to zero when motion is off', () {
    Motion.scale = 0;
    expect(Motion.scale, 0);
  });

  testWidgets('Motion.of is zero under disableAnimations', (tester) async {
    late Duration on, off;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            on = Motion.of(c, Motion.base);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            off = Motion.of(c, Motion.base);
            return const SizedBox();
          },
        ),
        disableAnimations: true,
      ),
    );
    expect(on, Motion.base);
    expect(off, Duration.zero);
  });

  testWidgets('FadeThrough never builds two steps at once and settles', (
    tester,
  ) async {
    final alive = <String>{};
    Widget step(int i) => FadeThrough(
      token: i,
      child: _Probe('s$i', alive, key: ValueKey(i)),
    );
    await tester.pumpWidget(_host(step(0)));
    expect(alive, {'s0'});
    await tester.pumpWidget(_host(step(1)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(alive.length, lessThanOrEqualTo(1), reason: 'frame $i');
    }
    expect(alive, {'s1'});
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('FadeThrough swaps immediately with reduce-motion', (
    tester,
  ) async {
    final alive = <String>{};
    Widget step(int i) => FadeThrough(
      token: i,
      child: _Probe('s$i', alive, key: ValueKey(i)),
    );
    await tester.pumpWidget(_host(step(0), disableAnimations: true));
    await tester.pumpWidget(_host(step(1), disableAnimations: true));
    expect(alive, {'s1'});
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('launch reveal finishes within 1.1 s, then only Home remains', (
    tester,
  ) async {
    LaunchReveal.played = false;
    await tester.pumpWidget(_host(const LaunchReveal(child: Text('home'))));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pump(Motion.reveal + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(
      find.byType(ColoredBox).evaluate().where((e) {
        final w = e.widget as ColoredBox;
        return w.color == const Color(0xFF08342C);
      }),
      isEmpty,
    );
    // Plays once only.
    await tester.pumpWidget(_host(const LaunchReveal(child: Text('home2'))));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('launch reveal is skipped with reduce-motion', (tester) async {
    LaunchReveal.played = false;
    await tester.pumpWidget(
      _host(const LaunchReveal(child: Text('home')), disableAnimations: true),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('export stamp appears, then removes itself', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showSuccessStamp(ctx);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ScaleTransition), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('stamp and shake do nothing with reduce-motion', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const ShakeOnce(child: Text('x'));
          },
        ),
        disableAnimations: true,
      ),
    );
    showSuccessStamp(ctx);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('FadeScaleOut fades to nothing and settles', (tester) async {
    Widget host(bool out) =>
        _host(FadeScaleOut(out: out, child: const Text('card')));
    await tester.pumpWidget(host(false));
    await tester.pumpWidget(host(true));
    await tester.pump(Motion.quick + const Duration(milliseconds: 20));
    final o = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(o.opacity, 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('motion code avoids blur, backdrop filters and Opacity widgets', () {
    final files = [
      'lib/core/motion.dart',
      'lib/core/motion_widgets.dart',
      'lib/features/splash/launch_reveal.dart',
    ];
    for (final f in files) {
      final src = File(f).readAsStringSync();
      expect(src, isNot(contains('BackdropFilter')), reason: f);
      expect(src, isNot(contains('ImageFilter.blur')), reason: f);
      expect(RegExp(r'\bOpacity\(').hasMatch(src), isFalse, reason: f);
    }
  });
}
