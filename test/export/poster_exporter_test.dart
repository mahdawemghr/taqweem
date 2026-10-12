import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/export/poster_exporter.dart';
import 'package:taqweem/features/preview/poster_preview.dart';

import '../test_helpers/load_fonts.dart';

const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Future<Uint8List> _tinyPng() async {
  final rec = ui.PictureRecorder();
  Canvas(rec)
      .drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = Colors.red);
  final img = await rec.endRecording().toImage(2, 2);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> _pumpPoster(WidgetTester tester, GlobalKey key) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetDevicePixelRatio);
  final poster = seedReferenceMonth().copyWith(templateId: 'navy_gold');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosterPreview(poster: poster, width: 1000, boundaryKey: key),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('fileNameFor', () {
    final p = seedReferenceMonth();
    test('ascii name from year and month index', () {
      expect(
        PosterExporter.fileNameFor(p, 'png'),
        'taqweem-${p.hijriYear}-m${p.hijriMonthIndex + 1}.png',
      );
    });
    test('suffix and ext sanitising', () {
      final n = PosterExporter.fileNameFor(p, '.PnG!', suffix: 'navy_gold');
      expect(
        n,
        'taqweem-${p.hijriYear}-m${p.hijriMonthIndex + 1}-navy_gold.png',
      );
      expect(RegExp(r'^[\x20-\x7E]+$').hasMatch(n), isTrue);
    });
  });

  group('toPdf', () {
    for (final s in PdfPageSize.values) {
      testWidgets('single page pdf for $s', (tester) async {
        final pdf = await tester.runAsync(
          () async => PosterExporter.toPdf(await _tinyPng(), size: s),
        );
        final text = String.fromCharCodes(pdf!);
        expect(text.startsWith('%PDF'), isTrue);
        expect(RegExp(r'/Type\s*/Page(?![s\w])').allMatches(text).length, 1);
      });
    }
  });

  group('toPdf page size', () {
    Future<List<double>> box(WidgetTester tester, PdfPageSize sz) async {
      final pdf = await tester.runAsync(
        () async => PosterExporter.toPdf(await _tinyPng(), size: sz),
      );
      final m = RegExp(
        r'/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\]',
      ).firstMatch(String.fromCharCodes(pdf!));
      expect(m, isNotNull);
      return [for (var i = 1; i <= 4; i++) double.parse(m!.group(i)!)];
    }

    testWidgets('a4 portrait', (tester) async {
      final b = await box(tester, PdfPageSize.a4);
      expect(b[2], closeTo(595.28, 0.1));
      expect(b[3], closeTo(841.89, 0.1));
      expect(b[3], greaterThan(b[2]));
    });
    testWidgets('a3 portrait', (tester) async {
      final b = await box(tester, PdfPageSize.a3);
      expect(b[2], closeTo(841.89, 0.1));
      expect(b[3], closeTo(1190.55, 0.1));
      expect(b[3], greaterThan(b[2]));
    });
    testWidgets('poster 750x1650', (tester) async {
      final b = await box(tester, PdfPageSize.poster);
      expect(b[2], closeTo(750, 0.1));
      expect(b[3], closeTo(1650, 0.1));
    });
  });

  group('capture seam', () {
    late Future<ui.Image> Function(RenderRepaintBoundary, double) original;
    setUp(() => original = PosterExporter.captureImage);
    tearDown(() => PosterExporter.captureImage = original);

    testWidgets('capture failure becomes ExportException naming the ratio', (
      tester,
    ) async {
      final key = GlobalKey();
      await _pumpPoster(tester, key);
      PosterExporter.captureImage = (_, _) async => throw StateError('oom');
      await expectLater(
        PosterExporter.toPng(key, pixelRatio: 4),
        throwsA(
          isA<ExportException>().having(
            (e) => e.message,
            'message',
            allOf(contains('4'), contains('lower')),
          ),
        ),
      );
    });

    final cases = {
      'NaN': (double.nan, 3.0),
      'infinity': (double.infinity, 4.0),
      'negative': (-2.0, 1.0),
    };
    for (final e in cases.entries) {
      testWidgets('pixelRatio ${e.key} -> ${e.value.$2}', (tester) async {
        final key = GlobalKey();
        await _pumpPoster(tester, key);
        double? seen;
        PosterExporter.captureImage = (_, r) async {
          seen = r;
          throw StateError('stop');
        };
        await expectLater(
          PosterExporter.toPng(key, pixelRatio: e.value.$1),
          throwsA(isA<ExportException>()),
        );
        expect(seen, e.value.$2);
      });
    }
  });

  group('toPng', () {
    testWidgets('3000x6600 at pixelRatio 3', (tester) async {
      final key = GlobalKey();
      await _pumpPoster(tester, key);
      final png = await tester.runAsync(() => PosterExporter.toPng(key));
      expect(png!.sublist(0, 8), _pngMagic);
      final img = await tester.runAsync(() => _decode(png));
      expect(img!.width, 3000);
      expect(img.height, 6600);
      img.dispose();
    });

    testWidgets('pixelRatio clamped to 1..4', (tester) async {
      final key = GlobalKey();
      await _pumpPoster(tester, key);
      final hi = await tester.runAsync(
        () => PosterExporter.toPng(key, pixelRatio: 9),
      );
      final lo = await tester.runAsync(
        () => PosterExporter.toPng(key, pixelRatio: 0),
      );
      final a = await tester.runAsync(() => _decode(hi!));
      final b = await tester.runAsync(() => _decode(lo!));
      expect(a!.width, 4000);
      expect(b!.width, 1000);
      a.dispose();
      b.dispose();
    });

    testWidgets('unattached key throws ExportException', (tester) async {
      await expectLater(
        PosterExporter.toPng(GlobalKey()),
        throwsA(isA<ExportException>()),
      );
    });

    testWidgets('non-boundary render object throws ExportException', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(SizedBox(key: key));
      await expectLater(
        PosterExporter.toPng(key),
        throwsA(isA<ExportException>()),
      );
    });
  });

  group('saveBytes', () {
    late Directory tmp;
    late Future<Directory> Function() original;
    setUp(() {
      original = PosterExporter.documentsDirectory;
      tmp = Directory.systemTemp.createTempSync('taqweem_export_');
      PosterExporter.documentsDirectory = () async => tmp;
    });
    tearDown(() {
      PosterExporter.documentsDirectory = original;
      tmp.deleteSync(recursive: true);
    });

    test('writes into <docs>/exports/', () async {
      final f = await PosterExporter.saveBytes(
        Uint8List.fromList([1, 2, 3]),
        'a.png',
      );
      expect(f.path, '${tmp.path}/exports/a.png');
      expect(f.readAsBytesSync(), [1, 2, 3]);
    });

    test('rejects unsafe names', () async {
      for (final n in ['../x', 'a/b.png', r'a\b.png', '', '..', 'a..b']) {
        await expectLater(
          PosterExporter.saveBytes(Uint8List(1), n),
          throwsArgumentError,
          reason: n,
        );
      }
      expect(
        Directory('${tmp.path}/exports').existsSync() &&
            Directory('${tmp.path}/exports').listSync().isNotEmpty,
        isFalse,
      );
    });
  });
}
