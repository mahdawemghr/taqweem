import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fam = {
    'Amiri': ['Amiri-Regular.ttf', 'Amiri-Bold.ttf'],
    'Tajawal': ['Tajawal-Regular.ttf', 'Tajawal-Bold.ttf'],
    'ArefRuqaa': ['ArefRuqaa-Regular.ttf', 'ArefRuqaa-Bold.ttf'],
  };
  for (final e in fam.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }
}
