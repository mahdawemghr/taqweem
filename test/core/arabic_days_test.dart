import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/arabic_days.dart';

void main() {
  test('number agreement of «يوم»', () {
    expect(arabicDays(1), 'يوم واحد');
    expect(arabicDays(2), 'يومين');
    for (var n = 3; n <= 10; n++) {
      expect(arabicDays(n), '$n أيام', reason: '$n');
    }
    for (final n in [11, 12, 21, 29, 30, 100]) {
      expect(arabicDays(n), '$n يوماً', reason: '$n');
    }
  });

  test('zero and negative stay grammatical', () {
    expect(arabicDays(0), '0 يوماً');
  });
}
