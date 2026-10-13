import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';
import '../templates/poster_template.dart';

enum PdfPageSize { a4, a3, poster }

/// Thrown when a poster cannot be captured or encoded.
class ExportException implements Exception {
  const ExportException(this.message);
  final String message;
  @override
  String toString() => 'ExportException: $message';
}

class PosterExporter {
  PosterExporter._();

  /// Test seam: where exports are stored (`<dir>/exports/`).
  static Future<Directory> Function() documentsDirectory =
      getApplicationDocumentsDirectory;

  /// Test seam for the raw engine capture.
  static Future<ui.Image> Function(RenderRepaintBoundary, double) captureImage =
      _defaultCapture;

  static Future<ui.Image> _defaultCapture(
    RenderRepaintBoundary boundary,
    double ratio,
  ) => boundary.toImage(pixelRatio: ratio);

  /// Test/UI seam for the platform share sheet.
  static Future<void> Function(File file, {Rect? sharePositionOrigin})
  shareFile = _defaultShare;

  static Future<void> _defaultShare(
    File file, {
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Makes an on-screen poster of [template] ready for [toPng]: waits until
  /// the template's raster assets are decoded ([PosterTemplate.precache]),
  /// then for the frame that lays out and paints them. Call it right before
  /// every capture; a vector-only template only waits for the frame.
  static Future<void> prepareCapture(
    BuildContext context,
    PosterTemplate template,
  ) async {
    await template.precache(context);
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Captures the [RepaintBoundary] behind [boundaryKey] as PNG bytes.
  /// [pixelRatio] is clamped to 1..4 (NaN becomes 3). Engine failures (e.g.
  /// out of memory at high ratios) surface as [ExportException].
  static Future<Uint8List> toPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    final ratio = pixelRatio.isNaN ? 3.0 : pixelRatio.clamp(1.0, 4.0);
    final ro = boundaryKey.currentContext?.findRenderObject();
    if (ro == null) {
      throw const ExportException('Poster is not on screen; cannot export.');
    }
    if (ro is! RenderRepaintBoundary) {
      throw const ExportException('Export key is not on a RepaintBoundary.');
    }
    // Debug only: debugNeedsPaint is always false in release builds.
    for (var i = 0; i < 5 && ro.debugNeedsPaint; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    ui.Image? image;
    try {
      image = await captureImage(ro, ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const ExportException('Failed to encode poster as PNG.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on ExportException {
      rethrow;
    } catch (_) {
      throw ExportException(
        'Could not render the poster at ${ratio}x resolution; '
        'try a lower resolution.',
      );
    } finally {
      image?.dispose();
    }
  }

  static PdfPageFormat _format(PdfPageSize s) {
    switch (s) {
      case PdfPageSize.a4:
        return PdfPageFormat.a4.copyWith(
          marginLeft: 0,
          marginTop: 0,
          marginRight: 0,
          marginBottom: 0,
        );
      case PdfPageSize.a3:
        return PdfPageFormat.a3.copyWith(
          marginLeft: 0,
          marginTop: 0,
          marginRight: 0,
          marginBottom: 0,
        );
      case PdfPageSize.poster:
        return PdfPageFormat(
          kPosterSize.width * 0.75,
          kPosterSize.height * 0.75,
        );
    }
  }

  /// Wraps [png] in a one-page PDF, image centred with `BoxFit.contain`.
  static Future<Uint8List> toPdf(
    Uint8List png, {
    PdfPageSize size = PdfPageSize.a4,
  }) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageFormat: _format(size),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox.expand(
          child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      ),
    );
    return doc.save();
  }

  static final _safeName = RegExp(r'^[A-Za-z0-9_\-][A-Za-z0-9_.\-]*$');

  /// Writes [bytes] to `<documents>/exports/<fileName>`.
  static Future<File> saveBytes(Uint8List bytes, String fileName) async {
    if (fileName.isEmpty ||
        fileName.contains('..') ||
        !_safeName.hasMatch(fileName)) {
      throw ArgumentError.value(fileName, 'fileName', 'unsafe file name');
    }
    final base = await documentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}exports');
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> share(File file, {Rect? sharePositionOrigin}) =>
      shareFile(file, sharePositionOrigin: sharePositionOrigin);

  /// `taqweem-<hijriYear>-m<monthIndex+1>[-<suffix>].<ext>`, ASCII only.
  static String fileNameFor(MonthPoster p, String ext, {String? suffix}) {
    String clean(String s, RegExp keep) => s.replaceAll(keep, '');
    final e = clean(ext.toLowerCase(), RegExp(r'[^a-z0-9]'));
    final sfx = suffix == null ? '' : clean(suffix, RegExp(r'[^A-Za-z0-9_\-]'));
    return 'taqweem-${p.hijriYear}-m${p.hijriMonthIndex + 1}'
        '${sfx.isEmpty ? '' : '-$sfx'}${e.isEmpty ? '' : '.$e'}';
  }
}
