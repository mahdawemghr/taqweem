import 'dart:async';
import 'dart:io';

import 'package:taqweem/core/motion.dart';

/// Animations are off by default in tests (durations scale to zero, so
/// `pumpAndSettle` and golden captures are unaffected). Motion tests call
/// `Motion.scale = 1` in a setUp and restore 0 in a tearDown.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // TAQWEEM_MOTION=1 runs the whole suite with animations on (stress check).
  Motion.scale = Platform.environment['TAQWEEM_MOTION'] == '1' ? 1 : 0;
  await testMain();
}
