import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/arabic_days.dart';
import '../../core/arabic_digits.dart';
import '../../core/motion.dart';
import '../../domain/models.dart';
import '../../domain/occasions_library.dart';
import '../../domain/shia_occasion.dart';
import '../../domain/shia_occasions_lookup.dart';
import '../../domain/time_format.dart';
import '../../domain/validation.dart';
import '../../state/editor_controller.dart';
import 'honorific_bar.dart';
import 'invalid_times.dart';
import 'time_cell.dart';

part 'day_row.dart';
part 'grid_sheets.dart';
part 'note_field.dart';

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

/// Build counts of the day rows by index (debug builds only). A test seam
/// proving that editing one row does not rebuild the others.
@visibleForTesting
final Map<int, int> debugGridRowBuilds = {};

/// Validation issues of the poster being edited.
final posterIssuesProvider = Provider<List<PosterIssue>>((ref) {
  final s = ref.watch(editorProvider.select((s) => s.poster));
  return validatePoster(s);
});

/// [posterIssuesProvider] plus the invalid typed times of this session
/// (`اليوم N: وقت <slot> غير صالح`), ordered by day. An invalid entry
/// replaces the "missing" issue of the same cell.
final gridIssuesProvider = Provider<List<PosterIssue>>((ref) {
  final base = ref.watch(posterIssuesProvider);
  final invalid = ref.watch(invalidTimesProvider);
  final n = ref.watch(editorProvider.select((s) => s.poster.days.length));
  if (invalid.isEmpty) return base;
  final extra = [
    for (final k in invalid.keys)
      if (k.$1 < n)
        PosterIssue(
          dayIndex: k.$1,
          kind: IssueKind.invalidTime,
          field: _fieldOf(k.$2),
          messageAr: 'اليوم ${k.$1 + 1}: وقت ${k.$2.labelAr} غير صالح',
        ),
  ];
  bool shadowed(PosterIssue i) =>
      i.kind == IssueKind.missingTime &&
      extra.any((e) => e.dayIndex == i.dayIndex && e.field == i.field);
  final all = [
    for (final i in base)
      if (!shadowed(i)) i,
    ...extra,
  ];
  // Stable sort: row-wide issues first, then by day, then slot order.
  int slotRank(PosterIssue i) => i.field?.index ?? -1;
  final indexed = all.indexed.toList()
    ..sort((a, b) {
      final da = a.$2.dayIndex ?? -1, db = b.$2.dayIndex ?? -1;
      if (da != db) return da.compareTo(db);
      final sa = slotRank(a.$2), sb = slotRank(b.$2);
      if (sa != sb) return sa.compareTo(sb);
      return a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
});

const _gold = Color(0xFFB8892B);
const _goldText = Color(0xFF6E500F);
const _goldTint = Color(0xFFFBF3DF);
const _highlightBg = Color(0xFFFFF9EC);

/// `3 تنبيهات`, with the Arabic number agreement for 1, 2 and 11+.
String issuesLabel(int n) {
  if (n == 1) return 'تنبيه واحد';
  if (n == 2) return 'تنبيهان';
  if (n <= 10) return '$n تنبيهات';
  return '$n تنبيهاً';
}

/// A minute count that reads correctly inside Arabic text: a signed number
/// (negative, or positive with [plus]) is wrapped in an LTR isolate
/// (LRI…PDI) so `+2` never renders as `2+`.
String signedMinutes(int d, {bool plus = false}) {
  if (d < 0) return '\u2066$d\u2069';
  if (plus) return '\u2066+$d\u2069';
  return '$d';
}

/// The cell a pending "next" is waiting to focus, for the [StepGrid] above
/// [context] (tests only).
@visibleForTesting
(int, PrayerSlot)? debugGridPendingFocus(BuildContext context) {
  final e = context as StatefulElement;
  return (e.state as _StepGridState)._nav.pending;
}

String _fieldLabel(DayField f) => switch (f) {
  DayField.fajr => PrayerSlot.fajr.labelAr,
  DayField.shurooq => PrayerSlot.shurooq.labelAr,
  DayField.zuhr => PrayerSlot.zuhr.labelAr,
  DayField.maghrib => PrayerSlot.maghrib.labelAr,
  DayField.note => 'المناسبة',
  DayField.weekday => 'اليوم',
  DayField.hijri => 'هجري',
  DayField.gregorian => 'ميلادي',
  DayField.solar => 'شمسي',
};

DayField _fieldOf(PrayerSlot s) => switch (s) {
  PrayerSlot.fajr => DayField.fajr,
  PrayerSlot.shurooq => DayField.shurooq,
  PrayerSlot.zuhr => DayField.zuhr,
  PrayerSlot.maghrib => DayField.maghrib,
};

/// The time cell to focus for an issue (null: nothing to type there, the
/// row is just shown). A wrong order starts at الفجر.
PrayerSlot? _slotOfIssue(PosterIssue i) {
  if (i.kind == IssueKind.timeOrder) return PrayerSlot.fajr;
  return switch (i.field) {
    DayField.fajr => PrayerSlot.fajr,
    DayField.shurooq => PrayerSlot.shurooq,
    DayField.zuhr => PrayerSlot.zuhr,
    DayField.maghrib => PrayerSlot.maghrib,
    _ => null,
  };
}

/// Parses a date-cell override: a day number 1..31, or a month-name label.
DayCell? parseDateCellInput(String raw) {
  final t = normalizeDigits(raw.trim());
  if (t.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(t)) {
    final n = int.parse(t);
    return n >= 1 && n <= 31 ? DayCell.number(n) : null;
  }
  if (RegExp(r'\d').hasMatch(t)) return null;
  return DayCell.label(raw.trim());
}

/// Focus nodes and contexts of the rows currently built, so "next" can
/// cross rows and the issues sheet can jump to a row.
class _GridNav {
  final nodes = <(int, PrayerSlot), FocusNode>{};
  final rows = <int, BuildContext>{};

  /// A cell to focus as soon as its row is built.
  (int, PrayerSlot)? pending;

  /// Rows changed by a bulk action (auto-fill, time shift): built rows among
  /// them flash gold once so the user sees what changed. A new [gen] = a new
  /// event.
  final flash = ValueNotifier<({int gen, Set<int> rows})>((
    gen: 0,
    rows: const {},
  ));

  void flashRows(Iterable<int> rows) =>
      flash.value = (gen: flash.value.gen + 1, rows: rows.toSet());
}

/// A 600 ms gold tint that fades out over a row changed by a bulk action.
/// Only the tiny overlay animates (opacity); the row itself is untouched.
class _RowFlash extends StatefulWidget {
  const _RowFlash({
    required this.index,
    required this.nav,
    required this.child,
  });
  final int index;
  final _GridNav nav;
  final Widget child;

  @override
  State<_RowFlash> createState() => _RowFlashState();
}

class _RowFlashState extends State<_RowFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _gen = widget.nav.flash.value.gen;
    widget.nav.flash.addListener(_onFlash);
  }

  void _onFlash() {
    final e = widget.nav.flash.value;
    if (e.gen == _gen) return;
    _gen = e.gen;
    if (!e.rows.contains(widget.index) || !Motion.enabled(context)) return;
    _c
      ..value = 1
      ..animateTo(
        0,
        duration: Motion.of(context, const Duration(milliseconds: 600)),
        curve: Curves.easeOut,
      );
  }

  @override
  void dispose() {
    widget.nav.flash.removeListener(_onFlash);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack (stable tree: the row keeps its state and focus); the
    // overlay costs nothing at opacity 0.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _c.drive(Tween<double>(begin: 0, end: 0.35)),
              child: const ColoredBox(color: Color(0xFFC9A45E)),
            ),
          ),
        ),
      ],
    );
  }
}

/// What a row needs from the step (stable for the step's lifetime).
class _GridScope {
  _GridScope({
    required this.ctl,
    required this.nav,
    required this.activeNote,
    required this.activeTime,
    required this.invalid,
    required this.focusNext,
    required this.snack,
  });

  final EditorController ctl;
  final _GridNav nav;
  final ActiveTextController activeNote;
  final ActiveTimeCell activeTime;
  final InvalidTimes invalid;
  final void Function(int row, PrayerSlot slot) focusNext;
  final void Function(String text, {bool undo}) snack;
}

// ---------------------------------------------------------------------------
// Step 2
// ---------------------------------------------------------------------------

/// Step 2 "الأيام": the day grid where the times and occasions are typed.
///
/// Phones get a lazy list of compact day cards; screens of 900 px and more
/// a table. Each row watches only its own [DayRow], so typing in one day
/// never rebuilds the others.
class StepGrid extends ConsumerStatefulWidget {
  const StepGrid({required this.onGoToStep, super.key});

  /// Switches the editor to another step (the empty state goes to step 0).
  final ValueChanged<int> onGoToStep;

  @override
  ConsumerState<StepGrid> createState() => _StepGridState();
}

class _StepGridState extends ConsumerState<StepGrid> {
  final _scroll = ScrollController();
  final _nav = _GridNav();
  final _activeNote = ActiveTextController();
  final _activeTime = ActiveTimeCell();
  final _rowCache = <(bool, int), Widget>{};
  late final EditorController _ctl = ref.read(editorProvider.notifier);
  late final _GridScope _scope = _GridScope(
    ctl: _ctl,
    nav: _nav,
    activeNote: _activeNote,
    activeTime: _activeTime,
    invalid: ref.read(invalidTimesProvider.notifier),
    focusNext: _focusNext,
    snack: _snack,
  );

  @override
  void dispose() {
    _scroll.dispose();
    _activeNote.dispose();
    _activeTime.dispose();
    super.dispose();
  }

  int get _length => ref.read(editorProvider).poster.days.length;

  void _snack(String text, {bool undo = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: undo
              ? SnackBarAction(label: 'تراجع', onPressed: _ctl.undo)
              : null,
        ),
      );
  }

  void _focusNext(int row, PrayerSlot slot) {
    final next = slot == PrayerSlot.maghrib
        ? (row + 1, PrayerSlot.fajr)
        : (row, PrayerSlot.values[slot.index + 1]);
    if (next.$1 >= _length) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    final node = _nav.nodes[next];
    if (node != null) {
      node.requestFocus();
    } else {
      _nav.pending = next;
      _reveal(next.$1);
    }
  }

  /// Scrolls row [i] into view (building it first when it is off-screen),
  /// then focuses [focus] in it.
  void _reveal(int i, {PrayerSlot? focus, int attempt = 0}) {
    if (!mounted) return;
    if (i >= _length) {
      // The row is gone: a pending "next" into it must not fire later.
      _clearPending(i);
      return;
    }
    final ctx = _nav.rows[i];
    if (ctx != null && ctx.mounted) {
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ).then((_) {
          if (focus != null) _nav.nodes[(i, focus)]?.requestFocus();
        }),
      );
      return;
    }
    if (attempt > 6 || !_scroll.hasClients) {
      // Gave up: never let the row steal the focus when it appears later.
      _clearPending(i);
      return;
    }
    final pos = _scroll.position;
    final n = _length;
    final avg = (pos.maxScrollExtent + pos.viewportDimension) / n;
    _scroll.jumpTo((i * avg).clamp(0.0, pos.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(i, focus: focus, attempt: attempt + 1),
    );
  }

  void _clearPending(int row) {
    if (_nav.pending?.$1 == row) _nav.pending = null;
  }

  /// Blurs the focused field and lets its commit run (focus changes are
  /// applied in a microtask), so what follows sees the typed value.
  Future<void> _commitFocused() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.microtask(() {});
  }

  Future<void> _openShift() async {
    await _commitFocused();
    if (!mounted) return;
    final poster = ref.read(editorProvider).poster;
    final r = await showModalBottomSheet<(PrayerSlot, int)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShiftSheet(poster: poster),
    );
    if (r == null || !mounted) return;
    final (slot, delta) = r;
    _ctl.update(
      (p) => p.copyWith(
        days: [
          for (final d in p.days)
            d.times[slot] == null
                ? d
                : d.copyWith(
                    times: d.times.withSlot(
                      slot,
                      shiftMinutes(d.times[slot]!, delta),
                    ),
                  ),
        ],
      ),
    );
    _nav.flashRows([
      for (var i = 0; i < poster.days.length; i++)
        if (poster.days[i].times[slot] != null) i,
    ]);
    _snack(
      'تم إزاحة ${slot.labelAr} بمقدار ${signedMinutes(delta)} دقيقة',
      undo: true,
    );
  }

  /// «تعبئة المناسبات تلقائياً»: after a confirmation, writes the verified
  /// main occasions into every EMPTY note (one undo step).
  Future<void> _autofill() async {
    await _commitFocused();
    if (!mounted) return;
    final fills = autofillOccasionNotes(ref.read(editorProvider).poster);
    if (fills.isEmpty) {
      _snack('لا توجد مناسبات جاهزة للتعبئة');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AutofillDialog(count: fills.length),
    );
    if (ok != true || !mounted) return;
    var filled = 0;
    _ctl.update((p) {
      final days = [...p.days];
      for (final e in fills.entries) {
        if (e.key < days.length && days[e.key].note.trim().isEmpty) {
          days[e.key] = days[e.key].copyWith(note: e.value);
          filled++;
        }
      }
      return p.copyWith(days: days);
    });
    _nav.flashRows(fills.keys);
    _snack('تمت تعبئة ${arabicDays(filled)}', undo: true);
  }

  Future<void> _openIssues() async {
    await _commitFocused();
    if (!mounted) return;
    final issue = await showModalBottomSheet<PosterIssue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _IssuesSheet(),
    );
    final i = issue?.dayIndex;
    if (issue == null || i == null || !mounted || i >= _length) return;
    _reveal(i, focus: _slotOfIssue(issue));
  }

  Widget _row(bool wide, int i) => _rowCache[(wide, i)] ??= RepaintBoundary(
    child: _RowFlash(
      index: i,
      nav: _nav,
      child: _DayRowItem(
        key: ValueKey('row-$i'),
        index: i,
        wide: wide,
        scope: _scope,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final n = ref.watch(editorProvider.select((s) => s.poster.days.length));
    if (n == 0) return _EmptyState(onGo: () => widget.onGoToStep(0));
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final list = ListView.builder(
          key: const ValueKey('grid-list'),
          controller: _scroll,
          scrollCacheExtent: const ScrollCacheExtent.pixels(400),
          padding: wide
              ? const EdgeInsets.only(bottom: 24)
              : const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: n,
          itemBuilder: (_, i) => _row(wide, i),
        );
        return Column(
          children: [
            _ToolsBar(
              onShift: _openShift,
              onIssues: _openIssues,
              onAutofill: _autofill,
            ),
            Expanded(
              child: wide
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          children: [
                            const _TableHeader(),
                            Expanded(child: list),
                          ],
                        ),
                      ),
                    )
                  : list,
            ),
            // Docked above the keyboard: honorifics for a note, التالي / تم
            // for a time cell.
            ValueListenableBuilder<TextEditingController?>(
              valueListenable: _activeNote,
              builder: (_, c, _) => c == null
                  ? const SizedBox.shrink()
                  : HonorificBar(
                      key: const ValueKey('honorific-bar'),
                      controller: c,
                    ),
            ),
            ValueListenableBuilder<TimeCellActions?>(
              valueListenable: _activeTime,
              builder: (_, a, _) => a == null
                  ? const SizedBox.shrink()
                  : TimeCellAccessory(
                      key: const ValueKey('time-accessory'),
                      actions: a,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tools bar, sheets, empty state
// ---------------------------------------------------------------------------

class _ToolsBar extends StatelessWidget {
  const _ToolsBar({
    required this.onShift,
    required this.onIssues,
    required this.onAutofill,
  });
  final VoidCallback onShift, onIssues, onAutofill;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shift = OutlinedButton.icon(
      onPressed: onShift,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      icon: const Icon(Icons.swap_vert_rounded),
      label: const Text('إزاحة عمود'),
    );
    final autofill = FilledButton.tonalIcon(
      key: const ValueKey('autofill-occasions'),
      onPressed: onAutofill,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: _goldTint,
        foregroundColor: _goldText,
        side: BorderSide(color: _gold.withValues(alpha: 0.5)),
      ),
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text(
        'تعبئة المناسبات تلقائياً',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final issues = Expanded(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _IssuesChip(onTap: onIssues),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: LayoutBuilder(
          // Phones: the auto-fill button gets its own full-width line.
          builder: (context, c) => c.maxWidth >= 600
              ? Row(
                  children: [
                    issues,
                    const SizedBox(width: 8),
                    autofill,
                    const SizedBox(width: 8),
                    shift,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [issues, const SizedBox(width: 8), shift]),
                    const SizedBox(height: 4),
                    autofill,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Confirms «تعبئة المناسبات تلقائياً» for [count] days (pops true).
class _AutofillDialog extends StatelessWidget {
  const _AutofillDialog({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.auto_awesome_rounded, color: _gold),
      title: const Text('تعبئة المناسبات'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سيتم ملء ${arabicDays(count)} بالمناسبات الموثّقة (الأيام التي فيها ملاحظات لن تتغير). متابعة؟',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المصدر: قاعدة بيانات المناسبات الشيعية المدمجة — تحقق منها قبل الطباعة',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          child: const Text('تعبئة'),
        ),
      ],
    );
  }
}

class _IssuesChip extends ConsumerWidget {
  const _IssuesChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = ref.watch(gridIssuesProvider.select((l) => l.length));
    if (n == 0) {
      return Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'كل شيء سليم',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
          ],
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      button: true,
      label: '${issuesLabel(n)} — اضغط للعرض',
      excludeSemantics: true,
      child: ActionChip(
        onPressed: onTap,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        avatar: const Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: uncertainColor,
        ),
        backgroundColor: uncertainTint,
        side: const BorderSide(color: Color(0xFFE5C98A)),
        label: Text(
          issuesLabel(n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: uncertainColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGo});
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note_rounded, size: 44, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد أيام بعد',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أنشئ أيام الشهر من خطوة «الشهر» ثم عُد لإدخال الأوقات.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onGo,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('الذهاب إلى الشهر'),
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
