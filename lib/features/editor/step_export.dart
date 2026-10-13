import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/validation.dart';
import '../../export/poster_exporter.dart';
import '../../export/poster_exporter_api.dart';
import '../../state/editor_controller.dart';
import '../../templates/poster_template.dart';
import '../../templates/registry.dart';
import '../preview/poster_preview.dart';
import 'step_grid.dart' show gridIssuesProvider;

/// The templates offered by the picker (tests inject their own list).
final templatesProvider = Provider<List<PosterTemplate>>((ref) => allTemplates);

enum _Kind { png, pdf, share }

enum _Failure { retry, lower, close }

enum _Warning { export, review }

/// `يوجد N تنبيهات …` dialog title (the brief's verbatim wording).
String _warningTitle(int n) =>
    'يوجد $n تنبيهات في البيانات. هل تريد التصدير رغم ذلك؟';

/// Step 4 "التصدير": swipe through the templates (the real poster with the
/// user's data), then save a PNG / PDF or share it with one tap.
class StepExport extends ConsumerStatefulWidget {
  const StepExport({required this.poster, required this.onGoToStep, super.key});

  final MonthPoster poster;

  /// Switches the editor to another step (review → 1, no days → 0).
  final ValueChanged<int> onGoToStep;

  @override
  ConsumerState<StepExport> createState() => _StepExportState();
}

class _StepExportState extends ConsumerState<StepExport> {
  late final PageController _pages;
  late int _page;
  final _boundaryKeys = <String, GlobalKey>{};
  final _pngKey = GlobalKey(), _pdfKey = GlobalKey(), _shareKey = GlobalKey();

  double _ratio = 3;
  PdfPageSize _pdfSize = PdfPageSize.a4;
  bool _busy = false;

  List<PosterTemplate> get _templates => ref.read(templatesProvider);

  @override
  void initState() {
    super.initState();
    final i = _templates.indexWhere((t) => t.id == widget.poster.templateId);
    _page = i < 0 ? 0 : i;
    _pages = PageController(initialPage: _page);
    // Warm every template's logos so swiping to a page never shows a poster
    // whose logo pops in a frame later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final t in _templates) {
        unawaited(t.precache(context));
      }
    });
    if (i < 0 && _templates.isNotEmpty) {
      // The stored template no longer exists: make the poster agree with
      // what the picker shows (and the exported file name).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final id = _templates.first.id;
        if (ref.read(editorProvider).poster.templateId == id) return;
        ref
            .read(editorProvider.notifier)
            .update((p) => p.copyWith(templateId: id));
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _boundaryKeys.putIfAbsent(id, GlobalKey.new);

  void _onPageChanged(int i) {
    final t = _templates;
    if (i < 0 || i >= t.length) return;
    setState(() => _page = i);
    final id = t[i].id;
    final ctl = ref.read(editorProvider.notifier);
    if (ref.read(editorProvider).poster.templateId == id) return;
    ctl.update((p) => p.copyWith(templateId: id));
  }

  /// Undo/redo of a template change moves the picker with it.
  void _onTemplateIdChanged(String? prev, String id) {
    final i = _templates.indexWhere((t) => t.id == id);
    if (i < 0 || i == _page) return;
    _page = i;
    if (_pages.hasClients) _pages.jumpToPage(i);
    setState(() {});
  }

  void _step(int d) {
    final n = _templates.length;
    final to = _page + d;
    if (to < 0 || to >= n) return;
    unawaited(
      _pages.animateToPage(
        to,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _zoom() {
    final templates = _templates;
    if (templates.isEmpty || _busy) return;
    final t = templates[math.min(_page, templates.length - 1)];
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ZoomRoute(template: t, fallback: widget.poster),
      ),
    );
  }

  Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // -------------------------------------------------------------------------
  // Export flow
  // -------------------------------------------------------------------------

  Future<void> _start(_Kind kind) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.microtask(() {});
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final poster = ref.read(editorProvider).poster;

    if (poster.days.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('لا توجد أيام للتصدير — أنشئ الأيام أولاً'),
            action: SnackBarAction(
              label: 'الشهر',
              onPressed: () => widget.onGoToStep(0),
            ),
          ),
        );
      return;
    }

    final issues = ref.read(gridIssuesProvider);
    if (issues.isNotEmpty) {
      final r = await showDialog<_Warning>(
        context: context,
        builder: (_) => _WarningDialog(issues: issues),
      );
      if (!mounted) return;
      if (r == _Warning.review) {
        widget.onGoToStep(1);
        return;
      }
      if (r != _Warning.export) return;
    }
    await _run(kind, _ratio, messenger);
  }

  Future<void> _run(
    _Kind kind,
    double ratio,
    ScaffoldMessengerState messenger,
  ) async {
    while (true) {
      if (!mounted) return;
      setState(() => _busy = true);
      Object? error;
      File? file;
      try {
        file = await _produce(kind, ratio);
      } catch (e) {
        error = e;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      if (error == null && file != null) {
        _afterSuccess(kind, file, messenger);
        return;
      }
      final r = await showDialog<_Failure>(
        context: context,
        builder: (_) => _FailureDialog(error: error!, ratio: ratio),
      );
      if (!mounted) return;
      switch (r) {
        case _Failure.retry:
          continue;
        case _Failure.lower:
          ratio = 2;
          setState(() => _ratio = 2);
          continue;
        case _Failure.close:
        case null:
          return;
      }
    }
  }

  Future<File> _produce(_Kind kind, double ratio) async {
    final api = ref.read(posterExporterProvider);
    final poster = ref.read(editorProvider).poster;
    final templates = _templates;
    if (templates.isEmpty) {
      throw const ExportException('No templates available.');
    }
    final t = templates[math.min(_page, templates.length - 1)];
    // The page (and its logos) must be loaded, laid out and painted before
    // it is captured.
    await PosterExporter.prepareCapture(context, t);
    if (!mounted) throw const ExportException('Export step closed.');
    final png = await api.toPng(_keyFor(t.id), pixelRatio: ratio);
    final pdf = kind == _Kind.pdf;
    final bytes = pdf ? await api.toPdf(png, size: _pdfSize) : png;
    final name = api.fileNameFor(poster, pdf ? 'pdf' : 'png', suffix: t.id);
    final file = await api.saveBytes(bytes, name);
    if (kind == _Kind.share) {
      await api.share(file, sharePositionOrigin: _originOf(_shareKey));
    }
    return file;
  }

  void _afterSuccess(_Kind kind, File file, ScaffoldMessengerState messenger) {
    if (kind == _Kind.share) return;
    final key = kind == _Kind.pdf ? _pdfKey : _pngKey;
    final api = ref.read(posterExporterProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('تم الحفظ: ${_shortPath(file.path)}'),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () => unawaited(_shareSaved(api, messenger, file, key)),
          ),
        ),
      );
  }

  Future<void> _shareSaved(
    PosterExporterApi api,
    ScaffoldMessengerState messenger,
    File file,
    GlobalKey from,
  ) async {
    // The step may be gone by now: origin is then simply unknown.
    final origin = mounted ? (_originOf(from) ?? _originOf(_shareKey)) : null;
    try {
      await api.share(file, sharePositionOrigin: origin);
    } catch (e) {
      debugPrint('share failed: $e');
      messenger.showSnackBar(const SnackBar(content: Text('تعذّرت المشاركة')));
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(
      editorProvider.select((s) => s.poster.templateId),
      _onTemplateIdChanged,
    );
    final templates = ref.watch(templatesProvider);
    final poster = ref.watch(editorProvider.select((s) => s.poster));
    final shown = poster.id.isEmpty ? widget.poster : poster;
    final page = math.min(_page, math.max(0, templates.length - 1));
    return LayoutBuilder(
      builder: (context, c) {
        final w = math.min(420.0, c.maxWidth - 32);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Picker(
                    controller: _pages,
                    templates: templates,
                    page: page,
                    poster: shown,
                    width: w,
                    keyFor: _keyFor,
                    onChanged: _onPageChanged,
                    onStep: _step,
                    onZoom: _zoom,
                    busy: _busy,
                  ),
                  const SizedBox(height: 16),
                  _Actions(
                    busy: _busy,
                    noTemplates: templates.isEmpty,
                    ratio: _ratio,
                    pdfSize: _pdfSize,
                    pngKey: _pngKey,
                    pdfKey: _pdfKey,
                    shareKey: _shareKey,
                    onRatio: (r) => setState(() => _ratio = r),
                    onPdfSize: (s) => setState(() => _pdfSize = s),
                    onExport: (k) => unawaited(_start(k)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `…/exports/<file>`: the last two path segments.
String _shortPath(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty);
  final l = parts.toList();
  if (l.length <= 2) return l.join('/');
  return '…/${l[l.length - 2]}/${l.last}';
}

// ---------------------------------------------------------------------------
// Picker
// ---------------------------------------------------------------------------

class _Picker extends StatelessWidget {
  const _Picker({
    required this.controller,
    required this.templates,
    required this.page,
    required this.poster,
    required this.width,
    required this.keyFor,
    required this.onChanged,
    required this.onStep,
    required this.onZoom,
    required this.busy,
  });

  final bool busy;
  final PageController controller;
  final List<PosterTemplate> templates;
  final int page;
  final MonthPoster poster;
  final double width;
  final GlobalKey Function(String id) keyFor;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onZoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = templates.length;
    final height = width * kPosterSize.height / kPosterSize.width;
    final many = n > 1;
    final name = n == 0 ? '' : templates[page].nameAr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (many)
              IconButton(
                tooltip: 'القالب السابق',
                onPressed: !busy && page > 0 ? () => onStep(-1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 30,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    key: const ValueKey('template-name'),
                    label: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    backgroundColor: cs.primaryContainer,
                    side: BorderSide.none,
                  ),
                  if (many) ...[
                    const SizedBox(height: 6),
                    Semantics(
                      container: true,
                      label: 'القالب ${page + 1} من $n',
                      excludeSemantics: true,
                      child: Row(
                        key: const ValueKey('template-dots'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < n; i++)
                            Container(
                              width: i == page ? 18 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == page ? cs.primary : cs.outline,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (many)
              IconButton(
                tooltip: 'القالب التالي',
                onPressed: !busy && page < n - 1 ? () => onStep(1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 30,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            key: const ValueKey('zoom-button'),
            onPressed: busy || n == 0 ? null : onZoom,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.zoom_in_rounded),
            label: const Text('تكبير'),
          ),
        ),
        if (n == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'لا توجد قوالب متاحة',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: height + 8,
            child: IgnorePointer(
              ignoring: busy,
              child: PageView.builder(
                controller: controller,
                itemCount: n,
                onPageChanged: onChanged,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return Center(
                    child: Semantics(
                      button: true,
                      label: 'معاينة الملصق بقالب ${t.nameAr} — اضغط للتكبير',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: ValueKey('preview-tap-$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onZoom,
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
                          child: PosterPreview(
                            poster: poster,
                            template: t,
                            boundaryKey: keyFor(t.id),
                            width: width,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _Actions extends StatelessWidget {
  const _Actions({
    required this.busy,
    required this.noTemplates,
    required this.ratio,
    required this.pdfSize,
    required this.pngKey,
    required this.pdfKey,
    required this.shareKey,
    required this.onRatio,
    required this.onPdfSize,
    required this.onExport,
  });

  final bool busy, noTemplates;
  final double ratio;
  final PdfPageSize pdfSize;
  final GlobalKey pngKey, pdfKey, shareKey;
  final ValueChanged<double> onRatio;
  final ValueChanged<PdfPageSize> onPdfSize;
  final ValueChanged<_Kind> onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SegmentedRow<double>(
          title: 'جودة الصورة',
          value: ratio,
          options: const [
            (2.0, 'عادية ×2'),
            (3.0, 'عالية ×3'),
            (4.0, 'طباعة ×4'),
          ],
          onChanged: busy ? null : onRatio,
        ),
        const SizedBox(height: 8),
        _BigButton(
          buttonKey: const ValueKey('export-png'),
          boxKey: pngKey,
          icon: Icons.image_rounded,
          label: 'حفظ PNG',
          onPressed: busy || noTemplates ? null : () => onExport(_Kind.png),
          filled: true,
        ),
        const SizedBox(height: 20),
        _SegmentedRow<PdfPageSize>(
          title: 'حجم الصفحة',
          value: pdfSize,
          options: const [
            (PdfPageSize.a4, 'A4'),
            (PdfPageSize.a3, 'A3'),
            (PdfPageSize.poster, 'حجم الملصق'),
          ],
          onChanged: busy ? null : onPdfSize,
        ),
        const SizedBox(height: 8),
        _BigButton(
          buttonKey: const ValueKey('export-pdf'),
          boxKey: pdfKey,
          icon: Icons.picture_as_pdf_rounded,
          label: 'حفظ PDF',
          onPressed: busy || noTemplates ? null : () => onExport(_Kind.pdf),
          filled: true,
        ),
        const SizedBox(height: 20),
        _BigButton(
          buttonKey: const ValueKey('export-share'),
          boxKey: shareKey,
          icon: Icons.ios_share_rounded,
          label: 'مشاركة',
          onPressed: busy || noTemplates ? null : () => onExport(_Kind.share),
          filled: false,
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 8),
                Text(
                  'جارٍ التصدير…',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.buttonKey,
    required this.boxKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  final Key buttonKey;
  final GlobalKey boxKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, 52);
    return KeyedSubtree(
      key: boxKey,
      child: filled
          ? FilledButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              style: FilledButton.styleFrom(minimumSize: size),
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(minimumSize: size),
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, 48)),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            segments: [
              for (final o in options)
                ButtonSegment<T>(
                  value: o.$1,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(o.$2, maxLines: 1),
                  ),
                ),
            ],
            selected: {value},
            onSelectionChanged: onChanged == null
                ? null
                : (s) => onChanged!(s.first),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs and zoom route
// ---------------------------------------------------------------------------

class _WarningDialog extends StatelessWidget {
  const _WarningDialog({required this.issues});
  final List<PosterIssue> issues;

  @override
  Widget build(BuildContext context) {
    final n = issues.length;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_warningTitle(n), style: theme.textTheme.titleMedium),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in issues.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, left: 8),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFF8A5A00),
                      ),
                    ),
                    Expanded(child: Text(i.messageAr)),
                  ],
                ),
              ),
            if (n > 5) Text('…و ${n - 5} أخرى'),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context, _Warning.review),
          child: const Text('مراجعة'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context, _Warning.export),
          child: const Text('تصدير'),
        ),
      ],
    );
  }
}

class _FailureDialog extends StatelessWidget {
  const _FailureDialog({required this.error, required this.ratio});
  final Object error;
  final double ratio;

  String get _reason {
    final e = error;
    if (e is ExportException && e.message.contains('not on screen')) {
      return 'الملصق غير ظاهر — أعد المحاولة';
    }
    if (ratio > 2) return 'تعذّر إنشاء الصورة بهذه الدقة — جرّب جودة أقل';
    return 'حدث خطأ أثناء التصدير — أعد المحاولة';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('export failed: $error');
    return AlertDialog(
      title: const Text('تعذّر التصدير'),
      content: Text(_reason),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context, _Failure.close),
          child: const Text('إغلاق'),
        ),
        if (ratio > 2)
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(context, _Failure.lower),
            child: const Text('جرّب ×2'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context, _Failure.retry),
          child: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }
}

/// Full-screen pinch-zoomable view of the poster in [template].
class _ZoomRoute extends ConsumerWidget {
  const _ZoomRoute({required this.template, required this.fallback});
  final PosterTemplate template;
  final MonthPoster fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorProvider);
    final poster = s.isOpen && s.poster.id == fallback.id ? s.poster : fallback;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(template.nameAr),
        leading: IconButton(
          tooltip: 'إغلاق',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  child: PosterPreview(poster: poster, template: template),
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
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
