import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed_reference.dart';
import '../../domain/models.dart';
import '../../state/editor_controller.dart';
import 'honorific_bar.dart';

/// How long typing pauses before an edit is committed to the editor.
const _commitDelay = Duration(milliseconds: 400);

/// Above this many characters the poster shrinks the text to fit.
const _longText = 300;

/// One editable text of [PosterTexts].
class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label,
    this.get,
    this.set, {
    this.minLines = 1,
  });
  final String key, label;
  final String Function(PosterTexts) get;
  final PosterTexts Function(PosterTexts, String) set;
  final int minLines;
}

class _SectionSpec {
  const _SectionSpec(this.title, this.helper, this.fields);
  final String title, helper;
  final List<_FieldSpec> fields;
}

final _sections = <_SectionSpec>[
  _SectionSpec('العنوان', 'يظهر في أعلى الملصق، بجانب الشعار.', [
    _FieldSpec(
      'title',
      'نص العنوان',
      (t) => t.title,
      (t, v) => t.copyWith(title: v),
    ),
  ]),
  _SectionSpec('الاقتباس الأيمن', 'المربع على يمين الشعار في رأس الملصق.', [
    _FieldSpec(
      'rightQuote-text',
      'نص الاقتباس',
      (t) => t.rightQuote.text,
      (t, v) => t.copyWith(rightQuote: t.rightQuote.copyWith(text: v)),
      minLines: 2,
    ),
    _FieldSpec(
      'rightQuote-attribution',
      'نسبة القول',
      (t) => t.rightQuote.attribution,
      (t, v) => t.copyWith(rightQuote: t.rightQuote.copyWith(attribution: v)),
    ),
  ]),
  _SectionSpec('الاقتباس الأيسر', 'المربع على يسار الشعار في رأس الملصق.', [
    _FieldSpec(
      'leftQuote-text',
      'نص الاقتباس',
      (t) => t.leftQuote.text,
      (t, v) => t.copyWith(leftQuote: t.leftQuote.copyWith(text: v)),
      minLines: 2,
    ),
    _FieldSpec(
      'leftQuote-attribution',
      'نسبة القول',
      (t) => t.leftQuote.attribution,
      (t, v) => t.copyWith(leftQuote: t.leftQuote.copyWith(attribution: v)),
    ),
  ]),
  _SectionSpec(
    'الاقتباس تحت الشعار',
    'السطر بين الرأس والجدول. الأقواس تُضاف تلقائياً: لا تكتب الأقواس { }.',
    [
      _FieldSpec(
        'braceQuote',
        'نص الاقتباس',
        (t) => t.braceQuote,
        (t, v) => t.copyWith(braceQuote: v),
        minLines: 2,
      ),
    ],
  ),
  _SectionSpec('المقال الختامي', 'يظهر في أسفل الملصق، تحت الجدول.', [
    _FieldSpec(
      'article-author',
      'اسم الكاتب',
      (t) => t.article.author,
      (t, v) => t.copyWith(article: t.article.copyWith(author: v)),
    ),
    _FieldSpec(
      'article-body',
      'نص المقال',
      (t) => t.article.body,
      (t, v) => t.copyWith(article: t.article.copyWith(body: v)),
      minLines: 4,
    ),
  ]),
  _SectionSpec('سؤال وجواب (يمين)', 'يظهر عمودياً على حافة الجدول اليمنى.', [
    _FieldSpec(
      'sideRight-question',
      'السؤال',
      (t) => t.sideRight.question,
      (t, v) => t.copyWith(sideRight: t.sideRight.copyWith(question: v)),
      minLines: 2,
    ),
    _FieldSpec(
      'sideRight-answer',
      'الجواب',
      (t) => t.sideRight.answer,
      (t, v) => t.copyWith(sideRight: t.sideRight.copyWith(answer: v)),
      minLines: 2,
    ),
  ]),
  _SectionSpec('سؤال وجواب (يسار)', 'يظهر عمودياً على حافة الجدول اليسرى.', [
    _FieldSpec(
      'sideLeft-question',
      'السؤال',
      (t) => t.sideLeft.question,
      (t, v) => t.copyWith(sideLeft: t.sideLeft.copyWith(question: v)),
      minLines: 2,
    ),
    _FieldSpec(
      'sideLeft-answer',
      'الجواب',
      (t) => t.sideLeft.answer,
      (t, v) => t.copyWith(sideLeft: t.sideLeft.copyWith(answer: v)),
      minLines: 2,
    ),
  ]),
  _SectionSpec('الملاحظات السفلية', 'السطر الصغير تحت الجدول وفوق المقال.', [
    _FieldSpec(
      'footerNotes',
      'نص الملاحظات',
      (t) => t.footerNotes,
      (t, v) => t.copyWith(footerNotes: v),
      minLines: 2,
    ),
  ]),
  _SectionSpec('الفاتحة', 'تظهر في أسفل الملصق، آخر سطر.', [
    _FieldSpec(
      'fatiha',
      'نص الفاتحة',
      (t) => t.fatiha,
      (t, v) => t.copyWith(fatiha: v),
    ),
  ]),
];

/// Step 3: the poster's text blocks, grouped in collapsible sections.
///
/// Every field commits to [editorProvider] after a short typing pause or
/// when it loses focus — one undo entry per committed edit, never one per
/// keystroke.
class StepTexts extends ConsumerStatefulWidget {
  const StepTexts({super.key});

  @override
  ConsumerState<StepTexts> createState() => _StepTextsState();
}

class _StepTextsState extends ConsumerState<StepTexts> {
  final _active = ActiveTextController();
  final _expanded = <int>{0};

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    // Commit what is being typed before replacing everything.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.microtask(() {});
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
          'سيتم استبدال كل النصوص بالنصوص الافتراضية. متابعة؟',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final ctl = ref.read(editorProvider.notifier);
    ctl.update((p) => p.copyWith(texts: defaultTexts()));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('تمت استعادة النصوص'),
          action: SnackBarAction(label: 'تراجع', onPressed: ctl.undo),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final texts = ref.watch(editorProvider.select((s) => s.poster.texts));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey('restore-texts'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _restore,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('استعادة النصوص الافتراضية'),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _sections.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: cs.surfaceContainerLowest,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: ValueKey('section-$i'),
                        initiallyExpanded: _expanded.contains(i),
                        maintainState: true,
                        onExpansionChanged: (v) =>
                            v ? _expanded.add(i) : _expanded.remove(i),
                        tilePadding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          4,
                          12,
                          4,
                        ),
                        childrenPadding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          0,
                          16,
                          4,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        title: Semantics(
                          header: true,
                          child: Text(
                            _sections[i].title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _sections[i].helper,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (i == 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'أي قسم تتركه فارغاً لا يُطبع على الملصق.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          for (final f in _sections[i].fields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _TextBlock(
                                spec: f,
                                value: f.get(texts),
                                active: _active,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Docked above the keyboard while a text field is focused.
        ValueListenableBuilder<TextEditingController?>(
          valueListenable: _active,
          builder: (_, c, _) => c == null
              ? const SizedBox.shrink()
              : HonorificBar(
                  key: const ValueKey('honorific-bar'),
                  controller: c,
                ),
        ),
      ],
    );
  }
}

/// One multiline text field with a live counter. Owns its controller and
/// the debounce; follows [value] when it changes from outside.
class _TextBlock extends ConsumerStatefulWidget {
  const _TextBlock({
    required this.spec,
    required this.value,
    required this.active,
  });

  final _FieldSpec spec;
  final String value;
  final ActiveTextController active;

  @override
  ConsumerState<_TextBlock> createState() => _TextBlockState();
}

class _TextBlockState extends ConsumerState<_TextBlock> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.value,
  );
  final _focus = FocusNode();
  // Kept as fields: `ref` must not be used in dispose().
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  late final EditorController _editor = _container.read(
    editorProvider.notifier,
  );
  late String _lastText = widget.value;

  /// The poster value this field last agreed with (committed or synced).
  /// A rebuild with a different value is a change from outside.
  late String _known = widget.value;
  Timer? _timer;

  /// An edit typed but not yet committed.
  bool get _pending => _ctl.text != _current();

  String _current() =>
      widget.spec.get(_container.read(editorProvider).poster.texts);

  @override
  void initState() {
    super.initState();
    _editor; // resolve the late fields while the element is active
    _focus.addListener(_onFocus);
    // Also sees inserts that do not go through onChanged (honorific bar).
    _ctl.addListener(_onText);
  }

  @override
  void didUpdateWidget(_TextBlock old) {
    super.didUpdateWidget(old);
    if (widget.value == _known) return;
    if (_ctl.text == widget.value) {
      _known = widget.value;
      return;
    }
    // A change from outside (undo, restore). Never clobber a field with an
    // edit in progress.
    if (_timer?.isActive ?? false) return;
    if (_focus.hasFocus && _pending) return;
    _known = widget.value;
    _lastText = widget.value;
    _ctl.text = widget.value;
  }

  void _onText() {
    if (_ctl.text == _lastText) return;
    _lastText = _ctl.text;
    _timer?.cancel();
    _timer = Timer(_commitDelay, _commit);
    setState(() {});
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.active.value = _ctl;
    } else {
      widget.active.release(_ctl);
      _commit();
    }
    setState(() {});
  }

  void _commit() {
    _timer?.cancel();
    _timer = null;
    final t = _ctl.text;
    if (t == _current()) return;
    _known = t;
    _editor.update((p) => p.copyWith(texts: widget.spec.set(p.texts, t)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    final t = _ctl.text;
    if (t != _current()) {
      final editor = _editor, spec = widget.spec;
      scheduleMicrotask(
        () => editor.update((p) => p.copyWith(texts: spec.set(p.texts, t))),
      );
    }
    // The holder's listeners must not run while the tree is locked.
    final active = widget.active, ctl = _ctl;
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
    final n = _ctl.text.characters.length;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    return TextField(
      key: ValueKey('txt-${widget.spec.key}'),
      controller: _ctl,
      focusNode: _focus,
      minLines: widget.spec.minLines,
      maxLines: 12,
      keyboardType: TextInputType.multiline,
      textDirection: TextDirection.rtl,
      style: theme.textTheme.bodyLarge,
      // Touch-outside does not blur on mobile by default.
      onTapOutside: (_) => _focus.unfocus(),
      decoration: InputDecoration(
        labelText: widget.spec.label,
        filled: true,
        fillColor: cs.surface,
        alignLabelWithHint: true,
        helperText: n > _longText ? 'النص الطويل سيُصغَّر تلقائياً' : null,
        helperMaxLines: 2,
        counter: Text('$n حرفاً', style: style),
      ),
    );
  }
}
