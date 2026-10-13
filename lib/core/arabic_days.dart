/// «N يوم» with correct Arabic number agreement: 1 → «يوم واحد»,
/// 2 → «يومين», 3–10 → «N أيام», 11 and above (and 0) → «N يوماً».
String arabicDays(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومين';
  if (n >= 3 && n <= 10) return '$n أيام';
  return '$n يوماً';
}
