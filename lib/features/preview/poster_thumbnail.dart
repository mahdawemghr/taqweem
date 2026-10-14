import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/models.dart';
import '../../templates/poster_template.dart';
import '../../templates/registry.dart';
import 'poster_preview.dart';

/// How many drafts keep a raster thumbnail (least recently used evicted).
const int kThumbnailCacheSize = 16;

/// Default debounce of a [PosterThumbnail] that follows live edits (the
/// editor mini preview): one raster per pause in typing, not per commit.
const Duration kThumbnailDebounce = Duration(milliseconds: 900);

/// Raster widths are rounded up to a multiple of this (fewer re-renders when
/// a tile is resized by a few pixels).
const int _kWidthStep = 120;

/// Thumbnails are never rendered narrower / wider than this (pixels).
const int _kMinWidthPx = 120, _kMaxWidthPx = 720;

/// Everything of [p] that is drawn on the poster, as a string: two drafts
/// with equal stamps render identically. `updatedAt` is left out (it changes
/// on every commit but is not drawn), so undoing back to an earlier state
/// reuses that state's raster.
String posterContentStamp(MonthPoster p) {
  final j = p.toJson()..remove('updatedAt');
  return jsonEncode(j);
}

/// Renders [poster] off screen at [widthPx] pixels wide. [context] supplies
/// the inherited themes and the view (it is mounted when called).
typedef PosterRasterizer = Future<ui.Image> Function(
  BuildContext context,
  MonthPoster poster,
  int widthPx,
);

/// Runs [task] shortly after the current frame (the default is a 48 ms delay).
typedef IdleScheduler = Future<T> Function<T>(T Function() task);

/// A short pause lets the frame that triggered the request finish first.
/// (Not `SchedulerBinding.scheduleTask(Priority.idle)`: while any animation
/// runs it re-arms zero-delay timers in a busy loop.)
Future<T> _idle<T>(T Function() task) =>
    Future<T>.delayed(const Duration(milliseconds: 48), task);

/// One cached raster.
class _Thumb {
  _Thumb(this.stamp, this.image, this.widthPx);
  final String stamp;
  final ui.Image image;
  final int widthPx;
}

class _Request {
  _Request(this.context, this.poster, this.stamp, this.widthPx);
  final BuildContext context;
  final MonthPoster poster;
  final String stamp;
  final int widthPx;
}

/// Low-resolution raster thumbnails of drafts, keyed by draft id.
///
/// * One entry per draft id ([capacity] entries, LRU): the latest raster and
///   the content stamp it shows. A stale raster keeps being shown while the
///   fresh one is generated (no flicker back to the placeholder).
/// * Generation is serial (one poster at a time) and runs at idle priority,
///   so a Home screen with many drafts never builds more than one poster at
///   once and never competes with scrolling or animations.
/// * Requests are de-duplicated per id: only the newest content is rendered.
class ThumbnailCache {
  ThumbnailCache({
    this.capacity = kThumbnailCacheSize,
    PosterRasterizer? rasterizer,
    IdleScheduler? scheduler,
  }) : assert(capacity > 0),
       _rasterize = rasterizer ?? rasterizePoster,
       _schedule = scheduler ?? _idle;

  /// The cache used by [PosterThumbnail] unless one is passed explicitly.
  static ThumbnailCache instance = ThumbnailCache();

  final int capacity;
  final PosterRasterizer _rasterize;
  final IdleScheduler _schedule;

  final LinkedHashMap<String, _Thumb> _thumbs = LinkedHashMap<String, _Thumb>();
  final LinkedHashMap<String, _Request> _queue =
      LinkedHashMap<String, _Request>();
  final Map<String, List<VoidCallback>> _listeners = {};
  bool _busy = false;
  bool _disposed = false;

  /// Stamps that failed to render (not retried until the content changes).
  final Map<String, String> _failed = {};

  /// Number of posters rendered so far.
  @visibleForTesting
  int debugRenderCount = 0;

  /// Most posters ever being rendered at the same time (always <= 1).
  @visibleForTesting
  int debugMaxConcurrentRenders = 0;
  int _active = 0;

  /// Number of cached rasters.
  @visibleForTesting
  int get debugLength => _thumbs.length;

  /// Number of drafts waiting to be rendered.
  @visibleForTesting
  int get debugPending => _queue.length;

  /// A new handle to the latest raster of [id] (the caller disposes it),
  /// with the stamp and width it was rendered for; null if none.
  (ui.Image, String, int)? peek(String id) {
    final t = _thumbs.remove(id);
    if (t == null) return null;
    _thumbs[id] = t; // most recently used
    return (t.image.clone(), t.stamp, t.widthPx);
  }

  /// Whether the cached raster of [id] shows [stamp] at >= [widthPx].
  bool isFresh(String id, String stamp, int widthPx) {
    final t = _thumbs[id];
    return t != null && t.stamp == stamp && t.widthPx >= widthPx;
  }

  /// Asks for a raster of [poster] (content [stamp]) at least [widthPx]
  /// wide. Replaces any queued request for the same draft. [context] must
  /// stay mounted until the render starts; otherwise the request is dropped.
  void request(
    BuildContext context,
    MonthPoster poster,
    String stamp,
    int widthPx,
  ) {
    if (_disposed || isFresh(poster.id, stamp, widthPx)) return;
    if (_failed[poster.id] == stamp) return;
    // Never downgrade: a draft keeps the largest resolution any of its
    // thumbnails needed (the Home card and the editor share one raster).
    final have = _thumbs[poster.id]?.widthPx ?? 0;
    final px = widthPx > have ? widthPx : have;
    _queue.remove(poster.id);
    _queue[poster.id] = _Request(context, poster, stamp, px);
    unawaited(_drain());
  }

  /// Calls [listener] whenever the raster of [id] changes.
  void addListener(String id, VoidCallback listener) =>
      (_listeners[id] ??= []).add(listener);

  void removeListener(String id, VoidCallback listener) {
    final l = _listeners[id];
    if (l == null) return;
    l.remove(listener);
    if (l.isEmpty) _listeners.remove(id);
  }

  /// Forgets the raster of [id] (e.g. the draft was deleted).
  void evict(String id) {
    _queue.remove(id);
    _thumbs.remove(id)?.image.dispose();
  }

  /// Forgets every raster and pending request.
  void clear() {
    _queue.clear();
    for (final t in _thumbs.values) {
      t.image.dispose();
    }
    _thumbs.clear();
    _failed.clear();
  }

  void dispose() {
    clear();
    _listeners.clear();
    _disposed = true;
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final id = _queue.keys.first;
        final r = _queue.remove(id)!;
        if (!r.context.mounted || isFresh(id, r.stamp, r.widthPx)) continue;
        final widthPx = _bucket(r.widthPx);
        ui.Image? image;
        try {
          // Logos decoded first, so the raster contains them.
          await templateById(r.poster.templateId).precache(r.context);
          if (!r.context.mounted || _disposed) continue;
          final pending = await _schedule<Future<ui.Image>?>(() {
            if (!r.context.mounted || _disposed) return null;
            _active++;
            if (_active > debugMaxConcurrentRenders) {
              debugMaxConcurrentRenders = _active;
            }
            try {
              return _rasterize(r.context, r.poster, widthPx);
            } finally {
              _active--;
            }
          });
          if (pending == null) continue;
          image = await pending;
          debugRenderCount++;
        } catch (_) {
          // A failed render keeps the placeholder / the previous raster.
          _failed[id] = r.stamp;
          continue;
        }
        if (_disposed) {
          image.dispose();
          break;
        }
        _failed.remove(id);
        _thumbs.remove(id)?.image.dispose();
        while (_thumbs.length >= capacity) {
          _thumbs.remove(_thumbs.keys.first)!.image.dispose();
        }
        _thumbs[id] = _Thumb(r.stamp, image, widthPx);
        for (final l in [...?_listeners[id]]) {
          l();
        }
      }
    } finally {
      _busy = false;
    }
  }

  static int _bucket(int px) {
    final b = ((px + _kWidthStep - 1) ~/ _kWidthStep) * _kWidthStep;
    return b.clamp(_kMinWidthPx, _kMaxWidthPx);
  }
}

/// Default [PosterRasterizer]: builds [poster] in a private, off-screen
/// widget/render tree (never in the visible tree), lays it out at
/// [kPosterSize], paints it and reads it back at [widthPx] pixels wide.
///
/// The inherited themes of [context] (e.g. the default text style) are
/// carried over, so the raster matches what a [PosterPreview] would show.
Future<ui.Image> rasterizePoster(
  BuildContext context,
  MonthPoster poster,
  int widthPx,
) async {
  final child = InheritedTheme.captureAll(
    context,
    MediaQuery(
      data: (MediaQuery.maybeOf(context) ?? const MediaQueryData()).copyWith(
        size: kPosterSize,
        textScaler: TextScaler.noScaling,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PosterPreview(poster: poster),
      ),
    ),
  );
  final boundary = RenderRepaintBoundary();
  final view = RenderView(
    view: View.of(context),
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(kPosterSize),
      physicalConstraints: BoxConstraints.tight(kPosterSize),
    ),
  );
  final pipeline = PipelineOwner()..rootNode = view;
  view.prepareInitialFrame();
  final owner = BuildOwner(focusManager: FocusManager());
  RenderObjectToWidgetElement<RenderBox>? root;
  try {
    root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: child,
    ).attachToRenderTree(owner);
    owner
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return await boundary.toImage(pixelRatio: widthPx / kPosterSize.width);
  } finally {
    // Unmount the private tree (removes image listeners etc.).
    if (root != null) {
      RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
          .attachToRenderTree(owner, root);
      owner
        ..buildScope(root)
        ..finalizeTree();
    }
    owner.focusManager.dispose();
    pipeline
      ..rootNode = null
      ..dispose();
  }
}

/// A poster thumbnail drawn from a cached low-resolution raster
/// ([ThumbnailCache]) instead of a live poster widget tree.
///
/// While no raster of [poster] exists yet a cheap [ThumbnailPlaceholder]
/// in the template's colours is shown; when only an older raster exists it
/// stays visible until the new one is ready. With a [debounce] (the editor
/// mini preview), a new raster is requested only after the poster stopped
/// changing for that long.
class PosterThumbnail extends StatefulWidget {
  const PosterThumbnail({
    super.key,
    required this.poster,
    this.width,
    this.debounce = Duration.zero,
    this.cache,
  });

  final MonthPoster poster;

  /// Fixed display width (height follows the poster ratio); without it the
  /// thumbnail takes the parent's width at the poster ratio.
  final double? width;
  final Duration debounce;

  /// Defaults to [ThumbnailCache.instance].
  final ThumbnailCache? cache;

  @override
  State<PosterThumbnail> createState() => _PosterThumbnailState();
}

class _PosterThumbnailState extends State<PosterThumbnail> {
  ThumbnailCache get _cache => widget.cache ?? ThumbnailCache.instance;
  late ThumbnailCache _listening;
  late String _id;
  String? _stamp;
  MonthPoster? _stampOf;
  ui.Image? _image;
  String? _imageStamp;
  int _widthPx = _kMinWidthPx;
  Timer? _debounce;
  String? _requested;
  bool _checkScheduled = false;

  /// Content stamp of the current poster (computed once per poster object).
  String get _currentStamp {
    if (!identical(_stampOf, widget.poster)) {
      _stampOf = widget.poster;
      _stamp = posterContentStamp(widget.poster);
    }
    return _stamp!;
  }

  bool get _upToDate =>
      _imageStamp == _currentStamp &&
      _cache.isFresh(_id, _currentStamp, _widthPx);

  @override
  void initState() {
    super.initState();
    _listening = _cache;
    _id = widget.poster.id;
    _listening.addListener(_id, _onCacheChanged);
    _take();
  }

  @override
  void didUpdateWidget(PosterThumbnail old) {
    super.didUpdateWidget(old);
    if (!identical(_cache, _listening) || widget.poster.id != _id) {
      _listening.removeListener(_id, _onCacheChanged);
      _listening = _cache;
      _id = widget.poster.id;
      _listening.addListener(_id, _onCacheChanged);
      _setImage(null, null);
      _requested = null;
      _debounce?.cancel();
      _take();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _listening.removeListener(_id, _onCacheChanged);
    _image?.dispose();
    super.dispose();
  }

  void _setImage(ui.Image? image, String? stamp) {
    _image?.dispose();
    _image = image;
    _imageStamp = stamp;
  }

  /// Picks up the cached raster of this draft (fresh or stale).
  void _take() {
    final hit = _listening.peek(_id);
    if (hit == null) return;
    _setImage(hit.$1, hit.$2);
  }

  void _onCacheChanged() {
    if (mounted) setState(_take);
  }

  /// Requests the current content once (after the frame that showed it).
  /// Live edits over an existing picture are debounced by [widget.debounce];
  /// a first picture is requested right away.
  void _check() {
    _checkScheduled = false;
    if (!mounted || _upToDate) return;
    final want = '$_currentStamp@$_widthPx';
    if (_requested == want) return;
    _requested = want;
    _debounce?.cancel();
    if (widget.debounce > Duration.zero && _image != null) {
      _debounce = Timer(widget.debounce, () {
        if (mounted) {
          _cache.request(context, widget.poster, _currentStamp, _widthPx);
        }
      });
    } else {
      _cache.request(context, widget.poster, _currentStamp, _widthPx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final child = LayoutBuilder(
      builder: (context, c) {
        final logical = c.hasBoundedWidth ? c.maxWidth : (w ?? 200);
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
        final px = (logical * dpr).ceil();
        if (px > _widthPx) _widthPx = px;
        if (!_checkScheduled && !_upToDate) {
          _checkScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _check());
        }
        final image = _image;
        return image == null
            ? ThumbnailPlaceholder(templateId: widget.poster.templateId)
            : RawImage(
                image: image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              );
      },
    );
    return SizedBox(
      width: w,
      child: AspectRatio(
        aspectRatio: kPosterSize.width / kPosterSize.height,
        child: child,
      ),
    );
  }
}

/// The cheap stand-in shown until a thumbnail raster is ready: the
/// template's background, frame colour and a header band.
class ThumbnailPlaceholder extends StatelessWidget {
  const ThumbnailPlaceholder({super.key, required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context) {
    final t = templateById(templateId).theme;
    return DecoratedBox(
      key: const ValueKey('thumbnail-placeholder'),
      decoration: BoxDecoration(
        color: t.background,
        border: Border.all(color: t.frameColor, width: 1.5),
      ),
      child: FractionallySizedBox(
        widthFactor: 0.72,
        heightFactor: 0.08,
        alignment: const Alignment(0, -0.82),
        child: ColoredBox(color: t.tableHeaderBg),
      ),
    );
  }
}

/// Hero tag shared by a Home card's thumbnail and the editor's mini preview.
Object posterHeroTag(String posterId) => 'poster-thumb-$posterId';

/// Hero flight: the cached raster scaling between the two places (never a
/// live poster; no placeholder flash because the cache already has it).
HeroFlightShuttleBuilder posterHeroShuttle(MonthPoster poster) =>
    (flightContext, animation, direction, fromContext, toContext) =>
        AspectRatio(
          aspectRatio: kPosterSize.width / kPosterSize.height,
          child: PosterThumbnail(poster: poster),
        );
