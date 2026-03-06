
import 'combined_load_state.dart';
import 'load_state.dart';
import 'load_states.dart';

class PagingData<T> {
  final List<T> data;
  final List<T>? oldList;
  final CombinedLoadStates? loadStates;
  PagingData(this.data, {this.oldList, this.loadStates});
}

class Page<Key, Value> {
  final List<Value> data;

  final Key? prevKey;

  final Key? nextKey;

  Page(this.data, this.prevKey, this.nextKey);

  bool isEmpty() => data.isEmpty;

  PagingData<Value> toPagingData(LoadStates states) {
    return PagingData(data, loadStates: CombinedLoadStates(
        LoadState(true), LoadState(true), LoadState(true)
    ));
  }
}