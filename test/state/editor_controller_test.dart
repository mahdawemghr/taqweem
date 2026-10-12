import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';

MonthPoster _withYear(MonthPoster p, int y) => p.copyWith(hijriYear: y);

void main() {
  late List<MonthPoster> saved;
  late Future<void> Function(MonthPoster) saver;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [posterSaverProvider.overrideWithValue((p) => saver(p))],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    saved = [];
    saver = (p) async => saved.add(p);
  });

  test('a) 3 rapid updates -> exactly one save after 600ms', () {
    fakeAsync((async) {
      final c = make();
      final base = seedReferenceMonth();
      final ctl = c.read(editorProvider.notifier)..open(base);
      ctl.update((p) => _withYear(p, 1));
      async.elapse(const Duration(milliseconds: 300));
      ctl.update((p) => _withYear(p, 2));
      ctl.update((p) => _withYear(p, 3));
      async.elapse(const Duration(milliseconds: 599));
      expect(saved, isEmpty);
      async.elapse(const Duration(milliseconds: 2));
      async.flushMicrotasks();
      expect(saved, hasLength(1));
      expect(saved.single.hijriYear, 3);
      expect(c.read(editorProvider).saving, isFalse);
    });
  });

  test('b) undo restores previous, redo re-applies', () {
    fakeAsync((async) {
      final c = make();
      final base = seedReferenceMonth();
      final ctl = c.read(editorProvider.notifier)..open(base);
      ctl.update((p) => _withYear(p, 7));
      expect(c.read(editorProvider).canUndo, isTrue);
      ctl.undo();
      expect(c.read(editorProvider).poster.hijriYear, base.hijriYear);
      expect(c.read(editorProvider).canRedo, isTrue);
      ctl.redo();
      expect(c.read(editorProvider).poster.hijriYear, 7);
      expect(c.read(editorProvider).canRedo, isFalse);
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('c) update after undo clears redo', () {
    fakeAsync((async) {
      final c = make();
      final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
      ctl.update((p) => _withYear(p, 7));
      ctl.undo();
      expect(c.read(editorProvider).canRedo, isTrue);
      ctl.update((p) => _withYear(p, 8));
      expect(c.read(editorProvider).canRedo, isFalse);
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('d) flush saves immediately and cancels the timer', () {
    fakeAsync((async) {
      final c = make();
      final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
      ctl.update((p) => _withYear(p, 9));
      ctl.flush();
      async.flushMicrotasks();
      expect(saved, hasLength(1));
      async.elapse(const Duration(seconds: 2));
      expect(saved, hasLength(1));
      ctl.flush(); // not dirty -> no extra save
      async.flushMicrotasks();
      expect(saved, hasLength(1));
    });
  });

  test(
    'saver failure (async and sync) sets saveError, later success clears',
    () {
      fakeAsync((async) {
        final c = make();
        final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
        saver = (p) async => throw StateError('disk full');
        ctl.update((p) => _withYear(p, 1));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(c.read(editorProvider).saveError, isNotNull);
        expect(c.read(editorProvider).saving, isFalse);

        saver = (p) => throw ArgumentError('unsafe id');
        ctl.update((p) => _withYear(p, 2));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(c.read(editorProvider).saveError, isNotNull);

        saver = (p) async => saved.add(p);
        ctl.update((p) => _withYear(p, 3));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(saved, hasLength(1));
        expect(c.read(editorProvider).saveError, isNull);
      });
    },
  );

  test('open(other) flushes the previous poster first', () {
    fakeAsync((async) {
      final c = make();
      final a = seedReferenceMonth();
      final b = a.copyWith(id: 'other');
      final ctl = c.read(editorProvider.notifier)..open(a);
      ctl.update((p) => _withYear(p, 5));
      ctl.open(b);
      async.flushMicrotasks();
      expect(saved, hasLength(1));
      expect(saved.single.id, a.id);
      expect(saved.single.hijriYear, 5);
      expect(c.read(editorProvider).poster.id, 'other');
      expect(c.read(editorProvider).canUndo, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(saved, hasLength(1));
    });
  });

  test('undo stack is capped at 100', () {
    fakeAsync((async) {
      final c = make();
      final base = seedReferenceMonth();
      final ctl = c.read(editorProvider.notifier)..open(base);
      for (var i = 1; i <= 150; i++) {
        ctl.update((p) => _withYear(p, i));
      }
      var n = 0;
      while (c.read(editorProvider).canUndo) {
        ctl.undo();
        n++;
      }
      expect(n, 100);
      expect(c.read(editorProvider).poster.hijriYear, 50);
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('disposing the container cancels the pending timer', () {
    fakeAsync((async) {
      final c = ProviderContainer(
        overrides: [posterSaverProvider.overrideWithValue((p) => saver(p))],
      );
      c.read(editorProvider.notifier)
        ..open(seedReferenceMonth())
        ..update((p) => _withYear(p, 4));
      c.dispose();
      expect(async.nonPeriodicTimerCount, 0);
      async.elapse(const Duration(seconds: 2));
      expect(saved, isEmpty);
    });
  });

  group('fix round 1', () {
    test('open(B) while A save pending then fails: B state untouched', () {
      fakeAsync((async) {
        final c = make();
        final a = seedReferenceMonth();
        final comp = Completer<void>();
        saver = (p) => p.id == a.id ? comp.future : Future.value();
        final ctl = c.read(editorProvider.notifier)..open(a);
        ctl.update((p) => _withYear(p, 5));
        ctl.flush();
        async.flushMicrotasks();
        expect(c.read(editorProvider).saving, isTrue);
        ctl.open(a.copyWith(id: 'B'));
        expect(c.read(editorProvider).saving, isFalse);
        comp.completeError(StateError('boom'));
        async.flushMicrotasks();
        final s = c.read(editorProvider);
        expect(s.poster.id, 'B');
        expect(s.saving, isFalse);
        expect(s.saveError, isNull);
        final before = saved.length;
        ctl.flush();
        async.elapse(const Duration(seconds: 10));
        expect(saved.length, before);
      });
    });

    test('overlapping saves: saving stays true until both finish', () {
      fakeAsync((async) {
        final c = make();
        final comps = <Completer<void>>[];
        saver = (p) {
          final x = Completer<void>();
          comps.add(x);
          return x.future;
        };
        final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
        ctl.update((p) => _withYear(p, 1));
        async.elapse(const Duration(milliseconds: 700));
        ctl.update((p) => _withYear(p, 2));
        async.elapse(const Duration(milliseconds: 700));
        expect(comps, hasLength(2));
        comps[0].complete();
        async.flushMicrotasks();
        expect(c.read(editorProvider).saving, isTrue);
        comps[1].complete();
        async.flushMicrotasks();
        expect(c.read(editorProvider).saving, isFalse);
      });
    });

    test('first save fails, newer succeeds: saveError null at end', () {
      fakeAsync((async) {
        final c = make();
        final comps = <Completer<void>>[];
        saver = (p) {
          final x = Completer<void>();
          comps.add(x);
          return x.future;
        };
        final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
        ctl.update((p) => _withYear(p, 1));
        async.elapse(const Duration(milliseconds: 700));
        ctl.update((p) => _withYear(p, 2));
        async.elapse(const Duration(milliseconds: 700));
        comps[0].completeError(StateError('x'));
        async.flushMicrotasks();
        comps[1].complete();
        async.flushMicrotasks();
        expect(c.read(editorProvider).saveError, isNull);
        expect(c.read(editorProvider).saving, isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(comps, hasLength(2));
      });
    });

    test('update/undo/redo/flush are no-ops before open', () {
      fakeAsync((async) {
        final c = make();
        final ctl = c.read(editorProvider.notifier);
        expect(c.read(editorProvider).isOpen, isFalse);
        ctl.update((p) => _withYear(p, 1));
        ctl.undo();
        ctl.redo();
        ctl.flush();
        expect(async.nonPeriodicTimerCount, 0);
        async.elapse(const Duration(seconds: 2));
        expect(saved, isEmpty);
        expect(c.read(editorProvider).canUndo, isFalse);
      });
    });

    test('undo/redo stamp updatedAt', () {
      fakeAsync((async) {
        final c = make();
        final base = seedReferenceMonth();
        final ctl = c.read(editorProvider.notifier)..open(base);
        ctl.update((p) => _withYear(p, 1));
        async.elapse(const Duration(seconds: 1));
        final afterUpdate = c.read(editorProvider).poster.updatedAt;
        async.elapse(const Duration(seconds: 5));
        ctl.undo();
        final afterUndo = c.read(editorProvider).poster.updatedAt;
        expect(afterUndo.isAfter(afterUpdate), isTrue);
        async.elapse(const Duration(seconds: 5));
        ctl.redo();
        expect(
          c.read(editorProvider).poster.updatedAt.isAfter(afterUndo),
          isTrue,
        );
        async.elapse(const Duration(seconds: 1));
      });
    });

    test('failed save retries once after 5s; no timers after dispose', () {
      fakeAsync((async) {
        final c = ProviderContainer(
          overrides: [posterSaverProvider.overrideWithValue((p) => saver(p))],
        );
        var calls = 0;
        saver = (p) async {
          calls++;
          throw StateError('fail');
        };
        final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
        ctl.update((p) => _withYear(p, 1));
        async.elapse(const Duration(milliseconds: 700));
        expect(calls, 1);
        async.elapse(const Duration(seconds: 5));
        expect(calls, 2);
        c.dispose();
        expect(async.nonPeriodicTimerCount, 0);
        async.elapse(const Duration(seconds: 20));
        expect(calls, 2);
      });
    });
  });

  group('close()', () {
    test('drops unsaved edits, cancels timers, resets to unopened', () {
      fakeAsync((async) {
        final c = make();
        final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
        ctl.update((p) => _withYear(p, 9));
        ctl.close();
        final s = c.read(editorProvider);
        expect(s.isOpen, isFalse);
        expect(s.canUndo, isFalse);
        expect(s.saving, isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(saved, isEmpty);
        // Stray edits / flushes after close are no-ops.
        ctl.update((p) => _withYear(p, 10));
        ctl.flush();
        async.elapse(const Duration(seconds: 10));
        expect(saved, isEmpty);
        expect(c.read(editorProvider).isOpen, isFalse);
      });
    });

    test('an in-flight save finishing after close does not touch state', () {
      fakeAsync((async) {
        final c = make();
        final comp = Completer<void>();
        saver = (p) => comp.future;
        final ctl = c.read(editorProvider.notifier)..open(seedReferenceMonth());
        ctl.update((p) => _withYear(p, 9));
        ctl.flush();
        async.flushMicrotasks();
        ctl.close();
        comp.completeError(StateError('late'));
        async.elapse(const Duration(seconds: 10));
        final s = c.read(editorProvider);
        expect(s.isOpen, isFalse);
        expect(s.saving, isFalse);
        expect(s.saveError, isNull);
      });
    });
  });
}
