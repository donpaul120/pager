import 'dart:async';
import 'load_state.dart';

/// Container for paginated data that can be efficiently displayed in a list
class PagingData<T> {
  /// The actual data items
  final List<T> _items;
  
  /// Load states for different load operations
  final CombinedLoadStates loadStates;
  
  /// Source information for tracking data origin
  final PagingDataSource? _source;
  
  const PagingData._(
    this._items,
    this.loadStates, 
    this._source,
  );
  
  /// Create empty [PagingData]
  static PagingData<T> empty<T>({
    CombinedLoadStates? loadStates,
  }) {
    return PagingData._(
      <T>[],
      loadStates ?? const CombinedLoadStates(
        refresh: LoadStateNotLoading(endOfPaginationReached: false),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: false),
      ),
      null,
    );
  }
  
  /// Create [PagingData] from a list of items
  static PagingData<T> fromList<T>(
    List<T> data, {
    CombinedLoadStates? loadStates,
  }) {
    return PagingData._(
      List.unmodifiable(data),
      loadStates ?? const CombinedLoadStates(
        refresh: LoadStateNotLoading(endOfPaginationReached: true),
        prepend: LoadStateNotLoading(endOfPaginationReached: true), 
        append: LoadStateNotLoading(endOfPaginationReached: true),
      ),
      null,
    );
  }
  
  /// Get item at [index], returns null if index is out of bounds or represents placeholder
  T? getItem(int index) {
    if (index < 0 || index >= _items.length) return null;
    return _items[index];
  }
  
  /// Total number of items, including placeholders
  int get itemCount => _items.length;
  
  /// Get all loaded items as an unmodifiable list
  List<T> get items => _items;
  
  /// Transform this [PagingData] by applying [transform] to each item
  PagingData<R> map<R>(R Function(T item) transform) {
    return PagingData._(
      _items.map(transform).toList(growable: false),
      loadStates,
      _source,
    );
  }
  
  /// Transform this [PagingData] by applying [transform] to each item asynchronously
  Future<PagingData<R>> mapAsync<R>(
    Future<R> Function(T item) transform,
  ) async {
    final transformedItems = await Future.wait(
      _items.map(transform),
    );
    
    return PagingData._(
      transformedItems,
      loadStates,
      _source,
    );
  }
  
  /// Filter this [PagingData] by applying [predicate] to each item
  PagingData<T> filter(bool Function(T item) predicate) {
    return PagingData._(
      _items.where(predicate).toList(growable: false),
      loadStates,
      _source,
    );
  }
  
  /// Insert [item] at [index] with separator handling
  PagingData<R> insertSeparators<R>({
    required R? Function(T? before, T? after) generator,
  }) {
    if (_items.isEmpty) {
      final separator = generator(null, null);
      return PagingData._(
        separator != null ? [separator] : [],
        loadStates,
        _source,
      );
    }
    
    final List<R> result = [];
    
    // Add separator before first item
    final beforeFirst = generator(null, _items.first);
    if (beforeFirst != null) result.add(beforeFirst);
    
    // Add items with separators between them
    for (int i = 0; i < _items.length; i++) {
      if (_items[i] is R) {
        result.add(_items[i] as R);
      }
      
      if (i < _items.length - 1) {
        final separator = generator(_items[i], _items[i + 1]);
        if (separator != null) result.add(separator);
      }
    }
    
    // Add separator after last item
    final afterLast = generator(_items.last, null);
    if (afterLast != null) result.add(afterLast);
    
    return PagingData._(
      result,
      loadStates,
      _source,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagingData<T> &&
          runtimeType == other.runtimeType &&
          _listEquals(_items, other._items) &&
          loadStates == other.loadStates;

  @override
  int get hashCode => Object.hash(_items, loadStates);
  
  @override
  String toString() => 'PagingData(${_items.length} items, $loadStates)';
  
  bool _listEquals<E>(List<E> a, List<E> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Internal source tracking for [PagingData]
abstract class PagingDataSource {}

/// Event types for [PagingData] updates
abstract class PagingDataEvent<T> {}

/// Event indicating data has been refreshed
class PagingDataRefresh<T> extends PagingDataEvent<T> {
  final PagingData<T> data;
  PagingDataRefresh(this.data);
}

/// Event indicating data has been prepended
class PagingDataPrepend<T> extends PagingDataEvent<T> {
  final List<T> data;
  PagingDataPrepend(this.data);
}

/// Event indicating data has been appended  
class PagingDataAppend<T> extends PagingDataEvent<T> {
  final List<T> data;
  PagingDataAppend(this.data);
}

/// Event indicating load state has changed
class PagingDataLoadState<T> extends PagingDataEvent<T> {
  final CombinedLoadStates loadStates;
  PagingDataLoadState(this.loadStates);
}