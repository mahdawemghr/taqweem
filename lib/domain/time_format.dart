import '../core/arabic_digits.dart';

enum PrayerSlot {
  fajr('الفجر'),
  shurooq('الشروق'),
  zuhr('الظهر'),
  maghrib('المغرب');

  const PrayerSlot(this.labelAr);
  final String labelAr;
}

String? formatTime(int? minutes) {
  if (minutes == null) return null;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

int? parseTimeInput(String raw) {
  final s = normalizeDigits(raw.trim());
  if (s.isEmpty) return null;
  int h, m;
  if (s.contains(':')) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null || parts[1].length != 2) return null;
    h = hh;
    m = mm;
  } else {
    if (!RegExp(r'^\d{3,4}$').hasMatch(s)) return null;
    m = int.parse(s.substring(s.length - 2));
    h = int.parse(s.substring(0, s.length - 2));
  }
  if (h < 1 || h > 12 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

int shiftMinutes(int minutes, int delta) {
  const lo = 60, span = 720; // 1:00 .. 12:59
  return (((minutes + delta - lo) % span) + span) % span + lo;
}

int to24h(PrayerSlot slot, int minutes) {
  final h = minutes ~/ 60;
  switch (slot) {
    case PrayerSlot.fajr:
    case PrayerSlot.shurooq:
      return minutes;
    case PrayerSlot.zuhr:
      return h < 10 ? minutes + 720 : minutes; // 1:05 -> 13:05, 12:05 stays
    case PrayerSlot.maghrib:
      return h < 12 ? minutes + 720 : minutes;
  }
}
