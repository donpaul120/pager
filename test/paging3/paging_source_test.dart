import 'package:flutter_test/flutter_test.dart';
import 'package:pager/paging3/paging3.dart';

void main() {
  group('ListPagingSource', () {
    test('should load initial page correctly', () async {
      final items = List.generate(20, (i) => 'Item $i');
      final source = ListPagingSource(items);
      
      final params = LoadParamsRefresh<int>(
        key: null,
        loadSize: 10,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int, String>>());
      final page = result as LoadResultPage<int, String>;
      
      expect(page.data, hasLength(10));
      expect(page.data.first, 'Item 0');
      expect(page.data.last, 'Item 9');
      expect(page.prevKey, isNull);
      expect(page.nextKey, 1);
      expect(page.itemsBefore, 0);
      expect(page.itemsAfter, 10);
    });
    
    test('should load subsequent pages correctly', () async {
      final items = List.generate(25, (i) => 'Item $i');
      final source = ListPagingSource(items);
      
      final params = LoadParamsAppend<int>(
        key: 1,
        loadSize: 10,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int, String>>());
      final page = result as LoadResultPage<int, String>;
      
      expect(page.data, hasLength(10));
      expect(page.data.first, 'Item 10');
      expect(page.data.last, 'Item 19');
      expect(page.prevKey, 0);
      expect(page.nextKey, 2);
      expect(page.itemsBefore, 10);
      expect(page.itemsAfter, 5);
    });
    
    test('should handle last page correctly', () async {
      final items = List.generate(25, (i) => 'Item $i');
      final source = ListPagingSource(items);
      
      final params = LoadParamsAppend<int>(
        key: 2,
        loadSize: 10,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int, String>>());
      final page = result as LoadResultPage<int, String>;
      
      expect(page.data, hasLength(5));
      expect(page.data.first, 'Item 20');
      expect(page.data.last, 'Item 24');
      expect(page.prevKey, 1);
      expect(page.nextKey, isNull);
      expect(page.itemsBefore, 20);
      expect(page.itemsAfter, 0);
    });
    
    test('should handle empty list', () async {
      final source = ListPagingSource<String>([]);
      
      final params = LoadParamsRefresh<int>(
        key: null,
        loadSize: 10,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int, String>>());
      final page = result as LoadResultPage<int, String>;
      
      expect(page.data, isEmpty);
      expect(page.prevKey, isNull);
      expect(page.nextKey, isNull);
    });
    
    test('should generate correct refresh key', () {
      final items = List.generate(50, (i) => 'Item $i');
      final source = ListPagingSource(items);
      
      final state = PagingState<int, String>(
        pages: [],
        anchorPosition: 25,
        config: const PagingConfig(pageSize: 10),
      );
      
      final refreshKey = source.getRefreshKey(state);
      expect(refreshKey, 2); // 25 / 10 = 2
    });
  });
  
  group('PagingSource invalidation', () {
    test('should emit invalidation event', () async {
      final source = ListPagingSource<String>([]);
      
      final future = source.invalidatedStream.first;
      source.invalidate();
      
      await expectLater(future, completes);
      expect(source.invalid, isTrue);
    });
    
    test('should handle multiple invalidations', () async {
      final source = ListPagingSource<String>([]);
      
      int eventCount = 0;
      final subscription = source.invalidatedStream.listen((_) {
        eventCount++;
      });
      
      source.invalidate();
      source.invalidate();
      source.invalidate();
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(eventCount, 3);
      expect(source.invalid, isTrue);
      
      subscription.cancel();
    });
  });
  
  group('OffsetPagingSource', () {
    test('should handle offset-based pagination', () async {
      final source = OffsetPagingSource<String>(
        loader: (offset, limit) async {
          final items = List.generate(limit, (i) => 'Item ${offset + i}');
          await Future.delayed(const Duration(milliseconds: 10));
          return items;
        },
      );
      
      final params = LoadParamsRefresh<int>(
        key: null,
        loadSize: 5,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int, String>>());
      final page = result as LoadResultPage<int, String>;
      
      expect(page.data, hasLength(5));
      expect(page.data.first, 'Item 0');
      expect(page.data.last, 'Item 4');
      expect(page.prevKey, isNull);
      expect(page.nextKey, 5);
    });
    
    test('should handle loader errors', () async {
      final source = OffsetPagingSource<String>(
        loader: (offset, limit) async {
          throw Exception('Network error');
        },
      );
      
      final params = LoadParamsRefresh<int>(
        key: null,
        loadSize: 5,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultError<int, String>>());
      final error = result as LoadResultError<int, String>;
      
      expect(error.exception.toString(), contains('Network error'));
    });
  });
  
  group('CursorPagingSource', () {
    test('should handle cursor-based pagination', () async {
      final source = CursorPagingSource<String, int>(
        loader: (cursor, limit) async {
          final start = cursor ?? 0;
          final data = List.generate(limit, (i) => 'Item ${start + i}');
          final hasNext = start + limit < 50; // Simulate 50 total items
          
          return CursorPage(
            data: data,
            hasNextPage: hasNext,
            nextCursor: hasNext ? start + limit : null,
          );
        },
        getCursor: (item) {
          final parts = item.split(' ');
          return int.parse(parts.last);
        },
      );
      
      final params = LoadParamsRefresh<int?>(
        key: null,
        loadSize: 10,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int?, String>>());
      final page = result as LoadResultPage<int?, String>;
      
      expect(page.data, hasLength(10));
      expect(page.data.first, 'Item 0');
      expect(page.data.last, 'Item 9');
      expect(page.prevKey, isNull);
      expect(page.nextKey, 9); // Cursor of last item
    });
    
    test('should handle end of data correctly', () async {
      final source = CursorPagingSource<String, int>(
        loader: (cursor, limit) async {
          return const CursorPage<String, int>(
            data: [],
            hasNextPage: false,
            nextCursor: null,
          );
        },
        getCursor: (item) => 0,
      );
      
      final params = LoadParamsAppend<int?>(
        key: 45,
        loadSize: 10,
        placeholdersEnabled: true,
      );
      
      final result = await source.load(params);
      
      expect(result, isA<LoadResultPage<int?, String>>());
      final page = result as LoadResultPage<int?, String>;
      
      expect(page.data, isEmpty);
      expect(page.nextKey, isNull);
    });
  });
}