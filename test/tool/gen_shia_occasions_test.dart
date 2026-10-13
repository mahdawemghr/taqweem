import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> gen(String out, {String? convention}) => Process.run(
  'python3',
  [
    '-I',
    'tool/gen_shia_occasions.py',
    '--out',
    out,
    if (convention != null) ...['--convention', convention],
  ],
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('gen_shia_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, dynamic> readConv() =>
      jsonDecode(File('docs/shia-occasions/convention.json').readAsStringSync())
          as Map<String, dynamic>;

  Future<ProcessResult> genWith(Map<String, dynamic> conv, String name) {
    final f = File('${tmp.path}/$name.json')
      ..writeAsStringSync(jsonEncode(conv));
    return gen('${tmp.path}/out_$name', convention: f.path);
  }

  test('output is byte-identical to lib/data/shia_occasions.dart', () async {
    final r = await gen('${tmp.path}/a');
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(
      File('${tmp.path}/a/shia_occasions.dart').readAsBytesSync(),
      File('lib/data/shia_occasions.dart').readAsBytesSync(),
    );
    expect(
      File('${tmp.path}/a/DATA-SUMMARY.md').readAsBytesSync(),
      File('docs/shia-occasions/DATA-SUMMARY.md').readAsBytesSync(),
    );
  });

  test('idempotent: two runs give identical files', () async {
    await gen('${tmp.path}/a');
    await gen('${tmp.path}/b');
    expect(
      File('${tmp.path}/a/shia_occasions.dart').readAsBytesSync(),
      File('${tmp.path}/b/shia_occasions.dart').readAsBytesSync(),
    );
  });

  test('a swap that matches no entry fails loudly', () async {
    final c = readConv();
    ((c['swaps'] as List).first['main'] as Map)['titleContains'] = 'لا يوجد';
    final r = await genWith(c, 'noswap');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('swaps[0]'));
  });

  test('an addSources reference matching 0 entries fails loudly', () async {
    final c = readConv();
    (c['addSources'] as List).first['titleContains'] = 'لا يوجد';
    final r = await genWith(c, 'noadd');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('addSources[0]'));
  });

  test('an ambiguous reference (>1 match) fails loudly', () async {
    final c = readConv();
    // 2/9 has two entries; a one-letter needle matches both.
    (c['addSources'] as List).add({
      'month': 2,
      'day': 9,
      'titleContains': 'ا',
      'source': (c['addSources'] as List).first['source'],
    });
    final r = await genWith(c, 'ambig');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('2 entries'));
  });

  test('an alternate without alternateNoteAr is an error', () async {
    final c = readConv();
    final alt = (c['scanOnly'] as List).firstWhere(
      (e) => e['variant'] == 'alternate',
    );
    (alt as Map).remove('alternateNoteAr');
    final r = await genWith(c, 'nonote');
    expect(r.exitCode, isNot(0));
  });

  test('a titleFix whose text is not found fails loudly', () async {
    final c = readConv();
    (c['titleFixes'] as List).first['from'] = 'نص غير موجود';
    final r = await genWith(c, 'nofix');
    expect(r.exitCode, isNot(0));
  });

  test('scan-only titles must be verbatim in the scan row', () async {
    final c = readConv();
    (c['scanOnly'] as List).firstWhere(
      (e) => (e['titleSource'] ?? 'scan') == 'scan',
    )['titleAr'] = 'عنوان مختلف';
    final r = await genWith(c, 'notverbatim');
    expect(r.exitCode, isNot(0));
  });

  test('a structurally broken convention file exits non-zero', () async {
    final f = File('${tmp.path}/bad.json')..writeAsStringSync('{"swaps": 3}');
    final r = await gen('${tmp.path}/outbad', convention: f.path);
    expect(r.exitCode, isNot(0));
  });
}
