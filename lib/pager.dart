library pager;

import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:synchronized/synchronized.dart';

import 'paging/combined_load_state.dart';
import 'paging/load_state.dart';
import 'paging/load_states.dart';
import 'paging/page_config.dart';
import 'paging/paging_data.dart';
import 'paging/paging_source.dart';
import 'paging/paging_state.dart';
import 'paging/remote_mediator.dart';
import 'package:collection/collection.dart';


/// @author Paul Okeke
/// A Paging Library

typedef PagingBuilder<T> = Widget Function(BuildContext context, T value);

class Pager<K, T> extends StatefulWidget {
  const Pager({
    Key? key,
    required this.source,
    required this.builder,
    this.pagingConfig = const PagingConfig.fromDefault(),
    this.scrollController,
    this.keepAlive = false
  }) : super(key: key);

  final PagingSource<K, T> source;

  final PagingBuilder<PagingData<T>> builder;

  final PagingConfig pagingConfig;

  final ScrollController? scrollController;

  final bool keepAlive;

  @override
  State<StatefulWidget> createState() => _PagerState<K,T>();

}

class _PagerState<K, T> extends State<Pager<K, T>> with AutomaticKeepAliveClientMixin {

  ///
  final List<Page<K, T>> _pages = [];

  ///
  LoadStates _states = LoadStates.idle();

  ///
  PagingData<T> snapShot = PagingData([]);

  /// Local Data state
  LoadStates? sourceStates = LoadStates.idle();

  /// Remote data state
  LoadStates? mediatorStates = LoadStates.idle();

  final lock = Lock();

  /// The Current PagingData value. This value is what is passed
  /// to the PagingBuilder when the data is updated/changes
  late PagingData<T> value;

  /// A ScrollController used basically to listen for scroll events
  /// and to append more data when the scroll position hits
  /// the prefetch distance
  ScrollController? _scrollController;

  ///
  int _totalNumberOfItems = 0;

  /// Holds a subscription for each page fetched
  final LinkedHashMap<K?, StreamSubscription<Page<K, T>>> _pageSubscriptions =
  LinkedHashMap();

  ///
  PagingSource<K, T>? _pagingSource;

  ///
  RemoteMediator<K, dynamic>? _remoteMediator;

  LoadParams<K> loadParams(LoadType loadType, K? key) {
    return LoadParams(
        loadType,
        key,
        (loadType == LoadType.REFRESH)
            ? widget.pagingConfig.initialPageSize
            : widget.pagingConfig.pageSize
    );
  }

  @override
  void initState() {
    value = PagingData([]);
    _pagingSource = widget.source;
    _remoteMediator = _pagingSource?.remoteMediator;
    super.initState();
    _doInitialLoad();
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;

  List<T> transformPages() {
    _totalNumberOfItems = 0;
    return _pages.fold(<T>[], (List<T> previousValue, element) {
      _totalNumberOfItems += element.data.length;
      previousValue.addAll(element.data);
      return previousValue;
    });
  }

  _doInitialLoad() {
    Future.microtask(() {
      mediatorStates = mediatorStates?.modifyState(LoadType.REFRESH, Loading());
      _requestRemoteLoad(LoadType.REFRESH);
      _doLoad(LoadType.REFRESH);
    });
  }

  _doLoad(LoadType loadType) async {
    LoadParams<K> params;

    await lock.synchronized(() async {
      if (loadType == LoadType.REFRESH && _pages.isNotEmpty) {
        await invalidate();
      }

      if (_pages.isEmpty || _pages.last.isEmpty()) {
        params = loadParams(LoadType.REFRESH, null);
      } else {
        final nextKey = _pages.last.nextKey;
        params = loadParams(loadType, nextKey);
      }

      switch (loadType) {
        case LoadType.REFRESH:
          sourceStates = sourceStates?.modifyState(loadType, Loading());
          await _closeAllSubscriptions();
          await _onRefresh(params);
          break;
        case LoadType.APPEND:
          sourceStates = sourceStates?.modifyState(loadType, Loading());
          await _onAppend(params);
          break;
        case LoadType.PREPEND:
          onPrepend(params);
          break;
      }
    });
  }

  ///This is triggered when we are reloading the page, e.g a new paging source
  _onRefresh(LoadParams<K> params) async {
    if (_pageSubscriptions.containsKey(params.key)) return;

    dispatchUpdates();

    final localSource = widget.source.localSource.call(params);
    final subscription = localSource.listen((page) {

      final newData = page.data;

      if (_pages.isNotEmpty) {
        insertOrUpdate(page.prevKey, page);
        return;
      }

      if (newData.length < widget.pagingConfig.initialPageSize) {
        sourceStates = sourceStates
            ?.modifyState(LoadType.REFRESH, NotLoading(true))
            .modifyState(LoadType.APPEND, NotLoading(true))
            .modifyState(LoadType.PREPEND, NotLoading(true));
      } else {
        sourceStates = sourceStates
            ?.modifyState(LoadType.REFRESH, NotLoading(false))
            .modifyState(LoadType.APPEND, NotLoading(true))
            .modifyState(LoadType.PREPEND, NotLoading(true));
      }

      insertOrUpdate(page.prevKey, page);
    });
    _pageSubscriptions.putIfAbsent(params.key, () => subscription);
  }

  _onAppend(LoadParams<K> params) async {

    if (_pageSubscriptions.containsKey(params.key)) {
      return;
    }

    final localSource = widget.source.localSource.call(params);
    StreamSubscription<Page<K, T>>? subscription;

    subscription = localSource.listen((page) {
      if (_pages.isEmpty) {
        subscription?.cancel();
        _pageSubscriptions.remove(params.key);
        return;
      }

      final newData = page.data;
      final lastPage = _pages.last;

      if (lastPage.nextKey != page.prevKey) {
        insertOrUpdate(page.prevKey, page);
        return;
      }

      final endOfPage = newData.length < widget.pagingConfig.pageSize;

      sourceStates = sourceStates
          ?.modifyState(LoadType.REFRESH, NotLoading(true))
          .modifyState(LoadType.APPEND, NotLoading(endOfPage))
          .modifyState(LoadType.PREPEND, NotLoading(true));

      if (newData.isEmpty || endOfPage) {
        _requestRemoteLoad(LoadType.APPEND);
      }

      insertOrUpdate(page.prevKey, page);
    });
    _pageSubscriptions.putIfAbsent(params.key, () => subscription!);
    dispatchUpdates();
  }

  onPrepend(LoadParams params) {

  }

  /// The next page key to fetch.
  /// If the next key is null that would mean the last page
  /// data isn't up to the [PagingConfig.pageSize] and thus the [Page.prevKey]
  /// will be used instead
  K? get _nextPageKey {
    final lastPage = _pages.lastOrNull;
    return lastPage?.nextKey ?? lastPage?.prevKey;
  }

  _requestRemoteLoad(LoadType loadType) async {
    if (true == mediatorStates?.refresh.endOfPaginationReached ||
        true == mediatorStates?.append.endOfPaginationReached ||
        null == _remoteMediator) {
      return;
    }

    mediatorStates = mediatorStates?.modifyState(loadType, Loading());

    final result = await _remoteMediator?.load(
        loadType, PagingState<K, T>(_nextPageKey, widget.pagingConfig)
    );

    if (result is MediatorSuccess) {
      mediatorStates = mediatorStates?.modifyState(
          loadType, NotLoading(result.endOfPaginationReached)
      );
      _doLoad(loadType);
    } else if (result is MediatorError) {
      mediatorStates = mediatorStates?.modifyState(
          loadType, Error(result.exception)
      );
      dispatchUpdates();
    }
  }

  invalidate({bool dispatch = true}) async {
    _pages.clear();
    snapShot.data.clear();
    if (dispatch) dispatchUpdates();
    await _closeAllSubscriptions();
  }

  bool _calculateDiffAndUpdate(Page<K, T> oldPage, Page<K, T> newPage) {
    final oldList = oldPage.data;
    final newList = newPage.data;

    ///Using The Myer's difference algorithm to find the difference
    final dataDiffUpdates = calculateListDiff(oldList, newList)
        .getUpdatesWithData();

    final isSame = dataDiffUpdates.isEmpty;

    if (!isSame) {
      oldList.clear();
      oldList.addAll(newList);
      if (oldList.isEmpty) {
        _pages.remove(oldPage);
      }
    }
    return isSame;
  }

  insertOrUpdate(K? prevKey, Page<K, T> page) {
    bool inserted = false;
    if (null == prevKey) {
      if (_pages.isEmpty) {
        if (!page.isEmpty()) _pages.add(page);
        inserted = true;
      } else if(_pages.isNotEmpty) {
        inserted = !_calculateDiffAndUpdate(_pages.first, page);
      }
    } else {
      //this is a possible append or prepend
      if (_pages.isEmpty) {
        invalidate();
        return;
      }

      //TODO: consider using an hashtable for faster look up in 0(1) time
      final oldPage = _pages.firstWhereOrNull((element) {
        return element.prevKey == prevKey;
      });
      //TODO: We should not be adding to this page if the previous page is not up to load size
      if (null == oldPage && page.data.isNotEmpty) {
        _pages.add(page);
        inserted = true;
      } else if (null != oldPage) {
        inserted = !_calculateDiffAndUpdate(oldPage, page);
      }
    }
    if (inserted) {
      dispatchUpdates();
    }
  }

  /// It's paramount that this ends before any other subscription is added
  _closeAllSubscriptions() async {
    if(_pageSubscriptions.isEmpty) return;
    await Future.microtask(() async {
      for (final subscription in _pageSubscriptions.entries) {
        await subscription.value.cancel();
      }
      _pageSubscriptions.clear();
    });
  }

  void dispatchUpdates() {
    _states = _states.combineStates(sourceStates!, mediatorStates!);
    final combinedStates = CombinedLoadStates(
        _states.refresh, _states.append, _states.prepend,
        source: sourceStates, mediator: mediatorStates);

    final pages = transformPages();
    final PagingData<T> event = PagingData(pages, loadStates: combinedStates);

    if (mounted) {
      setState(() {
        value = event;
      });
      snapShot = event;
    }
  }

  void _scrollListener() {
    final prefetchDistance = widget.pagingConfig.preFetchDistance;
    final currentScrollExtent = _scrollController?.position.pixels ?? 0;
    final maxScrollExtent = _scrollController?.position.maxScrollExtent ?? 0;

    final heightPerItem = maxScrollExtent / _totalNumberOfItems;
    final scrollOffsetPerItem = currentScrollExtent / heightPerItem;

    print("Listening to scroll event!!!");

    if ((_totalNumberOfItems - scrollOffsetPerItem) <= prefetchDistance) {
      _doLoad(LoadType.APPEND);
    }
  }

  void _registerScrollListener() {
    final scrollController = _scrollController ?? widget.scrollController;
    print("ScrollController is $scrollController");
    scrollController?.removeListener(_scrollListener);
    scrollController?.addListener(_scrollListener);
  }

  Future<void> resetPager() async {
    _states = LoadStates.idle();
    sourceStates = LoadStates.idle();
    mediatorStates = LoadStates.idle();
    _pagingSource = widget.source;
    _remoteMediator = widget.source.remoteMediator;
    await invalidate(dispatch: false);
  }

  @override
  void didUpdateWidget(covariant Pager<K, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      resetPager().then((value) {
        _doInitialLoad();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (wantKeepAlive) {
      super.build(context);
    }
    Widget builder = widget.builder(context, value);
    if (builder is ScrollView) {
      print("We have a scroll Controller");
      _scrollController = builder.controller;
    } else {
      _scrollController = widget.scrollController;
      print("We don't have a controller");

    }
    _registerScrollListener();
    return builder;
  }

  @override
  void dispose() {
    invalidate(dispatch: false);
    super.dispose();
  }

}