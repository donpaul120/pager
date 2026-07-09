import 'package:pager/paging/helper/paged_record_response.dart';
import 'package:pager/paging/paging_state.dart';
import 'package:pager/paging/remote_mediator.dart';

PagerRecordMediator<K, V> pagerRecordMediator<K, V>({
  required Future<void> Function(List<V> value) save,
  required Future<void> Function(List<V> value) clear,
  required Future<PagerRecordData<V>> Function(K? page) fetch,
}) {
  return _PagerRecordMediatorImpl(save, clear, fetch);
}

abstract class PagerRecordMediator<K, V> extends RemoteMediator<K, V> {
  Future<void> save(List<V> value);

  Future<PagerRecordData<V>> fetch(K? page);

  Future<void> clear(List<V> items);

  K? _page;

  @override
  Future<MediatorResult> load(
      LoadType loadType, PagingState<dynamic, dynamic> pagingState) async {
    try {
      switch (loadType) {
        case LoadType.REFRESH:
          _page = null;
          break;
        case LoadType.APPEND:
          _page = pagingState.nextKey as K?;
          break;
        case LoadType.PREPEND:
          return MediatorResult.success();
      }
      final response = await fetch(_page);
      var endOfPagination = false;
      final contentLength = response.records?.length ?? 0;
      if (loadType == LoadType.REFRESH) {
        await clear(response.records ?? []);
        await save(response.records ?? []);
        if (pagingState.pagingConfig.initialPageSize > contentLength) {
          endOfPagination = true;
        }
      } else {
        endOfPagination = pagingState.pagingConfig.pageSize > contentLength ||
            contentLength == 0;
      }

      if (contentLength != 0 && loadType != LoadType.REFRESH) {
        await save(response.records ?? []);
      }

      return MediatorResult.success(endOfPaginationReached: endOfPagination);
    } catch (e, _) {
      if (e is Exception) {
        return MediatorResult.error(exception: e);
      } else {
        return MediatorResult.error(exception: Exception(e));
      }
    }
  }
}

///============================================================================
class _PagerRecordMediatorImpl<K, V> extends PagerRecordMediator<K, V> {
  _PagerRecordMediatorImpl(this._save, this._clear, this._fetch);

  final Future<void> Function(List<V> value) _save;
  final Future<void> Function(List<V> value) _clear;
  final Future<PagerRecordData<V>> Function(K? page) _fetch;

  @override
  Future<void> clear(List<V> items) => _clear(items);

  @override
  Future<void> save(List<V> value) => _save(value);

  @override
  Future<PagerRecordData<V>> fetch(K? page) => _fetch(page);
}
