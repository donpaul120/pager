import 'dart:async';
import 'load_params.dart';
import 'load_result.dart';

/// Base class for loading pages of data from a paginated data source
abstract class PagingSource<Key, Value> {
  /// Whether this [PagingSource] supports jumping (random access)
  bool get jumpingSupported => false;
  
  /// The refresh key used for subsequent loads after the initial load
  Key? getRefreshKey(PagingState<Key, Value> state) {
    return state.anchorPosition != null 
        ? state.closestPageToPosition(state.anchorPosition!)?.prevKey
        : null;
  }
  
  /// Load a page of data from this [PagingSource]
  Future<LoadResult<Key, Value>> load(LoadParams<Key> params);
  
  /// Called when this [PagingSource] is invalidated
  void invalidate() {
    _invalidated = true;
    _invalidatedController.add(null);
  }
  
  /// Whether this [PagingSource] has been invalidated  
  bool get invalid => _invalidated;
  
  /// Stream that emits when this [PagingSource] is invalidated
  Stream<void> get invalidatedStream => _invalidatedController.stream;
  
  bool _invalidated = false;
  final StreamController<void> _invalidatedController = StreamController.broadcast();
  
  void dispose() {
    _invalidatedController.close();
  }
}

/// Information about the current state of pagination
class PagingState<Key, Value> {
  /// List of pages that have been loaded
  final List<PagingSourceLoadResultPage<Key, Value>> pages;
  
  /// Index of the item closest to the current scroll position
  final int? anchorPosition;
  
  /// The [PagingConfig] used to configure loading behavior  
  final PagingConfig config;
  
  /// Leading placeholder count before the first loaded page
  final int leadingPlaceholderCount;
  
  const PagingState({
    required this.pages,
    this.anchorPosition,
    required this.config,
    this.leadingPlaceholderCount = 0,
  });
  
  /// Returns the loaded page closest to [position], or null if no pages loaded
  PagingSourceLoadResultPage<Key, Value>? closestPageToPosition(int position) {
    if (pages.isEmpty) return null;
    
    int currentPosition = leadingPlaceholderCount;
    for (final page in pages) {
      final pageEnd = currentPosition + page.data.length;
      if (position < pageEnd) return page;
      currentPosition = pageEnd;
    }
    
    return pages.last;
  }
  
  /// Returns the item closest to [position], or null if position is out of bounds
  Value? closestItemToPosition(int position) {
    final page = closestPageToPosition(position);
    if (page == null) return null;
    
    int currentPosition = leadingPlaceholderCount;
    for (final p in pages) {
      if (p == page) break;
      currentPosition += p.data.length;
    }
    
    final indexInPage = position - currentPosition;
    return indexInPage < page.data.length ? page.data[indexInPage] : null;
  }
  
  /// Returns true if [position] represents a placeholder
  bool isPlaceholder(int position) {
    if (position < leadingPlaceholderCount) return true;
    
    int currentPosition = leadingPlaceholderCount;
    for (final page in pages) {
      final pageEnd = currentPosition + page.data.length;
      if (position < pageEnd) return false;
      currentPosition = pageEnd;
    }
    
    return true;
  }
}

/// A [LoadResultPage] with additional metadata for [PagingState]
class PagingSourceLoadResultPage<Key, Value> extends LoadResultPage<Key, Value> {
  const PagingSourceLoadResultPage({
    required List<Value> data,
    Key? prevKey,
    Key? nextKey,
    int? itemsBefore,
    int? itemsAfter,
  }) : super(
    data: data,
    prevKey: prevKey, 
    nextKey: nextKey,
    itemsBefore: itemsBefore,
    itemsAfter: itemsAfter,
  );
}

/// Configuration for pagination behavior
class PagingConfig {
  /// Number of items to load at a time
  final int pageSize;
  
  /// Number of items to load for the initial page
  final int initialLoadSize;
  
  /// Whether to enable placeholder UI for not-yet-loaded items
  final bool enablePlaceholders;
  
  /// Maximum number of items to keep in memory
  final int? maxSize;
  
  /// Number of items to load before the current viewport
  final int prefetchDistance;
  
  /// Number of items to jump when using [PagingSource.jumpingSupported]
  final int jumpThreshold;
  
  const PagingConfig({
    required this.pageSize,
    int? initialLoadSize,
    this.enablePlaceholders = true,
    this.maxSize,
    int? prefetchDistance,
    int? jumpThreshold,
  }) : initialLoadSize = initialLoadSize ?? (pageSize * 3),
       prefetchDistance = prefetchDistance ?? pageSize,
       jumpThreshold = jumpThreshold ?? (pageSize * 3);
}