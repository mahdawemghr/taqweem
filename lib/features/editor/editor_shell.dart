import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/motion_widgets.dart';
import '../../domain/models.dart';
import '../../state/editor_controller.dart';
import '../preview/poster_preview.dart';
import '../preview/poster_thumbnail.dart';
import 'invalid_times.dart';
import 'step_export.dart';
import 'step_grid.dart';
import 'step_setup.dart';
import 'step_texts.dart';

/// Labels of the four editor steps, in order.
const editorStepLabels = ['الشهر', 'الأيام', 'النصوص', 'التصدير'];

/// The step-by-step poster editor: a tappable 4-step header, the current
/// step, and a bottom bar with السابق / التالي and the autosave status.
///
/// Opens [initial] in [editorProvider] once on init and flushes the
/// autosave when the route is left.
class EditorShell extends ConsumerStatefulWidget {
  const EditorShell({required this.initial, super.key});

  final MonthPoster initial;

  @override
  ConsumerState<EditorShell> createState() => _EditorShellState();
}

enum _SaveStatus { none, saving, saved }

class _EditorShellState extends ConsumerState<EditorShell> {
  int _step = 0;

  /// Identifies this editing session for the Step 1 draft.
  final Object _session = Object();

  // Autosave status as seen by the user. `_pending` covers the debounce
  // window (an edit not yet written) as well as the save itself.
  bool _pending = false;
  bool _everSaved = false;
  MonthPoster? _savingPoster;

  @override
  void initState() {
    super.initState();
    // Providers must not be modified while the tree is building.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(editorProvider.notifier).open(widget.initial);
      // Invalid typed times belong to one editor session.
      ref.read(invalidTimesProvider.notifier).clear();
    });
  }

  bool _isMine(EditorState s) => s.isOpen && s.poster.id == widget.initial.id;

  void _onEditorChanged(EditorState? prev, EditorState next) {
    if (prev == null || !_isMine(next)) return;
    // Rows removed (e.g. undo of an extension): drop their invalid entries.
    if (_isMine(prev) && next.poster.days.length < prev.poster.days.length) {
      ref
          .read(invalidTimesProvider.notifier)
          .pruneFrom(next.poster.days.length);
    }
    var pending = _pending, everSaved = _everSaved;
    if (_isMine(prev) && !identical(prev.poster, next.poster)) pending = true;
    if (!prev.saving && next.saving) _savingPoster = next.poster;
    if (prev.saving &&
        !next.saving &&
        next.saveError == null &&
        identical(_savingPoster, next.poster)) {
      pending = false;
      everSaved = true;
    }
    if (pending != _pending || everSaved != _everSaved) {
      setState(() {
        _pending = pending;
        _everSaved = everSaved;
      });
    }
  }

  /// Blurs the focused field and waits for its commit (focus changes are
  /// applied in a microtask): undo/redo, step changes and leaving the editor
  /// then act on what was typed, the same on every platform.
  Future<void> _commitFocused() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.microtask(() {});
  }

  int _invalidCount() => countInvalidTimes(
    ref.read(invalidTimesProvider),
    ref.read(editorProvider).poster.days.length,
  );

  void _warnInvalid(ScaffoldMessengerState messenger) {
    final n = _invalidCount();
    if (n == 0) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('تم تجاهل أوقات غير صالحة ($n) — راجعها في الأيام'),
        ),
      );
  }

  Future<void> _goTo(int i) async {
    if (i < 0 || i >= editorStepLabels.length || i == _step) return;
    await _commitFocused();
    if (!mounted || i == _step) return;
    if (_step == 1) _warnInvalid(ScaffoldMessenger.of(context));
    setState(() => _step = i);
  }

  Future<void> _undoRedo({required bool redo}) async {
    await _commitFocused();
    if (!mounted) return;
    final ctl = ref.read(editorProvider.notifier);
    redo ? ctl.redo() : ctl.undo();
  }

  void _openPreview() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullPreview(fallback: widget.initial),
      ),
    );
  }

  /// Step 2 reads its rows from [editorProvider] itself (each row watches
  /// only its own day), so one instance is reused: shell rebuilds then never
  /// rebuild the grid.
  late final StepGrid _grid = StepGrid(onGoToStep: _goTo);

  /// Builders of the steps, in [editorStepLabels] order. Only the current
  /// step is built.
  late final List<Widget Function(MonthPoster)> _steps = [
    (p) => StepSetup(poster: p, session: _session),
    (_) => _grid,
    (_) => const StepTexts(),
    (p) => StepExport(poster: p, onGoToStep: _goTo),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(editorProvider, _onEditorChanged);
    final s = ref.watch(editorProvider);
    final mine = _isMine(s);
    final poster = mine ? s.poster : widget.initial;
    final ctl = ref.read(editorProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final status = !mine
        ? _SaveStatus.none
        : (s.saving || _pending)
        ? _SaveStatus.saving
        : _everSaved
        ? _SaveStatus.saved
        : _SaveStatus.none;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Leaving the editor: commit the focused field first, then write
        // any pending edit right away.
        final ctl = ref.read(editorProvider.notifier);
        final messenger = ScaffoldMessenger.of(context);
        FocusManager.instance.primaryFocus?.unfocus();
        scheduleMicrotask(() {
          if (mounted) _warnInvalid(messenger);
          unawaited(ctl.flush());
        });
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          // Scales down rather than cutting off the year at large text sizes.
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              poster.hijriHeader.replaceAll('\n', ' '),
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تراجع',
              onPressed: mine && s.canUndo
                  ? () => unawaited(_undoRedo(redo: false))
                  : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'إعادة',
              onPressed: mine && s.canRedo
                  ? () => unawaited(_undoRedo(redo: true))
                  : null,
              icon: const Icon(Icons.redo_rounded),
            ),
            _MiniPreview(poster: poster, onTap: _openPreview),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            _StepHeader(current: _step, onTap: _goTo),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
            Expanded(
              child: FadeThrough(
                token: _step,
                child: KeyedSubtree(
                  key: ValueKey('step-body-$_step'),
                  child: _steps[_step](poster),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          step: _step,
          status: status,
          saveError: mine ? s.saveError : null,
          onPrev: () => unawaited(_goTo(_step - 1)),
          onNext: () => unawaited(_goTo(_step + 1)),
          onFinish: () => Navigator.of(context).maybePop(),
          onRetry: () => unawaited(ctl.flush()),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = editorStepLabels.length;
    final dur = Motion.of(context, Motion.base);
    Widget line(bool visible, bool active) => Expanded(
      child: AnimatedContainer(
        duration: dur,
        curve: Motion.enter,
        height: 2,
        color: !visible
            ? Colors.transparent
            : active
            ? cs.primary
            : cs.outlineVariant,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == current,
                label: 'الخطوة ${i + 1} من $n: ${editorStepLabels[i]}',
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('step-$i'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              line(i > 0, i <= current),
                              _StepDot(
                                index: i,
                                state: i == current
                                    ? _DotState.current
                                    : i < current
                                    ? _DotState.done
                                    : _DotState.todo,
                              ),
                              line(i < n - 1, i < current),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: dur,
                            curve: Motion.enter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge!.copyWith(
                              fontWeight: i == current
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: i == current
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                            child: Text(editorStepLabels[i]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _DotState { todo, current, done }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.state});
  final int index;
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (bg, fg, border) = switch (state) {
      _DotState.current => (cs.primary, cs.onPrimary, cs.primary),
      _DotState.done => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        cs.primary,
      ),
      _DotState.todo => (cs.surface, cs.onSurfaceVariant, cs.outline),
    };
    return AnimatedContainer(
      duration: Motion.of(context, Motion.base),
      curve: Motion.enter,
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: state == _DotState.done
          ? Icon(Icons.check_rounded, size: 18, color: fg)
          : Text(
              '${index + 1}',
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.status,
    required this.saveError,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
    required this.onRetry,
  });

  final int step;
  final _SaveStatus status;
  final String? saveError;
  final VoidCallback onPrev, onNext, onFinish, onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final last = step == editorStepLabels.length - 1;
    const minSize = Size(0, 48);
    final err = saveError;
    return Material(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
            if (err != null)
              Semantics(
                liveRegion: true,
                child: Container(
                  color: cs.errorContainer,
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 20,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تعذّر الحفظ — تحقق من المساحة المتاحة ثم أعد المحاولة',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          minimumSize: minSize,
                          foregroundColor: cs.onErrorContainer,
                        ),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: step == 0 ? null : onPrev,
                    style: OutlinedButton.styleFrom(minimumSize: minSize),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('السابق'),
                  ),
                  Expanded(
                    child: Center(
                      child: _SaveIndicator(
                        status: err == null ? status : _SaveStatus.none,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: last ? onFinish : onNext,
                    style: FilledButton.styleFrom(minimumSize: minSize),
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      last ? Icons.check_rounded : Icons.arrow_forward,
                    ),
                    label: Text(last ? 'إنهاء' : 'التالي'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.status});
  final _SaveStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final Widget child = switch (status) {
      _SaveStatus.none => const SizedBox.shrink(),
      _SaveStatus.saving => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text('جارٍ الحفظ…', style: style),
        ],
      ),
      _SaveStatus.saved => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Text('تم الحفظ', style: style?.copyWith(color: cs.primary)),
        ],
      ),
    };
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.quick),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(a),
            child: c,
          ),
        ),
        child: FittedBox(
          key: ValueKey(status),
          fit: BoxFit.scaleDown,
          child: child,
        ),
      ),
    );
  }
}

/// A small thumbnail of the poster (debounced cached raster); tapping it
/// opens the live [_FullPreview].
class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.poster, required this.onTap});
  final MonthPoster poster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'معاينة الملصق',
      child: Semantics(
        button: true,
        label: 'معاينة الملصق',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline, width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  // A cached raster, refreshed once typing pauses: a commit
                  // never re-lays-out a full poster just for this icon.
                  // Shares a Hero tag with the Home card it was opened from.
                  child: Hero(
                    tag: posterHeroTag(poster.id),
                    flightShuttleBuilder: posterHeroShuttle(poster),
                    child: PosterThumbnail(
                      poster: poster,
                      width: 19,
                      debounce: kThumbnailDebounce,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-zoomable live preview of the poster being edited.
class _FullPreview extends ConsumerWidget {
  const _FullPreview({required this.fallback});
  final MonthPoster fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorProvider);
    final poster = s.isOpen && s.poster.id == fallback.id ? s.poster : fallback;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        title: const Text('معاينة الملصق'),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(64),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: PosterPreview(poster: poster),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'قرّب بإصبعين للتكبير',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
