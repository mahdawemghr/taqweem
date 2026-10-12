import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/poster_repository.dart';
import '../domain/models.dart';

/// Repository rooted at `<documents>/posters`. Tests override this.
final repositoryProvider = FutureProvider<PosterRepository>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  return PosterRepository(Directory('${docs.path}/posters'));
});

List<MonthPoster> _sorted(Iterable<MonthPoster> l) =>
    l.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

class PostersNotifier extends AsyncNotifier<List<MonthPoster>> {
  @override
  Future<List<MonthPoster>> build() async {
    final repo = await ref.watch(repositoryProvider.future);
    return repo.loadAll();
  }

  Future<void> reload() async {
    final repo = await ref.read(repositoryProvider.future);
    state = AsyncData(await repo.loadAll());
  }

  /// Replaces/inserts [p] in the in-memory list (newest first) without a
  /// disk reload.
  Future<void> upsert(MonthPoster p) async {
    final cur = state.value ?? await future;
    state = AsyncData(
      _sorted([
        for (final e in cur)
          if (e.id != p.id) e,
        p,
      ]),
    );
  }

  /// Deletes the draft on disk and drops it from the list. Callers must
  /// `flush()`/cancel the editor autosave for [id] first: a pending autosave
  /// would recreate the file.
  Future<void> remove(String id) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.delete(id);
    final cur = state.value ?? await future;
    state = AsyncData([
      for (final e in cur)
        if (e.id != id) e,
    ]);
  }
}

final postersProvider =
    AsyncNotifierProvider<PostersNotifier, List<MonthPoster>>(
      PostersNotifier.new,
    );

typedef PosterSaver = Future<void> Function(MonthPoster);

/// Persists a poster and refreshes the drafts list. Overridable in tests.
final posterSaverProvider = Provider<PosterSaver>((ref) {
  return (p) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.save(p);
    await ref.read(postersProvider.notifier).upsert(p);
  };
});
