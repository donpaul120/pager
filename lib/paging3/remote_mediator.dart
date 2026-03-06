import 'dart:async';
import 'paging_source.dart';

/// Defines the contract between [Pager] and network/database layers
abstract class RemoteMediator<Key, Value> {
  /// Callback to perform the actual load operation for the given [loadType] and [state]
  Future<MediatorResult> load(LoadType loadType, PagingState<Key, Value> state);
  
  /// Called before the initial load or when [PagingSource] is invalidated
  Future<void> initialize() async {}
}

/// Type of load operation
enum LoadType {
  /// Initial load or refresh operation
  refresh,
  
  /// Load data before the current dataset
  prepend,
  
  /// Load data after the current dataset  
  append,
}

/// Result of a [RemoteMediator.load] call
abstract class MediatorResult {
  const MediatorResult();
}

/// Indicates load operation completed successfully
class MediatorResultSuccess extends MediatorResult {
  /// Whether the end of pagination has been reached
  final bool endOfPaginationReached;
  
  const MediatorResultSuccess({
    required this.endOfPaginationReached,
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediatorResultSuccess &&
          endOfPaginationReached == other.endOfPaginationReached;

  @override
  int get hashCode => endOfPaginationReached.hashCode;
  
  @override
  String toString() => 
      'MediatorResult.Success(endOfPaginationReached=$endOfPaginationReached)';
}

/// Indicates load operation failed with an error
class MediatorResultError extends MediatorResult {
  /// The error that caused the operation to fail
  final Exception throwable;
  
  const MediatorResultError(this.throwable);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediatorResultError && throwable == other.throwable;

  @override
  int get hashCode => throwable.hashCode;
  
  @override
  String toString() => 'MediatorResult.Error($throwable)';
}

/// Abstract base class for handling layered data sources (network + database)
abstract class AbstractRemoteMediator<Key, Value> extends RemoteMediator<Key, Value> {
  @override
  Future<MediatorResult> load(LoadType loadType, PagingState<Key, Value> state) async {
    try {
      switch (loadType) {
        case LoadType.refresh:
          return await loadRefresh(state);
        case LoadType.prepend:
          return await loadPrepend(state);
        case LoadType.append:
          return await loadAppend(state);
      }
    } catch (e) {
      return MediatorResultError(e is Exception ? e : Exception(e.toString()));
    }
  }
  
  /// Handle refresh load operation
  Future<MediatorResult> loadRefresh(PagingState<Key, Value> state);
  
  /// Handle prepend load operation  
  Future<MediatorResult> loadPrepend(PagingState<Key, Value> state) async {
    return const MediatorResultSuccess(endOfPaginationReached: true);
  }
  
  /// Handle append load operation
  Future<MediatorResult> loadAppend(PagingState<Key, Value> state);
}