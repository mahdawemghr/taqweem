import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqweem/templates/shared/fit_text.dart';

import '../test_helpers/load_fonts.dart';

Widget _box(double w, double h, Widget child) => Directionality(
  textDirection: TextDirection.rtl,
  child: Center(
    child: SizedBox(width: w, height: h, child: child),
  ),
);

const _style = TextStyle(fontFamily: 'Amiri', color: Color(0xFF000000));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('short text keeps maxSize', (tester) async {
    await tester.pumpWidget(
      _box(300, 40, const FitText('الفجر', style: _style, maxSize: 20)),
    );
    final text = tester.widget<Text>(find.text('الفجر'));
    expect(text.style!.fontSize, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Arabic text shrinks to fit without clipping', (
    tester,
  ) async {
    final long = List.filled(80, 'وفاة السيد').join(' ').substring(0, 400);
    expect(long.length, 400);
    await tester.pumpWidget(
      _box(200, 60, FitText(long, style: _style, maxSize: 22)),
    );
    final text = tester.widget<Text>(find.text(long));
    expect(text.style!.fontSize, lessThan(22));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(text.overflow, isNot(TextOverflow.clip));
    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
    expect(paragraph.textSize.height, lessThanOrEqualTo(60));
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('empty string renders SizedBox.shrink', (tester) async {
    await tester.pumpWidget(
      _box(300, 40, const FitText('', style: _style, maxSize: 24)),
    );
    expect(find.byType(Text), findsNothing);
    final fit = find.byType(FitText);
    final shrink = tester.widget<SizedBox>(
      find.descendant(of: fit, matching: find.byType(SizedBox)).first,
    );
    expect(shrink.width, 0);
    expect(shrink.height, 0);
  });

  testWidgets('binary search bounds the number of layouts', (tester) async {
    // Expensive: 400 chars, one-line limit, tiny box -> both passes run and
    // the never-clip fallback kicks in. A linear 0.5-step search would need
    // about 2 * 116 layouts here.
    final long = List.filled(80, 'وفاة السيد').join(' ').substring(0, 400);
    FitText.debugLayoutCount = 0;
    await tester.pumpWidget(
      _box(120, 20, FitText(long, style: _style, maxSize: 64, maxLines: 1)),
    );
    expect(FitText.debugLayoutCount, lessThanOrEqualTo(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('binary search picks the same size as a linear search', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.rtl, child: SizedBox()),
    );
    double linear(String text, double w, double h, double max, int? lines) {
      for (var size = max; size >= kFitTextFloor; size -= 0.5) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: _style.copyWith(fontSize: size),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: lines,
          textScaler: TextScaler.noScaling,
        )..layout(maxWidth: w);
        final ok = !tp.didExceedMaxLines && tp.height <= h && tp.width <= w;
        tp.dispose();
        if (ok) return size;
      }
      return -1;
    }

    final cases = <(String, double, double, double, int?)>[
      ('الفجر', 300, 40, 20, 1),
      ('وفاة القاسم ابن الامام موسى الكاظم(ع)192هـ', 160, 44, 22, null),
      ('مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة', 170, 44, 22, null),
      ('هدم مسجد رد الشمس لأمير المؤمنين(ع)في المدينة1422هـ', 400, 30, 24, 1),
      ('تقويم أهل البيت', 340, 120, 64, 1),
    ];
    for (final (text, w, h, max, lines) in cases) {
      final fit = FitText(text, style: _style, maxSize: max, maxLines: lines);
      final (size, _, ok) = fit.fitFontSize(_style, w, h);
      expect(ok, isTrue, reason: text);
      expect(size, linear(text, w, h, max, lines), reason: text);
    }
  });

  testWidgets('a single word wider than the box is scaled, never split', (
    tester,
  ) async {
    const word = 'جمادىالآخرة';
    await tester.pumpWidget(
      _box(100, 120, const FitText(word, style: _style, maxSize: 30)),
    );
    final text = tester.widget<Text>(find.text(word));
    expect(text.style!.fontSize, lessThan(30));
    final paragraph = tester.renderObject<RenderParagraph>(find.text(word));
    expect(
      paragraph.getMinIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(100.5),
    );
    final lines = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: word.length),
    );
    expect(lines.map((b) => b.top.round()).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-word text that wraps at word boundaries is unchanged', (
    tester,
  ) async {
    const t = 'الفجر والظهر والمغرب';
    await tester.pumpWidget(
      _box(150, 120, const FitText(t, style: _style, maxSize: 20)),
    );
    expect(tester.widget<Text>(find.text(t)).style!.fontSize, 20);
  });
}
