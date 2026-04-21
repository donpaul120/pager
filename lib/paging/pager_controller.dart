import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'combined_load_state.dart';
import 'load_state.dart';
import 'load_states.dart';
import 'page_config.dart';
import 'paging_data.dart';
import 'paging_source.dart';
import 'paging_state.dart';
import 'remote_mediator.dart';

/// Controls and exposes the state of a paginated data stream.
///
/// Can be used headlessly — without a [Pager] widget — to access loaded data
/// programmatically (e.g. to show a count badge before rendering a list).
///
/// ```dart
/// final controller = PagerController(source: mySource);
/// controller.initialize();
/// controller.addListener(() => print(controller.totalItems));
/// ```
///
/// Pass it to [Pager.withController] when you're ready to render.
class PagerController<K, T> extends ValueNotifier<PagingData<T>> {
  PagerController({
    required this.source,
    this.pagingConfig = const PagingConfig.fromDefault(),
  }) : super(PagingData([], totalItems: 0));

  final PagingSource<K, T> source;
  final PagingConfig pagingConfig;

  final List<Page<K, T>> _pages = [];

  // Maps positionKey → index in _pages for O(1) append lookups.
  final HashMap<K?, int> _pageIndex = HashMap();

  LoadStates _states = LoadStates.idle();
  LoadStates _sourceStates = LoadStates.idle();
  LoadStates _mediatorStates = LoadStates.idle();

  final Lock _lock = Lock();

  final LinkedHashMap<K?, StreamSubscription<Page<K, T>>> _pageSubscriptions =
      LinkedHashMap();

  int _totalItems = 0;
  int? _mediatorTotalItems;
  bool _disposed = false;

  // Set synchronously before the lock is acquired so that concurrent scroll
  // events are rejected before they can queue another append on the lock.
  bool _isAppendInFlight = false;

  RemoteMediator<K, dynamic>? get _remoteMediator => source.remoteMediator;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Total raw item count across all loaded pages (pre-group for grouped data).
  int get totalItems => _totalItems;

  /// Flat list of currently loaded items.
  List<T> get items => value.data;

  /// Number of items currently loaded. Equivalent to [items].length.
  int get itemCount => value.itemCount;

  /// Current combined load states.
  CombinedLoadStates? get loadStates => value.loadStates;

  /// True while the initial/refresh load is in progress.
  bool get isLoading => value.isLoading;

  /// True when there is no data and no refresh is in progress.
  bool get isEmpty => value.isEmpty;

  /// True when data is present.
  bool get isNotEmpty => value.isNotEmpty;

  /// True while the next page is being loaded.
  bool get isAppending => value.isAppending;

  /// True when all pages have been loaded and there is no more data to fetch.
  bool get endOfPaginationReached => value.endOfPaginationReached;

  /// True if either the refresh or append load has failed.
  bool get hasError => value.hasError;

  /// The exception from the most recent failed refresh, or null.
  Exception? get refreshError => value.refreshError;

  /// The exception from the most recent failed append, or null.
  Exception? get appendError => value.appendError;

  /// Starts the initial data load. Must be called once after construction.
  ///
  /// Not required when the controller is passed to a [Pager] widget — the
  /// widget manages initialization automatically.
  void initialize() => _doInitialLoad();

  /// Clears all data and restarts from the first page.
  Future<void> refresh() async {
    _states = LoadStates.idle();
    _sourceStates = LoadStates.idle();
    _mediatorStates = LoadStates.idle();
    _isAppendInFlight = false;
    await _invalidate(dispatch: false);
    _doInitialLoad();
  }

  /// Retries after an error. Calls [refresh] on a refresh error; retries the
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

  /// Called by [Pager] (or manually) with the current scroll position.
  ///
  /// Triggers an append load when the remaining visible items fall within
  /// [PagingConfig.preFetchDistance].
  void onScrollPositionChanged(double currentPosition, double maxScrollExtent) {
    if (_isAppendInFlight) return;
    if (_sourceStates.append is Loading) return;
    if (_sourceStates.append.endOfPaginationReached &&
        (_remoteMediator == null ||
            _mediatorStates.append.endOfPaginationReached)) return;

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

  void _doInitialLoad() {
    Future.microtask(() async {
      await _requestRemoteLoad(LoadType.REFRESH);
      await _doLoad(LoadType.REFRESH);
    });
  }

  Future<void> _doLoad(LoadType loadType) async {
    // Synchronously gate concurrent append calls before touching the lock.
    if (loadType == LoadType.APPEND) {
      if (_isAppendInFlight) return;
      _isAppendInFlight = true;
    }

    try {
      await _lock.synchronized(() async {
        if (loadType == LoadType.REFRESH && _pages.isNotEmpty) {
          await _invalidate();
        }

        final LoadParams<K> params;
        if (_pages.isEmpty || _pages.last.isEmpty()) {
          params = _buildParams(LoadType.REFRESH, null);
        } else {
          params = _buildParams(loadType, _pages.last.nextKey);
        }

        switch (loadType) {
          case LoadType.REFRESH:
            _sourceStates = _sourceStates.modifyState(loadType, Loading());
            await _closeAllSubscriptions();
            await _onRefresh(params);
            break;

          case LoadType.APPEND:
            // Guards inside the lock as a safety net for any queued calls.
            if (_sourceStates.append is Loading) return;
            if (_sourceStates.append.endOfPaginationReached &&
                (_remoteMediator == null ||
                    _mediatorStates.append.endOfPaginationReached)) return;
            if (_pages.isNotEmpty && _pages.last.nextKey == null) {
              _sourceStates = _sourceStates.modifyState(
                  LoadType.APPEND, NotLoading(true));
              dispatchUpdates();
              return;
            }
            _sourceStates = _sourceStates.modifyState(loadType, Loading());
            await _onAppend(params);
            break;

          case LoadType.PREPEND:
            break;
        }
      });
    } finally {
      if (loadType == LoadType.APPEND) {
        _isAppendInFlight = false;
      }
    }
  }

  LoadParams<K> _buildParams(LoadType loadType, K? key) {
    return LoadParams(
      loadType,
      key,
      loadType == LoadType.REFRESH
          ? pagingConfig.initialPageSize
          : pagingConfig.pageSize,
    );
  }

  int _getPageSize(Page<K, T> page) {
    if (page is PageGroup<K, T>) return page.originalDataSize;
    return page.data.length;
  }

  // ─── Page subscription handlers ───────────────────────────────────────────

  FutureOr<void> _onRefresh(LoadParams<K> params) async {
    if (_pageSubscriptions.containsKey(params.key)) return;

    dispatchUpdates();

    final localSource = source.localSource.call(params);
    final subscription = localSource.listen(
      (page) {
        if (_pages.isNotEmpty) {
          // Reactive update — refresh data for the first page.
          _insertOrUpdate(params.key, page);
          return;
        }
        // Use nextKey as the authoritative end-of-pagination signal.
        final isEnd = page.nextKey == null;
        _sourceStates = _sourceStates
            .modifyState(LoadType.REFRESH, NotLoading(isEnd))
            .modifyState(LoadType.APPEND, NotLoading(isEnd))
            .modifyState(LoadType.PREPEND, NotLoading(true));
        _insertOrUpdate(params.key, page);
        // For empty pages, _insertOrUpdate won't dispatch — do it explicitly.
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

    final completer = Completer<void>();
    StreamSubscription<Page<K, T>>? subscription;
    bool streamCompleted = false;

    final localSource = source.localSource.call(params);

    subscription = localSource.listen(
      (page) async {
        if (_pages.isEmpty) {
          await subscription?.cancel();
          _pageSubscriptions.remove(params.key);
          if (!completer.isCompleted) completer.complete();
          return;
        }

        // nextKey == null means this is the last page.
        final endOfPage = page.nextKey == null;

        _sourceStates = _sourceStates
            .modifyState(LoadType.REFRESH, NotLoading(true))
            .modifyState(LoadType.APPEND, NotLoading(endOfPage))
            .modifyState(LoadType.PREPEND, NotLoading(true));

        // Use params.key as the position key so the page is always appended
        // at the correct slot regardless of how the source sets page.prevKey.
        _insertOrUpdate(params.key, page);

        if (page.data.isEmpty || endOfPage) {
          subscription?.pause();
          await _requestRemoteLoad(LoadType.APPEND);
          if (!streamCompleted) {
            subscription?.resume();
          } else {
            _pageSubscriptions.remove(params.key);
          }
        }

        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        streamCompleted = true;
        // Stream ended (one-shot source). Unstick any Loading state so the
        // scroll guard recovers, and remove the subscription so a future scroll
        // can re-subscribe for new data (e.g. after a remote mediator load).
        if (_sourceStates.append is Loading) {
          _sourceStates =
              _sourceStates.modifyState(LoadType.APPEND, NotLoading(true));
          dispatchUpdates();
        }
        _pageSubscriptions.remove(params.key);
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

  FutureOr<void> _requestRemoteLoad(LoadType loadType) async {
    if (_remoteMediator == null) return;
    if (loadType == LoadType.APPEND &&
        _mediatorStates.append.endOfPaginationReached) return;
    if (loadType == LoadType.REFRESH &&
        _mediatorStates.refresh.endOfPaginationReached) return;

    _mediatorStates = _mediatorStates.modifyState(loadType, Loading());
    dispatchUpdates();

    final result = await _remoteMediator!
        .load(loadType, PagingState<K, T>(_nextPageKey, pagingConfig));

    if (_disposed) return;

    if (result is MediatorSuccess) {
      _mediatorStates = _mediatorStates.modifyState(
          loadType, NotLoading(result.endOfPaginationReached));
      if (result.totalItems != null) _mediatorTotalItems = result.totalItems;
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
    _mediatorTotalItems = null;
    if (dispatch) dispatchUpdates();
    await _closeAllSubscriptions();
  }

  bool _calculateDiffAndUpdate(Page<K, T> oldPage, Page<K, T> newPage) {
    final updates =
        calculateListDiff(oldPage.data, newPage.data).getUpdatesWithData();
    if (updates.isEmpty) return true; // no change

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

  /// Inserts or updates a page identified by [positionKey].
  ///
  /// [positionKey] for the first (refresh) page is always `null`.
  /// For appended pages it is [LoadParams.key] — the nextKey of the previous
  /// page — which gives O(1) lookup via [_pageIndex].
  void _insertOrUpdate(K? positionKey, Page<K, T> page) {
    bool inserted = false;

    if (positionKey == null) {
      // First page slot.
      if (_pages.isEmpty) {
        if (!page.isEmpty()) {
          _pages.add(page);
          _pageIndex[positionKey] = 0;
          inserted = true;
        }
      } else {
        inserted = !_calculateDiffAndUpdate(_pages.first, page);
      }
    } else {
      if (_pages.isEmpty) {
        _invalidate();
        return;
      }

      final index = _pageIndex[positionKey];

      if (index == null && page.data.isNotEmpty) {
        // New page — append it.
        _pageIndex[positionKey] = _pages.length;
        _pages.add(page);
        inserted = true;
      } else if (index != null && index < _pages.length) {
        // Existing page — diff and update.
        inserted = !_calculateDiffAndUpdate(_pages[index], page);
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
      } catch (_) {}
    }
  }

  // ─── State dispatch ───────────────────────────────────────────────────────

  List<T> _transformPages() {
    _totalItems = 0;
    int? serverTotal;
    final List<T> result = _pages.fold(<T>[], (prev, element) {
      _totalItems += _getPageSize(element);
      if (element.totalItems != null) serverTotal = element.totalItems;
      prev.addAll(_transformGroupData(prev, element));
      return prev;
    });
    // Priority: mediator total (most authoritative) > page-level total > fetched count.
    if (_mediatorTotalItems != null) {
      _totalItems = _mediatorTotalItems!;
    } else if (serverTotal != null) {
      _totalItems = serverTotal!;
    }
    return result;
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
        for (final item in firstItem.items) {
          if (!lastItem.items.contains(item)) lastItem.items.add(item);
        }
        return element.data.sublist(1);
      }
    }
    return element.data;
  }

  void dispatchUpdates() {
    if (_disposed) return;
    _states = _states.combineStates(_sourceStates, _mediatorStates);
    final combined = CombinedLoadStates(
        _states.refresh, _states.append, _states.prepend,
        source: _sourceStates,
        mediator: _mediatorStates);
    final pages = _transformPages();
    value = PagingData<T>(pages, totalItems: _totalItems, loadStates: combined);
  }

  @override
  void dispose() {
    _disposed = true;
    _closeAllSubscriptions();
    super.dispose();
  }
}
