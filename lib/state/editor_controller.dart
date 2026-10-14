import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'providers.dart';

class EditorState {
  final MonthPoster poster;
  final bool canUndo;
  final bool canRedo;
  final bool saving;
  final String? saveError;
  const EditorState({
    required this.poster,
    this.canUndo = false,
    this.canRedo = false,
    this.saving = false,
    this.saveError,
  });

  /// True once a poster has been opened (the initial state is a placeholder).
  bool get isOpen => poster.id.isNotEmpty;

  EditorState copyWith({
    MonthPoster? poster,
    bool? canUndo,
    bool? canRedo,
    bool? saving,
    String? Function()? saveError,
  }) => EditorState(
    poster: poster ?? this.poster,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    saving: saving ?? this.saving,
    saveError: saveError != null ? saveError() : this.saveError,
  );
}

const _maxUndo = 100;
const _debounce = Duration(milliseconds: 600);
const _retryDelay = Duration(seconds: 5);

final editorProvider = NotifierProvider<EditorController, EditorState>(
  EditorController.new,
);

class EditorController extends Notifier<EditorState> {
  final List<MonthPoster> _undo = [];
  final List<MonthPoster> _redo = [];
  Timer? _timer;
  Timer? _retryTimer;
  bool _dirty = false;
  bool _disposed = false;
  int _epoch = 0; // incremented on every open(); stale save results are dropped
  int _inFlight = 0; // saves in flight for the current epoch
  int _saveSeq = 0; // sequence number of the most recently started save

  @override
  EditorState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _cancelTimers();
    });
    return _placeholder();
  }

  static EditorState _placeholder() => EditorState(
    poster: MonthPoster(
      id: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      hijriMonthIndex: 0,
      hijriYear: 0,
    ),
  );

  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Opens [p] for editing; any unsaved edits of the previous poster are
  /// flushed first. Results of still-running saves of the previous poster
  /// are ignored (they never touch the new poster's state).
  void open(MonthPoster p) {
    unawaited(flush());
    _cancelTimers();
    _epoch++;
    _inFlight = 0;
    _undo.clear();
    _redo.clear();
    _dirty = false;
    state = EditorState(poster: p);
  }

  /// Closes the editor WITHOUT saving (e.g. its poster was just deleted):
  /// pending autosave/retry timers are cancelled, unsaved edits are dropped,
  /// results of in-flight saves are ignored, and the state returns to the
  /// unopened placeholder (`isOpen == false`), so later update/flush calls
  /// are no-ops and cannot recreate the poster.
  void close() {
    _cancelTimers();
    _epoch++;
    _inFlight = 0;
    _undo.clear();
    _redo.clear();
    _dirty = false;
    state = _placeholder();
  }

  void update(MonthPoster Function(MonthPoster) change) {
    // Late (deferred) edits may arrive after the provider was disposed.
    if (_disposed || !state.isOpen) return;
    final cur = state.poster;
    final next = change(cur);
    _undo.add(cur);
    if (_undo.length > _maxUndo) _undo.removeAt(0);
    _redo.clear();
    _changed(next);
  }

  void undo() {
    if (!state.isOpen || _undo.isEmpty) return;
    _redo.add(state.poster);
    _changed(_undo.removeLast());
  }

  void redo() {
    if (!state.isOpen || _redo.isEmpty) return;
    _undo.add(state.poster);
    _changed(_redo.removeLast());
  }

  void _changed(MonthPoster p) {
    _dirty = true;
    state = state.copyWith(
      poster: p.copyWith(updatedAt: DateTime.now()),
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    );
    _cancelTimers();
    _timer = Timer(_debounce, () {
      _timer = null;
      unawaited(_save());
    });
  }

  /// Cancels any pending autosave and saves now if there are unsaved edits.
  Future<void> flush() async {
    if (!state.isOpen) return;
    _cancelTimers();
    if (_dirty) await _save();
  }

  Future<void> _save() async {
    if (!_dirty || _disposed || !state.isOpen) return;
    final p = state.poster;
    final epoch = _epoch;
    final seq = ++_saveSeq;
    _dirty = false;
    _inFlight++;
    state = state.copyWith(saving: true);
    String? error;
    try {
      // The saver may throw synchronously (e.g. ArgumentError for unsafe ids).
      await ref.read(posterSaverProvider)(p);
    } catch (e) {
      error = e.toString();
      debugPrint('autosave failed: $e');
    }
    // Poster was switched (or provider disposed) meanwhile: drop the result.
    if (_disposed || epoch != _epoch) return;
    _inFlight--;
    if (error != null && seq == _saveSeq) {
      // No newer save has started, so these edits are still unsaved: keep
      // them dirty and retry once after a delay (cancelled by any new edit,
      // flush, open or dispose).
      _dirty = true;
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        _retryTimer = null;
        unawaited(_save());
      });
    }
    state = state.copyWith(saving: _inFlight > 0, saveError: () => error);
  }
}
