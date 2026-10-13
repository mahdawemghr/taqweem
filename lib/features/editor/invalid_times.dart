import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/time_format.dart';

/// Time text the user typed that could not be parsed, per (row, slot).
///
/// Kept for the editor session (survives card recycling and step switches)
/// so an invalid entry is never silently dropped: the cell shows it again in
/// red, the validation chip counts it, and leaving the step warns about it.
/// A valid commit or clearing the cell removes the entry.
class InvalidTimes extends Notifier<Map<(int, PrayerSlot), String>> {
  @override
  Map<(int, PrayerSlot), String> build() => const {};

  /// Records [text] for the cell, or removes the entry when [text] is null.
  void put(int row, PrayerSlot slot, String? text) {
    // Cells may report late (after dispose); the store may be gone by then.
    if (!ref.mounted) return;
    final key = (row, slot);
    if (state[key] == text) return;
    final next = {...state};
    if (text == null) {
      next.remove(key);
    } else {
      next[key] = text;
    }
    state = next;
  }

  /// Drops the entries of rows with index >= [n] (rows that were removed).
  void pruneFrom(int n) {
    if (!ref.mounted) return;
    if (!state.keys.any((k) => k.$1 >= n)) return;
    state = {
      for (final e in state.entries)
        if (e.key.$1 < n) e.key: e.value,
    };
  }

  /// Forgets every entry (a new editor session).
  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final invalidTimesProvider =
    NotifierProvider<InvalidTimes, Map<(int, PrayerSlot), String>>(
      InvalidTimes.new,
    );

/// Number of entries that belong to existing rows.
int countInvalidTimes(Map<(int, PrayerSlot), String> m, int rowCount) =>
    m.keys.where((k) => k.$1 < rowCount).length;
