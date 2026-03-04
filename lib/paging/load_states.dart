import 'load_state.dart';
import 'paging_state.dart';

class LoadStates {
  LoadStates(this.refresh, this.append, this.prepend);

  final LoadState refresh;
  final LoadState append;
  final LoadState prepend;

  @override
  String toString() {
    return 'LoadStates(refresh=$refresh, append=$append, prepend=$prepend)';
  }

  LoadStates modifyState(LoadType type, LoadState newState) {
    switch (type) {
      case LoadType.REFRESH:
        return LoadStates(newState, append, prepend);
      case LoadType.APPEND:
        return LoadStates(refresh, newState, prepend);
      case LoadType.PREPEND:
        return LoadStates(refresh, append, newState);
    }
  }

  /// Combines source (local) and mediator (remote) states into a single view.
  ///
  /// Priority rules:
  /// 1. A [Loading] state from the mediator takes precedence over source.
  /// 2. An [Error] state from either source or mediator takes highest priority
  ///    (mediator error wins if both have errors).
  LoadStates combineStates(LoadStates sourceState, LoadStates mediatorState) {
    // Start with source state as baseline
    LoadState aRefresh = sourceState.refresh;
    LoadState aAppend = sourceState.append;
    LoadState aPrepend = sourceState.prepend;

    // Remote loading takes precedence over local not-loading
    if (mediatorState.refresh is Loading) aRefresh = mediatorState.refresh;
    if (mediatorState.append is Loading) aAppend = mediatorState.append;
    if (mediatorState.prepend is Loading) aPrepend = mediatorState.prepend;

    // Errors take highest precedence; mediator error wins over source error
    if (sourceState.refresh is Error) aRefresh = sourceState.refresh;
    if (mediatorState.refresh is Error) aRefresh = mediatorState.refresh;

    if (sourceState.append is Error) aAppend = sourceState.append;
    if (mediatorState.append is Error) aAppend = mediatorState.append;

    if (sourceState.prepend is Error) aPrepend = sourceState.prepend;
    if (mediatorState.prepend is Error) aPrepend = mediatorState.prepend;

    return LoadStates(aRefresh, aAppend, aPrepend);
  }

  factory LoadStates.idle() => LoadStates(
      NotLoading(false), NotLoading(false), NotLoading(false));
}
