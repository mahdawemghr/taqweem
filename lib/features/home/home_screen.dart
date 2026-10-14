import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/motion_widgets.dart';
import '../../data/new_poster.dart';
import '../../data/poster_repository.dart';
import '../../data/seed_reference.dart';
import '../../domain/models.dart';
import '../../state/editor_controller.dart';
import '../../state/providers.dart';
import '../../templates/poster_template.dart';
import '../editor/editor_shell.dart';
import 'draft_card.dart';

const _gutter = 16.0;
const _maxTileWidth = 260.0;
const _gold = Color(0xFFC9A227);

/// Drafts grid (or a friendly empty state) with a "new poster" action.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;

  /// The FAB shrinks to its icon while scrolling down, extends on the way up.
  bool _fabExtended = true;

  /// Draft ids whose card is fading out (delete in progress).
  final Set<String> _leaving = {};

  bool _onScroll(UserScrollNotification n) {
    if (n.depth != 0) return false;
    final ext = n.direction != ScrollDirection.reverse;
    if (ext != _fabExtended) setState(() => _fabExtended = ext);
    return false;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(MonthPoster p) => Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => EditorShell(initial: p)));

  /// Runs [action] unless another one is still in flight (double taps).
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  /// Saves [p] (disk + list). Shows a SnackBar and returns false on failure.
  Future<bool> _save(MonthPoster p) async {
    try {
      await ref.read(posterSaverProvider)(p);
      return true;
    } catch (_) {
      _snack('تعذّر حفظ التقويم، حاول مرة أخرى');
      return false;
    }
  }

  /// Reloads the list; if the repository itself is unavailable the error
  /// state stays and an Arabic message is shown (never an unhandled throw).
  Future<void> _retryLoad() async {
    try {
      await ref.read(postersProvider.notifier).reload();
    } catch (e) {
      debugPrint('reload failed: $e');
      _snack('تعذّر تحميل التقاويم، حاول مرة أخرى');
    }
  }

  Future<void> _newPoster() => _guard(() => _open(newBlankPoster()));

  Future<void> _trySample() => _guard(() async {
    final now = DateTime.now();
    final p = seedReferenceMonth().copyWith(
      id: 'poster-${now.microsecondsSinceEpoch}',
      updatedAt: now,
    );
    if (await _save(p) && mounted) await _open(p);
  });

  Future<void> _duplicate(MonthPoster p) => _guard(() async {
    final MonthPoster dup;
    try {
      final repo = await ref.read(repositoryProvider.future);
      dup = repo.duplicateAsNextMonth(p);
    } on CannotDeriveNextMonthDates {
      _snack('تعذّر تحديد تاريخ بداية الشهر التالي — أنشئ تقويماً جديداً');
      return;
    } catch (_) {
      _snack('تعذّر نسخ التقويم، حاول مرة أخرى');
      return;
    }
    if (await _save(dup) && mounted) await _open(dup);
  });

  Future<void> _delete(MonthPoster p) => _guard(() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(title: posterTitle(p)),
    );
    if (ok != true) return;
    try {
      // A pending autosave of this poster would recreate its file.
      final editor = ref.read(editorProvider);
      if (editor.isOpen && editor.poster.id == p.id) {
        await ref.read(editorProvider.notifier).flush();
      }
      final openHere = editor.isOpen && editor.poster.id == p.id;
      // The card fades and shrinks first, then the grid reflows.
      if (mounted && Motion.enabled(context)) {
        setState(() => _leaving.add(p.id));
        await Future<void>.delayed(Motion.of(context, Motion.quick));
      }
      await ref.read(postersProvider.notifier).remove(p.id);
      // Close it so no later edit/autosave can resurrect the deleted file.
      if (openHere) ref.read(editorProvider.notifier).close();
      _snack('تم حذف التقويم');
    } catch (_) {
      _snack('تعذّر حذف التقويم، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _leaving.remove(p.id));
    }
  });

  void _onAction(MonthPoster p, DraftAction a) {
    switch (a) {
      case DraftAction.edit:
        _guard(() => _open(p));
      case DraftAction.duplicate:
        _duplicate(p);
      case DraftAction.delete:
        _delete(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posters = ref.watch(postersProvider);
    final theme = Theme.of(context);

    final Widget body = posters.when(
      skipLoadingOnReload: true,
      data: (list) => list.isEmpty
          ? _EmptyState(
              key: const ValueKey('empty'),
              onNew: _newPoster,
              onSample: _trySample,
            )
          : _DraftsGrid(
              key: const ValueKey('grid'),
              posters: list,
              leaving: _leaving,
              onAction: _onAction,
            ),
      loading: () => const _SkeletonGrid(key: ValueKey('loading')),
      error: (_, _) =>
          _ErrorState(key: const ValueKey('error'), onRetry: _retryLoad),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تقاويمي',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
      ),
      // Always present: the one "new" action reachable in every state.
      floatingActionButton: FloatingActionButton.extended(
        isExtended: _fabExtended,
        extendedIconLabelSpacing: _fabExtended ? 8 : 0,
        onPressed: _newPoster,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('تقويم جديد'),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.base),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Tile geometry shared by the real grid and the loading skeleton: as many
/// columns as `SliverGridDelegateWithMaxCrossAxisExtent` would pick, and a
/// tile height that keeps the thumbnail at the poster ratio plus the footer.
SliverGridDelegate _gridDelegate(BoxConstraints c, TextScaler scaler) {
  final cross = c.maxWidth - 2 * _gutter;
  final count = math.max(1, (cross / (_maxTileWidth + _gutter)).ceil());
  final tileW = (cross - _gutter * (count - 1)) / count;
  final thumbW = tileW - 2 * kDraftThumbPadding;
  final thumbH = thumbW * kPosterSize.height / kPosterSize.width;
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: _maxTileWidth,
    mainAxisSpacing: _gutter,
    crossAxisSpacing: _gutter,
    mainAxisExtent:
        thumbH + 2 * kDraftThumbPadding + draftCardFooterHeight(scaler, tileW),
  );
}

/// Space kept free at the bottom of every scrolling body so the extended FAB
/// (56dp + 16dp margin) never covers content scrolled to the end.
const _fabClearance = 104.0;

const _gridPadding = EdgeInsets.fromLTRB(_gutter, 8, _gutter, _fabClearance);

class _DraftsGrid extends StatelessWidget {
  const _DraftsGrid({
    super.key,
    required this.posters,
    required this.onAction,
    this.leaving = const {},
  });

  final List<MonthPoster> posters;
  final Set<String> leaving;
  final void Function(MonthPoster, DraftAction) onAction;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, c) => GridView.builder(
        padding: _gridPadding,
        gridDelegate: _gridDelegate(c, scaler),
        itemCount: posters.length,
        // Keeps each card's state (and its cached thumbnail) when a newer
        // draft is inserted above it.
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final i = posters.indexWhere((p) => p.id == key.value);
          return i < 0 ? null : i;
        },
        itemBuilder: (_, i) {
          final p = posters[i];
          return FadeScaleOut(
            key: ValueKey(p.id),
            out: leaving.contains(p.id),
            child: DraftCard(
              key: ValueKey(p.id),
              poster: p,
              onAction: (a) => onAction(p, a),
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(h / 2),
      ),
    );
    return Semantics(
      label: 'جارٍ تحميل التقاويم',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) => GridView.builder(
            padding: _gridPadding,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: _gridDelegate(c, scaler),
            itemCount: 4,
            itemBuilder: (_, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(kDraftThumbPadding),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(96, 12),
                        const SizedBox(height: 8),
                        bar(64, 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.onNew, required this.onSample});

  final VoidCallback onNew;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const buttonSize = Size.fromHeight(52);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, _fabClearance),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OneShotEntrance(child: _EmptyIllustration()),
              const SizedBox(height: 28),
              Text(
                'لا توجد تقاويم بعد',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _BalancedText(
                'أنشئ ملصق تقويم شهري جاهزاً للطباعة بخطوات بسيطة',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onNew,
                style: FilledButton.styleFrom(
                  minimumSize: buttonSize,
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('ابدأ تقويماً جديداً'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSample,
                style: OutlinedButton.styleFrom(
                  minimumSize: buttonSize,
                  textStyle: theme.textTheme.titleMedium,
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
                ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('جرّب مثالاً جاهزاً'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered text whose lines are balanced: it wraps at the narrowest width
/// that still gives the same number of lines, so the last line never holds
/// a lone word.
class _BalancedText extends StatelessWidget {
  const _BalancedText(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: effective),
          textDirection: dir,
          textScaler: scaler,
          textAlign: TextAlign.center,
        );
        int linesAt(double w) {
          tp.layout(maxWidth: w);
          return tp.computeLineMetrics().length;
        }

        var width = c.maxWidth;
        if (width.isFinite) {
          final target = linesAt(width);
          if (target > 1) {
            var lo = 0.0, hi = width;
            for (var i = 0; i < 14; i++) {
              final mid = (lo + hi) / 2;
              if (linesAt(mid) > target) {
                lo = mid;
              } else {
                hi = mid;
              }
            }
            width = math.min(c.maxWidth, hi.ceilToDouble() + 1);
          }
        }
        tp.dispose();
        return Center(
          child: SizedBox(
            width: width.isFinite ? width : null,
            child: Text(text, textAlign: TextAlign.center, style: style),
          ),
        );
      },
    );
  }
}

/// A calm crescent-over-calendar mark built from shapes (no images).
class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 168,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.07),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Icon(Icons.calendar_month_rounded, size: 84, color: cs.primary),
            const PositionedDirectional(
              top: 30,
              end: 30,
              child: CustomPaint(
                size: Size.square(40),
                painter: _CrescentPainter(_gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  const _CrescentPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final moon = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: c + Offset(r * 0.45, -r * 0.25),
          radius: r * 0.85,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, moon, bite),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_CrescentPainter old) => old.color != color;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, _fabClearance),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'تعذّر تحميل التقاويم',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
      title: const Text('هل تريد حذف هذا التقويم؟'),
      content: Text('سيُحذف «$title» نهائياً.', textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('حذف'),
        ),
      ],
    );
  }
}
