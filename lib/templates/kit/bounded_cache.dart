import 'package:flutter/foundation.dart';

/// A small memo cache for heavy ornament paths: at most [maxEntries] values,
/// evicting the oldest entry first (insertion order). Posters are drawn at a
/// handful of sizes (page, thumbnails, previews), so 4 entries keep the hot
/// paths cached without growing without bound.
class BoundedCache<K, V> {
  BoundedCache({this.maxEntries = 4}) : assert(maxEntries > 0);

  final int maxEntries;
  final Map<K, V> _map = <K, V>{};

  /// The cached value for [key], built with [build] (and stored) on a miss.
  V get(K key, V Function() build) {
    final hit = _map[key];
    if (hit != null || _map.containsKey(key)) return hit as V;
    final v = build();
    while (_map.length >= maxEntries) {
      _map.remove(_map.keys.first);
    }
    _map[key] = v;
    return v;
  }

  /// Number of cached entries (always <= [maxEntries]).
  @visibleForTesting
  int get length => _map.length;

  /// Whether [key] is cached.
  @visibleForTesting
  bool containsKey(K key) => _map.containsKey(key);
}
