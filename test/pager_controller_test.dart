import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pager/pager.dart';

/// Builds page [p] of [totalPages]: 3 items per page, page-number keys.
/// prevKey/nextKey are null at the respective boundaries.
Page<int, String> pageAt(int p, int totalPages) => Page(
      List.generate(3, (i) => 'item${p * 3 + i}'),
      p > 0 ? p - 1 : null,
      p < totalPages - 1 ? p + 1 : null,
    );

/// One-shot source over pages 0..totalPages-1. REFRESH loads [startPage];
/// APPEND/PREPEND load the page named by the cursor.
PagingSource<int, String> pagedSource({
  required int startPage,
  required int totalPages,
}) {
  return PagingSource(
    localSource: (params) =>
        Stream.value(pageAt(params.key ?? startPage, totalPages)),
  );
}

class FakeMediator extends RemoteMediator<int, String> {
  FakeMediator(this.onLoad);

  final Future<MediatorResult> Function(LoadType type, int? cursor) onLoad;
  final List<LoadType> calls = [];

  @override
  Future<MediatorResult> load(LoadType loadType, PagingState pagingState) {
    calls.add(loadType);
    return onLoad(loadType, pagingState.nextKey as int?);
  }
}

void main() {
  group('prepend', () {
    test('prepends pages in order until the first page is reached', () async {
      final controller = PagerController<int, String>(
          source: pagedSource(startPage: 2, totalPages: 5));
      controller.initialize();
      await pumpEventQueue();
      expect(controller.items, ['item6', 'item7', 'item8']);

      controller.triggerPrepend();
      await pumpEventQueue();
      expect(controller.items,
          ['item3', 'item4', 'item5', 'item6', 'item7', 'item8']);

      controller.triggerPrepend();
      await pumpEventQueue();
      expect(controller.items, List.generate(9, (i) => 'item$i'));
      expect(controller.loadStates?.prepend.endOfPaginationReached, isTrue);

      controller.dispose();
    });

    test('a non-empty top page with null prevKey does not overwrite the '
        'refresh page', () async {
      final controller = PagerController<int, String>(
          source: pagedSource(startPage: 1, totalPages: 5));
      controller.initialize();
      await pumpEventQueue();
      expect(controller.items, ['item3', 'item4', 'item5']);

      // Page 0 arrives with prevKey == null; it must be inserted in front of
      // the refresh page, not diffed into its slot via the null index key.
      controller.triggerPrepend();
      await pumpEventQueue();
      expect(controller.items,
          ['item0', 'item1', 'item2', 'item3', 'item4', 'item5']);
      expect(controller.loadStates?.prepend.endOfPaginationReached, isTrue);

      controller.dispose();
    });

    test('reactive refresh emissions update the refresh page, not the '
        'prepended page', () async {
      final refreshStream = StreamController<Page<int, String>>();
      final source = PagingSource<int, String>(
        localSource: (params) {
          if (params.key == null) return refreshStream.stream;
          return Stream.value(pageAt(params.key!, 5));
        },
      );
      final controller = PagerController<int, String>(source: source);
      controller.initialize();
      await pumpEventQueue();

      refreshStream.add(pageAt(1, 5));
      await pumpEventQueue();
      expect(controller.items, ['item3', 'item4', 'item5']);

      controller.triggerPrepend();
      await pumpEventQueue();
      expect(controller.items,
          ['item0', 'item1', 'item2', 'item3', 'item4', 'item5']);

      // The refresh query re-emits (e.g. a DB watcher) with changed data.
      // The update must land on the refresh page — now at index 1 — and must
      // not clobber the prepended page at the front.
      refreshStream.add(Page(['item3', 'item4', 'CHANGED'], 0, 2));
      await pumpEventQueue();
      expect(controller.items,
          ['item0', 'item1', 'item2', 'item3', 'item4', 'CHANGED']);

      controller.dispose();
      await refreshStream.close();
    });

    test('empty prepend result without a mediator ends pagination instead of '
        'looping', () async {
      var prependLoads = 0;
      final source = PagingSource<int, String>(
        localSource: (params) {
          if (params.key == null) {
            return Stream.value(Page(['a', 'b', 'c'], 0, null));
          }
          prependLoads++;
          return Stream.value(Page(<String>[], null, null));
        },
      );
      final controller = PagerController<int, String>(source: source);
      controller.initialize();
      await pumpEventQueue();

      controller.triggerPrepend();
      await pumpEventQueue();

      expect(controller.items, ['a', 'b', 'c']);
      expect(controller.loadStates?.prepend.endOfPaginationReached, isTrue);
      // Exactly one local load — no self-re-triggering without a mediator.
      expect(prependLoads, 1);

      controller.dispose();
    });
  });

  group('remote mediator prepend', () {
    test('cache miss triggers a mediator fetch and loads the fetched page',
        () async {
      final store = <int, Page<int, String>>{1: pageAt(1, 3)};
      final mediator = FakeMediator((type, cursor) async {
        switch (type) {
          case LoadType.REFRESH:
            return MediatorResult.success(endOfPaginationReached: false);
          case LoadType.PREPEND:
            if (cursor == null) {
              return MediatorResult.success(endOfPaginationReached: true);
            }
            // "Fetch" the page from the server into the local store.
            store[cursor] = pageAt(cursor, 3);
            return MediatorResult.success(endOfPaginationReached: false);
          case LoadType.APPEND:
            return MediatorResult.success(endOfPaginationReached: true);
        }
      });
      final source = PagingSource<int, String>(
        remoteMediator: mediator,
        localSource: (params) {
          final key = params.key ?? 1;
          return Stream.value(store[key] ?? Page(<String>[], null, null));
        },
      );
      final controller = PagerController<int, String>(source: source);
      controller.initialize();
      await pumpEventQueue();
      expect(controller.items, ['item3', 'item4', 'item5']);

      // Cursor 0 misses the cache → mediator fetches page 0 → the load
      // re-triggers and picks it up.
      controller.triggerPrepend();
      await pumpEventQueue();
      expect(controller.items,
          ['item0', 'item1', 'item2', 'item3', 'item4', 'item5']);
      expect(controller.loadStates?.prepend.endOfPaginationReached, isTrue);
      expect(mediator.calls.where((c) => c == LoadType.PREPEND).length, 2);

      controller.dispose();
    });

    test('mediator prepend errors surface in the combined load states',
        () async {
      final store = <int, Page<int, String>>{1: pageAt(1, 3)};
      final mediator = FakeMediator((type, cursor) async {
        if (type == LoadType.PREPEND) {
          return MediatorResult.error(exception: Exception('boom'));
        }
        return MediatorResult.success(endOfPaginationReached: false);
      });
      final source = PagingSource<int, String>(
        remoteMediator: mediator,
        localSource: (params) {
          final key = params.key ?? 1;
          return Stream.value(store[key] ?? Page(<String>[], null, null));
        },
      );
      final controller = PagerController<int, String>(source: source);
      controller.initialize();
      await pumpEventQueue();

      controller.triggerPrepend();
      await pumpEventQueue();

      expect(controller.items, ['item3', 'item4', 'item5']);
      expect(controller.loadStates?.prepend, isA<Error>());
      // The failed load must not chain into another attempt.
      expect(mediator.calls.where((c) => c == LoadType.PREPEND).length, 1);

      controller.dispose();
    });
  });

  group('scroll boundary', () {
    test('scroll events at exhausted boundaries do not redispatch', () async {
      final mediator = FakeMediator((type, cursor) async =>
          MediatorResult.success(endOfPaginationReached: false));
      final source = PagingSource<int, String>(
        remoteMediator: mediator,
        localSource: (params) => Stream.value(pageAt(0, 1)),
      );
      final controller = PagerController<int, String>(source: source);
      controller.initialize();
      await pumpEventQueue();
      expect(controller.items, ['item0', 'item1', 'item2']);

      var notifications = 0;
      controller.addListener(() => notifications++);

      // Single page with null prevKey and nextKey: scrolling near either
      // boundary must neither notify listeners nor consult the mediator.
      for (var i = 0; i < 5; i++) {
        controller.onScrollPositionChanged(0, 300);
        await pumpEventQueue();
      }

      expect(notifications, 0);
      expect(mediator.calls, [LoadType.REFRESH]);

      controller.dispose();
    });
  });

  group('append', () {
    test('appends pages until the last page is reached', () async {
      final controller = PagerController<int, String>(
          source: pagedSource(startPage: 0, totalPages: 3));
      controller.initialize();
      await pumpEventQueue();
      expect(controller.items, ['item0', 'item1', 'item2']);

      controller.triggerAppend();
      await pumpEventQueue();
      controller.triggerAppend();
      await pumpEventQueue();

      expect(controller.items, List.generate(9, (i) => 'item$i'));
      expect(controller.endOfPaginationReached, isTrue);

      controller.dispose();
    });
  });

  group('LoadStates.combineStates', () {
    LoadStates idle() => LoadStates.idle();

    test('preserves local source errors when a mediator is present', () {
      final local = LoadStates(
          NotLoading(false), Error(Exception('x')), NotLoading(false));
      final combined =
          idle().combineStates(local, idle(), hasMediator: true);
      expect(combined.append, isA<Error>());
    });

    test('surfaces mediator errors', () {
      final remote = LoadStates(
          NotLoading(false), NotLoading(false), Error(Exception('x')));
      final combined =
          idle().combineStates(idle(), remote, hasMediator: true);
      expect(combined.prepend, isA<Error>());
    });

    test('keeps local Loading visible with a mediator', () {
      final local =
          LoadStates(NotLoading(false), Loading(), NotLoading(false));
      final combined =
          idle().combineStates(local, idle(), hasMediator: true);
      expect(combined.append, isA<Loading>());
    });

    test('remote Loading takes precedence', () {
      final remote =
          LoadStates(NotLoading(false), NotLoading(false), Loading());
      final combined =
          idle().combineStates(idle(), remote, hasMediator: true);
      expect(combined.prepend, isA<Loading>());
    });

    test('end of pagination requires both sides with a mediator', () {
      final local =
          LoadStates(NotLoading(false), NotLoading(true), NotLoading(true));
      final remoteOpen =
          LoadStates(NotLoading(false), NotLoading(false), NotLoading(false));
      final remoteEnded =
          LoadStates(NotLoading(false), NotLoading(true), NotLoading(true));

      final open = idle().combineStates(local, remoteOpen, hasMediator: true);
      expect(open.append.endOfPaginationReached, isFalse);
      expect(open.prepend.endOfPaginationReached, isFalse);

      final ended =
          idle().combineStates(local, remoteEnded, hasMediator: true);
      expect(ended.append.endOfPaginationReached, isTrue);
      expect(ended.prepend.endOfPaginationReached, isTrue);
    });

    test('without a mediator local state passes through', () {
      final local =
          LoadStates(NotLoading(false), NotLoading(true), NotLoading(true));
      final combined = idle().combineStates(local, idle());
      expect(combined.append.endOfPaginationReached, isTrue);
      expect(combined.prepend.endOfPaginationReached, isTrue);
    });

    test('local refresh errors are preserved', () {
      final local = LoadStates(
          Error(Exception('x')), NotLoading(false), NotLoading(false));
      final combined =
          idle().combineStates(local, idle(), hasMediator: true);
      expect(combined.refresh, isA<Error>());
    });
  });
}
