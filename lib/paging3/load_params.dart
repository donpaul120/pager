/// Parameters for [PagingSource.load]
abstract class LoadParams<Key> {
  /// The key for the page to be loaded
  final Key? key;
  
  /// Requested number of items to load
  final int loadSize;
  
  /// Whether placeholders are enabled
  final bool placeholdersEnabled;
  
  const LoadParams({
    required this.key,
    required this.loadSize,
    required this.placeholdersEnabled,
  });
}

/// Parameters for an initial load or a refresh
class LoadParamsRefresh<Key> extends LoadParams<Key> {
  const LoadParamsRefresh({
    required Key? key,
    required int loadSize,
    required bool placeholdersEnabled,
  }) : super(
    key: key,
    loadSize: loadSize, 
    placeholdersEnabled: placeholdersEnabled,
  );
}

/// Parameters for appending data after the current dataset
class LoadParamsAppend<Key> extends LoadParams<Key> {
  const LoadParamsAppend({
    required Key key,
    required int loadSize,
    required bool placeholdersEnabled,
  }) : super(
    key: key,
    loadSize: loadSize,
    placeholdersEnabled: placeholdersEnabled,
  );
}

/// Parameters for prepending data before the current dataset
class LoadParamsPrepend<Key> extends LoadParams<Key> {
  const LoadParamsPrepend({
    required Key key,
    required int loadSize,
    required bool placeholdersEnabled,
  }) : super(
    key: key,
    loadSize: loadSize,
    placeholdersEnabled: placeholdersEnabled,
  );
}