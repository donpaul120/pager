import 'dart:developer';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';
import 'package:pager/paging/paging_data.dart';
import 'package:pager/paging/paging_source.dart';

void main() {
  group('Legacy Pager Sorting Tests', () {
    testWidgets('should sort string data in ascending order when PagingSource has sort modifier', (tester) async {
      // Arrange
      final source = PagingSource<int, String>(
        localSource: (params) => Stream.fromIterable([
          Page(["B", "A", "C"], 0, 1)
        ])
      ).sort((a, b) => a.compareTo(b));

      final pager = Pager(
        source: source,
        builder: (context, pagingData) {
          log('PagingData received: ${pagingData.data}');
          return MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: pagingData.data.length,
                itemBuilder: (context, index) {
                  return Text('item_${pagingData.data[index]}');
                },
              ),
            ),
          );
        },
      );

      // Act
      await tester.pumpWidget(pager);
      await tester.pump(); // Allow for async operations
      await tester.pumpAndSettle(); // Wait for all animations to complete

      // Assert
      expect(find.text('item_A'), findsOneWidget);
      expect(find.text('item_B'), findsOneWidget);
      expect(find.text('item_C'), findsOneWidget);
      
      // Verify sorting order by checking widget positions
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      final sortedTexts = textWidgets.map((w) => w.data).where((d) => d?.startsWith('item_') == true).toList();
      
      expect(sortedTexts, ['item_A', 'item_B', 'item_C'], 
        reason: 'Items should be sorted in ascending order');
    });

    testWidgets('should sort numeric data in descending order when custom comparator is provided', (tester) async {
      // Arrange
      final source = PagingSource<int, int>(
        localSource: (params) => Stream.fromIterable([
          Page([1, 3, 2], 0, 1)
        ])
      ).sort((a, b) => b.compareTo(a)); // Descending order

      final pager = Pager(
        source: source,
        builder: (context, pagingData) {
          return MaterialApp(
            home: Scaffold(
              body: Column(
                children: pagingData.data.map((item) => Text('number_$item')).toList(),
              ),
            ),
          );
        },
      );

      // Act
      await tester.pumpWidget(pager);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('number_1'), findsOneWidget);
      expect(find.text('number_2'), findsOneWidget);
      expect(find.text('number_3'), findsOneWidget);
      
      // Verify descending order
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      final numberTexts = textWidgets.map((w) => w.data).where((d) => d?.startsWith('number_') == true).toList();
      
      expect(numberTexts, ['number_3', 'number_2', 'number_1'],
        reason: 'Numbers should be sorted in descending order');
    });

    testWidgets('should handle empty data gracefully', (tester) async {
      // Arrange
      final source = PagingSource<int, String>(
        localSource: (params) => Stream.fromIterable([
          Page(<String>[], 0, null) // Empty page
        ])
      ).sort((a, b) => a.compareTo(b));

      final pager = Pager(
        source: source,
        builder: (context, pagingData) {
          return MaterialApp(
            home: Scaffold(
              body: pagingData.data.isEmpty 
                ? const Text('no_data')
                : ListView(
                    children: pagingData.data.map((item) => Text(item)).toList(),
                  ),
            ),
          );
        },
      );

      // Act
      await tester.pumpWidget(pager);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('no_data'), findsOneWidget);
    });
  });
}