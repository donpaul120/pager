/// Represents the load state of a [PagingSource]
abstract class LoadState {
  const LoadState();
  
  /// Returns true if this is a [LoadStateNotLoading] with [endOfPaginationReached] = true
  bool get isCompleted => this is LoadStateNotLoading && 
      (this as LoadStateNotLoading).endOfPaginationReached;
  
  /// Returns true if this is a [LoadStateError]
  bool get isError => this is LoadStateError;
  
  /// Returns true if this is a [LoadStateLoading]
  bool get isLoading => this is LoadStateLoading;
  
  /// Returns true if this is a [LoadStateNotLoading] with [endOfPaginationReached] = false
  bool get isNotLoadingIncomplete => this is LoadStateNotLoading && 
      !(this as LoadStateNotLoading).endOfPaginationReached;
}

/// Indicates the [PagingSource] is not currently loading
class LoadStateNotLoading extends LoadState {
  /// Whether the [PagingSource] has reached the end of pagination
  final bool endOfPaginationReached;
  
  const LoadStateNotLoading({required this.endOfPaginationReached});
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadStateNotLoading &&
          endOfPaginationReached == other.endOfPaginationReached;

  @override
  int get hashCode => endOfPaginationReached.hashCode;
  
  @override
  String toString() => 
      'LoadState.NotLoading(endOfPaginationReached=$endOfPaginationReached)';
}

/// Indicates the [PagingSource] is currently loading
class LoadStateLoading extends LoadState {
  const LoadStateLoading();
  
  @override
  bool operator ==(Object other) => other is LoadStateLoading;

  @override
  int get hashCode => 0;
  
  @override
  String toString() => 'LoadState.Loading';
}

/// Indicates the [PagingSource] has encountered an error
class LoadStateError extends LoadState {
  /// The error that occurred
  final Exception error;
  
  const LoadStateError(this.error);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadStateError && error == other.error;

  @override
  int get hashCode => error.hashCode;
  
  @override
  String toString() => 'LoadState.Error($error)';
}

/// Collection of [LoadState]s for refresh, prepend, and append loads
class CombinedLoadStates {
  /// [LoadState] for refresh loads
  final LoadState refresh;
  
  /// [LoadState] for prepend loads  
  final LoadState prepend;
  
  /// [LoadState] for append loads
  final LoadState append;
  
  /// [LoadState] for the [PagingSource] 
  final LoadState source;
  
  /// [LoadState] for the [RemoteMediator]
  final LoadState? mediator;
  
  const CombinedLoadStates({
    required this.refresh,
    required this.prepend, 
    required this.append,
    LoadState? source,
    this.mediator,
  }) : source = source ?? refresh;
  
  /// Returns true if any [LoadState] is [LoadStateLoading]
  bool get isLoading => 
      refresh.isLoading || prepend.isLoading || append.isLoading;
      
  /// Returns true if any [LoadState] is [LoadStateError]
  bool get hasError => 
      refresh.isError || prepend.isError || append.isError;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombinedLoadStates &&
          refresh == other.refresh &&
          prepend == other.prepend &&
          append == other.append &&
          source == other.source &&
          mediator == other.mediator;

  @override
  int get hashCode => Object.hash(refresh, prepend, append, source, mediator);
  
  @override
  String toString() => 'CombinedLoadStates('
      'refresh=$refresh, '
      'prepend=$prepend, '
      'append=$append, '
      'source=$source, '
      'mediator=$mediator)';
}