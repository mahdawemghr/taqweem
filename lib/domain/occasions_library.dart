import 'shia_occasion.dart';
import 'shia_occasions_lookup.dart';

/// Shia-relevant notes from the reference scans, verbatim; scholar/Sunni/
/// unrelated entries removed per project rule.
const List<String> occasionSuggestions = [
  // جمادى الأول 1448 (9.09.58 PM)
  'بدأ نزول الوحي على النبي محمد(ص)',
  'مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة',
  'غزوة مؤته8هـ',
  'هدم مسجد رد الشمس لأمير المؤمنين(ع)في المدينة1422هـ',
  'حرب الجمل 36هـ - اعطاء الزهراء القميص لأبنتها حتى تعطيه الحسين(ع)',
  'وفاة النبي شيث(ع)',
  'وفاة عبدا... بن عبدالمطلب والد الرسول الأكرم(ص)',
  'ذكرى استشهاد سيدة نساء العالمين فاطمة الزهراء(ع)11هـ',
  'فتح البصرة على يدالإمام علي بن أبي طالب(ع)',
  'غزوة ذات الرقاع 4هـ',
  'ولادة ذوالقرنين - بدء نزول الألواح على النبي موسى(ع)',
  'مقتل زيد بن صوحان36هـ',
  'استشهاد الصحابي الجليل زيد بن صوحان',
  'وفاة القاسم ابن الامام موسى الكاظم(ع)192هـ',
  'ولادة النبي صالح (ع)',
  'تفجير ماذنتي حرم الامامين الهادي والعسكري1428هـ',
  'وفاة السفير الثاني محمد بن عثمان304هـ',
  'ولادة النبي إسماعيل(ع)',
  // صفر 1448 (9.09.59 PM(1)) — rows re-verified at 4x, exactly as printed
  'ذكرى استشهاد الإمام المجتبى (ع)50هـ ومولد الإمام الكاظم (ع)128هـ',
  'شهادة محمد بن أبي بكر(رض)في مصر38هـ',
  'ذكرى استشهاد الإمام علي بن موسى الرضا (ع) 203هـ',
  'شهادة أويس القرني(رض)في صفين',
];

/// Suggestions containing [query] (trimmed substring match), at most 8.
List<String> searchOccasions(String query) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return occasionSuggestions.where((s) => s.contains(q)).take(8).toList();
}

/// What the note field suggests while typing [query]: the Shia occasions
/// database first (as printed, [ShiaOccasion.noteText]), then the cleaned
/// [occasionSuggestions]; normalised duplicates once, at most [limit].
List<String> searchNoteSuggestions(String query, {int limit = 5}) {
  if (query.trim().isEmpty || limit <= 0) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final s in [
    for (final o in searchShiaOccasions(query, limit: limit * 4)) o.noteText,
    ...searchOccasions(query),
  ]) {
    if (out.length >= limit) break;
    if (seen.add(normalizeArabic(s))) out.add(s);
  }
  return out;
}
