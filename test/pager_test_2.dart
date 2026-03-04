import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';

void main() {
  testWidgets('emptyBuilder is shown when source emits an empty page',
      (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) => Stream.value(Page([], null, null)));

    await tester.pumpWidget(MaterialApp(
      home: Pager(
          source: source,
          emptyBuilder: (_) => const Text('empty'),
          builder: (ctx, d) => const SizedBox()),
    ));

    // Allow microtasks and stream events to settle
    await tester.pump();
    await tester.pump();

    expect(find.text('empty'), findsOneWidget);
  });

  testWidgets('PagerController.refresh resets state', (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['A', 'B'], null, 1)]));

    final controller = PagerController<int, String>(source: source);
    controller.initialize();

    await tester.pump();
    await tester.pump();

    // Trigger refresh without awaiting; pump lets the internal microtasks run
    controller.refresh();
    await tester.pump();
    await tester.pump();

    // Controller should not be in error state
    expect(controller.loadStates?.refresh, isNot(isA<Error>()));
    controller.dispose();
  });

  testWidgets('PagingSource.groupBy groups items correctly', (tester) async {
    final source = PagingSource<int, String>(
            localSource: (a) => Stream.fromIterable([
                  Page(['apple', 'avocado', 'banana'], null, 1)
                ]))
        .groupBy<String, _TestGroup>(
          (item) => item[0].toUpperCase(),
          (key, items) => _TestGroup(key: key, items: items),
        );

    PagingData<_TestGroup>? lastData;

    await tester.pumpWidget(Pager<int, _TestGroup>(
        source: source,
        builder: (ctx, d) {
          lastData = d;
          return const SizedBox();
        }));

    await tester.pump();
    await tester.pump();

    // Should have grouped: A→[apple, avocado], B→[banana]
    expect(lastData?.data, isNotNull);
    expect(lastData?.data.length, 2);
    expect(lastData?.data.first.key, 'A');
    expect(lastData?.data.first.items.length, 2);
  });

  testWidgets('PagerController exposes totalItems', (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['X', 'Y', 'Z'], null, 1)]));

    final controller = PagerController<int, String>(source: source);
    controller.initialize();

    await tester.pump();
    await tester.pump();

    expect(controller.totalItems, 3);
    expect(controller.items.length, 3);
    controller.dispose();
  });

  testWidgets('PagingData convenience flags reflect load state',
      (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['A'], null, 1)]));

    PagingData<String>? lastData;

    await tester.pumpWidget(Pager<int, String>(
        source: source,
        builder: (ctx, d) {
          lastData = d;
          return const SizedBox();
        }));

    await tester.pump();
    await tester.pump();

    expect(lastData?.data, isNotNull);
    expect(lastData?.isLoading, false);
    expect(lastData?.isEmpty, false);
    expect(lastData?.hasError, false);
    expect(lastData?.totalItems, 1);
  });
}

class _TestGroup extends PageGroupData<String, String> {
  _TestGroup({required String key, required List<String> items})
      : super(key: key, items: items);
}
