import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/core/app_theme.dart';
import 'package:taqweem/data/seed_reference.dart';
import 'package:taqweem/domain/models.dart';
import 'package:taqweem/features/editor/editor_shell.dart';
import 'package:taqweem/features/editor/honorific_bar.dart';
import 'package:taqweem/state/editor_controller.dart';
import 'package:taqweem/state/providers.dart';

import '../test_helpers/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<ProviderContainer> pumpTexts(
    WidgetTester tester, {
    double textScale = 1.0,
    MonthPoster? poster,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [posterSaverProvider.overrideWithValue((p) async {})],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: EditorShell(initial: poster ?? seedReferenceMonth()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-2')));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(EditorShell)));
  }

  PosterTexts textsOf(ProviderContainer c) =>
      c.read(editorProvider).poster.texts;

  int undoCount(ProviderContainer c) {
    final ctl = c.read(editorProvider.notifier);
    var n = 0;
    while (c.read(editorProvider).canUndo) {
      ctl.undo();
      n++;
    }
    for (var i = 0; i < n; i++) {
      ctl.redo();
    }
    return n;
  }

  Finder field(String k) => find.byKey(ValueKey('txt-$k'));

  Future<void> open(WidgetTester tester, String section) async {
    final f = find.text(section);
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the grouped sections with the first one expanded', (
    tester,
  ) async {
    await pumpTexts(tester);
    for (final s in [
      'العنوان',
      'الاقتباس الأيمن',
      'الاقتباس الأيسر',
      'الاقتباس تحت الشعار',
      'المقال الختامي',
      'سؤال وجواب (يمين)',
      'سؤال وجواب (يسار)',
      'الملاحظات السفلية',
      'الفاتحة',
    ]) {
      await tester.dragUntilVisible(
        find.text(s),
        find.byType(Scrollable).first,
        const Offset(0, -150),
      );
      expect(find.text(s), findsOneWidget, reason: s);
    }
    await tester.dragUntilVisible(
      find.text('العنوان'),
      find.byType(Scrollable).first,
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(field('title'), findsOneWidget);
  });

  testWidgets('editing the title updates the poster; one undo entry', (
    tester,
  ) async {
    final c = await pumpTexts(tester);
    final before = undoCount(c);
    await tester.enterText(field('title'), 'عنوان جديد');
    await tester.pump(const Duration(seconds: 1));
    expect(textsOf(c).title, 'عنوان جديد');
    expect(undoCount(c), before + 1);
  });

  testWidgets('typing in a quote commits after the debounce only', (
    tester,
  ) async {
    final c = await pumpTexts(tester);
    await open(tester, 'الاقتباس الأيمن');
    final before = undoCount(c);
    final orig = textsOf(c).rightQuote.text;
    await tester.enterText(field('rightQuote-text'), 'ا');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field('rightQuote-text'), 'اب');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field('rightQuote-text'), 'ابج');
    await tester.pump(const Duration(milliseconds: 200));
    expect(textsOf(c).rightQuote.text, orig, reason: 'not per keystroke');
    await tester.pump(const Duration(milliseconds: 500));
    expect(textsOf(c).rightQuote.text, 'ابج');
    expect(undoCount(c), before + 1);
  });

  testWidgets('attribution is edited independently of the quote text', (
    tester,
  ) async {
    final c = await pumpTexts(tester);
    await open(tester, 'الاقتباس الأيسر');
    final text = textsOf(c).leftQuote.text;
    await tester.enterText(field('leftQuote-attribution'), 'الإمام (ع)');
    await tester.pump(const Duration(seconds: 1));
    expect(textsOf(c).leftQuote.attribution, 'الإمام (ع)');
    expect(textsOf(c).leftQuote.text, text);
  });

  testWidgets('all other fields write to their poster text', (tester) async {
    final c = await pumpTexts(tester);
    final cases = <String, (String, String, String Function(PosterTexts))>{
      'الاقتباس تحت الشعار': ('braceQuote', 'ب', (t) => t.braceQuote),
      'المقال الختامي': ('article-author', 'ك', (t) => t.article.author),
      'سؤال وجواب (يمين)': ('sideRight-answer', 'ج', (t) => t.sideRight.answer),
      'سؤال وجواب (يسار)': (
        'sideLeft-question',
        'س',
        (t) => t.sideLeft.question,
      ),
      'الملاحظات السفلية': ('footerNotes', 'ن', (t) => t.footerNotes),
      'الفاتحة': ('fatiha', 'ف', (t) => t.fatiha),
    };
    for (final e in cases.entries) {
      await open(tester, e.key);
      final (k, v, get) = e.value;
      await tester.ensureVisible(field(k));
      await tester.enterText(field(k), v);
      await tester.pump(const Duration(seconds: 1));
      expect(get(textsOf(c)), v, reason: e.key);
    }
    expect(textsOf(c).article.body, defaultTexts().article.body);
  });

  testWidgets('restore defaults: cancel keeps, confirm resets', (tester) async {
    final c = await pumpTexts(tester);
    await tester.enterText(field('title'), 'مخصص');
    await tester.pump(const Duration(seconds: 1));
    final poster = c.read(editorProvider).poster;

    await tester.tap(find.text('استعادة النصوص الافتراضية'));
    await tester.pumpAndSettle();
    expect(
      find.text('سيتم استبدال كل النصوص بالنصوص الافتراضية. متابعة؟'),
      findsOneWidget,
    );
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(textsOf(c).title, 'مخصص');

    final before = undoCount(c);
    await tester.tap(find.text('استعادة النصوص الافتراضية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استعادة'));
    await tester.pumpAndSettle();
    expect(textsOf(c).toJson(), defaultTexts().toJson());
    expect(c.read(editorProvider).poster.days, poster.days);
    expect(c.read(editorProvider).poster.templateId, poster.templateId);
    expect(undoCount(c), before + 1);
    expect(
      tester.widget<TextField>(field('title')).controller!.text,
      defaultTexts().title,
    );
    expect(find.text('تمت استعادة النصوص'), findsOneWidget);

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(textsOf(c).title, 'مخصص');
    expect(tester.widget<TextField>(field('title')).controller!.text, 'مخصص');
  });

  testWidgets('char counter and the long-text hint', (tester) async {
    await pumpTexts(tester);
    await tester.enterText(field('title'), 'x' * 123);
    await tester.pump();
    expect(find.text('123 حرفاً'), findsOneWidget);
    expect(find.text('النص الطويل سيُصغَّر تلقائياً'), findsNothing);
    await tester.enterText(field('title'), 'x' * 301);
    await tester.pump();
    expect(find.text('301 حرفاً'), findsOneWidget);
    expect(find.text('النص الطويل سيُصغَّر تلقائياً'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('undo updates an unfocused field, not the one being typed', (
    tester,
  ) async {
    final c = await pumpTexts(tester);
    await open(tester, 'الاقتباس الأيمن');
    // Commit an edit to the quote, then focus the title and type.
    await tester.enterText(field('rightQuote-text'), 'أول');
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(field('title'), 'يكتب الآن');
    await tester.pump(const Duration(milliseconds: 50));
    // Outside change while typing in the title (pending edit).
    c
        .read(editorProvider.notifier)
        .update(
          (p) => p.copyWith(
            texts: p.texts.copyWith(
              rightQuote: p.texts.rightQuote.copyWith(text: 'خارجي'),
              title: 'من الخارج',
            ),
          ),
        );
    await tester.pump();
    expect(
      tester.widget<TextField>(field('rightQuote-text')).controller!.text,
      'خارجي',
    );
    expect(
      tester.widget<TextField>(field('title')).controller!.text,
      'يكتب الآن',
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shell undo flushes the pending edit first', (tester) async {
    final c = await pumpTexts(tester);
    await tester.enterText(field('title'), 'أول');
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(field('title'), 'معلّق');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('تراجع'));
    await tester.pumpAndSettle();
    // 'معلّق' was committed, then undone.
    expect(textsOf(c).title, 'أول');
    expect(tester.widget<TextField>(field('title')).controller!.text, 'أول');
    await tester.tap(find.byTooltip('إعادة'));
    await tester.pumpAndSettle();
    expect(textsOf(c).title, 'معلّق');
    expect(tester.widget<TextField>(field('title')).controller!.text, 'معلّق');
  });

  testWidgets('honorific bar inserts at the caret of the focused field', (
    tester,
  ) async {
    final c = await pumpTexts(tester);
    expect(find.byType(HonorificBar), findsNothing);
    await tester.enterText(field('title'), 'الإمام علي');
    await tester.pump();
    final ctl = tester.widget<TextField>(field('title')).controller!;
    ctl.selection = const TextSelection.collapsed(offset: 10);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    ctl.selection = const TextSelection.collapsed(offset: 10);
    expect(find.byType(HonorificBar), findsOneWidget);
    await tester.tap(find.text('(ع)'));
    await tester.pump(const Duration(seconds: 1));
    expect(ctl.text, 'الإمام علي(ع)');
    expect(textsOf(c).title, 'الإمام علي(ع)');
  });

  testWidgets('leaving the step flushes a pending edit; values survive', (
    tester,
  ) async {
    final c = await pumpTexts(tester);
    await tester.enterText(field('title'), 'قبل الانتقال');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('step-1')));
    await tester.pumpAndSettle();
    expect(textsOf(c).title, 'قبل الانتقال');
    await tester.tap(find.byKey(const ValueKey('step-2')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('title')).controller!.text,
      'قبل الانتقال',
    );
  });

  testWidgets('text scale 1.3 has no overflow', (tester) async {
    await pumpTexts(tester, textScale: 1.3);
    await open(tester, 'المقال الختامي');
    expect(tester.takeException(), isNull);
  });
}
