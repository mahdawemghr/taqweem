import 'package:flutter/widgets.dart';

import 'navy_gold.dart';
import 'poster_template.dart';

/// Every shipped template, in picker order. Each template task appends its
/// class here (Task 10 adds `NavyGoldTemplate()` FIRST, so it becomes the
/// default for unknown ids).
List<PosterTemplate> get allTemplates => const <PosterTemplate>[
  NavyGoldTemplate(),
];

/// The template with [id]; unknown ids resolve to the first registered
/// template (Navy & Gold once Task 10 lands). Never throws: while no
/// template is registered yet it returns a plain white/black fallback.
PosterTemplate templateById(String id) {
  final all = allTemplates;
  for (final t in all) {
    if (t.id == id) return t;
  }
  return all.isNotEmpty ? all.first : _fallback;
}

const PosterTemplate _fallback = _FallbackTemplate();

class _BlankPainter extends CustomPainter {
  const _BlankPainter();
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

CustomPainter _blank() => const _BlankPainter();
CustomPainter _blankFrame(LayoutMetrics? _) => const _BlankPainter();

/// Minimal white/black template used only while [allTemplates] is empty.
class _FallbackTemplate extends PosterTemplate {
  const _FallbackTemplate();

  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);

  @override
  String get id => 'fallback';
  @override
  String get nameAr => 'بسيط';
  @override
  PosterTheme get theme => const PosterTheme(
    background: _white,
    frameColor: _black,
    accent: _black,
    titleColor: _black,
    bodyText: _black,
    tableHeaderBg: _white,
    tableHeaderFg: _black,
    rowBg: _white,
    rowAltBg: _white,
    rowText: _black,
    gridLine: _black,
    highlightBg: _black,
    highlightFg: _white,
    labelCellBg: _black,
    labelCellFg: _white,
    quoteBoxBg: _white,
    quoteBoxBorder: _black,
    quoteText: _black,
    headingFont: 'ArefRuqaa',
    bodyFont: 'Amiri',
    backgroundPainter: _blank,
    framePainter: _blankFrame,
  );
}
