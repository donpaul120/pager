
class LoadState {
  final bool endOfPaginationReached;
  LoadState(this.endOfPaginationReached);
  String toString() {
    return "LoadState(endOfPaginationReached=$endOfPaginationReached)";
  }
}

class NotLoading extends LoadState {
  NotLoading(bool endOfPaginationReached): super(endOfPaginationReached);
  @override
  String toString() {
    return "NotLoading(endOfPaginationReached=$endOfPaginationReached)";
  }
  @override
  int get hashCode => endOfPaginationReached.hashCode;

  @override
  bool operator ==(Object other) {
    return other is NotLoading && (endOfPaginationReached == other.endOfPaginationReached);
  }
}

class Loading extends LoadState {
  Loading({bool endOfPaginationReached = false}): super(endOfPaginationReached);
  @override
  String toString() {
    return "Loading(endOfPaginationReached=$endOfPaginationReached)";
  }
  @override
  int get hashCode => endOfPaginationReached.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Loading && (endOfPaginationReached == other.endOfPaginationReached);
  }
}

class Error extends LoadState {
  final Exception exception;
  Error(this.exception): super(false);
  @override
  String toString() {
    return "Error(endOfPaginationReached=$endOfPaginationReached)";
  }
  @override
  int get hashCode => endOfPaginationReached.hashCode + exception.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Error
        && (endOfPaginationReached == other.endOfPaginationReached)
        && (exception == other.exception);
  }
}