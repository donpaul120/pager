import 'load_state.dart';
import 'load_states.dart';

class CombinedLoadStates {

  CombinedLoadStates(this.refresh, this.append, this.prepend, {this.source, this.mediator});

  final LoadState refresh;
  final LoadState append;
  final LoadState prepend;
  final LoadStates? source;
  final LoadStates? mediator;

  @override
  String toString() {
    return "CombinedLoadStates(refresh=$refresh, prepend=$prepend, append=$append, " +
        "source=$source, mediator=$mediator)";
  }
}