/// Legacy Pager API - DEPRECATED
/// 
/// This is the original Pager API from v0.x. It's deprecated in favor of the new
/// Paging3 API but remains available for backwards compatibility.
/// 
/// **DEPRECATED**: Please migrate to the new API:
/// ```dart
/// import 'package:pager/paging3/paging3.dart';
/// ```
/// 
/// For migration guidance, see: MIGRATION.md
library pager_legacy;

// Re-export the old API for backwards compatibility
export 'pager.dart' show Pager, PagingBuilder;
export 'paging/paging_source.dart';
export 'paging/paging_data.dart';
export 'paging/load_state.dart';
export 'paging/load_states.dart';
export 'paging/combined_load_state.dart';
export 'paging/page_config.dart';
export 'paging/paging_state.dart';
export 'paging/remote_mediator.dart';
export 'paging/helper/abstract_remote_mediator.dart';
export 'paging/helper/abstract_data_remote_mediator.dart';