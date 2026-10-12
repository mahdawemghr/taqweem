/// Short Arabic "last edited" text for [then] relative to [now] (both are
/// compared in local time):
///
/// * under a minute (or in the future): `الآن`
/// * minutes / hours (same day) with Arabic number agreement:
///   1 `قبل دقيقة`, 2 `قبل دقيقتين`, 3–10 `قبل 3 دقائق`, 11+ `قبل 11 دقيقة`
///   (same pattern for ساعة / ساعتين / ساعات)
/// * previous calendar day: `أمس`; then `قبل يومين`, `قبل 3 أيام` … 6 days
/// * otherwise the date as `yyyy/MM/dd`.
String relativeTimeAr(DateTime then, DateTime now) {
  final t = then.toLocal();
  final n = now.toLocal();
  final diff = n.difference(t);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) {
    return _counted(diff.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق');
  }
  final days = DateTime.utc(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  if (days == 0) return _counted(diff.inHours, 'ساعة', 'ساعتين', 'ساعات');
  if (days == 1) return 'أمس';
  if (days == 2) return 'قبل يومين';
  if (days < 7) return 'قبل $days أيام';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)}';
}

String _counted(int n, String one, String two, String few) {
  if (n == 1) return 'قبل $one';
  if (n == 2) return 'قبل $two';
  if (n <= 10) return 'قبل $n $few';
  return 'قبل $n $one';
}
