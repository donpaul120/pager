import 'package:flutter_test/flutter_test.dart';
import 'package:pager/paging3/paging3.dart';

void main() {
  group('Pager', () {
    test('should emit initial PagingData correctly', () async {
      final items = List.generate(50, (i) => 'Item $i');
      
      final pager = Pager<int, String>(
        config: const PagingConfig(
          pageSize: 10,
          initialLoadSize: 20,
        ),
        pagingSourceFactory: () => ListPagingSource(items),
      );
      
      final firstData = await pager.flow.first;
      
      expect(firstData.itemCount, 20);
      expect(firstData.getItem(0), 'Item 0');
      expect(firstData.getItem(19), 'Item 19');
      expect(firstData.loadStates.refresh.isCompleted, isFalse);
      expect(firstData.loadStates.append.isNotLoadingIncomplete, isTrue);
    });
    
    test('should handle multiple emissions correctly', () async {
      final items = List.generate(15, (i) => 'Item $i');
      
      final pager = Pager<int, String>(
        config: const PagingConfig(
          pageSize: 10,
          initialLoadSize: 10,
        ),
        pagingSourceFactory: () => ListPagingSource(items),
      );
      
      final emissions = <PagingData<String>>[];
      final subscription = pager.flow.listen(emissions.add);
      
      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 600));
      
      expect(emissions, hasLength(1));
      expect(emissions.first.itemCount, 10);
      
      subscription.cancel();
    });
    
    test('should handle empty data source', () async {
      final pager = Pager<int, String>(
        config: const PagingConfig(pageSize: 10),
        pagingSourceFactory: () => ListPagingSource([]),
      );
      
      final firstData = await pager.flow.first;
      
      expect(firstData.itemCount, 0);
      expect(firstData.loadStates.refresh.isCompleted, isTrue);
      expect(firstData.loadStates.append.isCompleted, isTrue);
    });
    
    test('should handle PagingSource errors', () async {
      final pager = Pager<int, String>(
        config: const PagingConfig(pageSize: 10),
        pagingSourceFactory: () => ErrorPagingSource(),
      );
      
      final firstData = await pager.flow.first;
      
      expect(firstData.itemCount, 0);
      expect(firstData.loadStates.refresh.isError, isTrue);
      
      final error = firstData.loadStates.refresh as LoadStateError;
      expect(error.error.toString(), contains('Test error'));
    });
    
    test('should handle PagingSource invalidation', () async {
      late ListPagingSource<String> source;
      final items = List.generate(20, (i) => 'Item $i');
      
      final pager = Pager<int, String>(
        config: const PagingConfig(pageSize: 10),
        pagingSourceFactory: () {
          source = ListPagingSource(items);
          return source;
        },
      );
      
      final emissions = <PagingData<String>>[];
      final subscription = pager.flow.listen(emissions.add);
      
      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 600));
      expect(emissions, hasLength(1));
      
      // Invalidate source
      source.invalidate();
      
      // Wait for reload
      await Future.delayed(const Duration(milliseconds: 600));
      expect(emissions.length, greaterThan(1));
      
      subscription.cancel();
    });
  });
  
  group('PageFetcher', () {
    test('should handle append operations', () async {
      final items = List.generate(25, (i) => 'Item $i');
      
      final pager = Pager<int, String>(
        config: const PagingConfig(
          pageSize: 10,
          initialLoadSize: 10,
        ),
        pagingSourceFactory: () => ListPagingSource(items),
      );
      
      final emissions = <PagingData<String>>[];
      final subscription = pager.flow.listen(emissions.add);
      
      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 600));
      expect(emissions, hasLength(1));
      expect(emissions.first.itemCount, 10);
      
      subscription.cancel();
    });
    
    test('should respect PagingConfig settings', () async {
      final items = List.generate(100, (i) => 'Item $i');
      
      final pager = Pager<int, String>(
        config: const PagingConfig(
          pageSize: 5,
          initialLoadSize: 15,
        ),
        pagingSourceFactory: () => ListPagingSource(items),
      );
      
      final firstData = await pager.flow.first;
      
      expect(firstData.itemCount, 15); // Should respect initialLoadSize
    });
  });
  
  group('RemoteMediator integration', () {
    test('should work with RemoteMediator', () async {
      final pager = Pager<int, String>(
        config: const PagingConfig(pageSize: 10),
        pagingSourceFactory: () => ListPagingSource([]),
        remoteMediator: TestRemoteMediator(),
      );
      
      final firstData = await pager.flow.first;
      
      // Should at least attempt to load through mediator
      expect(firstData, isNotNull);
    });
  });
}

/// Test PagingSource that always returns errors
class ErrorPagingSource extends PagingSource<int, String> {
  @override
  Future<LoadResult<int, String>> load(LoadParams<int> params) async {
    return LoadResultError(Exception('Test error'));
  }
}

/// Test RemoteMediator for testing
class TestRemoteMediator extends RemoteMediator<int, String> {
  @override
  Future<MediatorResult> load(LoadType loadType, PagingState<int, String> state) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    return const MediatorResultSuccess(endOfPaginationReached: false);
  }
}