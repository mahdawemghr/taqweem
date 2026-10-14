import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/registry.dart';

void main() {
  test('registry order: grouped by colour family, navy_gold first', () {
    expect(allTemplates.map((t) => t.id).toList(), [
      'navy_gold',
      'navy_calligraphy',
      'midnight_dome',
      'mosque_blue',
      'deep_green',
      'emerald_mihrab',
      'emerald_garden',
      'cream_gold',
      'ivory_medallion',
      'minimal_modern',
    ]);
  });

  test('ids and Arabic names are unique; navy_gold is first and default', () {
    final ids = allTemplates.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(allTemplates.map((t) => t.nameAr).toSet().length, ids.length);
    expect(ids.first, 'navy_gold');
    expect(templateById('unknown-id').id, 'navy_gold');
  });
}
