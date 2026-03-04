import 'dart:async';

import 'paging_data.dart';
import 'paging_state.dart';
import 'remote_mediator.dart';
import 'package:collection/collection.dart' as collections;

/// @author Paul Okeke
class PagingSource<Key, Value> {
  PagingSource({
    required this.localSource,
    this.remoteMediator,
  });

  final Stream<Page<Key, Value>> Function(LoadParams<Key> loadParams)
      localSource;
  final RemoteMediator<Key, dynamic>? remoteMediator;

  @ExperimentalPagingApi()
  PagingSource<Key, Value> sort([int Function(Value a, Value b)? compare]) {
    return PagingSource(
        localSource: (params) => localSource(params).map((event) {
              final newData = List<Value>.of(event.data)..sort(compare);
              return Page(newData, event.prevKey, event.nextKey);
            }),
        remoteMediator: remoteMediator);
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> filter(bool Function(Value a) predicate) {
    return PagingSource(
        localSource: (params) => localSource(params).map((event) {
              final newData = event.data.where(predicate).toList();
              return Page(newData, event.prevKey, event.nextKey);
            }),
        remoteMediator: remoteMediator);
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> forEach(Function(List<Value> a) callback) {
    return PagingSource(
        localSource: (params) {
          return localSource(params).map((event) {
            callback.call(event.data);
            return event;
          });
        },
        remoteMediator: remoteMediator);
  }

  @ExperimentalPagingApi()
  PagingSource<Key, T> map<T>(T Function(Value a) transform) {
    return PagingSource(
        localSource: (params) => localSource(params).map((event) {
              final newData = event.data.map(transform).toList();
              return Page(newData, event.prevKey, event.nextKey);
            }),
        remoteMediator: remoteMediator);
  }

  @ExperimentalPagingApi()
  PagingSource<Key, T> groupBy<K, T>(
      K Function(Value a) key, T Function(K key, List<Value> items) mapper) {
    return PagingSource(
        localSource: (params) => localSource(params).map((event) {
              final groupedData = collections.groupBy(event.data, key);
              final newData = <T>[];
              groupedData.forEach((groupKey, values) {
                if (values.isNotEmpty) {
                  newData.add(mapper(groupKey, values));
                }
              });
              return PageGroup(
                  newData, event.prevKey, event.nextKey, event.data.length);
            }),
        remoteMediator: remoteMediator);
  }

  @ExperimentalPagingApi()
  PagingSource<Key, Value> take(int limit) {
    return PagingSource(
        localSource: (params) => localSource(params).take(limit),
        remoteMediator: remoteMediator);
  }

  factory PagingSource.empty() {
    return PagingSource<Key, Value>(
        localSource: (a) => Stream.value(Page([], null, null)));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagingSource<Key, Value> &&
          runtimeType == other.runtimeType &&
          localSource == other.localSource &&
          remoteMediator == other.remoteMediator;

  @override
  int get hashCode => localSource.hashCode ^ remoteMediator.hashCode;
}

class LoadParams<K> {
  LoadParams(this.loadType, this.key, this.loadSize);

  final LoadType loadType;
  final K? key;
  final int loadSize;
}

/// A [Page] where items have been grouped. [originalDataSize] reflects the
/// number of raw items before grouping.
class PageGroup<Key, Value> extends Page<Key, Value> {
  PageGroup(List<Value> data, Key? prevKey, Key? nextKey,
      this.originalDataSize)
      : super(data, prevKey, nextKey);

  final int originalDataSize;
}

/// Base class for grouped item models. Implement this in your data class when
/// using [PagingSource.groupBy].
abstract class PageGroupData<K, Value> {
  final K key;
  final List<Value> items;
  PageGroupData({required this.key, required this.items});
}

/// Marks APIs that may change in future releases.
class ExperimentalPagingApi {
  const ExperimentalPagingApi();
}
