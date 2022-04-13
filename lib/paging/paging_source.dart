import 'dart:async';

import 'paging_data.dart';
import 'paging_state.dart';
import 'remote_mediator.dart';

class PagingSource<Key, Value> {

  PagingSource({
    required this.localSource,
    this.remoteMediator
  });

  final Stream<Page<Key, Value>> Function(LoadParams<Key> loadParams) localSource;
  final RemoteMediator<Key, Value>? remoteMediator;

  Stream<Page<Key, Value>> readFromLocalSource(LoadParams<Key> loadParams)  {
    return localSource.call(loadParams).asBroadcastStream();
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> sort([int Function(Value a, Value b)? compare]) {
    return PagingSource(
        localSource: (a) => readFromLocalSource(a).map((event) {
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
        localSource: (params) => readFromLocalSource(params).map((event) {
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
          final value = readFromLocalSource(params);
          value.forEach((element) {
            callback.call(element.data);
          });
          return value;
        },
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