import '../domain/models.dart';
import 'seed_reference.dart';

/// A fresh, unsaved poster for "تقويم جديد": first hijri month of 1448, no
/// days yet, the default texts and the default template. It is only written
/// to disk once the editor saves an edit.
MonthPoster newBlankPoster({DateTime? now}) {
  final t = now ?? DateTime.now();
  return MonthPoster(
    id: 'poster-${t.microsecondsSinceEpoch}',
    updatedAt: t,
    hijriMonthIndex: 0,
    hijriYear: 1448,
    texts: defaultTexts(),
    templateId: defaultTemplateId,
  );
}
