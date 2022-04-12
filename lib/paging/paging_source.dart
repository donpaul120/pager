import 'dart:async';

import 'package:flutter/foundation.dart';

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

  final StreamController<Page<Key, Value>> _data = StreamController.broadcast();

  Stream<Page<Key, Value>> readFromLocalSource(LoadParams<Key> loadParams) async* {
    final stream = localSource.call(loadParams);
    if(!_data.isClosed) {
      await _data.addStream(stream);
    }
    yield* _data.stream;
  }

  PagingSource<Key, Value> forEach(Function(List<Value> a) callback) {
    _data.stream.listen((event) {
      callback.call(event.data);
    });
    return this;
  }

  PagingSource<Key, Value> map(PagingSource<Key, Value> Function(PagingSource<Key, Value> a) event) {
    return event.call(this);
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