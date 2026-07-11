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
  // Populated synchronously before the lock is acquired so that concurrent
  // scroll events are rejected before they can queue another load on the lock.
  final Set<LoadType> _loadsInFlight = {};

  RemoteMediator<K, dynamic>? get _remoteMediator => source.remoteMediator;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Total raw item count across all loaded pages (pre-group for grouped data).
  int get totalItems => _totalItems;

  /// Manually triggers the next append load, bypassing end-of-pagination guards.
  ///
  /// Use when the built-in scroll detection does not suit your layout, or when
  /// you know new data has arrived on the server. Safe to call concurrently —
  /// an in-flight load absorbs duplicate calls.
  void triggerAppend() => _doLoad(LoadType.APPEND, bypassEndOfPag: true);

  /// Manually triggers the next prepend load, bypassing end-of-pagination guards.
  ///
  /// Same semantics as [triggerAppend] but for the leading direction.
  void triggerPrepend() => _doLoad(LoadType.PREPEND, bypassEndOfPag: true);

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
    _loadsInFlight.clear();
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
  /// Triggers an append load when remaining items fall within
  /// [PagingConfig.preFetchDistance], and a prepend load when items above
  /// the viewport fall within [PagingConfig.preFetchDistance].
  void onScrollPositionChanged(double currentPosition, double maxScrollExtent) {
    if (maxScrollExtent <= 0 || _totalItems <= 0) return;

    final heightPerItem = maxScrollExtent / _totalItems;
    if (heightPerItem <= 0) return;

    final scrollOffsetPerItem = currentPosition / heightPerItem;
    final remainingItems = _totalItems - scrollOffsetPerItem;

    if (remainingItems <= pagingConfig.preFetchDistance &&
        _canLoadFromScroll(LoadType.APPEND)) {
      _doLoad(LoadType.APPEND);
    }

    if (scrollOffsetPerItem <= pagingConfig.preFetchDistance &&
        _canLoadFromScroll(LoadType.PREPEND)) {
      _doLoad(LoadType.PREPEND);
    }
  }

  /// The key the next load in [type]'s direction starts from: the first
  /// page's prevKey for prepends, the last page's nextKey otherwise.
  K? _loadCursor(LoadType type) => type == LoadType.PREPEND
      ? _pages.firstOrNull?.prevKey
      : _pages.lastOrNull?.nextKey;

  /// True when no further data can arrive in [type]'s direction: the source
  /// has ended and — when a mediator exists — the mediator has too.
  bool _isDirectionExhausted(LoadType type) =>
      _sourceStates.get(type).endOfPaginationReached &&
      (_remoteMediator == null ||
          _mediatorStates.get(type).endOfPaginationReached);

  /// Fast-path guard for scroll-triggered loads; [_doLoad] re-checks inside
  /// the lock as the safety net.
  bool _canLoadFromScroll(LoadType type) {
    if (_loadsInFlight.contains(type)) return false;
    if (_sourceStates.get(type) is Loading) return false;
    if (_isDirectionExhausted(type)) return false;
    // At a null boundary key with the end state already published, _doLoad is
    // a guaranteed no-op — skip the per-scroll-frame lock round trip.
    if (_pages.isNotEmpty &&
        _loadCursor(type) == null &&
        _sourceStates.get(type) == NotLoading(true)) {
      return false;
    }
    return true;
  }

  // ─── Internal loading ─────────────────────────────────────────────────────

  void _doInitialLoad() {
    Future.microtask(() async {
      await _requestRemoteLoad(LoadType.REFRESH);
      await _doLoad(LoadType.REFRESH);
    });
  }

  Future<void> _doLoad(LoadType loadType, {bool bypassEndOfPag = false}) async {
    // Synchronously gate concurrent append/prepend calls before touching the lock.
    if (loadType != LoadType.REFRESH && !_loadsInFlight.add(loadType)) return;

    try {
      await _lock.synchronized(() async {
        if (loadType == LoadType.REFRESH && _pages.isNotEmpty) {
          await _invalidate();
        }

        final LoadParams<K> params;
        if (_pages.isEmpty || _pages.last.isEmpty()) {
          params = _buildParams(LoadType.REFRESH, null);
        } else {
          params = _buildParams(loadType, _loadCursor(loadType));
        }

        if (loadType == LoadType.REFRESH) {
          _sourceStates = _sourceStates.modifyState(loadType, Loading());
          await _closeAllSubscriptions();
          await _onRefresh(params);
          return;
        }

        // Guards inside the lock as a safety net for any queued calls.
        if (_sourceStates.get(loadType) is Loading) return;
        if (!bypassEndOfPag && _isDirectionExhausted(loadType)) return;
        // An empty list gives a prepend nothing to anchor to; an append falls
        // back to the refresh-shaped params built above instead.
        if (loadType == LoadType.PREPEND && _pages.isEmpty) return;

        if (_pages.isNotEmpty && _loadCursor(loadType) == null) {
          // The source has no further page in this direction. Only dispatch
          // on an actual transition — scroll events near the boundary land
          // here every frame and would otherwise rebuild the UI each time
          // (PagingData has no ==, so every set notifies).
          if (_sourceStates.get(loadType) != NotLoading(true)) {
            _sourceStates =
                _sourceStates.modifyState(loadType, NotLoading(true));
            dispatchUpdates();
          }
          return;
        }

        // bypassEndOfPag also resets the mediator state so _requestRemoteLoad
        // is not silently short-circuited by a stale endOfPaginationReached.
        if (bypassEndOfPag &&
            _mediatorStates.get(loadType).endOfPaginationReached) {
          _mediatorStates =
              _mediatorStates.modifyState(loadType, NotLoading(false));
        }
        _sourceStates = _sourceStates.modifyState(loadType, Loading());
        await _onDirectionalLoad(loadType, params);
      });
    } finally {
      _loadsInFlight.remove(loadType);
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
        final isPrependEnd = page.prevKey == null;
        _sourceStates = _sourceStates
            .modifyState(LoadType.REFRESH, NotLoading(isEnd))
            .modifyState(LoadType.APPEND, NotLoading(isEnd))
            .modifyState(LoadType.PREPEND, NotLoading(isPrependEnd));
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

  /// Shared handler for append and prepend loads — the two directions differ
  /// only in which boundary key ends pagination, where the page is inserted,
  /// and the prepend-only re-trigger after a mediator fetch.
  FutureOr<void> _onDirectionalLoad(
      LoadType direction, LoadParams<K> params) async {
    if (_pageSubscriptions.containsKey(params.key)) return;

    final prepend = direction == LoadType.PREPEND;
    final completer = Completer<void>();
    StreamSubscription<Page<K, T>>? subscription;
    bool streamCompleted = false;
    // Set once this load hits the data boundary and the mediator was asked
    // for more.
    bool remoteLoadRequested = false;

    // Prepends re-run themselves once the mediator has saved new data: unlike
    // appends, there may never be another scroll event at the top of the list
    // to pick it up. Guarded against Error/end-of-pagination — and requiring a
    // mediator at all — so an empty local result can never re-trigger in an
    // infinite loop.
    void retriggerIfMediatorSavedData() {
      if (!prepend || _remoteMediator == null) return;
      final mediatorState = _mediatorStates.get(direction);
      if (mediatorState is Loading ||
          mediatorState is Error ||
          mediatorState.endOfPaginationReached) return;
      Future.delayed(Duration.zero, () {
        if (!_disposed) _doLoad(direction, bypassEndOfPag: true);
      });
    }

    final localSource = source.localSource.call(params);

    subscription = localSource.listen(
      (page) async {
        if (_pages.isEmpty) {
          await subscription?.cancel();
          _pageSubscriptions.remove(params.key);
          if (!completer.isCompleted) completer.complete();
          return;
        }

        // A null boundary key (nextKey for appends, prevKey for prepends)
        // means the source has no further page in this direction.
        final endOfPage = (prepend ? page.prevKey : page.nextKey) == null;

        final newState = NotLoading(endOfPage);
        final stateChanged = _sourceStates.get(direction) != newState;
        _sourceStates = _sourceStates.modifyState(direction, newState);
        if (!prepend) {
          _sourceStates =
              _sourceStates.modifyState(LoadType.REFRESH, NotLoading(true));
        }

        // Use params.key as the position key so the page always lands in the
        // correct slot regardless of how the source sets its own keys. Empty
        // first emissions (cache miss — the page exists only to trigger the
        // mediator) are no-ops; empty re-emissions remove the page.
        _insertOrUpdate(params.key, page, prepend: prepend);

        // _insertOrUpdate only dispatches when the data changed; a load-state
        // transition (e.g. Loading → NotLoading on an empty page) must still
        // be published or `value` stays stuck on the stale state.
        if (prepend && stateChanged) dispatchUpdates();

        if (page.data.isEmpty || endOfPage) {
          remoteLoadRequested = true;
          subscription?.pause();
          await _requestRemoteLoad(direction);
          if (!streamCompleted) {
            subscription?.resume();
          } else {
            // Stream completed while waiting for the mediator.
            _pageSubscriptions.remove(params.key);
            retriggerIfMediatorSavedData();
          }
        }

        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        streamCompleted = true;
        // Stream ended (one-shot source). Unstick any Loading state so the
        // scroll guard recovers, and remove the subscription so a future load
        // can re-subscribe for new data (e.g. after a remote mediator load).
        if (_sourceStates.get(direction) is Loading) {
          _sourceStates =
              _sourceStates.modifyState(direction, NotLoading(true));
          dispatchUpdates();
        }
        _pageSubscriptions.remove(params.key);
        if (!completer.isCompleted) completer.complete();
        // onDone fires after onData returned (streamCompleted was still false
        // when onData checked), so re-trigger from here in that case.
        if (remoteLoadRequested) retriggerIfMediatorSavedData();
      },
      onError: (Object e) {
        _sourceStates = _sourceStates.modifyState(
            direction, Error(e is Exception ? e : Exception(e.toString())));
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

  K? get _prevPageKey {
    final firstPage = _pages.firstOrNull;
    return firstPage?.prevKey;
  }

  FutureOr<void> _requestRemoteLoad(LoadType loadType) async {
    if (_remoteMediator == null) return;
    final current = _mediatorStates.get(loadType);
    if (current.endOfPaginationReached) return;
    // Refresh is fired outside the lock (initial load), so it also needs an
    // overlapping-call guard; append/prepend are serialized by _doLoad.
    if (loadType == LoadType.REFRESH && current is Loading) return;

    _mediatorStates = _mediatorStates.modifyState(loadType, Loading());
    dispatchUpdates();

    final pageKey =
        loadType == LoadType.PREPEND ? _prevPageKey : _nextPageKey;
    final result = await _remoteMediator!
        .load(loadType, PagingState<K, T>(pageKey, pagingConfig));

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
      if (idx != -1) _removePageAt(idx);
    }
    return false; // changed
  }

  /// Inserts [page] at the front of [_pages], registered under [positionKey].
  void _insertPageAtFront(K? positionKey, Page<K, T> page) {
    _pages.insert(0, page);
    _pageIndex.updateAll((key, value) => value + 1);
    _pageIndex[positionKey] = 0;
  }

  /// Removes the page at [index] and shifts [_pageIndex] entries accordingly,
  /// preserving each surviving page's original position key (null for the
  /// refresh page, load cursor for appended/prepended pages).
  void _removePageAt(int index) {
    _pages.removeAt(index);
    _pageIndex.removeWhere((key, value) => value == index);
    _pageIndex.updateAll((key, value) => value > index ? value - 1 : value);
  }

  /// Inserts or updates a page identified by [positionKey].
  ///
  /// [positionKey] for the first (refresh) page is always `null`.
  /// For appended and prepended pages it is [LoadParams.key] — the boundary
  /// key of the neighbouring page the load was issued from — which gives O(1)
  /// lookup via [_pageIndex]. Prepended pages must NOT be keyed by their own
  /// prevKey: the topmost page's prevKey is null, which would collide with the
  /// refresh page's slot.
  void _insertOrUpdate(K? positionKey, Page<K, T> page,
      {bool prepend = false}) {
    bool inserted = false;

    if (positionKey == null) {
      // Refresh page slot. Resolved via _pageIndex — after a prepend the
      // refresh page is no longer _pages.first.
      final index = _pageIndex[null];
      if (_pages.isEmpty) {
        if (!page.isEmpty()) {
          _pages.add(page);
          _pageIndex[positionKey] = 0;
          inserted = true;
        }
      } else if (index != null && index < _pages.length) {
        inserted = !_calculateDiffAndUpdate(_pages[index], page);
      } else if (!page.isEmpty()) {
        // The refresh page was removed (emptied by a reactive update) while
        // other pages remain — re-insert it at the front.
        _insertPageAtFront(positionKey, page);
        inserted = true;
      }
    } else {
      if (_pages.isEmpty) {
        _invalidate();
        return;
      }

      final index = _pageIndex[positionKey];
      if (index == null && page.data.isNotEmpty) {
        if (prepend) {
          _insertPageAtFront(positionKey, page);
        } else {
          _pageIndex[positionKey] = _pages.length;
          _pages.add(page);
        }
        inserted = true;
      } else if (index != null && index < _pages.length) {
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
    _states = _states.combineStates(_sourceStates, _mediatorStates,
        hasMediator: _remoteMediator != null);
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
