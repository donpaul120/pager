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