import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'combined_load_state.dart';
import 'load_state.dart';
import 'load_states.dart';
import 'page_cache.dart';
import 'page_config.dart';
import 'paging_data.dart';
import 'paging_source.dart';
import 'paging_state.dart';
import 'remote_mediator.dart';

/// Controls and exposes the state of a paginated data stream.
///
/// Manages fetching, caching, diffing, and state transitions for paginated
/// data. Can be used headlessly (without a [Pager] widget) to access loaded
/// data via [value], [items], and [totalItems].
///
/// ```dart
/// final controller = PagerController(source: mySource);
/// controller.initialize();
/// controller.addListener(() => print(controller.items));
/// ```
class PagerController<K, T> extends ValueNotifier<PagingData<T>> {
  PagerController({
    required this.source,
    this.pagingConfig = const PagingConfig.fromDefault(),
  }) : super(PagingData([], totalItems: 0));

  final PagingSource<K, T> source;
  final PagingConfig pagingConfig;

  // Ordered list of loaded pages
  final List<Page<K, T>> _pages = [];

  // O(1) lookup: prevKey → index in _pages
  final HashMap<K?, int> _pageIndex = HashMap();

  LoadStates _states = LoadStates.idle();
  LoadStates _sourceStates = LoadStates.idle();
  LoadStates _mediatorStates = LoadStates.idle();

  final Lock _lock = Lock();

  // One subscription per page key
  final LinkedHashMap<K?, StreamSubscription<Page<K, T>>> _pageSubscriptions =
      LinkedHashMap();

  int _totalItems = 0;
  bool _disposed = false;

  // Prevents the scroll listener from triggering concurrent appends
  bool _isAppendInFlight = false;

  PageCache<K, T>? _cache;

  RemoteMediator<K, dynamic>? get _remoteMediator => source.remoteMediator;

  /// Total number of raw data items across all loaded pages.
  /// For grouped pages this reflects the original (pre-group) count.
  int get totalItems => _totalItems;

  /// The current flat list of loaded items.
  List<T> get items => value.data;

  /// The current combined load states.
  CombinedLoadStates? get loadStates => value.loadStates;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Must be called once after creation to start the initial load.
  ///
  /// Not required when the controller is passed to a [Pager] widget as the
  /// widget manages initialization automatically.
  void initialize() {
    if (pagingConfig.enableCache) {
      _cache = PageCache(maxSize: pagingConfig.maxCacheSize);
    }
    _doInitialLoad();
  }

  /// Clears all data and restarts from the first page.
  Future<void> refresh() async {
    _states = LoadStates.idle();
    _sourceStates = LoadStates.idle();
    _mediatorStates = LoadStates.idle();
    _isAppendInFlight = false;
    await _invalidate(dispatch: false);
    _doInitialLoad();
  }

  /// Retries after an error. Refreshes on a refresh error; retries the
  /// last append on an append error.
  Future<void> retry() async {
    if (_states.refresh is Error) {
      await refresh();
    } else if (_states.append is Error) {
      _sourceStates =
          _sourceStates.modifyState(LoadType.APPEND, NotLoading(false));
      _mediatorStates =
          _mediatorStates.modifyState(LoadType.APPEND, NotLoading(false));
      await _doLoad(LoadType.APPEND);
    }
  }

  // ─── Scroll integration ───────────────────────────────────────────────────

  /// Call this from a scroll listener with the current scroll position.
  ///
  /// Triggers an append when the remaining items visible are within
  /// [PagingConfig.preFetchDistance].
  void onScrollPositionChanged(double currentPosition, double maxScrollExtent) {
    if (_isAppendInFlight) return;
    if (_sourceStates.append is Loading) return;
    if (_sourceStates.append.endOfPaginationReached &&
        _mediatorStates.append.endOfPaginationReached) return;

    if (maxScrollExtent <= 0 || _totalItems <= 0) return;

    final heightPerItem = maxScrollExtent / _totalItems;
    if (heightPerItem <= 0) return;

    final scrollOffsetPerItem = currentPosition / heightPerItem;
    final remainingItems = _totalItems - scrollOffsetPerItem;

    if (remainingItems <= pagingConfig.preFetchDistance) {
      _doLoad(LoadType.APPEND);
    }
  }

  // ─── Internal loading ─────────────────────────────────────────────────────

  LoadParams<K> _loadParams(LoadType loadType, K? key) {
    return LoadParams(
        loadType,
        key,
        loadType == LoadType.REFRESH
            ? pagingConfig.initialPageSize
            : pagingConfig.pageSize);
  }

  void _doInitialLoad() {
    Future.microtask(() async {
      // Sequence: remote refresh first so local source reads fresh data.
      // Don't touch mediator states here — _requestRemoteLoad sets Loading
      // only when a mediator is actually present.
      await _requestRemoteLoad(LoadType.REFRESH);
      await _doLoad(LoadType.REFRESH);
    });
  }

  Future<void> _doLoad(LoadType loadType) async {
    await _lock.synchronized(() async {
      if (loadType == LoadType.REFRESH && _pages.isNotEmpty) {
        await _invalidate();
      }

      final LoadParams<K> params;
      if (_pages.isEmpty || _pages.last.isEmpty()) {
        params = _loadParams(LoadType.REFRESH, null);
      } else {
        params = _loadParams(loadType, _pages.last.nextKey);
      }

      switch (loadType) {
        case LoadType.REFRESH:
          _sourceStates = _sourceStates.modifyState(loadType, Loading());
          await _closeAllSubscriptions();
          await _onRefresh(params);
          break;
        case LoadType.APPEND:
          // Guard: skip if already in progress or pagination exhausted
          if (_sourceStates.append is Loading) return;
          if (_sourceStates.append.endOfPaginationReached &&
              _mediatorStates.append.endOfPaginationReached) return;
          _sourceStates = _sourceStates.modifyState(loadType, Loading());
          await _onAppend(params);
          break;
        case LoadType.PREPEND:
          // Prepend not yet implemented
          break;
      }
    });
  }

  int _getPageSize(Page<K, T> page) {
    return page is PageGroup<K, T> ? page.originalDataSize : page.data.length;
  }

  // ─── Transformations ──────────────────────────────────────────────────────

  List<T> transformPages() {
    _totalItems = 0;
    return _pages.fold(<T>[], (List<T> previousValue, element) {
      _totalItems += _getPageSize(element);
      previousValue.addAll(_transformGroupData(previousValue, element));
      return previousValue;
    });
  }

  List<T> _transformGroupData(List<T> previousValue, Page<K, T> element) {
    if (element is PageGroup<K, T> &&
        previousValue.isNotEmpty &&
        previousValue.last is PageGroupData &&
        element.data.isNotEmpty &&
        element.data.first is PageGroupData) {
      final lastItem = previousValue.last as PageGroupData;
      final firstItem = element.data.first as PageGroupData;

      if (lastItem.key == firstItem.key) {
        // Use Set for O(1) duplicate detection; avoid mutating during iteration
        final existingSet = Set.identity()..addAll(lastItem.items);
        final newItems =
            firstItem.items.where((item) => !existingSet.contains(item)).toList();
        lastItem.items.addAll(newItems);
        return List.empty();
      }
    }
    return element.data;
  }

  // ─── Page subscription handlers ───────────────────────────────────────────

  FutureOr<void> _onRefresh(LoadParams<K> params) async {
    if (_pageSubscriptions.containsKey(params.key)) return;

    // Serve stale data from cache immediately while fresh data loads
    final cached = _cache?.get(params.key);
    if (cached != null) {
      final isEnd = _getPageSize(cached) < pagingConfig.initialPageSize;
      _sourceStates = _sourceStates
          .modifyState(LoadType.REFRESH, NotLoading(isEnd))
          .modifyState(LoadType.APPEND, NotLoading(isEnd))
          .modifyState(LoadType.PREPEND, NotLoading(true));
      _insertOrUpdate(params.key, cached);
    } else {
      dispatchUpdates();
    }

    final localSource = source.localSource.call(params);
    final subscription = localSource.listen(
      (page) {
        if (_pages.isNotEmpty) {
          _insertOrUpdate(page.prevKey, page);
          return;
        }
        final isEnd = _getPageSize(page) < pagingConfig.initialPageSize;
        _sourceStates = _sourceStates
            .modifyState(LoadType.REFRESH, NotLoading(isEnd))
            .modifyState(LoadType.APPEND, NotLoading(isEnd))
            .modifyState(LoadType.PREPEND, NotLoading(true));
        _insertOrUpdate(page.prevKey, page);
        // _insertOrUpdate only dispatches when a page is inserted/changed.
        // For empty pages nothing is inserted, so dispatch explicitly here
        // so that the empty state is reflected in the UI.
        if (page.isEmpty()) dispatchUpdates();
      },
      onError: (Object e) {
        _sourceStates = _sourceStates.modifyState(
            LoadType.REFRESH,
            Error(e is Exception ? e : Exception(e.toString())));
        dispatchUpdates();
      },
    );

    _pageSubscriptions.putIfAbsent(params.key, () => subscription);
  }

  FutureOr<void> _onAppend(LoadParams<K> params) async {
    if (_pageSubscriptions.containsKey(params.key)) return;

    // Serve from cache first
    final cached = _cache?.get(params.key);
    if (cached != null) {
      final endOfPage = _getPageSize(cached) < pagingConfig.pageSize;
      _sourceStates = _sourceStates
          .modifyState(LoadType.REFRESH, NotLoading(true))
          .modifyState(LoadType.APPEND, NotLoading(endOfPage))
          .modifyState(LoadType.PREPEND, NotLoading(true));
      _insertOrUpdate(params.key, cached);
      return;
    }

    final completer = Completer<void>();
    bool streamCompleted = false;

    StreamSubscription<Page<K, T>>? subscription;
    final localSource = source.localSource.call(params);

    subscription = localSource.listen(
      (page) async {
        if (_pages.isEmpty) {
          await subscription?.cancel();
          _pageSubscriptions.remove(params.key);
          if (!completer.isCompleted) completer.complete();
          return;
        }

        // Only process if this page belongs to the current tail
        final lastPage = _pages.last;
        if (lastPage.nextKey != page.prevKey) {
          _insertOrUpdate(page.prevKey, page);
          if (!completer.isCompleted) completer.complete();
          return;
        }

        final endOfPage = _getPageSize(page) < pagingConfig.pageSize;
        _sourceStates = _sourceStates
            .modifyState(LoadType.REFRESH, NotLoading(true))
            .modifyState(LoadType.APPEND, NotLoading(endOfPage))
            .modifyState(LoadType.PREPEND, NotLoading(true));

        _insertOrUpdate(page.prevKey, page);

        // When local is empty or at end, ask remote mediator for more data.
        // Pause the subscription during remote fetch to avoid double-processing.
        // Do NOT call _doLoad here — only scroll events trigger the next page,
        // preventing the fetch-without-scroll loop.
        if (page.data.isEmpty || endOfPage) {
          subscription?.pause();
          _isAppendInFlight = true;
          await _requestRemoteLoad(LoadType.APPEND);
          _isAppendInFlight = false;

          if (!streamCompleted) {
            subscription?.resume();
          } else {
            // Stream completed while paused (one-shot source).
            // Clear so the next scroll re-subscribes for the same key.
            _pageSubscriptions.remove(params.key);
          }
        }

        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        streamCompleted = true;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e) {
        _sourceStates = _sourceStates.modifyState(
            LoadType.APPEND,
            Error(e is Exception ? e : Exception(e.toString())));
        dispatchUpdates();
        if (!completer.isCompleted) completer.complete();
      },
    );

    _pageSubscriptions.putIfAbsent(params.key, () => subscription!);
    dispatchUpdates();
    return completer.future;
  }

  // ─── Remote mediator ──────────────────────────────────────────────────────

  K? get _nextPageKey {
    final lastPage = _pages.lastOrNull;
    return lastPage?.nextKey ?? lastPage?.prevKey;
  }

  /// Calls the remote mediator if present and updates mediator states.
  /// Intentionally does NOT call [_doLoad] on success — the existing local
  /// source subscription handles reactive updates, and only scroll events
  /// should trigger loading the next page.
  FutureOr<void> _requestRemoteLoad(LoadType loadType) async {
    if (_remoteMediator == null) return; // Leave mediator states as idle
    if (loadType == LoadType.APPEND &&
        _mediatorStates.append.endOfPaginationReached) return;
    if (loadType == LoadType.REFRESH &&
        _mediatorStates.refresh.endOfPaginationReached) return;

    // Only set Loading now that we know there is an actual mediator to call
    _mediatorStates = _mediatorStates.modifyState(loadType, Loading());
    dispatchUpdates();

    final result = await _remoteMediator!
        .load(loadType, PagingState<K, T>(_nextPageKey, pagingConfig));

    if (_disposed) return;

    if (result is MediatorSuccess) {
      _mediatorStates = _mediatorStates.modifyState(
          loadType, NotLoading(result.endOfPaginationReached));
    } else if (result is MediatorError) {
      _mediatorStates =
          _mediatorStates.modifyState(loadType, Error(result.exception));
    }
    dispatchUpdates();
  }

  // ─── Page management ──────────────────────────────────────────────────────

  Future<void> _invalidate({bool dispatch = true}) async {
    _pages.clear();
    _pageIndex.clear();
    if (!pagingConfig.persistCacheOnRefresh) _cache?.clear();
    if (dispatch) dispatchUpdates();
    await _closeAllSubscriptions();
  }

  /// Returns true if the pages are identical (no update needed).
  bool _calculateDiffAndUpdate(Page<K, T> oldPage, Page<K, T> newPage) {
    final updates =
        calculateListDiff(oldPage.data, newPage.data).getUpdatesWithData();
    if (updates.isEmpty) return true; // same

    oldPage.data.clear();
    oldPage.data.addAll(newPage.data);

    if (oldPage.data.isEmpty) {
      final idx = _pages.indexOf(oldPage);
      if (idx != -1) {
        _pages.removeAt(idx);
        _rebuildPageIndex();
      }
    }
    return false; // changed
  }

  void _rebuildPageIndex() {
    _pageIndex.clear();
    for (int i = 0; i < _pages.length; i++) {
      _pageIndex[_pages[i].prevKey] = i;
    }
  }

  void _insertOrUpdate(K? prevKey, Page<K, T> page) {
    bool inserted = false;

    if (prevKey == null) {
      if (_pages.isEmpty) {
        if (!page.isEmpty()) {
          _pages.add(page);
          _pageIndex[prevKey] = 0;
          _cache?.put(prevKey, page);
          inserted = true;
        }
      } else {
        inserted = !_calculateDiffAndUpdate(_pages.first, page);
        if (inserted) _cache?.put(prevKey, page);
      }
    } else {
      if (_pages.isEmpty) {
        _invalidate();
        return;
      }

      // O(1) lookup via index map
      final index = _pageIndex[prevKey];

      if (index == null && page.data.isNotEmpty) {
        // Only append if the previous page was full (integrity check)
        final prevPage = _pages.lastOrNull;
        if (prevPage != null &&
            prevPage.prevKey != null &&
            _getPageSize(prevPage) < pagingConfig.pageSize) {
          return;
        }
        _pages.add(page);
        _pageIndex[prevKey] = _pages.length - 1;
        _cache?.put(prevKey, page);
        inserted = true;
      } else if (index != null && index < _pages.length) {
        inserted = !_calculateDiffAndUpdate(_pages[index], page);
        if (inserted) _cache?.put(prevKey, page);
      }
    }

    if (inserted) dispatchUpdates();
  }

  Future<void> _closeAllSubscriptions() async {
    if (_pageSubscriptions.isEmpty) return;
    final entries = List.of(_pageSubscriptions.entries);
    _pageSubscriptions.clear();
    for (final entry in entries) {
      try {
        await entry.value.cancel();
      } catch (_) {
        // Ignore cancellation errors
      }
    }
  }

  // ─── State dispatch ───────────────────────────────────────────────────────

  void dispatchUpdates() {
    if (_disposed) return;
    _states = _states.combineStates(_sourceStates, _mediatorStates);
    final combined = CombinedLoadStates(
        _states.refresh, _states.append, _states.prepend,
        source: _sourceStates,
        mediator: _mediatorStates);
    final pages = transformPages();
    value = PagingData<T>(pages, totalItems: _totalItems, loadStates: combined);
  }

  @override
  void dispose() {
    _disposed = true;
    _closeAllSubscriptions();
    super.dispose();
  }
}
