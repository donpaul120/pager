import 'package:flutter_test/flutter_test.dart';
import 'package:pager/paging3/paging3.dart';

void main() {
  group('PagingData', () {
    group('construction', () {
      test('should create empty PagingData', () {
        final data = PagingData.empty<String>();
        
        expect(data.itemCount, 0);
        expect(data.items, isEmpty);
        expect(data.loadStates.refresh.isNotLoadingIncomplete, isTrue);
        expect(data.loadStates.append.isNotLoadingIncomplete, isTrue);
        expect(data.loadStates.prepend.isNotLoadingIncomplete, isTrue);
      });
      
      test('should create PagingData from list', () {
        final items = ['Item 0', 'Item 1', 'Item 2'];
        final data = PagingData.fromList(items);
        
        expect(data.itemCount, 3);
        expect(data.items, equals(items));
        expect(data.loadStates.refresh.isCompleted, isTrue);
        expect(data.loadStates.append.isCompleted, isTrue);
        expect(data.loadStates.prepend.isCompleted, isTrue);
      });
      
      test('should create PagingData with custom load states', () {
        const customStates = CombinedLoadStates(
          refresh: LoadStateLoading(),
          append: LoadStateNotLoading(endOfPaginationReached: false),
          prepend: LoadStateNotLoading(endOfPaginationReached: true),
        );
        
        final data = PagingData.fromList(['Item'], loadStates: customStates);
        
        expect(data.loadStates, equals(customStates));
      });
    });
    
    group('item access', () {
      test('should get items correctly', () {
        final items = ['Item 0', 'Item 1', 'Item 2'];
        final data = PagingData.fromList(items);
        
        expect(data.getItem(0), 'Item 0');
        expect(data.getItem(1), 'Item 1');
        expect(data.getItem(2), 'Item 2');
      });
      
      test('should return null for out-of-bounds indices', () {
        final data = PagingData.fromList(['Item 0']);
        
        expect(data.getItem(-1), isNull);
        expect(data.getItem(1), isNull);
        expect(data.getItem(100), isNull);
      });
      
      test('should return unmodifiable items list', () {
        final items = ['Item 0', 'Item 1', 'Item 2'];
        final data = PagingData.fromList(items);
        
        expect(() => data.items.add('New Item'), throwsUnsupportedError);
      });
    });
    
    group('transformations', () {
      test('should map items correctly', () {
        final data = PagingData.fromList([1, 2, 3]);
        final mapped = data.map((item) => 'Item $item');
        
        expect(mapped.itemCount, 3);
        expect(mapped.getItem(0), 'Item 1');
        expect(mapped.getItem(1), 'Item 2');
        expect(mapped.getItem(2), 'Item 3');
        expect(mapped.loadStates, equals(data.loadStates));
      });
      
      test('should filter items correctly', () {
        final data = PagingData.fromList([1, 2, 3, 4, 5]);
        final filtered = data.filter((item) => item.isEven);
        
        expect(filtered.itemCount, 2);
        expect(filtered.getItem(0), 2);
        expect(filtered.getItem(1), 4);
        expect(filtered.loadStates, equals(data.loadStates));
      });
      
      test('should map items asynchronously', () async {
        final data = PagingData.fromList([1, 2, 3]);
        final mapped = await data.mapAsync((item) async {
          await Future.delayed(const Duration(milliseconds: 1));
          return 'Item $item';
        });
        
        expect(mapped.itemCount, 3);
        expect(mapped.getItem(0), 'Item 1');
        expect(mapped.getItem(1), 'Item 2');
        expect(mapped.getItem(2), 'Item 3');
      });
      
      test('should insert separators correctly', () {
        final data = PagingData.fromList([1, 2, 3]);
        final withSeparators = data.insertSeparators<String>(
          generator: (before, after) {
            if (before == null) return 'Start';
            if (after == null) return 'End';
            return 'Sep';
          },
        );
        
        expect(withSeparators.itemCount, 6);
        expect(withSeparators.getItem(0), 'Start');
        expect(withSeparators.getItem(1), '1');
        expect(withSeparators.getItem(2), 'Sep');
        expect(withSeparators.getItem(3), '2');
        expect(withSeparators.getItem(4), 'Sep');
        expect(withSeparators.getItem(5), '3');
      });
      
      test('should handle empty data with separators', () {
        final data = PagingData.fromList<int>([]);
        final withSeparators = data.insertSeparators<String>(
          generator: (before, after) => 'Empty',
        );
        
        expect(withSeparators.itemCount, 1);
        expect(withSeparators.getItem(0), 'Empty');
      });
      
      test('should handle null separators', () {
        final data = PagingData.fromList([1, 2]);
        final withSeparators = data.insertSeparators<String>(
          generator: (before, after) => null,
        );
        
        expect(withSeparators.itemCount, 2);
        expect(withSeparators.getItem(0), '1');
        expect(withSeparators.getItem(1), '2');
      });
    });
    
    group('equality and hashing', () {
      test('should compare equality correctly', () {
        final data1 = PagingData.fromList([1, 2, 3]);
        final data2 = PagingData.fromList([1, 2, 3]);
        final data3 = PagingData.fromList([1, 2, 4]);
        
        expect(data1, equals(data2));
        expect(data1, isNot(equals(data3)));
      });
      
      test('should consider load states in equality', () {
        const states1 = CombinedLoadStates(
          refresh: LoadStateNotLoading(endOfPaginationReached: true),
          append: LoadStateNotLoading(endOfPaginationReached: true),
          prepend: LoadStateNotLoading(endOfPaginationReached: true),
        );
        
        const states2 = CombinedLoadStates(
          refresh: LoadStateLoading(),
          append: LoadStateNotLoading(endOfPaginationReached: true),
          prepend: LoadStateNotLoading(endOfPaginationReached: true),
        );
        
        final data1 = PagingData.fromList([1, 2], loadStates: states1);
        final data2 = PagingData.fromList([1, 2], loadStates: states2);
        
        expect(data1, isNot(equals(data2)));
      });
      
      test('should have consistent hash codes', () {
        final data1 = PagingData.fromList([1, 2, 3]);
        final data2 = PagingData.fromList([1, 2, 3]);
        
        expect(data1.hashCode, equals(data2.hashCode));
      });
    });
    
    group('string representation', () {
      test('should have meaningful toString', () {
        final data = PagingData.fromList([1, 2, 3]);
        final string = data.toString();
        
        expect(string, contains('PagingData'));
        expect(string, contains('3 items'));
        expect(string, contains('CombinedLoadStates'));
      });
    });
  });
}