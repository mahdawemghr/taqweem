part of 'step_grid.dart';

// ---------------------------------------------------------------------------
// Note field
// ---------------------------------------------------------------------------

/// A note as printed: the poster shows it in one table cell, so line
/// breaks (and the spaces around them) become one space; ends are trimmed.
String cleanNote(String s) =>
    s.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

/// The occasion note of a day: RTL, up to 3 lines, committed on blur.
/// While focused it offers occasion suggestions and publishes its
/// controller to [activeNote] for the [HonorificBar].
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
    final suggestions = _focus.hasFocus && q.isNotEmpty
        ? searchOccasions(q).where((s) => s != q).take(5).toList()
        : const <String>[];
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
          ),
      ],
    );
  }
}
