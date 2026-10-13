import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/time_format.dart';
import 'package:taqweem/features/editor/invalid_times.dart';

void main() {
  test('pruneFrom drops entries with row index >= n only', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(invalidTimesProvider.notifier);
    n.put(0, PrayerSlot.fajr, 'a');
    n.put(28, PrayerSlot.zuhr, 'b');
    n.put(29, PrayerSlot.fajr, 'c');
    n.put(31, PrayerSlot.zuhr, 'd');
    n.pruneFrom(29);
    expect(c.read(invalidTimesProvider), {
      (0, PrayerSlot.fajr): 'a',
      (28, PrayerSlot.zuhr): 'b',
    });
  });
}
