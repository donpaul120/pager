import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';

import 'package:pager/paging/paging_data.dart';
import 'package:pager/paging/paging_source.dart';

void main() {

  testWidgets("Test that we can sort a paging source data", (tester) async {
    final source = PagingSource<int, String>(localSource: (a) => Stream.fromIterable([Page(["B", "A"], 0, 1)]))
        .sort((a, b) => a.compareTo(b))
        .forEach((a) {
          expect(a.first, equals("A"));
        });

    await tester.pumpWidget(Pager(
        source: source,
        builder: (ctx, d, da) {
          return const SizedBox();
        }
    ));
  });


  testWidgets("Test that we can filter out data in paging source", (tester) async {
    final source = PagingSource<int, String>(localSource: (a) => Stream.fromIterable([Page(["B", "A"], 0, 1)]))
        .filter((a) => a != "A")
        .forEach((a) {
          expect(a.first, equals("B"));
        });

    await tester.pumpWidget(Pager(
        source: source,
        builder: (ctx, d, da) {
          return const SizedBox();
        }
    ));
  });

  testWidgets("Test that we can find the nearest scrollView in the tree", (tester) async {
    final source = PagingSource<int, String>(localSource: (a) => Stream.fromIterable([Page(["B", "A"], 0, 1)]));

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Expanded(child: Pager(
                source: source,
                builder: (ctx, d, da) {
                  return SizedBox(
                      height: 100,
                      child: ListView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: 1,
                          itemBuilder: (a, b) => SizedBox.shrink()
                      )
                  );
                }
            ))
          ],
        ),
      )
    );

    final type = find.byType(ListView);
    expect(type, findsOneWidget);
  });

}
