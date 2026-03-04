import 'combined_load_state.dart';
import 'load_state.dart';
import 'load_states.dart';

class PagingData<T> {
  PagingData(this.data, {this.totalItems = 0, this.loadStates, List<T>? oldList})
      : oldList = oldList;

  final List<T> data;

  /// Total number of raw items loaded across all pages.
  /// For grouped data this reflects the original (pre-group) count.
  final int totalItems;

  final CombinedLoadStates? loadStates;

  /// Deprecated. Was intended for diff purposes but is no longer used
  /// internally. Kept for backward compatibility only.
  @Deprecated('oldList is no longer used. Use data directly.')
  final List<T>? oldList;

  /// True while the initial/refresh load is in progress.
  bool get isLoading => loadStates?.refresh is Loading;

  /// True when there is no data and the refresh is not loading.
  bool get isEmpty => data.isEmpty && loadStates?.refresh is! Loading;

  /// True while the next page is being appended.
  bool get isAppending => loadStates?.append is Loading;

  /// True if either the refresh or append is in an error state.
  bool get hasError =>
      loadStates?.refresh is Error || loadStates?.append is Error;

  /// The exception from the most recent failed refresh, or null.
  Exception? get refreshError =>
      loadStates?.refresh is Error
          ? (loadStates!.refresh as Error).exception
          : null;

  /// The exception from the most recent failed append, or null.
  Exception? get appendError =>
      loadStates?.append is Error
          ? (loadStates!.append as Error).exception
          : null;
}

class Page<Key, Value> {
  Page(this.data, this.prevKey, this.nextKey);

  final List<Value> data;
  final Key? prevKey;
  final Key? nextKey;

  bool isEmpty() => data.isEmpty;

  /// Deprecated. The implementation was incorrect (hardcoded states).
  /// Kept for backward compatibility only.
  @Deprecated('toPagingData is no longer supported. Use PagingData directly.')
  PagingData<Value> toPagingData(LoadStates states) {
    return PagingData(data,
        loadStates: CombinedLoadStates(
            LoadState(true), LoadState(true), LoadState(true)));
  }
}
