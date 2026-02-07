class LoadState {
  final bool endOfPaginationReached;
  final int? totalItems;

  LoadState(this.endOfPaginationReached, {this.totalItems = 0});

  String toString() {
    return "LoadState(endOfPaginationReached=$endOfPaginationReached, totalItems=$totalItems)";
  }
}

class NotLoading extends LoadState {
  NotLoading(bool endOfPaginationReached, {int? totalItems})
      : super(endOfPaginationReached, totalItems: totalItems);

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