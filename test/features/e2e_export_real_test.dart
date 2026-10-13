import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';
import 'package:taqweem/templates/registry.dart';

import '../test_helpers/load_fonts.dart';
import '../test_helpers/precache.dart';

void main() {
  setUpAll(loadAppFonts);

  late Directory tmp;
  final originalDocs = PosterExporter.documentsDirectory;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('taqweem_export_');
    PosterExporter.documentsDirectory = () async => tmp;
  });
  tearDown(() {
    PosterExporter.documentsDirectory = originalDocs;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  for (final t in allTemplates) {
    testWidgets('real export of ${t.id}: PNG 2000x4400 + PDF + saved', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);
      final poster = seedReferenceMonth().copyWith(templateId: t.id);
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1000, 2200)),
            child: PosterPreview(poster: poster, boundaryKey: key),
          ),
        ),
      );
      await tester.pump();
      // What StepExport does before capturing: decode the logos + a frame.
      await precacheTemplate(tester, t);

      final result = await tester.runAsync(() async {
        final png = await PosterExporter.toPng(key, pixelRatio: 2);
        final pdf = await PosterExporter.toPdf(png);
        final pngFile = await PosterExporter.saveBytes(
          png,
          PosterExporter.fileNameFor(poster, 'png', suffix: t.id),
        );
        final pdfFile = await PosterExporter.saveBytes(
          pdf,
          PosterExporter.fileNameFor(poster, 'pdf', suffix: t.id),
        );
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        final size = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
        if (t.id == 'mosque_blue') {
          await File(
            '/tmp/claude-1000/-home-mahdi-Desktop-projects-taqweem/'
            '324928d2-35bd-48cd-a591-4d5cfcdf8bd1/scratchpad/e2e-mosque.png',
          ).writeAsBytes(png);
        }
        return (png, pdf, pngFile, pdfFile, size);
      });
      final (png, pdf, pngFile, pdfFile, size) = result!;
      expect(
        png.sublist(0, 8),
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );
      expect(size, const Size(2000, 4400));
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
      expect(
        pngFile.existsSync() && pngFile.lengthSync() == png.length,
        isTrue,
      );
      expect(
        pdfFile.existsSync() && pdfFile.lengthSync() == pdf.length,
        isTrue,
      );
      expect(pngFile.path, startsWith(tmp.path));
    });
  }
}
