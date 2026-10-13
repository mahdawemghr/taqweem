import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Sanity checks for the transparent logo assets extracted from the mock-ups
/// by tool/extract_logos.py (see docs/design/logo-assets.md).
class _Spec {
  const _Spec(this.name, this.minWidth, this.minHeight, this.minCornerClear);
  final String name;
  final int minWidth;
  final int minHeight;

  /// Minimum fraction of fully transparent pixels in each 10 % corner box.
  final double minCornerClear;
}

const _assets = <_Spec>[
  _Spec('title_white', 800, 250, 0.95),
  _Spec('title_gold', 550, 200, 0.95),
  _Spec('title_navy', 250, 220, 0.95),
  _Spec('medallion_emerald', 400, 400, 0.95),
  _Spec('medallion_emerald_b', 400, 400, 0.95),
  _Spec('medallion_ivory', 350, 350, 0.95),
  _Spec('dome_green', 120, 120, 0.75),
  _Spec('finial_gold', 180, 250, 0.95),
];

/// PNG IHDR: bytes 16..23 = width, height (big endian); byte 25 = colour type
/// (6 = truecolour with alpha).
int _u32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

void main() {
  test('pubspec lists assets/logos/ under flutter assets', () {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final flutterAt = lines.indexOf('flutter:');
    expect(flutterAt, isNonNegative);
    final assetsAt = lines.indexOf('  assets:', flutterAt);
    expect(assetsAt, greaterThan(flutterAt));
    expect(lines.sublist(assetsAt + 1).takeWhile((l) => l.startsWith('    -')),
        contains('    - assets/logos/'));
  });

  for (final spec in _assets) {
    testWidgets('${spec.name}.png is an RGBA PNG with a clean cut',
        (tester) async {
      final file = File('assets/logos/${spec.name}.png');
      expect(file.existsSync(), isTrue, reason: '${file.path} missing');
      final bytes = file.readAsBytesSync();
      expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
      expect(bytes[25], 6, reason: 'colour type must be RGBA');
      final w = _u32(bytes, 16);
      final h = _u32(bytes, 20);
      expect(w, greaterThanOrEqualTo(spec.minWidth));
      expect(h, greaterThanOrEqualTo(spec.minHeight));

      final rgba = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image
            .toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        frame.image.dispose();
        codec.dispose();
        return data!.buffer.asUint8List();
      });
      expect(rgba, isNotNull);
      expect(rgba!.length, w * h * 4);

      final cw = w ~/ 10;
      final ch = h ~/ 10;
      for (final (x0, y0) in [(0, 0), (w - cw, 0), (0, h - ch), (w - cw, h - ch)]) {
        var clear = 0;
        for (var y = y0; y < y0 + ch; y++) {
          for (var x = x0; x < x0 + cw; x++) {
            if (rgba[(y * w + x) * 4 + 3] == 0) clear++;
          }
        }
        expect(clear / (cw * ch), greaterThanOrEqualTo(spec.minCornerClear),
            reason: 'corner ($x0,$y0) of ${spec.name} not transparent enough');
      }

      // Not an empty cut: some fully opaque artwork must remain.
      var opaque = 0;
      for (var i = 3; i < rgba.length; i += 4) {
        if (rgba[i] == 255) opaque++;
      }
      expect(opaque / (w * h), greaterThan(0.08));
    });
  }
}
