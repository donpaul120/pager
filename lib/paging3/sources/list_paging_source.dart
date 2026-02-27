import '../load_params.dart';
import '../load_result.dart';
import '../paging_source.dart';

/// A [PagingSource] that loads data from a static list
/// Useful for testing or simple use cases where all data is available in memory
class ListPagingSource<T> extends PagingSource<int, T> {
  final List<T> _items;
  
  ListPagingSource(this._items);
  
  @override
  bool get jumpingSupported => true;
  
  @override
  int? getRefreshKey(PagingState<int, T> state) {
    final anchorPosition = state.anchorPosition;
    if (anchorPosition == null) return null;
    
    // Return the key for the page containing the anchor position
    return (anchorPosition / state.config.pageSize).floor();
  }
  
  @override
  Future<LoadResult<int, T>> load(LoadParams<int> params) async {
    try {
      final key = params.key ?? 0;
      final startIndex = key * (params.loadSize);
      final endIndex = (startIndex + params.loadSize).clamp(0, _items.length);
      
      // Simulate network delay for testing
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (startIndex >= _items.length) {
        return LoadResultPage<int, T>(data: []);
      }
      
      final data = _items.sublist(startIndex, endIndex);
      
      final prevKey = startIndex > 0 ? key - 1 : null;
      final nextKey = endIndex < _items.length ? key + 1 : null;
      
      return LoadResultPage<int, T>(
        data: data,
        prevKey: prevKey,
        nextKey: nextKey,
        itemsBefore: startIndex,
        itemsAfter: _items.length - endIndex,
      );
    } catch (e) {
      return LoadResultError<int, T>(
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }
}

/// A [PagingSource] that loads data from an async data source with offset-based pagination
class OffsetPagingSource<T> extends PagingSource<int, T> {
  final Future<List<T>> Function(int offset, int limit) _loader;
  
  OffsetPagingSource({
    required Future<List<T>> Function(int offset, int limit) loader,
  }) : _loader = loader;
  
  @override
  int? getRefreshKey(PagingState<int, T> state) {
    final anchorPosition = state.anchorPosition;
    if (anchorPosition == null) return 0;
    
    return anchorPosition;
  }
  
  @override
  Future<LoadResult<int, T>> load(LoadParams<int> params) async {
    try {
      final offset = params.key ?? 0;
      final limit = params.loadSize;
      
      final data = await _loader(offset, limit);
      
      final prevKey = offset > 0 ? offset - limit : null;
      final nextKey = data.length == limit ? offset + limit : null;
      
      return LoadResultPage<int, T>(
        data: data,
        prevKey: prevKey,
        nextKey: nextKey,
      );
    } catch (e) {
      return LoadResultError<int, T>(
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }
}

/// A [PagingSource] that loads data using cursor-based pagination
class CursorPagingSource<T, K> extends PagingSource<K?, T> {
  final Future<CursorPage<T, K>> Function(K? cursor, int limit) _loader;
  final K? Function(T item) _getCursor;
  
  CursorPagingSource({
    required Future<CursorPage<T, K>> Function(K? cursor, int limit) loader,
    required K? Function(T item) getCursor,
  }) : _loader = loader,
       _getCursor = getCursor;
  
  @override
  K? getRefreshKey(PagingState<K?, T> state) {
    final anchorItem = state.closestItemToPosition(state.anchorPosition ?? 0);
    return anchorItem != null ? _getCursor(anchorItem) : null;
  }
  
  @override
  Future<LoadResult<K?, T>> load(LoadParams<K?> params) async {
    try {
      final page = await _loader(params.key, params.loadSize);
      
      K? nextKey;
      if (page.data.isNotEmpty && page.hasNextPage) {
        nextKey = _getCursor(page.data.last);
      }
      
      return LoadResultPage<K?, T>(
        data: page.data,
        prevKey: null, // Cursor-based pagination typically doesn't support prepend
        nextKey: nextKey,
      );
    } catch (e) {
      return LoadResultError<K?, T>(
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }
}

/// Data class for cursor-based pagination results
class CursorPage<T, K> {
  final List<T> data;
  final bool hasNextPage;
  final K? nextCursor;
  
  const CursorPage({
    required this.data,
    required this.hasNextPage,
    this.nextCursor,
  });
}