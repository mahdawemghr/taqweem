import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/poster_repository.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/state/providers.dart';

void main() {
  late Directory tmp;
  late PosterRepository repo;
  late ProviderContainer c;

  MonthPoster mk(String id, int minute) => seedReferenceMonth().copyWith(
    id: id,
    updatedAt: DateTime(2026, 1, 1, 0, minute),
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('posters_nt');
    repo = PosterRepository(tmp);
    c = ProviderContainer(
      overrides: [repositoryProvider.overrideWith((ref) async => repo)],
    );
    addTearDown(() async {
      c.dispose();
      await tmp.delete(recursive: true);
    });
  });

  test('upsert keeps newest-first and replaces by id', () async {
    await repo.save(mk('a', 1));
    await repo.save(mk('b', 2));
    expect((await c.read(postersProvider.future)).map((e) => e.id), ['b', 'a']);
    await c.read(postersProvider.notifier).upsert(mk('a', 5));
    await c.read(postersProvider.notifier).upsert(mk('n', 3));
    expect(c.read(postersProvider).value!.map((e) => e.id), ['a', 'n', 'b']);
  });

  test('remove of a missing id does not throw; existing is deleted', () async {
    await repo.save(mk('a', 1));
    await c.read(postersProvider.future);
    final n = c.read(postersProvider.notifier);
    await n.remove('nope');
    expect(c.read(postersProvider).value, hasLength(1));
    await n.remove('a');
    expect(c.read(postersProvider).value, isEmpty);
    expect(await repo.loadAll(), isEmpty);
  });

  test('reload re-reads disk', () async {
    await c.read(postersProvider.future);
    await repo.save(mk('z', 1));
    expect(c.read(postersProvider).value, isEmpty);
    await c.read(postersProvider.notifier).reload();
    expect(c.read(postersProvider).value!.map((e) => e.id), ['z']);
  });
}
