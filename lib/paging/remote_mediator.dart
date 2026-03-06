import 'package:flutter/foundation.dart';
import 'paging_state.dart';

abstract class RemoteMediator<K, V> extends ValueNotifier<MediatorResult?> {
  RemoteMediator() : super(null);

  Future<MediatorResult> load(LoadType loadType, PagingState pagingState);
}

class MediatorResult {

  MediatorResult();

  factory MediatorResult.success({
    bool endOfPaginationReached = true,
    int? totalItems,
  }) => MediatorSuccess(endOfPaginationReached, totalItems: totalItems);
  factory MediatorResult.error({required Exception exception}) => MediatorError(exception);
}

class MediatorSuccess extends MediatorResult {
  final bool endOfPaginationReached;

  /// The total number of items available on the server, as reported by the
  /// API response. When set, [PagerController.totalItems] reflects this value
  /// instead of the locally-fetched count.
  final int? totalItems;

  MediatorSuccess(this.endOfPaginationReached, {this.totalItems});

  @override
  String toString() {
    return "MediatorSuccess(endOfPaginationReached:$endOfPaginationReached)";
  }
}

class MediatorError extends MediatorResult {
  final Exception exception;
  MediatorError(this.exception);
  @override
  String toString() {
    return "MediatorError(exception:$exception)";
  }
}

