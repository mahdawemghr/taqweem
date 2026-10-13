import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/time_format.dart';

/// Amber used for "uncertain" markers (about 6:1 on the light surfaces).
const uncertainColor = Color(0xFF8A5A00);
const uncertainTint = Color(0xFFFFF4DC);

/// Error text shown under a time that cannot be parsed.
const invalidTimeText = 'وقت غير صالح';

/// The context-menu item (long-press) that toggles the uncertain flag.
ContextMenuButtonItem uncertainMenuItem({
  required bool uncertain,
  required VoidCallback onToggle,
}) => ContextMenuButtonItem(
  label: uncertain ? 'إلغاء التحديد' : 'تحديد كغير مؤكد',
  onPressed: () {
    ContextMenuController.removeAny();
    onToggle();
  },
);

/// Small amber ⚠ shown inside a field flagged as uncertain (never printed).
class UncertainMarker extends StatelessWidget {
  const UncertainMarker({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'غير مؤكد',
    child: const Padding(
      padding: EdgeInsetsDirectional.only(end: 4),
      child: Icon(Icons.warning_amber_rounded, size: 16, color: uncertainColor),
    ),
  );
}

/// What the keyboard accessory can do for the focused [TimeCell].
class TimeCellActions {
  const TimeCellActions({
    required this.label,
    required this.next,
    required this.done,
  });

  /// Spoken/visible name of the focused cell (e.g. `الفجر – اليوم 5`).
  final String label;

  /// Same as the keyboard's "next": commit, then move on (stays on invalid).
  final VoidCallback next;

  /// Commit and close the keyboard (stays on invalid input).
  final VoidCallback done;
}

/// Holds the actions of the focused [TimeCell] (or null) for a
/// [TimeCellAccessory]. Cells set it on focus and [release] it on blur.
class ActiveTimeCell extends ValueNotifier<TimeCellActions?> {
  ActiveTimeCell() : super(null);

  bool _disposed = false;

  void release(TimeCellActions a) {
    if (!_disposed && identical(value, a)) value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A bar docked above the keyboard while a time cell is focused: the iOS
/// number pad has neither "next" nor "done", so these are always at hand.
class TimeCellAccessory extends StatelessWidget {
  const TimeCellAccessory({required this.actions, super.key});
  final TimeCellActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const size = Size(88, 48);
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Material(
          color: cs.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      actions.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('accessory-next'),
                    onPressed: actions.next,
                    style: TextButton.styleFrom(minimumSize: size),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('الحقل التالي'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    key: const ValueKey('accessory-done'),
                    onPressed: actions.done,
                    style: FilledButton.styleFrom(minimumSize: size),
                    child: const Text('تم'),
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

/// One prayer-time field.
///
/// Numeric keypad; accepts `418`, `4:18` and Arabic-Indic digits. The typed
/// text is kept while editing and only committed (one [onCommit] call, so
/// one undo step) on submit, on tapping outside or when the field loses
/// focus. Valid input is then shown as `h:mm`; an empty field commits `null`
/// (a deliberate clear). Invalid input keeps the text, shows
/// [invalidTimeText] below the field (in reserved space: no layout jump),
/// leaves the stored value unchanged and is reported via [onInvalid] so the
/// owner can keep it ([pendingInvalid] restores it when the cell is rebuilt).
class TimeCell extends StatefulWidget {
  const TimeCell({
    required this.value,
    required this.label,
    required this.semanticLabel,
    required this.onCommit,
    this.focusNode,
    this.onNext,
    this.textInputAction = TextInputAction.next,
    this.uncertain = false,
    this.markerKey,
    this.onToggleUncertain,
    this.floatingLabel = true,
    this.pendingInvalid,
    this.onInvalid,
    this.active,
    super.key,
  });

  /// Stored minutes (12-hour clock, see [formatTime]) or null.
  final int? value;

  /// Short visible label (e.g. `الفجر`).
  final String label;

  /// Full spoken label (e.g. `الفجر – اليوم 5`).
  final String semanticLabel;

  /// Called with the new value when a different value is committed. May be
  /// called (asynchronously) after the cell was disposed with a pending edit.
  final ValueChanged<int?> onCommit;

  final FocusNode? focusNode;

  /// Moves the focus on after a valid submit (keyboard "next").
  final VoidCallback? onNext;
  final TextInputAction textInputAction;

  final bool uncertain;
  final Key? markerKey;

  /// Adds `تحديد كغير مؤكد` / `إلغاء التحديد` to the long-press menu.
  final VoidCallback? onToggleUncertain;

  /// Label floats above the value (cards); otherwise it is only a
  /// placeholder of an empty field (table rows, which have a header).
  final bool floatingLabel;

  /// Invalid text recorded earlier for this cell: shown (in red) instead of
  /// [value] when the cell is created.
  final String? pendingInvalid;

  /// Reports invalid text (to keep) or null (entry resolved). May be called
  /// asynchronously after dispose.
  final ValueChanged<String?>? onInvalid;

  /// Publishes this cell's [TimeCellActions] while it is focused.
  final ActiveTimeCell? active;

  @override
  State<TimeCell> createState() => _TimeCellState();
}

class _TimeCellState extends State<TimeCell> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.pendingInvalid ?? formatTime(widget.value) ?? '',
  );
  FocusNode? _own;

  /// The text differs from what was last committed / restored.
  bool _dirty = false;
  bool _error = false;

  /// An invalid entry is recorded with the owner.
  bool _recorded = false;
  late final TimeCellActions _actions = TimeCellActions(
    label: widget.semanticLabel,
    next: _submit,
    done: _done,
  );

  /// The stored value the field text currently shows (after a commit the
  /// owner may change the value again before this cell is rebuilt, e.g.
  /// commit-then-undo, so the widget's old value is not enough).
  int? _shown;

  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _shown = widget.value;
    // Restored invalid text: shown in red, retried on the next blur.
    _dirty = _error = _recorded = widget.pendingInvalid != null;
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(TimeCell old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _own)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    // External change (own commit, undo, column shift, copy): show it —
    // unless the cell holds invalid text, which is never silently replaced.
    if (widget.value != _shown && !_error) {
      _ctl.text = formatTime(widget.value) ?? '';
      _shown = widget.value;
      // The outside value replaces any typed text: no pending edit, no
      // error, and the recorded invalid entry is released (after the build).
      _dirty = false;
      _error = false;
      if (_recorded) {
        _recorded = false;
        final invalid = widget.onInvalid;
        if (invalid != null) scheduleMicrotask(() => invalid(null));
      }
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.active?.value = _actions;
    } else {
      widget.active?.release(_actions);
      _commit();
    }
  }

  void _resolve() {
    if (_recorded) {
      _recorded = false;
      widget.onInvalid?.call(null);
    }
  }

  /// Commits the typed text; false when it is invalid.
  bool _commit() {
    if (!_dirty) return !_error;
    final raw = _ctl.text;
    final t = raw.trim();
    final int? v;
    if (t.isEmpty) {
      v = null;
    } else {
      v = parseTimeInput(t);
      if (v == null) {
        if (!_error) setState(() => _error = true);
        _recorded = true;
        widget.onInvalid?.call(raw);
        return false;
      }
      final f = formatTime(v)!;
      if (_ctl.text != f) _ctl.text = f;
    }
    _dirty = false;
    if (_error) setState(() => _error = false);
    _resolve();
    _shown = v;
    if (v != widget.value) widget.onCommit(v);
    return true;
  }

  void _submit() {
    if (_commit()) {
      widget.onNext == null ? _focus.unfocus() : widget.onNext!();
    }
  }

  void _done() {
    if (_commit()) _focus.unfocus();
  }

  @override
  void dispose() {
    // Scrolled away / step left with a pending edit: never lose it. The
    // owner is told after the tree is unlocked.
    if (_dirty) {
      final raw = _ctl.text;
      final t = raw.trim();
      final v = t.isEmpty ? null : parseTimeInput(t);
      final commit = widget.onCommit, invalid = widget.onInvalid;
      if (t.isNotEmpty && v == null) {
        if (invalid != null) scheduleMicrotask(() => invalid(raw));
      } else {
        final recorded = _recorded;
        final changed = v != widget.value;
        scheduleMicrotask(() {
          if (recorded) invalid?.call(null);
          if (changed) commit(v);
        });
      }
    }
    final active = widget.active, actions = _actions;
    if (active != null) scheduleMicrotask(() => active.release(actions));
    (widget.focusNode ?? _own)?.removeListener(_onFocus);
    _own?.dispose();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final errorBorder = _error
        ? OutlineInputBorder(borderSide: BorderSide(color: cs.error))
        : null;
    final field = TextField(
      controller: _ctl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      textInputAction: widget.textInputAction,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: _error ? cs.error : cs.onSurface,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹:]')),
        LengthLimitingTextInputFormatter(5),
      ],
      onChanged: (_) {
        _dirty = true;
        if (_error) setState(() => _error = false);
      },
      // Touch-outside does not blur on mobile by default (iOS has no "done"
      // on the number pad): blur, which commits.
      onTapOutside: (_) => _focus.unfocus(),
      // Replaces the default focus move: invalid input keeps the focus.
      onEditingComplete: _submit,
      contextMenuBuilder: (context, state) {
        final toggle = widget.onToggleUncertain;
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            if (toggle != null)
              uncertainMenuItem(uncertain: widget.uncertain, onToggle: toggle),
            ...state.contextMenuButtonItems,
          ],
        );
      },
      decoration: InputDecoration(
        label: Text(
          widget.label,
          semanticsLabel: widget.semanticLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        floatingLabelBehavior: widget.floatingLabel
            ? FloatingLabelBehavior.always
            : FloatingLabelBehavior.never,
        enabledBorder: errorBorder,
        focusedBorder: _error
            ? OutlineInputBorder(
                borderSide: BorderSide(color: cs.error, width: 2),
              )
            : null,
        floatingLabelStyle: _error ? TextStyle(color: cs.error) : null,
        isDense: true,
        filled: true,
        fillColor: widget.uncertain ? uncertainTint : cs.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        suffixIcon: widget.uncertain
            ? UncertainMarker(key: widget.markerKey)
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
      ),
    );
    // Always a Stack (stable tree: the field keeps its state). The message sits in the gap below the field (callers leave about
    // 12 px there), so showing it never moves the layout.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        field,
        if (_error)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: -13,
            height: 13,
            child: Semantics(
              liveRegion: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  invalidTimeText,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
