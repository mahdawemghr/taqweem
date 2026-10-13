part of 'step_grid.dart';

// ---------------------------------------------------------------------------
// Note field
// ---------------------------------------------------------------------------

/// A note as printed: the poster shows it in one table cell, so line
/// breaks (and the spaces around them) become one space; ends are trimmed.
String cleanNote(String s) =>
    s.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

/// The occasion note of a day: RTL, up to 3 lines, committed on blur.
/// Below it, the day's Shia [occasions] are offered as chips (one tap adds
/// one); while the user types, search suggestions take their place. While
/// focused it publishes its controller to [activeNote] for the
/// [HonorificBar].
class _NoteField extends StatefulWidget {
  const _NoteField({
    required this.value,
    required this.dayNumber,
    required this.activeNote,
    required this.onCommit,
    required this.onToggleUncertain,
    required this.uncertain,
    required this.markerKey,
    required this.floatingLabel,
    this.occasions = const [],
    super.key,
  });

  final String value;
  final int dayNumber;
  final ActiveTextController activeNote;
  final ValueChanged<String> onCommit;
  final VoidCallback onToggleUncertain;
  final bool uncertain;
  final Key markerKey;
  final bool floatingLabel;

  /// This day's occasions from the built-in database (mains first).
  final List<ShiaOccasion> occasions;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.value,
  );
  final _focus = FocusNode(debugLabel: 'note');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_NoteField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        cleanNote(_ctl.text) != cleanNote(widget.value)) {
      _ctl.text = widget.value;
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.activeNote.value = _ctl;
    } else {
      widget.activeNote.release(_ctl);
      _commit();
    }
    setState(() {});
  }

  void _commit() {
    final t = cleanNote(_ctl.text);
    // Compared cleaned on both sides: a stored note with stray spaces is
    // not "changed" by a plain focus / blur (no spurious undo step).
    if (t == cleanNote(widget.value)) return;
    if (!_focus.hasFocus && _ctl.text != t) _ctl.text = t;
    widget.onCommit(t);
  }

  void _pick(String s) {
    _ctl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    _commit();
    setState(() {});
  }

  /// Adds an occasion: an empty note becomes [s]; otherwise « - [s]» is
  /// appended, unless the note already contains it. One committed update.
  void _addOccasion(String s) {
    final cur = cleanNote(_ctl.text);
    if (cur.contains(s)) return;
    _pick(cur.isEmpty ? s : '$cur - $s');
  }

  @override
  void dispose() {
    final t = cleanNote(_ctl.text);
    if (t != cleanNote(widget.value)) {
      final commit = widget.onCommit;
      scheduleMicrotask(() => commit(t));
    }
    // The holder's listeners must not run while the tree is locked.
    final active = widget.activeNote, ctl = _ctl;
    scheduleMicrotask(() {
      active.release(ctl);
      ctl.dispose();
    });
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = _ctl.text.trim();
    // "Typing": focused and the text differs from the stored note.
    final typing =
        _focus.hasFocus &&
        q.isNotEmpty &&
        cleanNote(_ctl.text) != cleanNote(widget.value);
    final suggestions = typing
        ? searchNoteSuggestions(q).where((s) => s != q).toList()
        : const <String>[];
    final index = widget.dayNumber - 1;
    final current = cleanNote(_ctl.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctl,
          focusNode: _focus,
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          textDirection: TextDirection.rtl,
          style: theme.textTheme.bodyLarge,
          onChanged: (_) => setState(() {}),
          // Touch-outside does not blur on mobile by default.
          onTapOutside: (_) => _focus.unfocus(),
          contextMenuBuilder: (context, state) =>
              AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: [
                  uncertainMenuItem(
                    uncertain: widget.uncertain,
                    onToggle: widget.onToggleUncertain,
                  ),
                  ...state.contextMenuButtonItems,
                ],
              ),
          decoration: InputDecoration(
            label: Text(
              'المناسبة',
              semanticsLabel: 'المناسبة – اليوم ${widget.dayNumber}',
            ),
            floatingLabelBehavior: widget.floatingLabel
                ? FloatingLabelBehavior.auto
                : FloatingLabelBehavior.never,
            isDense: true,
            filled: true,
            fillColor: widget.uncertain ? uncertainTint : cs.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            suffixIcon: widget.uncertain
                ? UncertainMarker(key: widget.markerKey)
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          TextFieldTapRegion(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      avatar: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          s,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () => _pick(s),
                    ),
                ],
              ),
            ),
          )
        else if (widget.occasions.isNotEmpty)
          TextFieldTapRegion(
            key: ValueKey('occasions-$index'),
            child: _DayOccasions(
              index: index,
              occasions: widget.occasions,
              current: current,
              onPick: _addOccasion,
            ),
          ),
      ],
    );
  }
}

/// «مناسبات هذا اليوم»: the day's occasions as wrapping chips.
class _DayOccasions extends StatelessWidget {
  const _DayOccasions({
    required this.index,
    required this.occasions,
    required this.current,
    required this.onPick,
  });

  final int index;
  final List<ShiaOccasion> occasions;

  /// The note as typed now (an occasion already in it shows a check).
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: _gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'مناسبات هذا اليوم',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (k, o) in occasions.indexed)
                _OccasionChip(
                  key: ValueKey('occ-$index-$k'),
                  occasion: o,
                  included: current.contains(o.noteText),
                  onTap: () => onPick(o.noteText),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One occasion: solid gold for a main entry, dashed outline and italic for
/// an alternate (another narration), ⚠ for an entry still to be verified.
/// Long-press shows the full research note and the sources.
class _OccasionChip extends StatelessWidget {
  const _OccasionChip({
    required this.occasion,
    required this.included,
    required this.onTap,
    super.key,
  });

  final ShiaOccasion occasion;
  final bool included;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final o = occasion;
    final text = o.noteText;
    final alt = o.isAlternate;
    final warn = !o.verified;
    final fg = warn
        ? uncertainColor
        : alt
        ? cs.onSurfaceVariant
        : _goldText;
    final border = warn
        ? const Color(0xFFE5C98A)
        : _gold.withValues(alpha: 0.7);
    final tip = [
      if (alt && o.fullNoteAr != null) o.fullNoteAr!,
      if (warn) 'يحتاج تأكيداً من حقيبة المؤمن',
      'المصادر: ${o.sourceNames.join('، ')}',
    ].join('\n');
    const radius = BorderRadius.all(Radius.circular(12));
    final icon = included
        ? Icons.check_rounded
        : warn
        ? Icons.warning_amber_rounded
        : Icons.add_rounded;
    return Semantics(
      button: true,
      label: 'مناسبة: $text',
      hint: [
        if (alt) 'رواية أخرى',
        if (warn) 'يحتاج تأكيداً',
        if (included) 'مضافة',
      ].join('، '),
      excludeSemantics: true,
      child: Tooltip(
        message: tip,
        excludeFromSemantics: true,
        triggerMode: TooltipTriggerMode.longPress,
        child: CustomPaint(
          foregroundPainter: alt
              ? _DashedBorderPainter(
                  color: warn ? uncertainColor : cs.outline,
                  radius: 12,
                )
              : null,
          child: Material(
            color: warn
                ? uncertainTint
                : alt
                ? cs.surface
                : _goldTint,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: alt ? BorderSide.none : BorderSide(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight: alt ? FontWeight.w500 : FontWeight.w600,
                            fontStyle: alt ? FontStyle.italic : null,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (warn) ...[
                        const SizedBox(width: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: uncertainColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'للتحقق',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: uncertainColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// A dashed rounded-rectangle outline (alternate occasion chips).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.6),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 3.5;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
