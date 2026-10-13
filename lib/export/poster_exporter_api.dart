import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'poster_exporter.dart';

/// The export operations the UI needs, as an injectable seam so widget tests
/// never touch the disk or the engine capture.
abstract class PosterExporterApi {
  Future<Uint8List> toPng(GlobalKey key, {double pixelRatio});
  Future<Uint8List> toPdf(Uint8List png, {PdfPageSize size});
  Future<File> saveBytes(Uint8List bytes, String fileName);
  Future<void> share(File file, {Rect? sharePositionOrigin});
  String fileNameFor(MonthPoster p, String ext, {String? suffix});
}

/// Default implementation: delegates to the static [PosterExporter].
class DefaultPosterExporter implements PosterExporterApi {
  const DefaultPosterExporter();

  @override
  Future<Uint8List> toPng(GlobalKey key, {double pixelRatio = 3}) =>
      PosterExporter.toPng(key, pixelRatio: pixelRatio);

  @override
  Future<Uint8List> toPdf(Uint8List png, {PdfPageSize size = PdfPageSize.a4}) =>
      PosterExporter.toPdf(png, size: size);

  @override
  Future<File> saveBytes(Uint8List bytes, String fileName) =>
      PosterExporter.saveBytes(bytes, fileName);

  @override
  Future<void> share(File file, {Rect? sharePositionOrigin}) =>
      PosterExporter.share(file, sharePositionOrigin: sharePositionOrigin);

  @override
  String fileNameFor(MonthPoster p, String ext, {String? suffix}) =>
      PosterExporter.fileNameFor(p, ext, suffix: suffix);
}

final posterExporterProvider = Provider<PosterExporterApi>(
  (ref) => const DefaultPosterExporter(),
);
