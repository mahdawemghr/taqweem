// Renders the brand kit PNGs (brand/png/*.png, 2048 px on the long side)
// from the same vector painter the app uses. Skipped by default (tag
// `brand-export`, see dart_test.yaml); regenerate with
//   flutter test --run-skipped --tags brand-export test/brand/brand_export_test.dart
@Tags(['brand-export'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/brand/brand_logo.dart';

const _long = 2048.0;

Future<void> _export(
  WidgetTester tester,
  String name,
  BrandLogoPainter painter,
) async {
  final art = painter.art;
  final s = _long / (art.width > art.height ? art.width : art.height);
  final size = Size(
    (art.width * s).roundToDouble(),
    (art.height * s).roundToDouble(),
  );
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), size);
  final picture = rec.endRecording();
  final bytes = await tester.runAsync(() async {
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data!.buffer.asUint8List();
  });
  picture.dispose();
  final file = File('brand/png/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
}

void main() {
  testWidgets('export brand/png', (tester) async {
    await _export(
      tester,
      'title_two_tone',
      const BrandLogoPainter(logoTitleTwoTone),
    );
    await _export(tester, 'title_gold', const BrandLogoPainter(logoTitleGold));
    await _export(
      tester,
      'title_white_mono',
      const BrandLogoPainter(logoTitleTwoTone, tint: BrandColors.white),
    );
    await _export(
      tester,
      'medallion_emerald',
      const BrandLogoPainter(logoMedallionEmerald),
    );
    await _export(
      tester,
      'medallion_emerald_double',
      const BrandLogoPainter(logoMedallionEmeraldDouble),
    );
    await _export(
      tester,
      'medallion_ivory',
      const BrandLogoPainter(logoMedallionIvory),
    );
    await _export(
      tester,
      'mark_gold',
      const BrandLogoPainter(
        logoMedallionEmerald,
        hidden: {'disc'},
        tint: BrandColors.gold,
      ),
    );
    await _export(
      tester,
      'mark_white',
      const BrandLogoPainter(
        logoMedallionEmerald,
        hidden: {'disc'},
        tint: Color(0xFFFFFFFF),
      ),
    );
    expect(File('brand/png/medallion_emerald.png').existsSync(), isTrue);
  });
}
