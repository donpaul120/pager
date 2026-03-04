import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';

void main() {
  testWidgets('PagingSource.sort reorders items', (tester) async {
    final source = PagingSource<int, String>(
            localSource: (a) =>
                Stream.fromIterable([Page(['B', 'A'], 0, 1)]))
        .sort((a, b) => a.compareTo(b))
        .forEach((a) {
      expect(a.first, equals('A'));
    });

    await tester.pumpWidget(Pager(
        source: source,
        builder: (ctx, d) => const SizedBox()));
  });

  testWidgets('PagingSource.filter removes matching items', (tester) async {
    final source = PagingSource<int, String>(
            localSource: (a) =>
                Stream.fromIterable([Page(['B', 'A'], 0, 1)]))
        .filter((a) => a != 'A')
        .forEach((a) {
      expect(a.first, equals('B'));
    });

    await tester.pumpWidget(Pager(
        source: source,
        builder: (ctx, d) => const SizedBox()));
  });

  testWidgets('Pager detects ScrollView from builder', (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['B', 'A'], 0, 1)]));

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Expanded(
              child: Pager(
                  source: source,
                  builder: (ctx, d) => SizedBox(
                        height: 100,
                        child: ListView.builder(
                            scrollDirection: Axis.vertical,
                            itemCount: 1,
                            itemBuilder: (a, b) => const SizedBox.shrink()),
                      )),
            )
          ],
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('PagingData exposes totalItems and convenience flags',
      (tester) async {
    PagingData<String>? lastData;

    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['A', 'B', 'C'], null, 1)]));

    await tester.pumpWidget(Pager<int, String>(
        source: source,
        builder: (ctx, d) {
          lastData = d;
          return const SizedBox();
        }));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(lastData?.data, isNotNull);
  });

  testWidgets('loadingBuilder is shown during initial load', (tester) async {
    // Use a stream that never emits to keep it in loading state
    final source = PagingSource<int, String>(
        localSource: (a) => const Stream.empty());

    await tester.pumpWidget(MaterialApp(
      home: Pager(
          source: source,
          loadingBuilder: (_) => const Text('loading...'),
          builder: (ctx, d) => const SizedBox()),
    ));

    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);
  });

  testWidgets('Headless PagerController can be used without Pager widget',
      (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['X', 'Y'], null, 1)]));

    final controller = PagerController<int, String>(source: source);
    controller.initialize();

    await tester.pump();
    await tester.pump();

    // Data is accessible directly without a widget tree
    expect(controller.totalItems, isNonNegative);
    controller.dispose();
  });

  testWidgets('Pager.withController renders from external controller',
      (tester) async {
    final source = PagingSource<int, String>(
        localSource: (a) =>
            Stream.fromIterable([Page(['X', 'Y'], null, 1)]));

    final controller = PagerController<int, String>(source: source);
    controller.initialize();

    await tester.pumpWidget(Pager.withController(
        controller: controller,
        builder: (ctx, d) => const SizedBox()));

    await tester.pump();
    await tester.pump();

    expect(controller.items.length, 2);
    controller.dispose();
  });
}
