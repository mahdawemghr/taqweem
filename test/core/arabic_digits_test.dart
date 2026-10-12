import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/arabic_digits.dart';

void main() {
  test('normalizes Arabic-Indic and Persian digits', () {
    expect(normalizeDigits('٤١٨'), '418');
    expect(normalizeDigits('۱۱:۲۵'), '11:25');
    expect(normalizeDigits('5:27'), '5:27');
  });
}
