import 'package:flutter_test/flutter_test.dart';
import 'package:pager/paging3/paging3.dart';

void main() {
  group('LoadState', () {
    group('LoadStateNotLoading', () {
      test('should have correct properties', () {
        const loadState = LoadStateNotLoading(endOfPaginationReached: true);
        
        expect(loadState.endOfPaginationReached, isTrue);
        expect(loadState.isCompleted, isTrue);
        expect(loadState.isError, isFalse);
        expect(loadState.isLoading, isFalse);
        expect(loadState.isNotLoadingIncomplete, isFalse);
      });
      
      test('should handle incomplete state', () {
        const loadState = LoadStateNotLoading(endOfPaginationReached: false);
        
        expect(loadState.endOfPaginationReached, isFalse);
        expect(loadState.isCompleted, isFalse);
        expect(loadState.isNotLoadingIncomplete, isTrue);
      });
      
      test('should compare equality correctly', () {
        const state1 = LoadStateNotLoading(endOfPaginationReached: true);
        const state2 = LoadStateNotLoading(endOfPaginationReached: true);
        const state3 = LoadStateNotLoading(endOfPaginationReached: false);
        
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
      
      test('should have correct string representation', () {
        const loadState = LoadStateNotLoading(endOfPaginationReached: true);
        
        expect(loadState.toString(), 
            'LoadState.NotLoading(endOfPaginationReached=true)');
      });
    });
    
    group('LoadStateLoading', () {
      test('should have correct properties', () {
        const loadState = LoadStateLoading();
        
        expect(loadState.isLoading, isTrue);
        expect(loadState.isCompleted, isFalse);
        expect(loadState.isError, isFalse);
        expect(loadState.isNotLoadingIncomplete, isFalse);
      });
      
      test('should compare equality correctly', () {
        const state1 = LoadStateLoading();
        const state2 = LoadStateLoading();
        
        expect(state1, equals(state2));
      });
      
      test('should have correct string representation', () {
        const loadState = LoadStateLoading();
        
        expect(loadState.toString(), 'LoadState.Loading');
      });
    });
    
    group('LoadStateError', () {
      test('should have correct properties', () {
        final exception = Exception('Test error');
        final loadState = LoadStateError(exception);
        
        expect(loadState.error, exception);
        expect(loadState.isError, isTrue);
        expect(loadState.isLoading, isFalse);
        expect(loadState.isCompleted, isFalse);
        expect(loadState.isNotLoadingIncomplete, isFalse);
      });
      
      test('should compare equality correctly', () {
        final exception1 = Exception('Test error');
        final exception3 = Exception('Different error');
        
        final state1 = LoadStateError(exception1);
        final state2 = LoadStateError(exception1);
        final state3 = LoadStateError(exception3);
        
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
      
      test('should have correct string representation', () {
        final exception = Exception('Test error');
        final loadState = LoadStateError(exception);
        
        expect(loadState.toString(), 
            'LoadState.Error(Exception: Test error)');
      });
    });
  });
  
  group('CombinedLoadStates', () {
    test('should initialize correctly', () {
      const states = CombinedLoadStates(
        refresh: LoadStateLoading(),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      expect(states.refresh, isA<LoadStateLoading>());
      expect(states.prepend, isA<LoadStateNotLoading>());
      expect(states.append, isA<LoadStateNotLoading>());
      expect(states.source, equals(states.refresh));
      expect(states.mediator, isNull);
    });
    
    test('should handle custom source state', () {
      const customSource = LoadStateNotLoading(endOfPaginationReached: true);
      const states = CombinedLoadStates(
        refresh: LoadStateLoading(),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
        source: customSource,
      );
      
      expect(states.source, equals(customSource));
      expect(states.source, isNot(equals(states.refresh)));
    });
    
    test('should detect loading state correctly', () {
      const loadingStates = CombinedLoadStates(
        refresh: LoadStateLoading(),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      const notLoadingStates = CombinedLoadStates(
        refresh: LoadStateNotLoading(endOfPaginationReached: false),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      expect(loadingStates.isLoading, isTrue);
      expect(notLoadingStates.isLoading, isFalse);
    });
    
    test('should detect error state correctly', () {
      final exception = Exception('Test error');
      final errorStates = CombinedLoadStates(
        refresh: LoadStateNotLoading(endOfPaginationReached: false),
        prepend: LoadStateError(exception),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      const noErrorStates = CombinedLoadStates(
        refresh: LoadStateNotLoading(endOfPaginationReached: false),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      expect(errorStates.hasError, isTrue);
      expect(noErrorStates.hasError, isFalse);
    });
    
    test('should compare equality correctly', () {
      const states1 = CombinedLoadStates(
        refresh: LoadStateLoading(),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      const states2 = CombinedLoadStates(
        refresh: LoadStateLoading(),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      const states3 = CombinedLoadStates(
        refresh: LoadStateNotLoading(endOfPaginationReached: false),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      expect(states1, equals(states2));
      expect(states1, isNot(equals(states3)));
    });
    
    test('should have correct string representation', () {
      const states = CombinedLoadStates(
        refresh: LoadStateLoading(),
        prepend: LoadStateNotLoading(endOfPaginationReached: false),
        append: LoadStateNotLoading(endOfPaginationReached: true),
      );
      
      final string = states.toString();
      
      expect(string, contains('CombinedLoadStates'));
      expect(string, contains('refresh=LoadState.Loading'));
      expect(string, contains('prepend=LoadState.NotLoading(endOfPaginationReached=false)'));
      expect(string, contains('append=LoadState.NotLoading(endOfPaginationReached=true)'));
    });
  });
}