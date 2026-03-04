class PagingConfig {
  const PagingConfig({
    this.pageSize = 15,
    this.preFetchDistance = 5,
    this.initialPageSize = 15,
    this.enableCache = false,
    this.maxCacheSize = 50,
    this.persistCacheOnRefresh = false,
  });

  /// Number of items per page for append/prepend loads.
  final int pageSize;

  /// How many items from the end of the list should trigger the next page load.
  final int preFetchDistance;

  /// Number of items to load on the very first (refresh) load.
  /// Defaults to [pageSize].
  final int initialPageSize;

  /// Whether to keep loaded pages in an in-memory LRU cache.
  /// Cached pages are served immediately while fresh data loads.
  final bool enableCache;

  /// Maximum number of pages to keep in cache. Only used when [enableCache]
  /// is true.
  final int maxCacheSize;

  /// When true, the cache is NOT cleared on refresh, allowing stale data to
  /// be shown while the refresh completes. Defaults to false.
  final bool persistCacheOnRefresh;

  const PagingConfig.fromDefault({
    this.pageSize = 20,
    this.preFetchDistance = 5,
    this.initialPageSize = 20,
    this.enableCache = false,
    this.maxCacheSize = 50,
    this.persistCacheOnRefresh = false,
  });
}
