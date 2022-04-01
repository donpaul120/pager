import 'package:flutter/foundation.dart';
import 'paging_state.dart';

abstract class RemoteMediator<K, V> extends ValueNotifier<MediatorResult?> {
  RemoteMediator() : super(null);

  Future<MediatorResult> load(LoadType loadType, PagingState pagingState);
}

class MediatorResult {

  MediatorResult();

  factory MediatorResult.success({bool endOfPaginationReached = true}) => MediatorSuccess(endOfPaginationReached);
  factory MediatorResult.error({required Exception exception}) => MediatorError(exception);
}

class MediatorSuccess extends MediatorResult {
  final bool endOfPaginationReached;
  MediatorSuccess(this.endOfPaginationReached);

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

