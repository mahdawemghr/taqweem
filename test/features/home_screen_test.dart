import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/data/poster_repository.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/home/draft_card.dart';
import 'package:taqweem/features/home/home_screen.dart';
import 'package:taqweem/features/preview/poster_thumbnail.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';

import '../test_helpers/instant_thumbnails.dart';
import '../test_helpers/load_fonts.dart';

/// Ordered log of saver / remove calls, shared by the fakes.
final events = <String>[];

class FakePosters extends PostersNotifier {
  FakePosters(this.initial, {this.fail = false, this.hang = false});
  final List<MonthPoster> initial;
  final bool fail;
  final bool hang;
  final removed = <String>[];
  int reloads = 0;

  @override
  Future<List<MonthPoster>> build() async {
    if (fail) throw StateError('disk');
    if (hang) return Completer<List<MonthPoster>>().future;
    return initial;
  }

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    events.add('remove:$id');
    state = AsyncData([
      for (final p in state.value ?? const <MonthPoster>[])
        if (p.id != id) p,
    ]);
  }
}

MonthPoster seed([String id = 'seed-a', int minutesAgo = 5]) =>
    seedReferenceMonth().copyWith(
      id: id,
      updatedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );

void main() {
  setUpAll(loadAppFonts);
  useInstantThumbnails();

  late FakePosters fake;
  late List<MonthPoster> saved;

  Future<void> pumpHome(
    WidgetTester tester,
    List<MonthPoster> posters, {
    Size size = const Size(390, 844),
    bool fail = false,
    bool hang = false,
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    fake = FakePosters(posters, fail: fail, hang: hang);
    saved = [];
    events.clear();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          postersProvider.overrideWith(() => fake),
          // duplicateAsNextMonth is pure; the directory is never touched.
          repositoryProvider.overrideWith(
            (ref) async => PosterRepository(Directory('/nonexistent-taqweem')),
          ),
          posterSaverProvider.overrideWith(
            (ref) => (p) async {
              saved.add(p);
              events.add('save:${p.id}:${p.hijriYear}');
              await ref.read(postersProvider.notifier).upsert(p);
            },
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        ),
      ),
    );
    if (hang) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> openMenu(WidgetTester tester, {int index = 0}) async {
    await tester.tap(find.byType(PopupMenuButton<DraftAction>).at(index));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state shows headline, explanation and both actions', (
    tester,
  ) async {
    await pumpHome(tester, const []);
    expect(find.text('تقاويمي'), findsOneWidget);
    expect(find.text('لا توجد تقاويم بعد'), findsOneWidget);
    expect(
      find.text('أنشئ ملصق تقويم شهري جاهزاً للطباعة بخطوات بسيطة'),
      findsOneWidget,
    );
    expect(find.text('ابدأ تقويماً جديداً'), findsOneWidget);
    expect(find.text('جرّب مثالاً جاهزاً'), findsOneWidget);
    expect(find.byType(DraftCard), findsNothing);
    expect(find.text('تقويم جديد'), findsOneWidget);
  });

  testWidgets('empty state: start new opens the editor without saving', (
    tester,
  ) async {
    await pumpHome(tester, const []);
    await tester.tap(find.text('ابدأ تقويماً جديداً'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('empty state: try example saves a seed copy and opens it', (
    tester,
  ) async {
    await pumpHome(tester, const []);
    await tester.tap(find.text('جرّب مثالاً جاهزاً'));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.id, startsWith('poster-'));
    expect(saved.single.hijriHeader, 'جمادى الأول\n1448');
    expect(find.byType(EditorShell), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DraftCard), findsOneWidget);
  });

  testWidgets('one seed poster shows its title, template and semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester, [seed()]);
    expect(find.text('جمادى الأول 1448'), findsOneWidget);
    expect(find.textContaining('كحلي وذهبي'), findsOneWidget);
    expect(find.textContaining('قبل 5 دقائق'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('تقويم جمادى الأول 1448')),
      findsOneWidget,
    );
    expect(find.byType(RepaintBoundary), findsWidgets);
    handle.dispose();
  });

  testWidgets('thumbnails are not rebuilt when another draft changes', (
    tester,
  ) async {
    await pumpHome(tester, [seed('a', 1)]);
    PosterThumbnail previewOf(String id) => tester.widget<PosterThumbnail>(
      find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byType(PosterThumbnail),
      ),
    );
    final before = previewOf('a');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await container.read(postersProvider.notifier).upsert(seed('b', 0));
    await tester.pumpAndSettle();
    expect(find.byType(DraftCard), findsNWidgets(2));
    expect(identical(previewOf('a'), before), isTrue);
  });

  testWidgets('tapping a card opens it in the editor', (tester) async {
    await pumpHome(tester, [seed()]);
    await tester.tap(find.text('جمادى الأول 1448'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell), findsOneWidget);
    expect(
      tester.widget<EditorShell>(find.byType(EditorShell)).initial.id,
      'seed-a',
    );
  });

  testWidgets('menu shows edit / duplicate / delete', (tester) async {
    await pumpHome(tester, [seed()]);
    await openMenu(tester);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('نسخ كشهر تالٍ'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell), findsOneWidget);
  });

  testWidgets('delete -> confirm removes the poster', (tester) async {
    await pumpHome(tester, [seed()]);
    await openMenu(tester);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(find.text('هل تريد حذف هذا التقويم؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();
    expect(fake.removed, ['seed-a']);
    expect(find.byType(DraftCard), findsNothing);
    expect(find.text('لا توجد تقاويم بعد'), findsOneWidget);
  });

  testWidgets('delete -> cancel keeps the poster', (tester) async {
    await pumpHome(tester, [seed()]);
    await openMenu(tester);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(fake.removed, isEmpty);
    expect(find.byType(DraftCard), findsOneWidget);
  });

  testWidgets('duplicate as next month creates Jumada II and opens it', (
    tester,
  ) async {
    await pumpHome(tester, [seed()]);
    await openMenu(tester);
    await tester.tap(find.text('نسخ كشهر تالٍ'));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.hijriHeader, 'جمادى الثانية\n1448');
    final editor = tester.widget<EditorShell>(find.byType(EditorShell));
    expect(editor.initial.id, saved.single.id);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DraftCard), findsNWidgets(2));
    expect(find.text('جمادى الثانية 1448'), findsOneWidget);
  });

  testWidgets('duplicate of an underivable poster shows the R10 snackbar', (
    tester,
  ) async {
    await pumpHome(tester, [seed().copyWith(gregorianHeader: 'garbled')]);
    await openMenu(tester);
    await tester.tap(find.text('نسخ كشهر تالٍ'));
    await tester.pumpAndSettle();
    expect(
      find.text('تعذّر تحديد تاريخ بداية الشهر التالي — أنشئ تقويماً جديداً'),
      findsOneWidget,
    );
    expect(saved, isEmpty);
    expect(find.byType(EditorShell), findsNothing);
  });

  testWidgets('FAB opens a blank poster in the editor', (tester) async {
    await pumpHome(tester, [seed()]);
    expect(find.text('تقويم جديد'), findsOneWidget);
    await tester.tap(find.text('تقويم جديد'));
    await tester.pumpAndSettle();
    final editor = tester.widget<EditorShell>(find.byType(EditorShell));
    expect(editor.initial.days, isEmpty);
    expect(editor.initial.id, startsWith('poster-'));
    expect(saved, isEmpty);
  });

  testWidgets('error state offers a retry that reloads', (tester) async {
    await pumpHome(tester, const [], fail: true);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('تقويم جديد'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(fake.reloads, 1);
  });

  testWidgets('retry survives a repository that keeps failing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          repositoryProvider.overrideWith(
            (ref) async => throw const FileSystemException('no documents dir'),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحميل التقاويم'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    // No unhandled exception, still in the error state, Arabic message shown.
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('error')), findsOneWidget);
    expect(find.text('تعذّر تحميل التقاويم، حاول مرة أخرى'), findsOneWidget);
    expect(find.textContaining('no documents'), findsNothing);
  });

  testWidgets('loading shows skeletons and the FAB', (tester) async {
    await pumpHome(tester, const [], hang: true);
    expect(find.byType(DraftCard), findsNothing);
    expect(find.bySemanticsLabel('جارٍ تحميل التقاويم'), findsOneWidget);
    expect(find.text('تقويم جديد'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('FAB never covers the empty-state buttons (scale $scale)', (
      tester,
    ) async {
      await pumpHome(tester, const [], textScale: scale);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      for (final label in ['ابدأ تقويماً جديداً', 'جرّب مثالاً جاهزاً']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        final r = tester.getRect(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        );
        expect(r.overlaps(fab), isFalse, reason: label);
      }
    });
  }

  testWidgets('FAB never covers the last card when scrolled to the end', (
    tester,
  ) async {
    await pumpHome(tester, [seed('a', 1), seed('b', 2), seed('c', 3)]);
    await tester.drag(find.byType(GridView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final last = tester.getRect(find.byType(DraftCard).last);
    expect(last.overlaps(fab), isFalse);
  });

  testWidgets('menu tooltips are unique per card', (tester) async {
    await pumpHome(tester, [
      seed('a', 1),
      seed('b', 2).copyWith(hijriMonthIndex: 5),
    ]);
    expect(find.byTooltip('خيارات تقويم جمادى الأول 1448'), findsOneWidget);
    expect(find.byTooltip('خيارات تقويم جمادى الثانية 1448'), findsOneWidget);
    expect(find.byTooltip('المزيد'), findsNothing);
  });

  testWidgets('double tap on FAB pushes a single editor route', (tester) async {
    await pumpHome(tester, [seed()]);
    // Two activations before any frame (a real double tap can land both).
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    fab.onPressed!();
    fab.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell, skipOffstage: false), findsOneWidget);
  });

  testWidgets('double tap on the empty-state button pushes one route', (
    tester,
  ) async {
    await pumpHome(tester, const []);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('ابدأ تقويماً جديداً'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(EditorShell, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'deleting the poster open in the editor flushes it first, removes it, '
    'closes the editor and never resaves it',
    (tester) async {
      final x = seed();
      await pumpHome(tester, [x]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final ctl = container.read(editorProvider.notifier)..open(x);
      ctl.update((p) => p.copyWith(hijriYear: 1500));
      await openMenu(tester);
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
      await tester.pumpAndSettle();
      expect(events, ['save:seed-a:1500', 'remove:seed-a']);
      expect(container.read(editorProvider).isOpen, isFalse);
      // A stray edit (e.g. a late callback) must not resurrect the draft.
      ctl.update((p) => p.copyWith(hijriYear: 1501));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(events, ['save:seed-a:1500', 'remove:seed-a']);
      expect(container.read(postersProvider).value, isEmpty);
      expect(find.byType(DraftCard), findsNothing);
    },
  );

  testWidgets('deleting another poster leaves the open editor alone', (
    tester,
  ) async {
    await pumpHome(tester, [seed('a', 1), seed('b', 2)]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.read(editorProvider.notifier).open(seed('b', 2));
    await openMenu(tester, index: 0); // card 'a' (newest first)
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();
    expect(events, ['remove:a']);
    expect(container.read(editorProvider).poster.id, 'b');
  });

  testWidgets('wide screens lay out 3+ cards per row', (tester) async {
    await pumpHome(tester, [
      seed('a', 1),
      seed('b', 2),
      seed('c', 3),
    ], size: const Size(1280, 900));
    final cards = find.byType(DraftCard);
    expect(cards, findsNWidgets(3));
    final tops = {
      for (var i = 0; i < 3; i++) tester.getTopLeft(cards.at(i)).dy,
    };
    expect(tops, hasLength(1));
  });

  testWidgets('phones lay out 2 cards per row', (tester) async {
    await pumpHome(tester, [seed('a', 1), seed('b', 2), seed('c', 3)]);
    final cards = find.byType(DraftCard);
    expect(
      tester.getTopLeft(cards.at(0)).dy,
      tester.getTopLeft(cards.at(1)).dy,
    );
    expect(
      tester.getTopLeft(cards.at(2)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
  });

  testWidgets('text scale 1.3 renders cards without overflow', (tester) async {
    await pumpHome(tester, [seed('a', 1), seed('b', 2)], textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 1.3 renders the empty state without overflow', (
    tester,
  ) async {
    await pumpHome(tester, const [], textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 2.0 on a small phone still renders cards', (
    tester,
  ) async {
    await pumpHome(
      tester,
      [seed('a', 1)],
      size: const Size(320, 640),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });
}
