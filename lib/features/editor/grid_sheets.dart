part of 'step_grid.dart';

class _IssuesSheet extends ConsumerWidget {
  const _IssuesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final issues = ref.watch(gridIssuesProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              issuesLabel(issues.length),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'التنبيهات لا تمنع المتابعة. اضغط على تنبيه للانتقال إلى اليوم.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: issues.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
              itemBuilder: (_, k) {
                final issue = issues[k];
                final jump = issue.dayIndex != null;
                return ListTile(
                  minTileHeight: 52,
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: uncertainColor,
                  ),
                  title: Text(issue.messageAr),
                  trailing: jump
                      ? Icon(Icons.chevron_right_rounded, color: cs.outline)
                      : null,
                  onTap: () => Navigator.of(context).pop(issue),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Choose a column and a signed minute offset; pops `(slot, delta)`.
class _ShiftSheet extends StatefulWidget {
  const _ShiftSheet({required this.poster});
  final MonthPoster poster;

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  PrayerSlot _slot = PrayerSlot.fajr;
  int _delta = 1;

  void _step(int by) => setState(() {
    var d = _delta + by;
    if (d == 0) d += by; // skip 0
    _delta = d.clamp(-30, 30);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sample = widget.poster.days
        .map((d) => d.times[_slot])
        .firstWhere((v) => v != null, orElse: () => null);
    final count = widget.poster.days.where((d) => d.times[_slot] != null);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إزاحة عمود',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'يُضاف الفرق إلى كل الأوقات المُدخلة في العمود (يمكنك التراجع).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in PrayerSlot.values)
                  ChoiceChip(
                    key: ValueKey('shift-slot-${s.name}'),
                    label: Text(s.labelAr),
                    selected: _slot == s,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => setState(() => _slot = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('shift-plus'),
                  tooltip: 'زيادة دقيقة',
                  iconSize: 28,
                  onPressed: _delta < 30 ? () => _step(1) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${signedMinutes(_delta, plus: true)} دقيقة',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  key: const ValueKey('shift-minus'),
                  tooltip: 'إنقاص دقيقة',
                  iconSize: 28,
                  onPressed: _delta > -30 ? () => _step(-1) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sample == null
                  ? 'لا توجد أوقات مُدخلة في هذا العمود'
                  : 'مثال: ${formatTime(sample)} تصبح '
                        '${formatTime(shiftMinutes(sample, _delta))}'
                        ' · ${count.length} يوماً',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: sample == null
                  ? null
                  : () => Navigator.of(context).pop((_slot, _delta)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDialog extends StatefulWidget {
  const _DateDialog({required this.title, required this.initial});
  final String title;
  final DayCell initial;

  @override
  State<_DateDialog> createState() => _DateDialogState();
}

class _DateDialogState extends State<_DateDialog> {
  late final _ctl = TextEditingController(
    text: widget.initial.isLabel
        ? widget.initial.label
        : '${widget.initial.number}',
  );
  bool _error = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    final c = parseDateCellInput(_ctl.text);
    if (c == null) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('date-dialog-field'),
      controller: _ctl,
      autofocus: true,
      textAlign: TextAlign.center,
      onChanged: (_) {
        if (_error) setState(() => _error = false);
      },
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        labelText: 'رقم اليوم أو اسم الشهر',
        helperText: 'اكتب اسم الشهر في أول يوم منه',
        helperMaxLines: 2,
        errorText: _error ? 'قيمة غير صالحة' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('حفظ')),
    ],
  );
}
