import 'dart:collection';

import 'paging_data.dart';

/// A simple LRU (Least Recently Used) in-memory cache for paged data.
///
/// When [maxSize] is reached, the oldest entry is evicted to make room.
class PageCache<K, V> {
  PageCache({this.maxSize = 50});

  final int maxSize;

  // LinkedHashMap preserves insertion order, enabling FIFO eviction
  final LinkedHashMap<K?, Page<K, V>> _store = LinkedHashMap();

  Page<K, V>? get(K? key) {
    final page = _store.remove(key);
    if (page != null) {
      // Re-insert to mark as most recently used
      _store[key] = page;
    }
    return page;
  }

  void put(K? key, Page<K, V> page) {
    _store.remove(key);
    if (_store.length >= maxSize) {
      _store.remove(_store.keys.first);
    }
    _store[key] = page;
  }

  void remove(K? key) => _store.remove(key);

  void clear() => _store.clear();

  int get size => _store.length;
}
