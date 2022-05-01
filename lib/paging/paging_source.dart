import 'dart:async';

import 'paging_data.dart';
import 'paging_state.dart';
import 'remote_mediator.dart';

///@author Paul Okeke

class PagingSource<Key, Value> {

  PagingSource({
    required this.localSource,
    this.remoteMediator
  });

  final Stream<Page<Key, Value>> Function(LoadParams<Key> loadParams) localSource;
  final RemoteMediator<Key, Value>? remoteMediator;

  @ExperimentalPagingApi()
  PagingSource<Key, Value> sort([int Function(Value a, Value b)? compare]) {
    return PagingSource(
        localSource: (a) => localSource(a).map((event) {
          final newData = event.data;
          newData.sort(compare);
          return Page(newData, event.prevKey, event.nextKey);
        }),
        remoteMediator: remoteMediator
    );
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> filter(bool Function(Value a) predicate) {
    return PagingSource(
        localSource: (params) => localSource(params).map((event) {
          final newData = event.data.where(predicate).toList();
          return Page(newData, event.prevKey, event.nextKey);
        }),
        remoteMediator: remoteMediator
    );
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> forEach(Function(List<Value> a) callback) {
    return PagingSource(
        localSource: (params) {
          final value = localSource(params);
          value.forEach((element) {
            callback.call(element.data);
          });
          return value;
        },
        remoteMediator: remoteMediator
    );
  }

  @ExperimentalPagingApi()
  PagingSource<Key, T> map<T>(T Function(Value a) predicate) {
    return PagingSource(
        localSource: (params) => localSource(params).map((event) {
          final newData = event.data.map(predicate).toList();
          return Page(newData, event.prevKey, event.nextKey);
        }),
      // remoteMediator: remoteMediator
    );
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> take(int limit) {
    return PagingSource(
      localSource: (params) => localSource(params).take(limit),
      remoteMediator: remoteMediator
    );
  }

  factory PagingSource.empty() {
    return PagingSource<Key, Value>(localSource: (a) => Stream.value(Page([], null, null)));
  }
}

class LoadParams<K> {
  final LoadType loadType;
  final K? key;
  final int loadSize;

  LoadParams(this.loadType, this.key, this.loadSize);
}

class ExperimentalPagingApi {
  const ExperimentalPagingApi();
}