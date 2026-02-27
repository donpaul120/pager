import 'dart:async';
import 'load_params.dart';
import 'load_result.dart';
import 'load_state.dart';
import 'paging_data.dart';
import 'paging_source.dart';
import 'remote_mediator.dart';

/// Primary entry point for Paging; constructor for a reactive stream of [PagingData]
class Pager<Key, Value> {
  final PagingConfig _config;
  final PagingSourceFactory<Key, Value> _pagingSourceFactory;
  final RemoteMediator<Key, Value>? _remoteMediator;
  final Key? _initialKey;
  
  /// Creates a [Pager] instance
  Pager({
    required PagingConfig config,
    required PagingSource<Key, Value> Function() pagingSourceFactory,
    RemoteMediator<Key, Value>? remoteMediator,
    Key? initialKey,
  }) : _config = config,
       _pagingSourceFactory = pagingSourceFactory,
       _remoteMediator = remoteMediator,
       _initialKey = initialKey;
  
  /// Flow of [PagingData] that can be collected to display paginated data
  Stream<PagingData<Value>> get flow => _createFlow();
  
  Stream<PagingData<Value>> _createFlow() async* {
    final controller = PageFetcher<Key, Value>(
      config: _config,
      pagingSourceFactory: _pagingSourceFactory,
      initialKey: _initialKey,
      remoteMediator: _remoteMediator,
    );
    
    yield* controller.flow;
  }
}

/// Factory function to create [PagingSource] instances
typedef PagingSourceFactory<Key, Value> = PagingSource<Key, Value> Function();

/// Internal class that manages the fetching and caching of pages
class PageFetcher<Key, Value> {
  final PagingConfig config;
  final PagingSourceFactory<Key, Value> pagingSourceFactory;
  final Key? initialKey;
  final RemoteMediator<Key, Value>? remoteMediator;
  
  PagingSource<Key, Value>? _pagingSource;
  final List<PagingSourceLoadResultPage<Key, Value>> _pages = [];
  final StreamController<PagingData<Value>> _controller = 
      StreamController<PagingData<Value>>.broadcast();
  
  CombinedLoadStates _loadStates = const CombinedLoadStates(
    refresh: LoadStateNotLoading(endOfPaginationReached: false),
    prepend: LoadStateNotLoading(endOfPaginationReached: false),
    append: LoadStateNotLoading(endOfPaginationReached: false),
  );
  
  StreamSubscription<void>? _invalidationSubscription;
  bool _disposed = false;
  
  PageFetcher({
    required this.config,
    required this.pagingSourceFactory,
    this.initialKey,
    this.remoteMediator,
  }) {
    _doInitialLoad();
  }
  
  Stream<PagingData<Value>> get flow => _controller.stream;
  
  Future<void> _doInitialLoad() async {
    await _refresh(initialKey);
  }
  
  Future<void> _refresh([Key? key]) async {
    await _setLoadState(LoadType.refresh, const LoadStateLoading());
    
    // Initialize RemoteMediator if present
    if (remoteMediator != null) {
      await _loadWithRemoteMediator(LoadType.refresh, key);
    } else {
      await _loadFromSource(LoadType.refresh, key);
    }
  }
  
  Future<void> _loadWithRemoteMediator(LoadType loadType, Key? key) async {
    final state = _createPagingState(key);
    
    try {
      final mediatorResult = await remoteMediator!.load(loadType, state);
      
      if (mediatorResult is MediatorResultSuccess) {
        await _setMediatorLoadState(
          loadType,
          LoadStateNotLoading(endOfPaginationReached: mediatorResult.endOfPaginationReached),
        );
        
        if (!mediatorResult.endOfPaginationReached || _pages.isEmpty) {
          await _loadFromSource(loadType, key);
        }
      } else if (mediatorResult is MediatorResultError) {
        await _setMediatorLoadState(loadType, LoadStateError(mediatorResult.throwable));
        await _setLoadState(loadType, LoadStateError(mediatorResult.throwable));
      }
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _setMediatorLoadState(loadType, LoadStateError(error));
      await _setLoadState(loadType, LoadStateError(error));
    }
  }
  
  Future<void> _loadFromSource(LoadType loadType, Key? key) async {
    _pagingSource ??= _createPagingSource();
    
    final params = _createLoadParams(loadType, key);
    
    try {
      final result = await _pagingSource!.load(params);
      
      if (result is LoadResultPage<Key, Value>) {
        await _handlePageResult(loadType, result);
      } else if (result is LoadResultError<Key, Value>) {
        await _setLoadState(loadType, LoadStateError(result.exception));
      } else if (result is LoadResultInvalid<Key, Value>) {
        _invalidate();
      }
    } catch (e) {
      final error = e is Exception ? e : Exception(e.toString());
      await _setLoadState(loadType, LoadStateError(error));
    }
  }
  
  Future<void> _handlePageResult(
    LoadType loadType,
    LoadResultPage<Key, Value> result,
  ) async {
    final page = PagingSourceLoadResultPage<Key, Value>(
      data: result.data,
      prevKey: result.prevKey,
      nextKey: result.nextKey,
      itemsBefore: result.itemsBefore,
      itemsAfter: result.itemsAfter,
    );
    
    switch (loadType) {
      case LoadType.refresh:
        _pages.clear();
        _pages.add(page);
        break;
      case LoadType.prepend:
        _pages.insert(0, page);
        break;
      case LoadType.append:
        _pages.add(page);
        break;
    }
    
    final endOfPaginationReached = (loadType == LoadType.append && result.nextKey == null) ||
        (loadType == LoadType.prepend && result.prevKey == null) ||
        result.data.length < _getExpectedLoadSize(loadType);
    
    await _setLoadState(
      loadType,
      LoadStateNotLoading(endOfPaginationReached: endOfPaginationReached),
    );
    
    _emitPagingData();
  }
  
  LoadParams<Key> _createLoadParams(LoadType loadType, Key? key) {
    final loadSize = loadType == LoadType.refresh 
        ? config.initialLoadSize 
        : config.pageSize;
    
    switch (loadType) {
      case LoadType.refresh:
        return LoadParamsRefresh<Key>(
          key: key,
          loadSize: loadSize,
          placeholdersEnabled: config.enablePlaceholders,
        );
      case LoadType.prepend:
        if (key == null) {
          throw ArgumentError('Key cannot be null for prepend operation');
        }
        return LoadParamsPrepend<Key>(
          key: key,
          loadSize: loadSize,
          placeholdersEnabled: config.enablePlaceholders,
        );
      case LoadType.append:
        if (key == null) {
          throw ArgumentError('Key cannot be null for append operation');
        }
        return LoadParamsAppend<Key>(
          key: key,
          loadSize: loadSize,
          placeholdersEnabled: config.enablePlaceholders,
        );
    }
  }
  
  int _getExpectedLoadSize(LoadType loadType) {
    return loadType == LoadType.refresh ? config.initialLoadSize : config.pageSize;
  }
  
  PagingState<Key, Value> _createPagingState(Key? anchorKey) {
    return PagingState<Key, Value>(
      pages: _pages,
      anchorPosition: null, // Could be calculated from anchorKey if needed
      config: config,
      leadingPlaceholderCount: 0,
    );
  }
  
  PagingSource<Key, Value> _createPagingSource() {
    _invalidationSubscription?.cancel();
    
    final source = pagingSourceFactory();
    
    _invalidationSubscription = source.invalidatedStream.listen((_) {
      _invalidate();
    });
    
    return source;
  }
  
  void _invalidate() {
    _pagingSource = null;
    _pages.clear();
    _doInitialLoad();
  }
  
  Future<void> _setLoadState(LoadType loadType, LoadState loadState) async {
    final currentStates = _loadStates;
    
    _loadStates = CombinedLoadStates(
      refresh: loadType == LoadType.refresh ? loadState : currentStates.refresh,
      prepend: loadType == LoadType.prepend ? loadState : currentStates.prepend,
      append: loadType == LoadType.append ? loadState : currentStates.append,
      source: currentStates.source,
      mediator: currentStates.mediator,
    );
    
    _emitPagingData();
  }
  
  Future<void> _setMediatorLoadState(LoadType loadType, LoadState loadState) async {
    final currentStates = _loadStates;
    
    // Update the combined load states with the new mediator load state
    _loadStates = CombinedLoadStates(
      refresh: currentStates.refresh,
      prepend: currentStates.prepend,
      append: currentStates.append,
      source: currentStates.source,
      mediator: loadState,
    );
  }
  
  void _emitPagingData() {
    if (_disposed) return;
    
    final allItems = _pages
        .expand((page) => page.data)
        .toList(growable: false);
    
    final pagingData = PagingData.fromList<Value>(
      allItems,
      loadStates: _loadStates,
    );
    
    _controller.add(pagingData);
  }
  
  /// Load more data if possible
  Future<void> append() async {
    if (_loadStates.append.isLoading || _loadStates.append.isCompleted) return;
    
    final lastPage = _pages.isNotEmpty ? _pages.last : null;
    if (lastPage?.nextKey != null) {
      await _setLoadState(LoadType.append, const LoadStateLoading());
      
      if (remoteMediator != null) {
        await _loadWithRemoteMediator(LoadType.append, lastPage!.nextKey);
      } else {
        await _loadFromSource(LoadType.append, lastPage!.nextKey);
      }
    }
  }
  
  /// Load earlier data if possible
  Future<void> prepend() async {
    if (_loadStates.prepend.isLoading || _loadStates.prepend.isCompleted) return;
    
    final firstPage = _pages.isNotEmpty ? _pages.first : null;
    if (firstPage?.prevKey != null) {
      await _setLoadState(LoadType.prepend, const LoadStateLoading());
      
      if (remoteMediator != null) {
        await _loadWithRemoteMediator(LoadType.prepend, firstPage!.prevKey);
      } else {
        await _loadFromSource(LoadType.prepend, firstPage!.prevKey);
      }
    }
  }
  
  /// Force refresh of all data
  Future<void> refresh([Key? key]) async {
    await _refresh(key);
  }
  
  void dispose() {
    _disposed = true;
    _invalidationSubscription?.cancel();
    _pagingSource?.dispose();
    _controller.close();
  }
}