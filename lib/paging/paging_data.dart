
import 'combined_load_state.dart';
import 'load_state.dart';
import 'load_states.dart';

class PagingData<T> {
  final List<T> data;

  /// Total number of raw items across all loaded pages.
  /// For grouped data this reflects the pre-group count.
  final int totalItems;

  /// @deprecated — no longer used internally. Kept for backward compatibility.
  final List<T>? oldList;

  final CombinedLoadStates? loadStates;

  PagingData(this.data, {this.totalItems = 0, this.oldList, this.loadStates});

  /// Number of items currently loaded. Equivalent to `data.length`.
  int get itemCount => data.length;

  /// True while the initial/refresh load is in progress.
  bool get isLoading => loadStates?.refresh is Loading;

  /// True when there is no data and no refresh is in progress.
  bool get isEmpty => data.isEmpty && loadStates?.refresh is! Loading;

  /// True when data is present.
  bool get isNotEmpty => !isEmpty;

  /// True while the next page is being loaded.
  bool get isAppending => loadStates?.append is Loading;

  /// True when all pages have been loaded and there is no more data to fetch.
  /// Use this to show a "you've reached the end" footer in your list.
  bool get endOfPaginationReached =>
      loadStates?.append.endOfPaginationReached == true;

  /// True if either the refresh or append load has failed.
  bool get hasError =>
      loadStates?.refresh is Error || loadStates?.append is Error;

  /// The exception from the most recent failed refresh, or null.
  Exception? get refreshError => loadStates?.refresh is Error
      ? (loadStates!.refresh as Error).exception
      : null;

  /// The exception from the most recent failed append, or null.
  Exception? get appendError => loadStates?.append is Error
      ? (loadStates!.append as Error).exception
      : null;
}

class Page<Key, Value> {
  final List<Value> data;

  final Key? prevKey;

  final Key? nextKey;

  /// The total number of items available on the server, as reported by the
  /// data source. Set this from your API response to surface an accurate count
  /// on the UI before all pages are loaded.
  ///
  /// Example:
  /// ```dart
  /// PagingSource<int, Transaction>(
  ///   localSource: (params) async* {
  ///     final response = await api.getTransactions(page: params.key ?? 0);
  ///     yield Page(
  ///       response.items,
  ///       response.prevPage,
  ///       response.nextPage,
  ///       totalItems: response.totalCount, // ← from API
  ///     );
  ///   },
  /// )
  /// ```
  final int? totalItems;

  Page(this.data, this.prevKey, this.nextKey, {this.totalItems});

  bool isEmpty() => data.isEmpty;

  PagingData<Value> toPagingData(LoadStates states) {
    return PagingData(data, loadStates: CombinedLoadStates(
        LoadState(true), LoadState(true), LoadState(true)
    ));
  }
}