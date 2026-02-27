import 'package:test/test.dart';

// Import core components directly to avoid Flutter dependencies
import 'package:pager/paging3/paging_source.dart';
import 'package:pager/paging3/load_state.dart';
import 'package:pager/paging3/paging_data.dart';

// Import legacy components directly
import 'package:pager/paging/paging_data.dart' as legacy_data;
import 'package:pager/paging/load_state.dart' as legacy_load;
import 'package:pager/paging/page_config.dart' as legacy_config;

void main() {
  group('Core API Access Tests', () {
    test('Paging3 core components should work', () {
      // Test that we can create Paging3 components
      const config = PagingConfig(pageSize: 20);
      expect(config.pageSize, 20);
      expect(config.initialLoadSize, 60); // Default is 3 * pageSize
      
      // Test load states
      const loadState = LoadStateLoading();
      expect(loadState.isLoading, isTrue);
      expect(loadState.isError, isFalse);
      expect(loadState.isCompleted, isFalse);
      
      // Test PagingData creation
      final pagingData = PagingData.empty<String>();
      expect(pagingData.itemCount, 0);
      expect(pagingData.items.isEmpty, isTrue);
    });
    
    test('Legacy core components should work', () {
      // Test legacy page creation with correct parameters  
      final legacyPage = legacy_data.Page<int, String>(['item1', 'item2'], 0, 1);
      expect(legacyPage.data.length, 2);
      expect(legacyPage.data.first, 'item1');
      expect(legacyPage.prevKey, 0);
      expect(legacyPage.nextKey, 1);
      expect(legacyPage.isEmpty(), isFalse);
      
      // Test legacy load states
      final legacyLoadState = legacy_load.NotLoading(true);
      expect(legacyLoadState.endOfPaginationReached, isTrue);
      
      // Test legacy paging data
      final legacyPagingData = legacy_data.PagingData<String>(['test1', 'test2']);
      expect(legacyPagingData.data.length, 2);
      expect(legacyPagingData.data.first, 'test1');
    });
    
    test('APIs should have different implementations', () {
      // Create instances of both config types
      const paging3Config = PagingConfig(pageSize: 20);
      final legacyConfig = legacy_config.PagingConfig(pageSize: 20);
      
      // Both should work correctly with same interface
      expect(paging3Config.pageSize, 20);
      expect(legacyConfig.pageSize, 20);
      
      // Paging3 has additional fields
      expect(paging3Config.initialLoadSize, 60); // 3 * pageSize
      expect(paging3Config.prefetchDistance, 20); // same as pageSize
      
      // Legacy has different defaults
      expect(legacyConfig.initialPageSize, 15); // legacy default
    });

    test('Load states should work correctly in both APIs', () {
      // Paging3 load states
      const paging3Loading = LoadStateLoading();
      const paging3NotLoading = LoadStateNotLoading(endOfPaginationReached: true);
      final paging3Error = LoadStateError(Exception('Test error'));
      
      expect(paging3Loading.isLoading, isTrue);
      expect(paging3NotLoading.isCompleted, isTrue);
      expect(paging3Error.isError, isTrue);
      
      // Legacy load states  
      final legacyNotLoading = legacy_load.NotLoading(true);
      final legacyLoading = legacy_load.Loading();
      final legacyError = legacy_load.Error(Exception('Test error'));
      
      expect(legacyNotLoading.endOfPaginationReached, isTrue);
      expect(legacyLoading.endOfPaginationReached, isFalse);
      expect(legacyError.exception.toString(), contains('Test error'));
    });
    
    test('PagingData transformations should work', () {
      // Test Paging3 PagingData transformations
      final pagingData = PagingData.fromList(['1', '2', '3']);
      final mappedData = pagingData.map((item) => int.parse(item));
      final filteredData = mappedData.filter((item) => item > 1);
      
      expect(mappedData.items, [1, 2, 3]);
      expect(filteredData.items, [2, 3]);
      expect(filteredData.itemCount, 2);
    });
  });
}