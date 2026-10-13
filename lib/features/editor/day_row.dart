part of 'step_grid.dart';

// ---------------------------------------------------------------------------
// Table layout
// ---------------------------------------------------------------------------

/// Column flex factors of the wide table (shared by header and rows).
const _flexWeekday = 10,
    _flexHijri = 6,
    _flexDate = 8,
    _flexTime = 9,
    _flexNote = 30;
const _actionsWidth = 148.0;

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget cell(String t, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          t,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return Container(
      key: const ValueKey('grid-table-header'),
      color: cs.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            cell('اليوم', _flexWeekday),
            cell('هجري', _flexHijri),
            cell('ميلادي', _flexDate),
            cell('شمسي', _flexDate),
            for (final s in PrayerSlot.values) cell(s.labelAr, _flexTime),
            cell('المناسبة', _flexNote),
            const SizedBox(width: _actionsWidth),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One day
// ---------------------------------------------------------------------------

class _DayRowItem extends ConsumerStatefulWidget {
  const _DayRowItem({
    required this.index,
    required this.wide,
    required this.scope,
    super.key,
  });

  final int index;
  final bool wide;
  final _GridScope scope;

  @override
  ConsumerState<_DayRowItem> createState() => _DayRowItemState();
}

class _DayRowItemState extends ConsumerState<_DayRowItem> {
  late final Map<PrayerSlot, FocusNode> _nodes = {
    for (final s in PrayerSlot.values)
      s: FocusNode(debugLabel: 'time-${widget.index}-${s.name}'),
  };

  int get _i => widget.index;
  _GridScope get _scope => widget.scope;

  @override
  void initState() {
    super.initState();
    final nav = _scope.nav;
    nav.rows[_i] = context;
    for (final e in _nodes.entries) {
      nav.nodes[(_i, e.key)] = e.value;
    }
    final p = nav.pending;
    if (p != null && p.$1 == _i) {
      nav.pending = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodes[p.$2]!.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    final nav = _scope.nav;
    if (identical(nav.rows[_i], context)) nav.rows.remove(_i);
    for (final e in _nodes.entries) {
      if (identical(nav.nodes[(_i, e.key)], e.value)) {
        nav.nodes.remove((_i, e.key));
      }
      e.value.dispose();
    }
    super.dispose();
  }

  /// One editor update (one undo step) changing this row. Uses the
  /// controller captured by the step, so it also works after dispose.
  void _updateRow(DayRow Function(DayRow) f) {
    final i = _i;
    _scope.ctl.update((p) {
      if (i >= p.days.length) return p;
      final days = [...p.days];
      days[i] = f(days[i]);
      return p.copyWith(days: days);
    });
  }

  void _toggleUncertain(DayField f) => _updateRow((r) {
    final u = {...r.uncertain};
    if (!u.remove(f)) u.add(f);
    return r.copyWith(uncertain: u);
  });

  void _copyPrevious() {
    final days = ref.read(editorProvider).poster.days;
    if (_i == 0 || _i >= days.length) return;
    final prev = days[_i - 1].times;
    _updateRow((r) => r.copyWith(times: prev));
    _scope.snack('تم نسخ أوقات اليوم السابق', undo: true);
  }

  Future<void> _editDate(DayField field, DayCell cell) async {
    final r = await showDialog<DayCell>(
      context: context,
      builder: (_) => _DateDialog(
        title:
            '${field == DayField.gregorian ? 'التاريخ الميلادي' : 'التاريخ الشمسي'} – اليوم ${_i + 1}',
        initial: cell,
      ),
    );
    if (r == null || r == cell) return;
    _updateRow(
      (row) => field == DayField.gregorian
          ? row.copyWith(gregorian: r)
          : row.copyWith(solar: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugGridRowBuilds.update(_i, (v) => v + 1, ifAbsent: () => 1);
      return true;
    }());
    final i = _i;
    final row = ref.watch(
      editorProvider.select(
        (s) => i < s.poster.days.length ? s.poster.days[i] : null,
      ),
    );
    if (row == null) return const SizedBox.shrink();
    final isLast = ref.watch(
      editorProvider.select((s) => i == s.poster.days.length - 1),
    );
    final month = ref.watch(
      editorProvider.select((s) => s.poster.hijriMonthIndex),
    );
    final daysInMonth = ref.watch(
      editorProvider.select((s) => s.poster.days.length),
    );
    final issues = ref.watch(
      gridIssuesProvider.select(
        (l) => [
          for (final x in l)
            if (x.dayIndex == i) x.messageAr,
        ].join('\n'),
      ),
    );

    // Invalid typed text of this row's cells (a record: value equality, so
    // other rows' entries never rebuild this row).
    final invalid = ref.watch(
      invalidTimesProvider.select(
        (m) => (
          m[(i, PrayerSlot.fajr)],
          m[(i, PrayerSlot.shurooq)],
          m[(i, PrayerSlot.zuhr)],
          m[(i, PrayerSlot.maghrib)],
        ),
      ),
    );
    String? invalidOf(PrayerSlot s) => switch (s) {
      PrayerSlot.fajr => invalid.$1,
      PrayerSlot.shurooq => invalid.$2,
      PrayerSlot.zuhr => invalid.$3,
      PrayerSlot.maghrib => invalid.$4,
    };

    Widget time(PrayerSlot s) {
      final f = _fieldOf(s);
      final store = _scope.invalid;
      return TimeCell(
        key: ValueKey('time-$i-${s.name}'),
        value: row.times[s],
        label: s.labelAr,
        semanticLabel: '${s.labelAr} – اليوم ${i + 1}',
        focusNode: _nodes[s],
        onCommit: (v) =>
            _updateRow((r) => r.copyWith(times: r.times.withSlot(s, v))),
        onNext: () => _scope.focusNext(i, s),
        textInputAction: isLast && s == PrayerSlot.maghrib
            ? TextInputAction.done
            : TextInputAction.next,
        uncertain: row.uncertain.contains(f),
        markerKey: ValueKey('uncertain-$i-${f.name}'),
        onToggleUncertain: () => _toggleUncertain(f),
        floatingLabel: !widget.wide,
        pendingInvalid: invalidOf(s),
        onInvalid: (t) => store.put(i, s, t),
        active: _scope.activeTime,
      );
    }

    final note = _NoteField(
      key: ValueKey('note-$i'),
      value: row.note,
      dayNumber: i + 1,
      uncertain: row.uncertain.contains(DayField.note),
      markerKey: ValueKey('uncertain-$i-note'),
      activeNote: _scope.activeNote,
      floatingLabel: !widget.wide,
      onCommit: (t) => _updateRow((r) => r.copyWith(note: t)),
      onToggleUncertain: () => _toggleUncertain(DayField.note),
      occasions: occasionsFor(
        hijriMonthIndex: month,
        day: row.hijriDay,
        daysInMonth: daysInMonth,
      ),
    );

    DateChip date(DayField f, DayCell c) => DateChip(
      key: ValueKey('date-$i-${f.name}'),
      cell: c,
      caption: f == DayField.gregorian ? 'ميلادي' : 'شمسي',
      dayNumber: i + 1,
      uncertain: row.uncertain.contains(f),
      showCaption: !widget.wide,
      onTap: () => _editDate(f, c),
    );

    final menu = _RowMenu(
      key: ValueKey('row-menu-$i'),
      dayNumber: i + 1,
      uncertain: row.uncertain,
      onToggle: _toggleUncertain,
    );
    final issueMarker = issues.isEmpty
        ? null
        : _IssueMarker(key: ValueKey('row-issue-$i'), message: issues);

    return widget.wide
        ? _TableRowView(
            row: row,
            index: i,
            time: time,
            note: note,
            date: date,
            menu: menu,
            issueMarker: issueMarker,
            onHighlight: (v) => _updateRow((r) => r.copyWith(highlighted: v)),
            onCopyPrevious: i == 0 ? null : _copyPrevious,
          )
        : _DayCard(
            row: row,
            index: i,
            time: time,
            note: note,
            date: date,
            menu: menu,
            issueMarker: issueMarker,
            onHighlight: (v) => _updateRow((r) => r.copyWith(highlighted: v)),
            onCopyPrevious: i == 0 ? null : _copyPrevious,
          );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.row,
    required this.index,
    required this.time,
    required this.note,
    required this.date,
    required this.menu,
    required this.issueMarker,
    required this.onHighlight,
    required this.onCopyPrevious,
  });

  final DayRow row;
  final int index;
  final Widget Function(PrayerSlot) time;
  final Widget note;
  final Widget Function(DayField, DayCell) date;
  final Widget menu;
  final Widget? issueMarker;
  final ValueChanged<bool> onHighlight;
  final VoidCallback? onCopyPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hl = row.highlighted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: hl ? _highlightBg : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hl ? _gold : cs.outlineVariant.withValues(alpha: 0.6),
            width: hl ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hl ? 16 : 12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      HijriBadge(day: row.hijriDay),
                      const SizedBox(width: 10),
                      Expanded(
                        // Scales down (never cut) at large text sizes.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            row.weekday.ar,
                            maxLines: 1,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      ?issueMarker,
                      const SizedBox(width: 4),
                      date(DayField.gregorian, row.gregorian),
                      const SizedBox(width: 6),
                      date(DayField.solar, row.solar),
                      menu,
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in PrayerSlot.values) ...[
                        if (s.index > 0) const SizedBox(width: 6),
                        Expanded(child: time(s)),
                      ],
                    ],
                  ),
                  // Also holds a cell's `وقت غير صالح` line (no jump).
                  const SizedBox(height: 16),
                  note,
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _HighlightSwitch(
                        index: index,
                        value: hl,
                        onChanged: onHighlight,
                      ),
                      if (onCopyPrevious != null)
                        TextButton.icon(
                          key: ValueKey('copy-prev-$index'),
                          onPressed: onCopyPrevious,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 18,
                          ),
                          label: const Text('نسخ اليوم السابق'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (hl)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: ColoredBox(color: _gold),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableRowView extends StatelessWidget {
  const _TableRowView({
    required this.row,
    required this.index,
    required this.time,
    required this.note,
    required this.date,
    required this.menu,
    required this.issueMarker,
    required this.onHighlight,
    required this.onCopyPrevious,
  });

  final DayRow row;
  final int index;
  final Widget Function(PrayerSlot) time;
  final Widget note;
  final Widget Function(DayField, DayCell) date;
  final Widget menu;
  final Widget? issueMarker;
  final ValueChanged<bool> onHighlight;
  final VoidCallback? onCopyPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hl = row.highlighted;
    Widget pad(int flex, Widget child) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: hl
            ? _highlightBg
            : index.isEven
            ? cs.surfaceContainerLowest
            : cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
          left: BorderSide(color: hl ? _gold : Colors.transparent, width: 6),
        ),
      ),
      // The bottom padding holds a cell's `وقت غير صالح` line.
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pad(
            _flexWeekday,
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.weekday.ar,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?issueMarker,
                ],
              ),
            ),
          ),
          pad(_flexHijri, Center(child: HijriBadge(day: row.hijriDay))),
          pad(_flexDate, date(DayField.gregorian, row.gregorian)),
          pad(_flexDate, date(DayField.solar, row.solar)),
          for (final s in PrayerSlot.values) pad(_flexTime, time(s)),
          pad(_flexNote, note),
          SizedBox(
            width: _actionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: ValueKey('highlight-$index'),
                  tooltip: 'مناسبة مهمة',
                  isSelected: hl,
                  onPressed: () => onHighlight(!hl),
                  icon: const Icon(Icons.star_border_rounded),
                  selectedIcon: const Icon(Icons.star_rounded, color: _gold),
                ),
                if (onCopyPrevious != null)
                  IconButton(
                    key: ValueKey('copy-prev-$index'),
                    tooltip: 'نسخ اليوم السابق',
                    onPressed: onCopyPrevious,
                    icon: const Icon(Icons.content_copy_rounded),
                  )
                else
                  const SizedBox(width: 48),
                menu,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Hijri day number in a filled circle.
class HijriBadge extends StatelessWidget {
  const HijriBadge({required this.day, super.key});
  final int day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      label: 'اليوم الهجري $day',
      excludeSemantics: true,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: Text(
          '$day',
          textScaler: TextScaler.noScaling,
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A Gregorian / solar date cell: the day number, or the month name on the
/// first day of a month. Tapping it opens the override dialog.
class DateChip extends StatelessWidget {
  const DateChip({
    required this.cell,
    required this.caption,
    required this.dayNumber,
    required this.onTap,
    this.uncertain = false,
    this.showCaption = true,
    super.key,
  });

  final DayCell cell;
  final String caption;
  final int dayNumber;
  final bool uncertain;
  final bool showCaption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = cell.isLabel;
    final text = label ? cell.label! : '${cell.number}';
    return Semantics(
      button: true,
      label:
          '$caption $text – اليوم $dayNumber${uncertain ? '، غير مؤكد' : ''}، اضغط للتعديل',
      excludeSemantics: true,
      child: Material(
        color: label ? _goldTint : cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: uncertain
                ? uncertainColor
                : label
                ? _gold.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showCaption)
                    Text(
                      caption,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: label ? _goldText : cs.onSurface,
                      height: 1.2,
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

class _IssueMarker extends StatelessWidget {
  const _IssueMarker({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    child: Semantics(
      label: 'تنبيه: $message',
      excludeSemantics: true,
      child: const SizedBox(
        width: 40,
        height: 48,
        child: Icon(Icons.error_outline_rounded, color: uncertainColor),
      ),
    ),
  );
}

class _HighlightSwitch extends StatelessWidget {
  const _HighlightSwitch({
    required this.index,
    required this.value,
    required this.onChanged,
  });
  final int index;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                key: ValueKey('highlight-$index'),
                value: value,
                activeTrackColor: _gold,
                onChanged: onChanged,
              ),
              const SizedBox(width: 6),
              Text(
                'مناسبة مهمة',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: value ? FontWeight.w700 : FontWeight.w400,
                  color: value ? _goldText : null,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-row menu: flag / unflag each field as uncertain.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.dayNumber,
    required this.uncertain,
    required this.onToggle,
    super.key,
  });

  final int dayNumber;
  final Set<DayField> uncertain;
  final ValueChanged<DayField> onToggle;

  static const _fields = [
    DayField.fajr,
    DayField.shurooq,
    DayField.zuhr,
    DayField.maghrib,
    DayField.note,
    DayField.gregorian,
    DayField.solar,
  ];

  @override
  Widget build(BuildContext context) => PopupMenuButton<DayField>(
    tooltip: 'خيارات اليوم $dayNumber',
    icon: Icon(
      uncertain.isEmpty ? Icons.more_vert_rounded : Icons.flag_rounded,
      color: uncertain.isEmpty ? null : uncertainColor,
    ),
    onSelected: onToggle,
    itemBuilder: (_) => [
      for (final f in _fields)
        PopupMenuItem(
          value: f,
          child: Text(
            '${_fieldLabel(f)}: '
            '${uncertain.contains(f) ? 'إلغاء التحديد' : 'تحديد كغير مؤكد'}',
          ),
        ),
    ],
  );
}
