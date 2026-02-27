/// Load result returned by [PagingSource.load]
abstract class LoadResult<Key, Value> {
  const LoadResult();
}

/// Success result with loaded data
class LoadResultPage<Key, Value> extends LoadResult<Key, Value> {
  /// The loaded data
  final List<Value> data;
  
  /// Key for previous page, null if this is the first page
  final Key? prevKey;
  
  /// Key for next page, null if this is the last page  
  final Key? nextKey;
  
  /// Count of items that could be loaded before the [prevKey] item
  final int? itemsBefore;
  
  /// Count of items that could be loaded after the [nextKey] item
  final int? itemsAfter;
  
  const LoadResultPage({
    required this.data,
    this.prevKey,
    this.nextKey,
    this.itemsBefore,
    this.itemsAfter,
  });

  @override
  String toString() => 'LoadResult.Page(data=${data.length} items, '
      'prevKey=$prevKey, nextKey=$nextKey)';
}

/// Error result when load failed
class LoadResultError<Key, Value> extends LoadResult<Key, Value> {
  /// The error that caused the load to fail
  final Exception exception;
  
  const LoadResultError(this.exception);
  
  @override
  String toString() => 'LoadResult.Error($exception)';
}

/// Invalid result - indicates refresh key is no longer valid
class LoadResultInvalid<Key, Value> extends LoadResult<Key, Value> {
  const LoadResultInvalid();
  
  @override
  String toString() => 'LoadResult.Invalid()';
}