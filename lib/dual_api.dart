// Dual API Access Library
library dual_api;

// Export Paging3 API as the primary API
export 'paging3/paging3.dart';

// Import legacy API with prefix for typedef access
import 'paging/paging_data.dart' as legacy_data;
import 'paging/load_state.dart' as legacy_load;
import 'paging/load_states.dart' as legacy_states;
import 'paging/paging_source.dart' as legacy_source;
import 'paging/page_config.dart' as legacy_config;

// Legacy classes with Legacy prefix
typedef LegacyPagingSource<Key, Value> = legacy_source.PagingSource<Key, Value>;
typedef LegacyPage<Key, Value> = legacy_data.Page<Key, Value>;
typedef LegacyPagingData<T> = legacy_data.PagingData<T>;
typedef LegacyLoadState = legacy_load.LoadState;
typedef LegacyNotLoading = legacy_load.NotLoading;
typedef LegacyLoading = legacy_load.Loading;  
typedef LegacyError = legacy_load.Error;
typedef LegacyLoadStates = legacy_states.LoadStates;
typedef LegacyPagingConfig = legacy_config.PagingConfig;

// Usage Examples:
//
// For new projects using Paging3:
// ```dart
// import 'package:pager/dual_api.dart';
// 
// final pager = Pager<int, String>(
//   config: PagingConfig(pageSize: 20),
//   pagingSourceFactory: () => MyPagingSource(),
// );
// ```
//
// For accessing legacy functionality:
// ```dart
// import 'package:pager/dual_api.dart';
//
// final legacySource = LegacyPagingSource<int, String>(
//   localSource: (params) => myLegacyDataSource(params),
// );
// final legacyState = LegacyNotLoading(true);
// final legacyPage = LegacyPage<int, String>(['item1', 'item2'], 0, 1);
// ```
//
// Alternative approach - Use specific imports:
// ```dart
// // For Paging3 only
// import 'package:pager/paging3/paging3.dart';
//
// // For legacy only  
// import 'package:pager/pager_legacy.dart';
// ```