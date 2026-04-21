import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';

import 'package:pager/paging/paging_data.dart';
import 'package:pager/paging/paging_source.dart';

class _Transaction {
  final String date;
  final String name;
  _Transaction(this.date, this.name);
}

class _DateGroup extends PageGroupData<String, _Transaction> {
  _DateGroup({required String key, required List<_Transaction> items})
      : super(key: key, items: items);
}

void main() {
  testWidgets(
      "groupBy merges page-boundary groups without dropping remaining groups",
      (tester) async {
    // Page 1: Jan1(tx1,tx2), Jan2(tx3)          nextKey=1
    // Page 2: Jan2(tx4),     Jan3(tx5,tx6)       nextKey=null
    //
    // Expected after merge: 3 groups
    //   Jan1 → [tx1, tx2]
    //   Jan2 → [tx3, tx4]   ← merged across boundary
    //   Jan3 → [tx5, tx6]   ← must NOT be dropped
    final source = PagingSource<int, _Transaction>(
      localSource: (params) {
        if (params.key == null) {
          return Stream.value(Page(
            [
              _Transaction('Jan1', 'tx1'),
              _Transaction('Jan1', 'tx2'),
              _Transaction('Jan2', 'tx3'),
            ],
            null,
            1,
          ));
        } else {
          return Stream.value(Page(
            [
              _Transaction('Jan2', 'tx4'),
              _Transaction('Jan3', 'tx5'),
              _Transaction('Jan3', 'tx6'),
            ],
            1,
            null,
          ));
        }
      },
    ).groupBy<String, _DateGroup>(
      (tx) => tx.date,
      (key, items) => _DateGroup(key: key, items: items),
    );

    final controller = PagerController<int, _DateGroup>(source: source);
    addTearDown(controller.dispose);

    controller.initialize();
    await tester.pumpAndSettle();

    expect(controller.items.length, 2,
        reason: 'first page should have 2 groups before append');

    // Scroll near the end to trigger the append load.
    controller.onScrollPositionChanged(100, 101);
    await tester.pumpAndSettle();

    final groups = controller.items.cast<_DateGroup>();
    expect(groups.length, 3,
        reason: 'Jan3 group must not be dropped after page-boundary merge');
    expect(groups[0].key, 'Jan1');
    expect(groups[0].items.length, 2);
    expect(groups[1].key, 'Jan2');
    expect(groups[1].items.length, 2, reason: 'Jan2 items should be merged');
    expect(groups[2].key, 'Jan3');
    expect(groups[2].items.length, 2);
  });

  testWidgets(
      "groupBy with only one group spanning a page boundary produces no duplicates",
      (tester) async {
    // Page 1: Jan1(tx1,tx2)   nextKey=1
    // Page 2: Jan1(tx3,tx4)   nextKey=null  ← entirely same group as page 1
    //
    // Expected: 1 group, Jan1 → [tx1, tx2, tx3, tx4]
    final source = PagingSource<int, _Transaction>(
      localSource: (params) {
        if (params.key == null) {
          return Stream.value(Page(
            [_Transaction('Jan1', 'tx1'), _Transaction('Jan1', 'tx2')],
            null,
            1,
          ));
        } else {
          return Stream.value(Page(
            [_Transaction('Jan1', 'tx3'), _Transaction('Jan1', 'tx4')],
            1,
            null,
          ));
        }
      },
    ).groupBy<String, _DateGroup>(
      (tx) => tx.date,
      (key, items) => _DateGroup(key: key, items: items),
    );

    final controller = PagerController<int, _DateGroup>(source: source);
    addTearDown(controller.dispose);

    controller.initialize();
    await tester.pumpAndSettle();

    controller.onScrollPositionChanged(100, 101);
    await tester.pumpAndSettle();

    final groups = controller.items.cast<_DateGroup>();
    expect(groups.length, 1, reason: 'single spanning group should not duplicate');
    expect(groups[0].key, 'Jan1');
    expect(groups[0].items.length, 4);
  });
}
