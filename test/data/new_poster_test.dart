import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/new_poster.dart';
import 'package:taqweem/data/seed_reference.dart';

void main() {
  test('newBlankPoster has a fresh safe id and blank defaults', () {
    final now = DateTime(2026, 10, 12, 9);
    final p = newBlankPoster(now: now);
    expect(p.id, 'poster-${now.microsecondsSinceEpoch}');
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p.id), isTrue);
    expect(p.updatedAt, now);
    expect(p.templateId, 'navy_gold');
    expect(p.hijriMonthIndex, 0);
    expect(p.hijriYear, 1448);
    expect(p.days, isEmpty);
    expect(p.texts.toJson(), defaultTexts().toJson());
  });

  test('two calls without a clock give different ids', () async {
    final a = newBlankPoster();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(newBlankPoster().id, isNot(a.id));
  });
}
