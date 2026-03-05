# Pager

A Flutter pagination library for loading data incrementally from local or remote sources. It handles scroll detection, load state management, error recovery, and optional offline-first caching through a remote mediator pattern.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Core Concepts](#core-concepts)
- [Quick Start](#quick-start)
- [PagingSource](#pagingsource)
  - [Basic usage](#basic-usage)
  - [Async generator syntax](#async-generator-syntax)
  - [Operators](#operators)
- [Pager widget](#pager-widget)
  - [Simple usage](#simple-usage)
  - [Accessing state outside the builder](#accessing-state-outside-the-builder)
  - [Inside a CustomScrollView](#inside-a-customscrollview)
- [PagerController](#pagercontroller)
  - [Headless pagination](#headless-pagination)
  - [Available getters](#available-getters)
  - [Actions](#actions)
- [PagingData](#pagingdata)
- [Load States](#load-states)
  - [Handling all states in the builder](#handling-all-states-in-the-builder)
  - [Granular state inspection](#granular-state-inspection)
- [PagingConfig](#pagingconfig)
- [Remote Mediator (offline-first)](#remote-mediator-offline-first)
  - [How it works](#how-it-works)
  - [Implementing a RemoteMediator](#implementing-a-remotemediator)
  - [Reporting the server total](#reporting-the-server-total)
- [Reporting totalItems](#reporting-totalitems)
  - [Via the remote mediator (recommended)](#via-the-remote-mediator-recommended)
  - [Via the Page directly](#via-the-page-directly)
- [Page and PageGroup](#page-and-pagegroup)
- [API Reference](#api-reference)

---

## Features

- Automatic scroll-to-bottom detection — no manual scroll controller wiring required
- Works inside `CustomScrollView` with a simple `scrollController` parameter
- `PagerController` exposes all pagination state as a `ValueNotifier` for reactive UI
- Headless mode — consume paginated data without rendering a widget
- Offline-first support via `RemoteMediator` (fetch → save → read from local DB)
- Server-reported `totalItems` surfaced to the UI before all pages are loaded
- `PagingSource` operators: `sort`, `filter`, `map`, `groupBy`, `take`, `forEach`
- Built-in error handling and retry
- `keepAlive` support for use inside `PageView` / `TabBarView`

---

## Installation

```yaml
dependencies:
  pager:
    git:
      url: https://github.com/donpaul120/pager.git
```

Then import the library:

```dart
import 'package:pager/pager.dart';
```

---

## Core Concepts

| Concept | Role |
|---|---|
| `PagingSource` | Defines how to load a single page of data (from DB, API, etc.) |
| `Page` | The unit of data returned by a `PagingSource` — holds items + next/prev keys |
| `PagerController` | Drives loading, holds all state, exposes it as a `ValueNotifier` |
| `Pager` widget | Thin Flutter widget that wires a `PagerController` to a builder |
| `PagingData` | Snapshot of current items + load states, delivered to the builder |
| `RemoteMediator` | Optional bridge: fetch from network → save to local DB |
| `PagingConfig` | Tuning knobs: page size, prefetch distance |

---

## Quick Start

```dart
// 1. Define a source
final source = PagingSource<int, String>(
  localSource: (params) => Stream.value(
    Page(['Alice', 'Bob', 'Charlie'], null, null),
  ),
);

// 2. Drop the Pager widget anywhere
Pager<int, String>(
  source: source,
  builder: (context, data) {
    if (data.isLoading) return const CircularProgressIndicator();
    if (data.isEmpty)   return const Text('No results');
    return ListView.builder(
      itemCount: data.itemCount,
      itemBuilder: (_, i) => ListTile(title: Text(data.data[i])),
    );
  },
)
```

---

## PagingSource

`PagingSource<Key, Value>` is the contract for loading one page at a time. You provide a `localSource` callback that receives `LoadParams` and returns a `Stream<Page<Key, Value>>`.

- **Key** — the type used to identify pages (e.g. `int` for page numbers, `String` for cursor tokens).
- **Value** — the type of items in each page.

### Basic usage

```dart
final source = PagingSource<int, Transaction>(
  localSource: (params) {
    // params.key      — the key for the page to load (null for the first page)
    // params.loadSize — number of items to fetch (from PagingConfig)
    // params.loadType — REFRESH, APPEND, or PREPEND

    final page = params.key ?? 0;
    return db.watchTransactions(page: page, limit: params.loadSize).map(
      (rows) => Page(
        rows,
        page > 0 ? page - 1 : null,  // prevKey
        rows.length == params.loadSize ? page + 1 : null, // nextKey — null means end
      ),
    );
  },
);
```

> **End-of-pagination signal**: set `nextKey` to `null` on the last page. The library uses this — not the page size — to determine that all data has been loaded.

### Async generator syntax

If your source is one-shot (not reactive), use `async*`:

```dart
final source = PagingSource<int, User>(
  localSource: (params) async* {
    final response = await api.getUsers(page: params.key ?? 0);
    yield Page(response.users, null, response.nextPage);
  },
);
```

### Operators

`PagingSource` provides chainable operators for transforming data. They are marked `@ExperimentalPagingApi()`.

#### `sort`

Sort items within each page. Accepts an optional comparator.

```dart
final source = PagingSource<int, String>(localSource: ...)
    .sort((a, b) => a.compareTo(b));
```

#### `filter`

Keep only items matching a predicate.

```dart
final source = PagingSource<int, Transaction>(localSource: ...)
    .filter((tx) => tx.amount > 0);
```

#### `map`

Transform each item to a different type.

```dart
final PagingSource<int, TransactionViewModel> source =
    PagingSource<int, Transaction>(localSource: ...)
        .map((tx) => TransactionViewModel.from(tx));
```

#### `groupBy`

Group items by a key and produce grouped data. Works with `PageGroupData`.

```dart
final source = PagingSource<int, Transaction>(localSource: ...)
    .groupBy(
      (tx) => tx.date,                         // group key
      (date, items) => TransactionGroup(date, items), // mapper
    );
```

`TransactionGroup` must extend `PageGroupData`. Adjacent pages with the same group key are automatically merged.

#### `take`

Limit the stream to the first N page emissions.

```dart
final source = PagingSource<int, String>(localSource: ...).take(1);
```

#### `forEach`

Side-effect callback invoked with each page's item list. Does not modify the data.

```dart
final source = PagingSource<int, String>(localSource: ...)
    .forEach((items) => print('loaded ${items.length} items'));
```

#### Chaining operators

Operators can be chained freely:

```dart
final source = PagingSource<int, Transaction>(localSource: ...)
    .filter((tx) => tx.status == 'completed')
    .sort((a, b) => b.date.compareTo(a.date))
    .map((tx) => TransactionViewModel.from(tx));
```

---

## Pager widget

`Pager<Key, Value>` is a `StatefulWidget` that wraps a `PagerController` and rebuilds your UI whenever the pagination state changes.

### Simple usage

The most common case — Pager creates and owns its own controller internally:

```dart
Pager<int, Transaction>(
  source: mySource,
  builder: (context, data) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.isEmpty) {
      return const Center(child: Text('No transactions'));
    }
    return ListView.builder(
      itemCount: data.itemCount,
      itemBuilder: (_, i) => TransactionTile(data.data[i]),
    );
  },
)
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `PagingSource<K, T>` | required | The data source |
| `builder` | `Widget Function(BuildContext, PagingData<T>)` | required | Builds the UI from the current paging state |
| `controller` | `PagerController<K, T>?` | `null` | Optional external controller (see below) |
| `pagingConfig` | `PagingConfig` | `PagingConfig.fromDefault()` | Page size and prefetch tuning |
| `keepAlive` | `bool` | `false` | Preserve state in `PageView`/`TabBarView` |
| `scrollController` | `ScrollController?` | `null` | Required only inside a `CustomScrollView` |

### Accessing state outside the builder

Pass your own `PagerController` to read `totalItems`, `isLoading`, etc. outside the builder — for example in an app bar badge or a header.

```dart
class _TransactionsPageState extends State<TransactionsPage> {
  late final _controller = PagerController<int, Transaction>(source: mySource);

  @override
  void dispose() {
    _controller.dispose(); // you own it, you dispose it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (_, data, __) => Text('${data.totalItems} Transactions'),
        ),
      ),
      body: Pager<int, Transaction>(
        source: mySource,
        controller: _controller, // pass it here
        builder: (context, data) => ListView.builder(
          itemCount: data.itemCount,
          itemBuilder: (_, i) => TransactionTile(data.data[i]),
        ),
      ),
    );
  }
}
```

> When you pass a `controller` to the default constructor, Pager uses it but does **not** call `initialize()` or `dispose()` — that is your responsibility.

### Headless — data without a visible Pager widget

Use `Pager.withController` when the controller is owned by a ViewModel or bloc and was already initialized before the widget mounted:

```dart
// In your ViewModel or bloc (outside the widget tree):
final controller = PagerController<int, Transaction>(source: mySource);
controller.initialize();

// In your widget:
Pager.withController(
  controller: controller,
  builder: (context, data) => ListView.builder(
    itemCount: data.itemCount,
    itemBuilder: (_, i) => TransactionTile(data.data[i]),
  ),
)
```

### Inside a CustomScrollView

When `Pager` is placed as a child inside a `CustomScrollView`, scroll notifications travel up through the scroll view and are not visible to `Pager`'s internal `NotificationListener`. Pass the `CustomScrollView`'s `ScrollController` to bridge this gap:

```dart
class _MyPageState extends State<MyPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverAppBar(title: Text('Transactions'), floating: true),
        SliverToBoxAdapter(
          child: Pager<int, Transaction>(
            source: mySource,
            scrollController: _scrollController, // required here
            builder: (context, data) => Column(
              children: data.data.map((tx) => TransactionTile(tx)).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
```

> When `Pager` itself returns a scroll view from `builder` (e.g. a `ListView`), the `scrollController` parameter is not needed — scroll events are detected automatically.

---

## PagerController

`PagerController<K, T>` extends `ValueNotifier<PagingData<T>>`, so it integrates natively with `ValueListenableBuilder` and can be used headlessly without any widget.

### Headless pagination

```dart
final controller = PagerController<int, Transaction>(
  source: mySource,
  pagingConfig: PagingConfig(pageSize: 20),
);

// Start loading
controller.initialize();

// React to changes
controller.addListener(() {
  print('items: ${controller.totalItems}');
  print('loading: ${controller.isLoading}');
});

// Dispose when done
controller.dispose();
```

### Available getters

| Getter | Type | Description |
|---|---|---|
| `totalItems` | `int` | Total items on the server (from API) or count of fetched items if not provided |
| `items` | `List<T>` | Flat list of all currently loaded items |
| `itemCount` | `int` | `items.length` |
| `loadStates` | `CombinedLoadStates?` | Full load state object for fine-grained inspection |
| `isLoading` | `bool` | `true` while the initial/refresh load is in progress |
| `isEmpty` | `bool` | `true` when there is no data and no refresh is in progress |
| `isNotEmpty` | `bool` | `true` when data is present |
| `isAppending` | `bool` | `true` while the next page is being loaded |
| `endOfPaginationReached` | `bool` | `true` when all pages have been loaded |
| `hasError` | `bool` | `true` if the last refresh or append failed |
| `refreshError` | `Exception?` | The exception from the last failed refresh |
| `appendError` | `Exception?` | The exception from the last failed append |

### Actions

| Method | Description |
|---|---|
| `initialize()` | Starts the initial load. Called automatically by `Pager`. |
| `refresh()` | Clears all data and reloads from the first page. |
| `retry()` | Retries after an error — calls `refresh()` for refresh errors, retries the last append for append errors. |

---

## PagingData

`PagingData<T>` is the immutable snapshot delivered to the `builder` callback on every state change. It mirrors all the getters on `PagerController`.

```dart
builder: (context, PagingData<T> data) {
  data.data                  // List<T> — loaded items
  data.totalItems            // int — server total or fetched count
  data.itemCount             // int — data.length
  data.isLoading             // bool
  data.isEmpty               // bool
  data.isNotEmpty            // bool
  data.isAppending           // bool
  data.endOfPaginationReached // bool
  data.hasError              // bool
  data.refreshError          // Exception?
  data.appendError           // Exception?
  data.loadStates            // CombinedLoadStates?
}
```

---

## Load States

### Handling all states in the builder

A complete builder that covers every state:

```dart
builder: (context, data) {
  // Initial load
  if (data.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  // Initial load failed
  if (data.refreshError != null) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Failed to load: ${data.refreshError}'),
          ElevatedButton(
            onPressed: controller.retry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // No data
  if (data.isEmpty) {
    return const Center(child: Text('Nothing here yet'));
  }

  // Data loaded — append states are shown as list footer
  return ListView.builder(
    itemCount: data.itemCount + 1, // +1 for footer
    itemBuilder: (_, i) {
      if (i == data.itemCount) {
        // Footer
        if (data.isAppending) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (data.appendError != null) {
          return TextButton(
            onPressed: controller.retry,
            child: const Text('Load more failed — tap to retry'),
          );
        }
        if (data.endOfPaginationReached) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text("You've reached the end")),
          );
        }
        return const SizedBox.shrink();
      }
      return TransactionTile(data.data[i]);
    },
  );
},
```

### Granular state inspection

For more control, inspect `data.loadStates` directly:

```dart
import 'package:pager/pager.dart';

final states = data.loadStates;

if (states?.refresh is Loading) { /* initial load in progress */ }
if (states?.refresh is NotLoading) { /* idle */ }
if (states?.refresh is Error) {
  final e = (states!.refresh as Error).exception;
}

if (states?.append is Loading) { /* next page loading */ }
if (states?.append.endOfPaginationReached == true) { /* last page */ }

// Separate source vs mediator states (when using RemoteMediator):
states?.source?.refresh   // local DB state
states?.mediator?.refresh // network state
```

**LoadState subclasses:**

| Class | Meaning |
|---|---|
| `Loading` | A load is currently in progress |
| `NotLoading` | Idle. `endOfPaginationReached` is `true` on the last page |
| `Error` | Load failed. Holds the `exception` |

---

## PagingConfig

Tune page sizes and the prefetch trigger distance:

```dart
Pager<int, Transaction>(
  source: mySource,
  pagingConfig: PagingConfig(
    pageSize: 20,          // number of items per append page
    initialPageSize: 40,   // number of items for the first load (can be larger)
    preFetchDistance: 5,   // start loading next page when ≤5 items remain visible
  ),
  builder: (context, data) => ...,
)
```

| Parameter | Default | Description |
|---|---|---|
| `pageSize` | `20` | Items per page for subsequent loads |
| `initialPageSize` | `20` | Items for the very first load |
| `preFetchDistance` | `5` | Trigger next-page load when this many items remain |

---

## Remote Mediator (offline-first)

A `RemoteMediator` is an optional layer that sits between your network API and local database. It lets you show cached data immediately while fetching fresh data in the background — the classic offline-first pattern.

### How it works

```
Scroll event
     │
     ▼
PagerController
     │
     ├─► localSource  (reads from local DB) ──► emits Page to UI
     │
     └─► RemoteMediator.load()
              │
              ├─► fetch from network API
              ├─► save to local DB
              └─► localSource re-emits updated data automatically
```

### Implementing a RemoteMediator

```dart
class TransactionMediator extends RemoteMediator<int, Transaction> {
  final TransactionApi _api;
  final TransactionDao _dao;

  TransactionMediator(this._api, this._dao);

  int? _page;

  @override
  Future<MediatorResult> load(
    LoadType loadType,
    PagingState pagingState,
  ) async {
    try {
      switch (loadType) {
        case LoadType.REFRESH:
          _page = null; // reset to first page
        case LoadType.APPEND:
          _page = pagingState.nextKey as int?;
        case LoadType.PREPEND:
          return MediatorResult.success(endOfPaginationReached: true);
      }

      final response = await _api.getTransactions(page: _page ?? 0);

      if (loadType == LoadType.REFRESH) {
        await _dao.clear();
      }

      await _dao.insertAll(response.items);

      final endOfPagination = response.items.isEmpty ||
          response.items.length < pagingState.pagingConfig.pageSize;

      return MediatorResult.success(
        endOfPaginationReached: endOfPagination,
        totalItems: response.totalCount, // surface server total to UI
      );
    } catch (e) {
      return MediatorResult.error(
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }
}
```

Wire it into your `PagingSource`:

```dart
final source = PagingSource<int, Transaction>(
  localSource: (params) => _dao.watchTransactions(
    limit: params.loadSize,
    offset: (params.key ?? 0) * params.loadSize,
  ).map((rows) => Page(rows, null, rows.isEmpty ? null : (params.key ?? 0) + 1)),
  remoteMediator: TransactionMediator(_api, _dao),
);
```

### Reporting the server total

Return `totalItems` in `MediatorResult.success()` and the controller automatically uses it for `totalItems` instead of the local count:

```dart
return MediatorResult.success(
  endOfPaginationReached: endOfPagination,
  totalItems: response.totalCount, // e.g. 500
);
```

---

## Reporting totalItems

`totalItems` tells the UI how many items exist in total on the server — useful for showing "500 transactions" in a header before all pages are fetched. There are two ways to set it.

### Via the remote mediator (recommended)

Best when using a `RemoteMediator` because the full API response is already available there:

```dart
return MediatorResult.success(
  endOfPaginationReached: endOfPagination,
  totalItems: response.totalCount,
);
```

### Via the Page directly

Best when loading directly from an API without a mediator:

```dart
PagingSource<int, Transaction>(
  localSource: (params) async* {
    final response = await api.getTransactions(page: params.key ?? 0);
    yield Page(
      response.items,
      response.prevPage,
      response.nextPage,
      totalItems: response.totalCount, // ← set here
    );
  },
)
```

**Priority chain** (highest to lowest):

1. `MediatorResult.success(totalItems: ...)` — most authoritative
2. `Page(..., totalItems: ...)` — from the local source
3. Count of locally-fetched items — fallback when neither is set

---

## Page and PageGroup

### Page

```dart
Page<Key, Value>(
  List<Value> data,    // items in this page
  Key? prevKey,        // key of the previous page (null for the first page)
  Key? nextKey,        // key of the next page (null = end of pagination)
  {int? totalItems},   // optional server-reported total
)
```

### PageGroup

For grouped data (used with the `groupBy` operator). Extends `Page` and carries an `originalDataSize` representing the pre-group item count.

```dart
abstract class PageGroupData<K, Value> {
  final K key;           // group key (e.g. a date string)
  final List<Value> items; // items belonging to this group
}
```

```dart
// Example grouped transaction:
class TransactionGroup extends PageGroupData<String, Transaction> {
  TransactionGroup(String date, List<Transaction> items)
      : super(key: date, items: items);
}

final source = PagingSource<int, Transaction>(localSource: ...)
    .groupBy(
      (tx) => tx.formattedDate,
      (date, items) => TransactionGroup(date, items),
    );
```

Adjacent pages sharing the same group key are automatically merged so a group header never appears twice even when items span a page boundary.

---

## API Reference

### Pager

```dart
Pager<K, T>({
  required PagingSource<K, T> source,
  required Widget Function(BuildContext, PagingData<T>) builder,
  PagerController<K, T>? controller,
  PagingConfig pagingConfig,
  bool keepAlive,
  ScrollController? scrollController,
})

Pager.withController({
  required PagerController<K, T> controller,
  required Widget Function(BuildContext, PagingData<T>) builder,
  bool keepAlive,
  ScrollController? scrollController,
})
```

### PagerController

```dart
PagerController<K, T>({
  required PagingSource<K, T> source,
  PagingConfig pagingConfig,
})

void initialize()
Future<void> refresh()
Future<void> retry()
void onScrollPositionChanged(double currentPosition, double maxScrollExtent)
void dispose()
```

### PagingSource

```dart
PagingSource<Key, Value>({
  required Stream<Page<Key, Value>> Function(LoadParams<Key>) localSource,
  RemoteMediator<Key, dynamic>? remoteMediator,
})

PagingSource<Key, Value> sort([int Function(Value, Value)? compare])
PagingSource<Key, Value> filter(bool Function(Value) predicate)
PagingSource<Key, T>     map<T>(T Function(Value) predicate)
PagingSource<Key, Value> groupBy<K, T>(K Function(Value) key, T Function(K, List<Value>) mapper)
PagingSource<Key, Value> take(int limit)
PagingSource<Key, Value> forEach(Function(List<Value>) callback)
```

### MediatorResult

```dart
MediatorResult.success({
  bool endOfPaginationReached,
  int? totalItems,
})

MediatorResult.error({
  required Exception exception,
})
```

### PagingConfig

```dart
PagingConfig({
  int pageSize,
  int initialPageSize,
  int preFetchDistance,
})
```

### LoadParams

```dart
class LoadParams<K> {
  final LoadType loadType; // REFRESH, APPEND, PREPEND
  final K? key;            // page key (null for first page)
  final int loadSize;      // number of items to load
}
```
