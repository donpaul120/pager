import 'load_state.dart';
import 'paging_state.dart';

class LoadStates {
  LoadStates(this.refresh, this.append, this.prepend);

  final LoadState refresh;
  final LoadState append;
  final LoadState prepend;

  @override
  String toString() {
    return "LoadStates(refresh=$refresh, prepend=$prepend, append=$append, " +
        "source=null, mediator=null)";
  }

  /// Read counterpart of [modifyState], so callers handling both directions
  /// don't have to fork into `.append`/`.prepend` branches.
  LoadState get(LoadType type) {
    switch (type) {
      case LoadType.REFRESH:
        return refresh;
      case LoadType.APPEND:
        return append;
      case LoadType.PREPEND:
        return prepend;
    }
  }

  LoadStates modifyState(LoadType type, LoadState newState) {
    switch(type) {
      case LoadType.REFRESH:{
        return LoadStates(newState, append, prepend);
      }
      case LoadType.APPEND:
        return LoadStates(refresh, newState, prepend);
      case LoadType.PREPEND:
        return LoadStates(refresh, append, newState);
    }
  }

  /// [hasMediator] must be true when a [RemoteMediator] is present.
  /// Without it, only the local source determines end-of-pagination (original
  /// behaviour). With it, both source AND mediator must confirm no more data
  /// before [endOfPaginationReached] becomes true — preventing a premature
  /// "end of list" when the local cache is empty but the server has more.
  ///
  /// [Error] and [Loading] states from either side always take precedence over
  /// the combined end-of-pagination flags, so failures and in-flight loads are
  /// never masked from the UI.
  LoadStates combineStates(LoadStates localState, LoadStates remoteState,
      {bool hasMediator = false}) {
    // Refresh deliberately ranks errors above Loading (a failed refresh must
    // surface even while the other side retries), unlike _combineDirection,
    // and never ANDs end-of-pagination flags.
    final LoadState aRefresh;
    if (remoteState.refresh is Error) {
      aRefresh = remoteState.refresh;
    } else if (localState.refresh is Error) {
      aRefresh = localState.refresh;
    } else if (remoteState.refresh is Loading) {
      aRefresh = remoteState.refresh;
    } else {
      aRefresh = localState.refresh;
    }

    final aAppend =
        _combineDirection(localState.append, remoteState.append, hasMediator);
    final aPrepend =
        _combineDirection(localState.prepend, remoteState.prepend, hasMediator);

    return LoadStates(aRefresh, aAppend, aPrepend);
  }

  static LoadState _combineDirection(
      LoadState local, LoadState remote, bool hasMediator) {
    if (remote is Loading) return remote;
    if (remote is Error) return remote;
    if (local is Loading || local is Error) return local;
    if (hasMediator) {
      return NotLoading(
          local.endOfPaginationReached && remote.endOfPaginationReached);
    }
    return local;
  }

  factory LoadStates.idle() => LoadStates(
      NotLoading(false),
      NotLoading(false),
      NotLoading(false)
  );
}