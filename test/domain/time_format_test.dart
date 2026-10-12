import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/time_format.dart';

void main() {
  group('formatTime', () {
    test('no leading zero', () {
      expect(formatTime(4 * 60 + 18), '4:18');
      expect(formatTime(11 * 60 + 5), '11:05');
      expect(formatTime(null), isNull);
    });
  });
  group('parseTimeInput', () {
    test('colon, digits only, arabic digits', () {
      expect(parseTimeInput('4:18'), 4 * 60 + 18);
      expect(parseTimeInput('418'), 4 * 60 + 18);
      expect(parseTimeInput('1125'), 11 * 60 + 25);
      expect(parseTimeInput('٤١٨'), 4 * 60 + 18);
    });
    test('rejects garbage', () {
      expect(parseTimeInput('4:75'), isNull);
      expect(parseTimeInput('abc'), isNull);
      expect(parseTimeInput(''), isNull);
      expect(parseTimeInput('0:30'), isNull);
      expect(parseTimeInput('13:00'), isNull);
      expect(parseTimeInput('12345'), isNull);
    });
  });
  group('shiftMinutes', () {
    test('adds and wraps in 12h window', () {
      expect(shiftMinutes(4 * 60 + 58, 5), 5 * 60 + 3);
      expect(shiftMinutes(12 * 60 + 58, 5), 1 * 60 + 3);
      expect(shiftMinutes(1 * 60 + 2, -5), 12 * 60 + 57);
    });
  });
  group('to24h', () {
    test('zuhr 11:25 stays AM, 1:05 becomes PM; maghrib is PM', () {
      expect(to24h(PrayerSlot.fajr, 4 * 60 + 18), 4 * 60 + 18);
      expect(to24h(PrayerSlot.zuhr, 11 * 60 + 25), 11 * 60 + 25);
      expect(to24h(PrayerSlot.zuhr, 12 * 60 + 5), 12 * 60 + 5);
      expect(to24h(PrayerSlot.zuhr, 1 * 60 + 5), 13 * 60 + 5);
      expect(to24h(PrayerSlot.maghrib, 5 * 60 + 27), 17 * 60 + 27);
    });
  });
}
