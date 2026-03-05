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

  LoadStates combineStates(LoadStates localState, LoadStates remoteState){
    LoadState aRefresh = LoadState(false);
    LoadState aAppend = LoadState(false);

    aRefresh = (remoteState.refresh is Loading) ? remoteState.refresh : localState.refresh;
    aAppend = (remoteState.append is Loading) ? remoteState.append : localState.append;

    if(remoteState.refresh is Error || localState.refresh is Error) {
      aRefresh = remoteState.refresh;
    }

    return LoadStates(aRefresh, aAppend, prepend);
  }

  factory LoadStates.idle() => LoadStates(
      NotLoading(false),
      NotLoading(false),
      NotLoading(false)
  );
}