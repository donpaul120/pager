import 'package:flutter/foundation.dart';
import 'paging_state.dart';

abstract class RemoteMediator<K, V> extends ValueNotifier<MediatorResult?> {
  RemoteMediator() : super(null);

  Future<MediatorResult> load(LoadType loadType, PagingState pagingState);
}

class MediatorResult {
  final int totalItems;

  MediatorResult({this.totalItems = 0});

  factory MediatorResult.success({
    bool endOfPaginationReached = true,
    int totalItems = 0,
  }) =>
      MediatorSuccess(endOfPaginationReached, totalItems);

  factory MediatorResult.error({required Exception exception}) =>
      MediatorError(exception);
}

class MediatorSuccess extends MediatorResult {
  final bool endOfPaginationReached;

  MediatorSuccess(this.endOfPaginationReached, int totalItems)
      : super(totalItems: totalItems);

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

