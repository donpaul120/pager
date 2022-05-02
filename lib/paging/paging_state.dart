import 'page_config.dart';
import 'paging_data.dart';

class PagingState<K, V> {
  final int? anchorPosition;
  final K? nextKey;
  final PagingConfig pagingConfig;

  PagingState(this.nextKey, this.pagingConfig, {this.anchorPosition});
}

enum LoadType {
  REFRESH, APPEND, PREPEND
}