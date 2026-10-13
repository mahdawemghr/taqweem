import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/domain/occasions_library.dart';
import 'package:taqweem/domain/shia_occasions_lookup.dart';

void main() {
  test('Shia DB note texts first, then the cleaned library, max 5', () {
    final r = searchNoteSuggestions('الزهراء');
    expect(r.length, lessThanOrEqualTo(5));
    final db = searchShiaOccasions('الزهراء', limit: 100)
        .map((o) => o.noteText)
        .toList();
    expect(db, isNotEmpty);
    expect(r.first, db.first);
  });

  test('library entries follow when the DB has few hits', () {
    // Only in the cleaned library (from the reference scan).
    final r = searchNoteSuggestions('الممرضة');
    expect(r, contains('مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة'));
  });

  test('normalised duplicates appear once; empty query gives nothing', () {
    final r = searchNoteSuggestions('ال', limit: 50);
    final keys = r.map(normalizeArabic).toList();
    expect(keys.toSet().length, keys.length);
    expect(searchNoteSuggestions('  '), isEmpty);
  });

  test('searchOccasions keeps its behaviour', () {
    expect(searchOccasions('ال').length, 8);
    expect(searchOccasions(''), isEmpty);
  });
}
