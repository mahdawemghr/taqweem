import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/relative_time.dart';

void main() {
  final now = DateTime(2026, 10, 12, 15, 30);
  String ago(Duration d) => relativeTimeAr(now.subtract(d), now);

  test('under a minute (and future times) is الآن', () {
    expect(ago(Duration.zero), 'الآن');
    expect(ago(const Duration(seconds: 59)), 'الآن');
    expect(relativeTimeAr(now.add(const Duration(hours: 2)), now), 'الآن');
  });

  test('minutes use singular / dual / plural / counted-singular forms', () {
    expect(ago(const Duration(minutes: 1)), 'قبل دقيقة');
    expect(ago(const Duration(minutes: 2)), 'قبل دقيقتين');
    expect(ago(const Duration(minutes: 3)), 'قبل 3 دقائق');
    expect(ago(const Duration(minutes: 10)), 'قبل 10 دقائق');
    expect(ago(const Duration(minutes: 11)), 'قبل 11 دقيقة');
    expect(ago(const Duration(minutes: 59)), 'قبل 59 دقيقة');
  });

  test('hours on the same day', () {
    expect(ago(const Duration(hours: 1)), 'قبل ساعة');
    expect(ago(const Duration(hours: 2)), 'قبل ساعتين');
    expect(ago(const Duration(hours: 3)), 'قبل 3 ساعات');
    expect(ago(const Duration(hours: 10)), 'قبل 10 ساعات');
    final late = DateTime(2026, 10, 12, 23, 50);
    expect(relativeTimeAr(DateTime(2026, 10, 12, 0, 10), late), 'قبل 23 ساعة');
  });

  test('previous calendar day is أمس, even if under 24 hours', () {
    expect(relativeTimeAr(DateTime(2026, 10, 11, 23, 0), DateTime(2026, 10, 12, 1, 0)),
        'أمس');
    expect(relativeTimeAr(DateTime(2026, 10, 11, 8, 0), now), 'أمس');
  });

  test('days: dual then plural up to a week', () {
    expect(relativeTimeAr(DateTime(2026, 10, 10, 9), now), 'قبل يومين');
    expect(relativeTimeAr(DateTime(2026, 10, 9, 9), now), 'قبل 3 أيام');
    expect(relativeTimeAr(DateTime(2026, 10, 6, 9), now), 'قبل 6 أيام');
  });

  test('a week or older shows yyyy/MM/dd', () {
    expect(relativeTimeAr(DateTime(2026, 10, 5, 9), now), '2026/10/05');
    expect(relativeTimeAr(DateTime(2025, 1, 2), now), '2025/01/02');
  });

  test('UTC timestamps are compared in local time', () {
    final utcNow = now.toUtc();
    expect(relativeTimeAr(utcNow.subtract(const Duration(minutes: 2)), now),
        'قبل دقيقتين');
  });
}
