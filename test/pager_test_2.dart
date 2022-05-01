import 'dart:developer';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';

import 'package:pager/paging/paging_data.dart';
import 'package:pager/paging/paging_source.dart';

void main() {

  testWidgets("", (tester) async {
    ///Arrange
    final source = PagingSource<int, String>(localSource: (a) => Stream.fromIterable([Page(["B", "A"], 0, 1)]))
        .sort((a, b) => a.compareTo(b));

    final pager = Pager(
        source: source,
        builder: (ctx, d) {
          log("$d");
          return const SizedBox();
        }
    );

    ///Act
    await tester.pumpWidget(pager);
    final sizeBox = find.byType(Text);

    ///Assert
  });


}
