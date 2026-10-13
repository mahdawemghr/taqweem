import 'package:flutter/material.dart';

/// The honorifics / era suffixes typed most often in occasion notes and
/// poster texts.
const honorifics = ['(ع)', '(ص)', '(س)', '(رض)', 'ه', 'م'];

/// Inserts [text] at the caret of [c] (replacing a selection); with no valid
/// selection it is appended. The caret ends right after the inserted text.
void insertAtCaret(TextEditingController c, String text) {
  final v = c.value;
  final sel = v.selection;
  final start = sel.isValid ? sel.start : v.text.length;
  final end = sel.isValid ? sel.end : v.text.length;
  c.value = TextEditingValue(
    text: v.text.replaceRange(start, end, text),
    selection: TextSelection.collapsed(offset: start + text.length),
  );
}

/// Holds the controller of the text field that currently has focus (or
/// null), so one [HonorificBar] can serve many fields. Fields set it on
/// focus and clear it on blur / dispose via [release].
class ActiveTextController extends ValueNotifier<TextEditingController?> {
  ActiveTextController() : super(null);

  bool _disposed = false;

  /// Clears the holder only if [c] is still the active controller. A no-op
  /// once the holder is disposed (fields may release it late).
  void release(TextEditingController c) {
    if (!_disposed && identical(value, c)) value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A row of buttons inserting [honorifics] at the caret of [controller].
///
/// Tapping a button keeps the keyboard and the focus on the field (the bar
/// is a [TextFieldTapRegion]). [onInserted] runs after each insertion.
class HonorificBar extends StatelessWidget {
  const HonorificBar({required this.controller, this.onInserted, super.key});

  final TextEditingController controller;
  final VoidCallback? onInserted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TextFieldTapRegion(
      // The buttons never take the focus away from the field.
      child: ExcludeFocus(
        child: Material(
          color: cs.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  for (final h in honorifics)
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'إدراج $h',
                        excludeSemantics: true,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            foregroundColor: cs.onSurface,
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            insertAtCaret(controller, h);
                            onInserted?.call();
                          },
                          child: Text(h, maxLines: 1),
                        ),
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
